---
description: Scaffold a new Source class from a template and register it.
agent: build
---

You are creating a new source implementation for the Lumen Tale project.
The user wants a source for: $ARGUMENTS

Follow these steps:

1. Read `AGENTS.md` and `.opencode/rules/03-source-system.md` first.
2. Look at an existing source in `lib/sources/implementations/` and mirror its structure exactly.
3. Create `lib/sources/implementations/<slug>_source.dart` with a class `<Name>Source` extending `ParsedHttpSource` (or `HttpSource` when the site does not fit declarative selectors).
4. Implement all abstract members:
   - `id` computed from `name`/`lang`/`versionId` (MD5), never hand-written
   - `baseUrl` (no trailing slash), `name`, `lang`, `supportsLatest`, `filterList`
   - popular / search / latest selectors + mappers
   - novel details + chapter list selectors
   - `chapterContentSelector` and `fetchChapterContent`
5. Register the source in `lib/sources/implementations/source_registry.dart`.
6. Create `test/fixtures/sources/<slug>/` with placeholder HTML fixtures and `test/sources/<slug>_source_test.dart` with parsing tests.
7. Run `dart format .`, `flutter analyze`, `flutter test` and fix every issue you introduce.

Do not invent selectors: the live site layout must be verified. If you cannot inspect the live site, mark the selectors with TODO comments and leave the parsing test as a documented stub so a later session can fill them in.
