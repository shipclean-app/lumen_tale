// Lumen Tale — every source this app ships, in one list.
//
// `architecture.md` § 2 and ADR-013: the registry is **static**. There is no dynamic
// extension system in v1 — a source is a plain Dart class listed here, and the list is
// the whole of it.
//
// ## Why Royal Road is first, and FanMTL is absent
//
// `18-external-contracts.md` records FanMTL as answering **403 with a Cloudflare
// challenge** under an honest User-Agent. ADR-014 rejected browser impersonation, and no
// bypass will be built. A source that cannot be read is not in the registry: shipping it
// would put a tab on the reader's screen that reports *every* read as broken, which is
// SC-6's failure at the scale of a whole site.
//
// FanMTL returns in the day its pages answer — that is finding F-012's closing trigger,
// and adding it to this list is the entire fix.
//
// ## E21: a second source is what makes the first one honest
//
// One site means one site's shape, one site's outage and one site's idea of a chapter.
// Royal Road alone is the whole of v1's catalogue until a second answers.

import 'package:lumen_tale/core/network/host_rate_limiter.dart';
import 'package:lumen_tale/core/network/http_client.dart';
import 'package:lumen_tale/core/network/source_endpoint.dart';
import 'package:lumen_tale/core/network/source_http_client.dart';
import 'package:lumen_tale/data/sources/source_manager.dart';
import 'package:lumen_tale/domain/sources/source.dart';
import 'package:lumen_tale/features/browse/browse_repository.dart';
import 'package:lumen_tale/sources/implementations/royal_road_source.dart';

/// Every source this app ships, newest contract first.
List<Source> buildSourceRegistry(HttpClient client) {
  return <Source>[
    RoyalRoadSource(client: client),
    // ⚠️ **No FanMTL.** F-012: 403 with a Cloudflare challenge under an honest
    // User-Agent. ADR-014 rejected browser impersonation and no bypass will be built, so
    // a site that answers 403 is a site that cannot be read.
    //
    // ⚠️ **And no Novel Fire.** `18-external-contracts.md` records it as **UNMEASURED**,
    // not `false` — the honest reading of a challenge under an honest User-Agent.
    // Adding it would be claiming a measurement that was never taken.
  ];
}

/// One registry entry: its endpoint, and how to build the source that speaks to it.
///
/// ⚠️ **A record, so the endpoint and the builder cannot be separated.** A list of URLs keyed
/// by source id would be a second source of truth for *which site is this*, and it would drift
/// from the list the first time a site moved.
typedef SourceEntry = ({
  SourceEndpoint endpoint,
  Source Function(HttpClient) build,
});

/// Every registry entry, newest contract first.
List<SourceEntry> buildSourceEntries() => <SourceEntry>[
  (endpoint: RoyalRoadSource.kEndpoint, build: RoyalRoadSource.build),
];

/// Builds one [HttpClient] per registered source and indexes them by id.
///
/// ## ⚠️ **One client per source, never one shared client**
///
/// `SourceEndpoint` carries a `baseUrl` and `Dio`'s `options.baseUrl` is set on the instance,
/// so a shared client would send one site's paths to whichever host was configured last. That
/// fails as a 404 on a site that is working perfectly — which is SC-6 with extra steps.
///
/// ## ⚠️ **A source that cannot be built does not take the others down** (B23)
///
/// Each entry is built inside its own guard, and a failure simply means that id resolves to
/// nothing — which every caller then reports as a typed `BrowseFailed`, rather than the
/// registry answering *this site has no novels*.
///
/// ## ⚠️ **Built ONCE, at the bootstrap, and shared**
///
/// `main.dart` overrides a provider with this. Building it per screen would re-run every
/// builder on every push, and `05-state-management.md` rule 8 puts a registry in a provider for
/// exactly this reason.
SourceManager buildSourceManager({required String appVersion}) {
  final HostRateLimiter limiter = HostRateLimiter();
  final List<Source> built = <Source>[];

  for (final SourceEntry entry in buildSourceEntries()) {
    try {
      built.add(
        entry.build(
          buildHttpClient(entry.endpoint, limiter, appVersion: appVersion),
        ),
      );
    } on Object {
      // ⚠️ **Swallowed, and B23 is why.** A source that cannot be constructed is a source this
      // build does not ship, and the reader's other sources must not care about it.
    }
  }
  return SourceManager(built);
}

/// A [BrowseRepository] over one [SourceManager].
///
/// ⚠️ **A parameter rather than a second build**, because building the registry twice would
/// give two sets of `Dio` instances for the same sites — two connection pools, two rate
/// limiter states, and a `HostRateLimiter` that no longer throttles the aggregate.
BrowseRepository buildBrowseRepository(SourceManager sources) =>
    BrowseRepository(sourceById: sources.byId);
