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

import 'package:lumen_tale/core/network/http_client.dart';
import 'package:lumen_tale/domain/sources/source.dart';
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
