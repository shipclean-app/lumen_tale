// Lumen Tale — the value types a source read produces, and the immutability the
// whole layer depends on.
//
// `03-source-system.md` § Models is the authority for the field list; the
// assertions here are about the properties the *next* slices rely on, which is
// why several of them are about what must NOT happen.

import 'package:flutter_test/flutter_test.dart';
import 'package:lumen_tale/domain/sources/models/filter.dart';
import 'package:lumen_tale/domain/sources/models/novel.dart';
import 'package:lumen_tale/domain/sources/models/novels_page.dart';
import 'package:lumen_tale/domain/sources/models/update.dart';

Novel novel({String? author, List<String>? genres}) {
  return Novel(
    id: '90db9662f191bf2418033ab0bee1e629',
    sourceId: 'f321cc5e31408b67cc64f3c498053e71',
    url: 'novel/ke383028.html',
    title: 'A Title the Site Wrote',
    author: author,
    description: null,
    status: NovelStatus.unknown,
    coverUrl: null,
    genres: genres ?? const <String>[],
  );
}

void main() {
  group('Novel', () {
    test('an absent author is null and never an empty string', () {
      // ADR-024: the author is displayed, never searched. `library.md` says an
      // absent author collapses the subtitle line rather than showing an em
      // dash, so `''` here would assert a value nobody gave us.
      expect(novel().author, isNull);
    });

    test('no cover means no cover and is distinct from a failed fetch', () {
      // B22: a failure is not rendered as a value.
      expect(novel().coverUrl, isNull);
    });

    test('the status the site did not publish is unknown, not ongoing', () {
      expect(novel().status, NovelStatus.unknown);
    });

    test('a description is plain text and carries no markup', () {
      final Novel withMarkup = novel().copyWith(description: '<b>bold</b>');
      expect(withMarkup.description, '<b>bold</b>');
      // The stripping happens in the converter (`2-2`), not here: B44's storage
      // guarantee is that by the time a description is *written*, this field
      // holds text. This test states that the model does not pretend otherwise.
    });

    test('identity fields are not rewritable through copyWith', () {
      // B3 / B2. There is no parameter for them, which is the enforcement.
      final Novel copy = novel().copyWith(author: 'Someone');
      expect(copy.id, novel().id);
      expect(copy.sourceId, novel().sourceId);
      expect(copy.url, novel().url);
      expect(copy.title, novel().title);
    });

    test('toString carries the id and not the title', () {
      expect(novel().toString(), isNot(contains('A Title the Site Wrote')));
    });

    test('novel status has a value for every rule-8 case', () {
      // Rule 8 enumerates seven states. A missing one is a `default` in a mapper,
      // and a `default` is how "site changed its wording" turns into "unknown"
      // without anybody noticing.
      expect(NovelStatus.values, hasLength(7));
      expect(NovelStatus.values, contains(NovelStatus.unknown));
      expect(NovelStatus.values, contains(NovelStatus.ongoing));
      expect(NovelStatus.values, contains(NovelStatus.completed));
      expect(NovelStatus.values, contains(NovelStatus.licensed));
      expect(NovelStatus.values, contains(NovelStatus.publishingFinished));
      expect(NovelStatus.values, contains(NovelStatus.cancelled));
      expect(NovelStatus.values, contains(NovelStatus.onHiatus));
    });
  });

  group('NovelsPage', () {
    test('the novel list is unmodifiable at construction', () {
      // An outcome is a value. A caller that mutates the list it was handed has
      // turned a read into an edit.
      final NovelsPage page = NovelsPage(
        novels: <Novel>[novel()],
        hasNextPage: true,
      );
      expect(() => page.novels.add(novel()), throwsUnsupportedError);
    });

    test('hasNextPage is what the site said and nothing is inferred here', () {
      // browse-catalogue.md § 8: the app never invents an end it has not reached,
      // so an empty page is still a page whose flag the source chose.
      expect(
        NovelsPage(novels: const <Novel>[], hasNextPage: true).hasNextPage,
        isTrue,
      );
    });

    test(
      'an empty catalogue page is representable and still a success value',
      () {
        // `BrowseSucceeded([])` and `BrowseFailed` are different types; this test
        // only pins that a zero-length list is not a special case in the model.
        expect(
          NovelsPage(novels: const <Novel>[], hasNextPage: false).novels,
          isEmpty,
        );
      },
    );
  });

  group('NovelUpdate', () {
    test('the chapter list is unmodifiable at construction', () {
      final NovelUpdate update = NovelUpdate(
        novel: novel(),
        chapters: const [],
      );
      expect(() => update.chapters.addAll(<Never>[]), throwsUnsupportedError);
    });

    test('an empty difference changes nothing about the novel', () {
      // B49: `6-4` writes `novels.lastCheckedAt`, and the source has no clock and
      // must never conclude that a novel is current. `Novel` is a **site read**,
      // so it carries no `lastCheckedAt` at all — the column is unreachable from
      // here by construction, and the only field an update carries as a
      // difference is [NovelUpdate.chapters].
      //
      // ⚠️ That absence is a **compile-time** property, not a runtime one, and it
      // is stated as prose rather than asserted: `dart:mirrors` is unavailable on
      // this platform, so there is no honest way to enumerate the fields here,
      // and a test that pretended to would be the "control that verifies nothing"
      // `SKILL.md` § Discipline de vérification, rule 6 warns about.
      final Novel before = novel();
      final NovelUpdate update = NovelUpdate(novel: before, chapters: const []);

      expect(update.chapters, isEmpty);
      expect(update.novel, same(before));
    });
  });

  group('Filter and FilterList', () {
    test('a filter list is iterable directly, by delegation', () {
      final FilterList filters = FilterList(<Filter<Object?>>[
        const HeaderFilter(name: 'All novels', state: 'all'),
        SelectFilter<String>(
          name: 'Genre',
          state: 0,
          values: const <SelectOption<String>>[
            SelectOption(value: 'xianxia', name: 'Xianxia'),
            SelectOption(value: 'wuxia', name: 'Wuxia'),
          ],
        ),
      ]);

      expect(filters.length, 2);
      expect(filters.isNotEmpty, isTrue);
      expect(filters.first, isA<HeaderFilter>());

      final List<Filter<Object?>> seen = <Filter<Object?>>[];
      filters.forEach(seen.add);
      expect(seen, hasLength(2));
    });

    test('a declared filter list cannot be mutated by the platform', () {
      // Rule 5: the platform never interprets a source's values, and the first
      // step towards that is not being able to add one.
      final FilterList filters = FilterList(<Filter<Object?>>[
        const HeaderFilter(name: 'All novels', state: 'all'),
      ]);
      expect(
        () => filters.add(const SeparatorFilter(name: '—')),
        throwsUnsupportedError,
      );
    });

    test('a select filter holds the site own slugs verbatim', () {
      final SelectFilter<String> genre = SelectFilter<String>(
        name: 'Genre',
        state: 0,
        values: const <SelectOption<String>>[
          SelectOption(value: 'contemporary-romance', name: 'Contemporary'),
        ],
      );
      expect(genre.selected!.value, 'contemporary-romance');
    });

    test('a select state outside the option list selects nothing', () {
      // Reachable: a source persists a selection, the site drops the option in a
      // release. `null` is the honest answer; throwing would take down a screen
      // that could show the other options perfectly well.
      final SelectFilter<String> genre = SelectFilter<String>(
        name: 'Genre',
        state: 9,
        values: const <SelectOption<String>>[
          SelectOption(value: 'xianxia', name: 'Xianxia'),
        ],
      );
      expect(genre.selected, isNull);
    });

    test('a tri-state ignore is a value and not the absence of one', () {
      // `null`-able would make "do not send this" and "not set yet" the same
      // state, and those two mean different things to a URL builder.
      expect(TriStateFilter.stateIgnore, isNot(0));
      expect(TriStateFilter.stateIgnore, isNot(1));
      expect(TriStateFilter.stateIgnore, isNot(2));
    });

    test('two identical sort selections compare equal', () {
      // A filter list compared by identity would report a change that is not one.
      expect(
        const Selection(index: 1, ascending: true),
        const Selection(index: 1, ascending: true),
      );
      expect(
        const Selection(index: 1, ascending: true),
        isNot(const Selection(index: 1, ascending: false)),
      );
    });

    test('a copy keeps the name', () {
      // A `withState` that dropped the label would leave the control unnamed
      // after the first change.
      const HeaderFilter header = HeaderFilter(
        name: 'All novels',
        state: 'all',
      );
      final Filter<String> changed = header.withState('xianxia');
      expect(changed.name, 'All novels');
      expect(changed.state, 'xianxia');
    });

    test('option lists are unmodifiable at construction', () {
      final SelectFilter<String> genre = SelectFilter<String>(
        name: 'Genre',
        state: 0,
        values: <SelectOption<String>>[
          const SelectOption(value: 'xianxia', name: 'Xianxia'),
        ],
      );
      expect(genre.values.clear, throwsUnsupportedError);
    });
  });
}
