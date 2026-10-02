---
type: design-verdicts
status: approved
generated_at: 2026-10-02
derived_from:
  - .forge/prd.md
  - .forge/benchmarks.md
  - .forge/design/design-system.md
---

# Mihon screen verdicts — every surface, decided

> The instruction was: *".forge/design/screens must eventually contain all Mihon screens, each with a copy/adapt/exclude verdict."* This file is that verdict set.
>
> **Source of truth:** Mihon cloned and read at `db45dda525f6934ad092bb3b2cba5d707b5db50f`. Every row cites the defining file and line in Mihon.

## Method — and a correction to what I assumed

I expected Mihon to use Jetpack Compose Navigation with route strings, because that is the modern default. **It does not.** Mihon uses **Voyager Navigator** (`cafe.adriel.voyager`), with no `Routes.kt`, no `NavHost`, no `composable(route = …)`, and no `ui/navigation/` directory at all (`ui/` has exactly 17 entries, verified). Navigation is `navigator.push / replace / pop / popUntilRoot / popUntil { }`.

This does not change anything in our design — ADR-008 already chose `go_router` over Voyager, and `design-system.md` § 3.5 specifies `go_router` shell routes. It is recorded because the shape of a designer's mind follows their navigation library, and Voyager's model (a stack of `Screen` objects, `twoPane` as a flag) is genuinely a different architecture, not just a different API.

**Scale.** Mihon has **53 Voyager `Screen` subclasses, 9 Activities, ~48 dialogs and bottom sheets, and roughly 135 distinct user-facing surfaces.** Lumen Tale v1 has **18 screens**. That ratio is the point of this file, not an embarrassment to be explained away.

## Verdicts

| Verdict | Meaning |
|---|---|
| **COPY** | We build the same surface, same job. Naming may change |
| **ADAPT** | We build it, but the job changes because our product or our constraints differ |
| **EXTEND** | Mihon has nothing here and we add it anyway — a deliberate addition |
| **EXCLUDE** | We do not build it. The reason is recorded, never just "out of scope" |

---

## 1. Shell and navigation

| Mihon surface | Source | Verdict | Our screen | Why |
|---|---|---|---|---|
| `MainActivity` | `ui/main/MainActivity.kt:129` | **ADAPT** | `app/` bootstrap | Mihon hosts a single Voyager navigator and routes 9 intent types into it (`handleIntentAction` `:524-599`). We have 1 intent type (the launcher) and a `go_router` router. Its global banner channel (`:217-227`) survives as the persistent download status bar |
| `HomeScreen` | `ui/home/HomeScreen.kt:54` | **ADAPT** | shell in `app/` | Owns the tab set and a `TabNavigator`. Its badge computation (`:206-255`) is worth keeping. `isTabletUi()` (`:83-88`) is dropped — ADR-010 |
| `LibraryTab` … `MoreTab` (5) | `ui/{library,updates,history,browse,more}/*Tab.kt` | **COPY** | 5 tabs | **The backbone transfers exactly**, and ADR-018 argues the same order from frequency rather than inheriting it |
| Tab re-tap behaviours | `LibraryTab.kt:79` (settings sheet), `UpdatesTab.kt:49` (download queue), `HistoryTab.kt:57` (**resume last chapter**), `BrowseTab.kt:46` (search), `MoreTab.kt:56` (settings) | **ADAPT** | — | History's "re-tap resumes the last chapter" is **the single best idea in the inventory** and we adopt it verbatim. Browse's re-tap opens search, which we cannot always do (ADR-015) — ours opens the genre index |
| Donation campaign sheet | `MainActivity.kt:361-478` | **EXCLUDE** | — | Asks for money after 30 days' install. The app is personal-use and unshipped (ADR-010). Also it is a modal the user cannot swipe away (`enableImplicitDismiss = false`, `:373`) |
| `CrashActivity` | `ui/../crash/CrashActivity.kt:11` | **EXCLUDE** | — | Mihon ships it in a separate process (`:error_handler`). We send nothing anywhere (B29), so there is no telemetry to crash-report and no Firebase to involve |
| `UnlockActivity` | `ui/security/UnlockActivity.kt:18` | **EXCLUDE** | — | Biometric app lock. The app is personal-use, single-user, with nothing but a local library to protect (B4, ADR-010) |
| `TrackLoginActivity` + `BaseOAuthLoginActivity` | `ui/setting/track/TrackLoginActivity.kt:9` | **EXCLUDE** | — | Six OAuth trackers. Requires an account and a server (B4) |
| `DeepLinkActivity`, `DeepLinkScreen` | `ui/deeplink/*.kt` | **EXCLUDE** | — | Resolves Android `SEARCH`/`SEND` intents. No other app integrates with a personal reader |
| `WebViewActivity` | `ui/webview/WebViewActivity.kt:31` | **EXCLUDE** | — | Exists so the reader stays alive underneath a WebView |
| `ExtensionInstallActivity` | `extension/util/ExtensionInstallActivity.kt:18` | **EXCLUDE** | — | Installs APK extensions. ADR-013: there is no extension system |

---

## 2. Library

| Mihon surface | Source | Verdict | Our screen | Why |
|---|---|---|---|---|
| `LibraryTab` | `ui/library/LibraryTab.kt:65` | **ADAPT** | `library` | Same job. Two changes: Mihon opens categories or one flat list; we lead with a **continue-reading shelf** then the list (ADR-018). Mihon has a "continue reading button" buried in display settings — we make it the first thing on the screen |
| `LibrarySettingsDialog` — **Filter / Sort / Display = 3 pages of ONE sheet** | `presentation/library/LibrarySettingsDialog.kt:42-53` | **ADAPT** | sheet of `library` | **Not three screens.** One tabbed sheet, as Mihon has it. We keep Filter/Sort/Display as three tabs |
| ↳ Filter page: tri-state downloaded/unread/started/bookmarked/completed + per-tracker | `:77-153` | **ADAPT** | filter tab | Same tri-state mechanic. **Per-tracker rows are dropped** — no trackers. Downloaded is forced on in downloaded-only mode (`:84-93`); we keep that, it is a good rule |
| ↳ Sort page: 10 sorts | `:157-215` | **ADAPT** | sort tab | Mihon has Alpha, Total chapters, Last read, Last update, Unread count, Latest chapter, Fetch date, Date added, **Tracker mean**, Random. We drop Tracker mean (no trackers) and Fetch date (an internal timestamp we do not expose — B48 makes counts a local fact, so a fetch-date sort would invite exactly the wrong inference). **We keep Random** — it is a one-line feature and genuinely useful in a large library |
| ↳ Display page: 4 modes, column slider, 5 overlay badges, 2 tab toggles | `:228-297` | **ADAPT** | display tab | 4 display modes carried. Column slider: **we drop the slider** — no tablet means one sensible column count, so a control with one useful value is a control that should not exist |
| `LibraryToolbar` / `LibrarySelectionToolbar` | `presentation/library/components/LibraryToolbar.kt:28,125` | **ADAPT** | `library` | Same two-toolbar switch. Mihon puts a count `Pill` in the title; ours does too |
| `LibraryContent` + 4 layouts (`LazyLibraryGrid`, `LibraryCompactGrid`, `LibraryComfortableGrid`, `LibraryList`) | `…/components/LibraryContent.kt:29` | **COPY** | `library` | Four display modes is the right number and all four survive |
| `LibraryPager` + `LibraryTabs` | `…/LibraryPager.kt:31`, `LibraryTabs.kt:14` | **EXCLUDE** | — | Horizontal category pages. **We have no user-defined categories** — Mihon's own tracker rows in the filter go with them. Without categories there is nothing to swipe between |
| `LibraryBadges` — Downloads / Unread / **Language** | `…/LibraryBadges.kt:13,24,31` | **ADAPT** | `NovelRow` slots | Downloads and Unread survive. **Language badge excluded**: it distinguishes sources, and in our product a novel belongs to exactly one source shown by name (B2), so a language flag is decoration |
| `GlobalSearchItem` | `…/GlobalSearchItem.kt:12` | **ADAPT** | `library` search | Mihon's library search is over title and author. **Ours is title only** — B45 |
| `LibraryBottomActionMenu` | `presentation/manga/components/MangaBottomActionMenu.kt:232` | **ADAPT** | `library` selection | Move category → dropped (no categories). Mark read/unread survives. Download survives, **but B18 changes it**: Mihon offers next 1/5/10/25/unread/bookmarked, we queue the whole novel one chapter at a time |
| ↳ long-press-to-confirm with a 1s haptic window | `:256-264` | **EXCLUDE** | — | A 1-second hold on a bottom-bar action is a hidden gesture. Our anti-references rule out this class of thing |
| `DeleteLibraryMangaDialog` | `presentation/library/DeleteLibraryMangaDialog.kt:19` | **ADAPT** | confirm dialog | Same. But **B32 changes the copy**: removing a novel keeps its downloads, and Mihon's dialog implies deletion of both |
| `ChangeCategoryDialog` | `presentation/category/components/CategoryDialogs.kt:189` | **EXCLUDE** | — | Category assignment. No categories |
| `DownloadDropdownMenu` | `presentation/components/DownloadDropdownMenu.kt` | **ADAPT** | `novel-details` | Mihon's next-1/5/10/25 is worth keeping for the single-chapter case (US-06). Its "bookmarked" variant is dropped — **we have no bookmarks in v1**; that is a scope decision, not an oversight |

**Mihon has no tracking UI on the Library tab.** Verified: the bottom bar is Move category / Mark read / Mark unread / Download / Migrate / Delete (`MangaBottomActionMenu.kt:232-355`), and tracking is reachable only from `MangaScreen` (`:134-140`). Noted so nobody goes looking for it.

---

## 3. Novel details — `MangaScreen`

| Mihon surface | Source | Verdict | Our screen | Why |
|---|---|---|---|---|
| `MangaScreen` | `ui/manga/MangaScreen.kt:64` | **ADAPT** | `novel-details` | The densest screen in both apps. Sections carried: info header, action row, description, chapter header, chapter list. **Dropped: notes section, chapter swipe actions, custom cover editing, fetch interval, tracker row** |
| Description with tappable genres → source genre search | `:141`, `:359-371` | **ADAPT** | `novel-details` → `browse-genre` | **This is the single most important interaction in the inventory for us.** Mihon forwards a novel's genre into the source's search. We forward it into the source's **genre index**, because per ADR-015 a source's search is optional and often absent — and because the owner said passing a novel's own tags back into a site's search bar "ain't satisfying at all". Same tap, correct destination |
| `MangaToolbar`, `SharedMangaBottomActionMenu` | `:293`, `:316`, `:693` | **ADAPT** | `novel-details` | Kept. Download / mark read / remove survive; migrate and track are excluded |
| `MangaCoverDialog` — view / share / save / **edit** / delete custom cover | `presentation/manga/components/MangaCoverDialog.kt:70` | **EXCLUDE** | — | Custom cover upload needs a file picker and storage. B30 forbids moving chapter-adjacent data around |
| `MangaNotesScreen` | `ui/manga/notes/MangaNotesScreen.kt:28` | **EXCLUDE** | — | User-authored notes. Not in the PRD, not personal-use scope |
| `ChapterSettingsDialog` — Filter / Sort / Display, 3 pages of one sheet | `presentation/manga/ChapterSettingsDialog.kt:46,70-76` | **ADAPT** | sheet of `novel-details` | Same shape as the library's, and **B9 requires the chapter list be shown complete and in reading order**, so our default is unsorted-unfiltered with the filters visible. Mihon's "set as default" nested dialog is excluded |
| `ScanlatorFilterDialog` | `…/MangaDialogs.kt:36`→`ScanlatorFilterDialog.kt:36` | **EXCLUDE** | — | Groups scanlation groups for manga. We have no scanlators — the site returns finished chapters |
| `DeleteChaptersDialog` | `presentation/manga/components/MangaDialogs.kt:36` | **ADAPT** | `downloads` | Kept — **B33** makes per-chapter deletion a rule |
| `SetAsDefaultDialog` | `ChapterSettingsDialog.kt:230` | **EXCLUDE** | — | Nested inside an excluded interaction |
| `DuplicateMangaDialog` — already in library from another source | `presentation/manga/DuplicateMangaDialog.kt:81` | **ADAPT** | `novel-details` | **Kept and re-pointed.** Mihon offers Open / Migrate; we offer Open / **Dismiss**, because B40 forbids merging and ADR-010 excludes migration. What survives is the warning itself |
| `MigrateMangaDialog`, `TrackInfoDialog*` (8 Screens), `TrackDateRemoverScreen`, `TrackerRemoveScreen` | `mihon/feature/migration/`, `ui/manga/track/TrackInfoDialog.kt` | **EXCLUDE** | — | Tracking and migration. Both require an account, a server, or an app-to-app transfer (B4, ADR-010) |
| `MissingChapterCountListItem` | `MangaScreenConstants.kt:17` | **ADAPT** | `novel-details` | Kept — it is B22 made visible at chapter granularity |
| `MangaChapterListItem` | `presentation/manga/MangaScreenConstants.kt:17` | **COPY** | `ChapterListTile` | Same job, respecified for our component contract |
| `ChapterDownloadIndicator` | same | **ADAPT** | `ChapterListTile` | Mihon's is a small icon; ours carries a determinate progress line, because B18 is sequential and the reader needs to see the queue's position |

---

## 4. Updates

| Mihon surface | Source | Verdict | Our screen | Why |
|---|---|---|---|---|
| `UpdatesTab` / `UpdateScreen` | `ui/updates/UpdatesTab.kt:35`, `presentation/updates/UpdatesScreen.kt:47` | **ADAPT** | `updates` | Same feed, grouped by day. **B35 changes one thing materially**: Mihon has an update *interval* setting; ours is off by default and never automatic, so this screen's manual action is the primary path, not a supplement |
| `UpdatesFilterDialog` — Filter + Categories, 2 tabs | `presentation/updates/UpdatesFilterDialog.kt:41,45-51` | **ADAPT** | sheet of `updates` | Filter tab survives; **Categories tab excluded** |
| `UpdatesDeleteConfirmationDialog` | `…/UpdatesDeleteConfirmationDialog.kt:11` | **EXCLUDE** | — | Deleting update records is a housekeeping act with no meaning without scheduled checks |
| `UpcomingScreen` — month calendar of upcoming releases | `mihon/feature/upcoming/UpcomingScreen.kt:38` | **EXCLUDE** | — | Japanese manga release calendar. Web novels are serialised without announced dates. **There is no data to draw** |
| `UpcomingFilterDialog` | same `:119` | **EXCLUDE** | — | Same |
| `DownloadQueueScreen` | `ui/download/DownloadQueueScreen.kt:62` | **ADAPT** | `downloads` | Kept, and **it is reachable from Updates on re-tap in Mihon (`:49-51`); ours puts it in More** (ADR-018). Mihon's play/pause FAB with scroll-driven expansion (`:76-96`) is a nice touch we keep |
| `DownloadAdapter` / `DownloadHolder` / `DownloadHeaderHolder` | `ui/download/` | **COPY** | `downloads` | Per-item rows with headers. Mihon is a RecyclerView; ours is a list |

---

## 5. History

| Mihon surface | Source | Verdict | Our screen | Why |
|---|---|---|---|---|
| `HistoryTab` / `HistoryScreen` | `ui/history/HistoryTab.kt:39`, `presentation/history/HistoryScreen.kt:33` | **ADAPT** | `history` | Same list. **B47 changes the bound**: Mihon has no time bound, ours is one year, configurable and clearable — and the screen must say so rather than implying endless scroll |
| ↳ "Resume" per entry (`getNextChapterForManga`) | `:68-76` | **COPY** | `history` | Adopted. Resume-from-history is exactly B46's distinction working correctly |
| ↳ re-tap tab resumes last chapter | `:57-59` | **COPY** | — | Verbatim adoption |
| ↳ long-press overflow: Add to library / Migrate / Edit categories | `:107-125` | **ADAPT** | `history` | Add to library survives. Migrate and categories excluded |
| `HistoryDeleteDialog` / `HistoryDeleteAllDialog` | `presentation/history/components/HistoryDialogs.kt:22,63` | **COPY** | `history` | Kept, plus B47's "clear all" is what the retention setting needs |

---

## 6. Browse

### 6.1 Sources

| Mihon surface | Source | Verdict | Our screen | Why |
|---|---|---|---|---|
| Sources sub-tab / `SourcesScreen` | `ui/browse/source/SourcesTab.kt:26`, `presentation/browse/SourcesScreen.kt:42` | **ADAPT** | `browse-sources` | **The pinned-first ordering survives.** Mihon shows per-language latest-chapter counts per source; we show the source's status and genre count instead, because a count implies a check we may not have run (B48) |
| `BrowseSourceScreen` — one source's listings | `ui/browse/source/browse/BrowseSourceScreen.kt:67` | **ADAPT** | `browse-genre` + `browse-catalogue` | Mihon's Popular/Latest/Other `FilterChip` row becomes our **genre index**, because ADR-015 makes genre browsing the real discovery path. Its WebView button is excluded. Its **source-settings button survives** → our `sources` screen |
| `BrowseSourceToolbar`, `BrowseSourceContent`, 3 layouts, `BaseBrowseItem`, `BrowseBadges`, `ExtensionPill`, `ContentWarningLabel` | `ui/browse/source/browse/…` | **ADAPT** | `browse-catalogue` | 3 layouts carried. `ExtensionPill` excluded (no extensions). `ContentWarningLabel` excluded — **we have no content warnings and cannot invent a rating system** |
| ↳ two-stage up-navigation (clear query, then pop) | `:85-90` | **ADAPT** | — | Adopted; it is the correct behaviour for a screen with a search field |
| `SourceOptionsDialog` — Pin / Disable | `presentation/browse/SourcesScreen.kt:165` | **ADAPT** | `browse-sources` | Pin survives. Disable survives — and its copy must say **downloaded chapters are kept** (B32) |
| `SourceFilterDialog` — **generic renderer of `Source.filterList`** | `ui/browse/source/browse/SourceFilterDialog.kt:34-60` | **COPY** | `browse-genre` | **The best idea in the Browse group and we adopt the mechanism exactly.** Checkbox / tri-state / select / sort / text items under collapsible headings, with a sticky reset+apply header. This is how any source contributes filters with zero platform code — and B41's "the platform never interprets filter values" is enforced structurally by this design, not by discipline |
| `SourcesFilterScreen` — language multi-select + per-source tri-state | `ui/browse/source/SourcesFilterScreen.kt:17` | **EXCLUDE** | — | Language filtering across many sources. We have three sources, one language each (B1) |
| `MissingSourceScreen` | `presentation/browse/BrowseSourceScreen.kt:150` | **ADAPT** | `source-unavailable` | Different cause, same job. Mihon shows it when the *extension* was removed; ours shows it when the **site** cannot be read (B22) — and ours must distinguish four causes, which Mihon does not |
| `RemoveMangaDialog` | `presentation/browse/components/BrowseSourceDialogs.kt:12` | **EXCLUDE** | — | Removes an item from a listing. No meaning without trackers |
| `GlobalSearchScreen` — searches **all enabled sources at once**, grouped per source | `ui/browse/source/globalsearch/GlobalSearchScreen.kt:19` | **EXCLUDE** | — | Cross-source search needs every source to support search. **FanMTL does not**, and Royal Road and Novel Fire are unmeasured. Also its single-result `replace`-with-`MangaScreen` shortcut (`:33-54`) is clever but depends on the search working |

### 6.2 Extensions

| Mihon surface | Source | Verdict | Our screen | Why |
|---|---|---|---|---|
| Extensions sub-tab / `ExtensionScreen` | `ui/browse/extension/ExtensionsTab.kt:28`, `presentation/browse/ExtensionsScreen.kt:86` | **EXCLUDE** | — | ADR-013: sources are a **static Dart registry**, so there is nothing to install, update, uninstall or trust. Mihon's install progress bars, sideload warnings and private-extension confirmations all evaporate |
| `ExtensionDetailsScreen` | `ui/browse/extension/details/ExtensionDetailsScreen.kt:16` | **EXCLUDE** | — | Lists the sources an extension provides. No extensions |
| `ExtensionDetailsScreen` ▸ per-source enable/disable, **incognito toggle**, **clear cookies** | `:40-44` | **ADAPT** | `sources` | The **enable/disable grid survives** as our `sources` screen — that part is source management, not extension management. Incognito and clear-cookies excluded: incognito needs an account concept, cookies exist because of Mihon's Cloudflare `cf_clearance` harvest, which **ADR-014 deliberately does not port** |
| `SourcePreferencesScreen` — a `PreferenceFragmentCompat` hosted in Compose | `ui/browse/extension/details/SourcePreferencesScreen.kt:47` | **ADAPT** | `sources` | **The capability survives, the technology does not.** `03-source-system.md` rule 6 keeps `ConfigurableSource` (shared_preferences namespaced `source_<id>`) and requires a settings UI. In Flutter that is a `dynamic_settings` section on the `sources` screen, not a nested Android fragment |
| `ExtensionFilterScreen` | `ui/browse/extension/ExtensionFilterScreen.kt:18` | **EXCLUDE** | — | Language filter over extensions |
| `ExtensionStoresScreen` + 3 dialogs | `ui/more/settings/screen/browse/ExtensionStoresScreen.kt:20` | **EXCLUDE** | — | Extension repositories. None exist |
| `ExtensionUninstallConfirmation`, `ExtensionInstallErrorDialog`, `ExtensionNotLoadedDialog`, `ExtensionTrustDialog`, `ContentWarningDialog` | `ExtensionsTab.kt:111`, `ExtensionsScreen.kt:309,730,781`, `ExtensionDetailsScreen.kt:459` | **EXCLUDE** | — | Five dialogs, all about the extension lifecycle |
| `WebViewScreen` / `WebViewScreenContent` | `ui/webview/WebViewScreen.kt:15` | **EXCLUDE** | — | In-app browser with source headers. It exists partly for sites we cannot parse; **B22 makes an honest error message the correct answer**, and a WebView would be a way to avoid writing that message |

### 6.3 MigrateSource

| Mihon surface | Source | Verdict | Our screen | Why |
|---|---|---|---|---|
| `MigrateSourceTab` / `MigrateSourceScreen` — sources ranked by migratability | `ui/browse/migration/sources/MigrateSourceTab.kt:21` | **EXCLUDE** | — | Migration is out of scope (ADR-010) |
| `MigrateMangaScreen` | `ui/browse/migration/manga/MigrateMangaScreen.kt:42` | **EXCLUDE** | — | Step 2 of a 4-step flow |
| `MigrationConfigScreen` + `MigrationConfigScreenSheet` | `mihon/feature/migration/config/*.kt` | **EXCLUDE** | — | Step 3, with drag-to-prioritise target sources |
| `MigrationListScreen` + 3 dialogs | `mihon/feature/migration/list/*.kt` | **EXCLUDE** | — | Step 4. The `addMatchOverride` mechanism (`:26-28`) is genuinely elegant and still has no use here |
| `MigrateSearchScreen`, `MigrateSourceSearchScreen` | `ui/browse/migration/search/*.kt` | **EXCLUDE** | — | Search used only to find migration targets |
| `MigrateMangaDialog`, `MigrationMangaDialog`, `MigrationProgressDialog`, `MigrationExitDialog` | `mihon/feature/migration/**` | **EXCLUDE** | — | — |

**One honest note:** this is **11 screens and 4 dialogs** removed by a single decision. It is also the largest single simplification available to us, and it removes the feature whose data model (per-source partial matches, `MigrationFlag`) is the most intricate in Mihon.

---

## 7. More, stats, settings

| Mihon surface | Source | Verdict | Our screen | Why |
|---|---|---|---|---|
| `MoreTab` / `MoreScreen` | `ui/more/MoreTab.kt:42`, `presentation/more/MoreScreen.kt:32` | **ADAPT** | `more` | The overflow list. **Mihon's two global switches are both excluded:** *Downloaded only* (`:90`) is a filter we get from the library's own filter sheet, and *Incognito mode* (`:91`) needs an identity concept |
| `StatsScreen` + content | `ui/stats/StatsScreen.kt:18` | **ADAPT** | `stats` | Kept — it is cheap once history exists. But it must be re-framed: reading time, entries per source, chapter distribution, averages. **No streaks, no goals, no achievements** — that is our explicit anti-reference against the competitor model |
| `SupportUsScreen` | `mihon/feature/support/SupportUsScreen.kt:40` | **EXCLUDE** | — | Patreon / OpenCollective / Discord. Personal use, unshipped |
| `CategoryScreen` + 3 dialogs | `ui/category/CategoryScreen.kt:21` | **EXCLUDE** | — | User-defined categories with drag-reorder. Our genres come from the sources |
| `SettingsScreen` (wrapper) + 2-pane `TwoPanelBox` | `ui/setting/SettingsScreen.kt:26,56-79` | **ADAPT** | `settings` | Same indirection, minus the tablet branch (ADR-010) |
| `SettingsMainScreen` — **10 category rows** | `presentation/more/settings/screen/SettingsMainScreen.kt:52,173-236` | **ADAPT** | `settings` | Mihon: Appearance, Library, Reader, Downloads, Tracking, Browse, Data & storage, Security, Advanced, About. Ours: **Appearance, Reader, Downloads, Library, Sources, History, Language, About** — 8. Tracking and Security have no content for us (B4, personal use). Data & storage becomes a per-source storage row inside Downloads |
| `SettingsSearchScreen` + `SearchableSettings` interface | `…/SettingsSearchScreen.kt:60`, `SearchableSettings.kt:12` | **EXCLUDE** | — | Full-text search across 9 settings screens. With 8 settings screens of ~30 rows total, a search index over it is more machinery than it saves |
| `SettingsAppearanceScreen` | `…/SettingsAppearanceScreen.kt:31` | **ADAPT** | `settings` | Theme (kept, **B26**), pure-black dark (**excluded** — ADR-016 gives night its own cool ink, and pure black raises halation), tablet UI mode (**excluded**, ADR-010), language (kept, **B28**), date format and relative format (kept — history is time-bounded by **B47**, so a relative timestamp is on the critical path) |
| `SettingsLibraryScreen` | `…/SettingsLibraryScreen.kt:41` | **ADAPT** | `settings` | Category rows excluded. `pref_library_update_interval` **survives but defaults to off** (**B35**) |
| `SettingsReaderScreen` — 6 groups incl. Pager viewer, Webtoon viewer, Reader navigation | `…/SettingsReaderScreen.kt:21` | **ADAPT** | `settings-reader` | Text size and theme survive (**B27**, **B26**). **Pager viewer and Webtoon viewer groups excluded wholesale** — they configure image scaling, zoom, crop, dual-page split and page rotation, which have no meaning for continuous text. Reader navigation (volume keys, vertical navigator) excluded |
| `SettingsDownloadScreen` | `…/SettingsDownloadScreen.kt:24` | **ADAPT** | `settings` | WiFi-only survives. **`save_chapter_as_cbz` excluded** — we store Markdown, and CBZ is a comic archive. `split_tall_images` excluded. **Concurrency is forced to 1 by B18**, so both concurrency preferences are excluded rather than exposed as a choice we do not offer. Delete-after-read survives only as an explicit per-chapter action (**B33**) |
| `SettingsTrackingScreen` | `…/SettingsTrackingScreen.kt:67` | **EXCLUDE** | — | Tracker login. B4 |
| `SettingsBrowseScreen` | `…/SettingsBrowseScreen.kt:22` | **ADAPT** | `settings` | Reduce to a link to the `sources` screen. Extension-store row and content-warning toggles excluded |
| `SettingsDataScreen` | `…/SettingsDataScreen.kt:75` | **EXCLUDE** | — | **Backup, restore, storage-location picker, cache clearing, library export.** Every one is blocked: **B30** forbids moving chapter data out of the app and **ADR-010** is personal-use with no backup. This is the group where the owner's scope decision costs the most, and `coverage.md` records it as an absence with a reason rather than an omission |
| `CreateBackupScreen`, `RestoreBackupScreen` | `…/screen/data/*.kt` | **EXCLUDE** | — | Same |
| `SettingsSecurityScreen` | `…/SettingsSecurityScreen.kt:22` | **EXCLUDE** | — | Biometrics, secure screen, hide notification content. And **Firebase Crashlytics + Analytics** (`:100`) — directly forbidden by B29 |
| `SettingsAdvancedScreen` | `…/SettingsAdvancedScreen.kt:63` | **EXCLUDE** | — | Dump crash logs, verbose logging, debug info, Shizuku installer, DoH providers, high-quality renderer. Developer surfaces for a shipped product |
| `SettingsSearchScreen`'s `WorkerInfoScreen`, `BackupSchemaScreen`, `DebugInfoScreen` | `…/screen/debug/*.kt` | **EXCLUDE** | — | Debug dumps |
| `ClearDatabaseScreen` | `…/advanced/ClearDatabaseScreen.kt:69` | **EXCLUDE** | — | Bulk DB wipe per source. **B33's per-chapter delete covers the legitimate case**; a bulk wipe is a footgun in an app with no backup |
| `AppLanguageScreen` | `…/appearance/AppLanguageScreen.kt:36` | **COPY** | `settings` | Language picker applying immediately. **B28** |
| `AboutScreen` | `…/screen/about/AboutScreen.kt:66` | **ADAPT** | `settings-about` | Version row and check-for-updates survive (**B43**, **B31**). Open-source licences → we have 24 dependencies and do owe attribution, so this is kept. **Privacy policy, social icons and What's New excluded.** But **our about screen gains what Mihon's lacks: the guarantee that an upgrade never destroys the library (B31)**, which `benchmarks.md` § 2.3 shows is the competitor's single worst-documented failure |
| `NewUpdateScreen` | `ui/more/NewUpdateScreen.kt:14` | **ADAPT** | `settings-about` | Mihon downloads and installs an update **in-app**. **Ours must not**: ADR-011 has CI produce an APK the owner installs themselves (**B31**). So the screen's job becomes *announcing* a build, not fetching one |

---

## 8. Reader — the deepest area, and the most divergent

| Mihon surface | Source | Verdict | Our screen | Why |
|---|---|---|---|---|
| `ReaderActivity` | `ui/reader/ReaderActivity.kt:105` | **ADAPT** | `reader` | Same hybrid View+Compose shape. It also finishes itself when incognito is switched off (`:188-191`) and applies forced orientation (`:229-231`) — both excluded |
| `PagerViewer` on legacy `androidx.viewpager.widget.ViewPager` | `ui/reader/viewer/pager/PagerViewer.kt:31` | **EXCLUDE** | — | **The pager is an image pager.** Our content is text in a continuous scroll (**ADR-009**), so the entire pager stack — `Pager`, `PagerConfig`, `PagerViewerAdapter`, `PagerPageHolder`, `PagerTransitionHolder`, `L2RPagerViewer`, `R2LPagerViewer`, `VerticalPagerViewer` — has no counterpart |
| `WebtoonViewer` on `RecyclerView` | `…/viewer/webtoon/WebtoonViewer.kt` | **ADAPT** | `reader` prose column | This is the one viewer that maps: a vertically scrolling continuous surface. Ours is simpler — no image subsampling, no gap, no double-tap zoom, no side padding |
| `WebGpuViewer` / `WebGpuViewerContinuous` | `…/viewer/webgpu/` | **EXCLUDE** | — | A high-quality image renderer behind a feature flag |
| `ReadingMode` — 6 modes | `ui/reader/setting/ReadingMode.kt:17-60,72-91` | **EXCLUDE** | — | LTR, RTL, Vertical, Webtoon, Continuous vertical, Default. **All six are image or manga modes. ADR-009 gives v1 one mode.** `benchmarks.md` § 2.2 records that competitors ship flipping, sliding *and* scrolling — the parity gap is real and recorded |
| `ReaderTopBar` — title + subtitle, bookmark, WebView/browser/share overflow | `…/reader/appbars/ReaderTopBar.kt:15` | **ADAPT** | `ReaderControls` | Mihon's top bar **shows the novel title permanently**. Ours shows it inside the tap-revealed controls, and **there is no top bar** — a title bar spends a row of the smallest screen in the app naming a novel the reader just tapped |
| `ReaderBottomBar` — 4 buttons: reading mode, orientation, crop borders, settings | `…/reader/appbars/ReaderBottomBar.kt:21` | **ADAPT** | `ReaderControls` | Mihon's 4 buttons are **reading mode / orientation / crop borders / settings** — three of the four are about images. Ours: **size, theme, chapter list, back** |
| `ChapterNavigator` + `HorizontalChapterNavigator` + `VerticalChapterNavigator` | `…/reader/components/ChapterNavigator.kt:66,156,246` | **ADAPT** | `ReaderControls.progressSlider` | Kept, simplified. One detail worth stealing: it **forces `LocalLayoutDirection.Ltr`** and then overrides per-isRtl (`:175-197`) because RTL reading order must not follow the system direction. We have no RTL source in v1, so it is deferred with the mode work |
| `ReaderPageActionsDialog` — Set as cover / Copy / Share / Save | `…/reader/ReaderPageActionsDialog.kt:29` | **EXCLUDE** | — | All four are image actions, and **Share and Save are forbidden by B30** |
| `SetCoverDialog` | same `:90` | **EXCLUDE** | — | Same |
| `ReaderSettingsDialog` — **Reading mode / General / Custom filter**, 3 tabs | `…/reader/settings/ReaderSettingsDialog.kt:22,28-32` | **ADAPT** | `settings-reader` | Its **General** page survives in spirit. The **Reading mode** and **Custom filter** pages are excluded wholesale. One genuinely good detail kept: while on the colour-filter tab it sets the window dim to 0 and hides the menus (`:47-55`) so the tint can be judged live |
| `ReadingModePage` + `PagerViewerSettings` + `WebtoonViewerSettings` + `WebGpuViewerSettings` + `TapZonesItems` | `…/settings/ReadingModePage.kt:31,122,199,297,267` | **EXCLUDE** | — | Five sub-blocks, every one configuring an image viewer |
| `GeneralSettingsPage` — reader theme, page number, vertical navigator, fullscreen, cutout, keep-screen-on, **page flash** + 3 sliders, transitions | `…/settings/GeneralSettingsPage.kt:36` | **ADAPT** | `settings-reader` | Kept: reader theme (**B26**), keep-screen-on, show-chapter-position. Excluded: vertical navigator, cutout, page flash and its three sliders, transition animation — all page-turn machinery |
| `ColorFilterPage` — custom brightness, 4 RGBA sliders, filter mode, greyscale, inverted | `…/settings/ColorFilterPage.kt:24` | **EXCLUDE** | — | Five controls for tinting images. ADR-009 defers colour filters to v2 |
| `ReadingModeSelectDialog`, `OrientationSelectDialog`, `ModeSelectionDialog` | `ui/reader/ReadingModeSelectDialog.kt:32`, `OrientationSelectDialog.kt:30`, `components/ModeSelectionDialog.kt:29` | **EXCLUDE** | — | Three sheets to pick a mode we do not have. `ModeSelectionDialog`'s **Revert-to-default + Apply** pattern is worth remembering for the v2 mode work |
| `ReaderNavigationOverlayView` | `ui/reader/ReaderNavigationOverlayView.kt:19` | **EXCLUDE** | — | A debug overlay drawing the tap zones. Not shipped |
| `ViewerNavigation` — 5 regions, `getAction` **falls back to `MENU` on any miss** | `ui/reader/viewer/ViewerNavigation.kt:11,44-53` | **ADAPT** | `TapLayer` | The region model transfers: left edge / centre / right edge. **The fallback is the part to keep in mind** — Mihon turns an unrecognised tap into "show the menu", which is the right default for a mis-aimed tap |
| 6 tap-zone schemes (`default`, `l_nav`, `kindlish_nav`, `edge_nav`, `right_and_left_nav`, `disabled`) | `ui/reader/setting/ReaderPreferences.kt:293-300` | **EXCLUDE** | — | Six schemes for six image viewers. Ours is fixed: edges change chapter, centre reveals chrome |
| Reader "Loading" `AlertDialog`, `ReaderPageIndicator`, `ReaderProgressIndicator` | `ReaderActivity.kt:279-293`, `…/ReaderPageIndicator.kt`, `…/viewer/ReaderProgressIndicator.kt` | **ADAPT** | `LoadingState`, `ReaderControls` | **Mihon's loading alert is non-dismissable** (`:279-293`). Ours must not block the reader — a skeleton that looks like prose. Its "3 / 20" page indicator becomes our chapter-position label |

### 8.1 What we add that Mihon does not have

| Our addition | Where | Why |
|---|---|---|
| **Reader chapter-list sheet** | `reader-chapter-sheet` | **A genuine Mihon absence.** Verified across all 616 lines of `ReaderActivity.kt`, all 17 files in `presentation/reader/**`, `ReaderAppBars.kt` and `ChapterNavigator.kt`: to change chapters from inside the reader you must tap the title, leave for `MangaScreen`, and pick a chapter. Mihon has only prev/next buttons and a page slider. For a 300-chapter novel on a small screen that is a real cost, and we add the sheet |
| **Text-size control in the reader chrome** | `ReaderControls.sizeButton` | Mihon has no font-size control in the reader — only in settings. **B27 asks for an adjustable size, and the reader's own chrome is where a reader reaches for it.** Benchmarks § 2.2 records both competitors offering full text customisation in-reader |
| **Theme switch in the reader chrome** | `ReaderControls.themeButton` | Mihon has reader theme in settings only. `benchmarks.md` § 2.2 records Dreame's dark mode being hard to find; one tap from the reading surface is the deliberate answer |
| **Offline-first framing** | `reader` states | Mihon has no offline state at all. **It is our entire product** (SC-2) |

---

## 9. The counts, honestly

| | Mihon | Lumen Tale v1 |
|---|---|---|
| Voyager `Screen` subclasses | 53 | — (go_router routes) |
| Activities | 9 | 1 |
| Dialogs / bottom sheets | ~48 | ~10 |
| **Total user-facing surfaces** | **~135** | **18** |
| Settings screens | 23 | 4 |

**What the 18 are:** `library` · `novel-details` · `updates` · `history` · `browse-sources` · `browse-genre` · `browse-catalogue` · `downloads` · `sources` · `more` · `stats` · `settings` · `settings-reader` · `settings-about` · `reader` · `reader-chapter-sheet` · `source-unavailable` · `onboarding`

### The four decisions that removed most of it

1. **ADR-010, personal use.** Removed backup, restore, export, security, trackers, support-us and the donation sheet — **24 screens and dialogs** with one decision. The cost is real: the reader has no safety net for their library, mitigated only by B31 guaranteeing the app never destroys it. `benchmarks.md` § 2.3 is the evidence that this is a cost worth paying and `coverage.md` records it as an absence with a reason.
2. **ADR-013, static source registry.** Removed the entire Extensions tree — **~14 surfaces** — and MigrateSource — **15 more**. It also converts Extensions' per-source enable/disable into the plain `sources` screen, which is source management wearing an extension costume.
3. **ADR-009, continuous scroll only.** Removed the pager stack, all six reading modes, three mode/orientation selection sheets, and the entire Pager/Webtoon/WebGPU settings. **~20 surfaces.** This is the largest single deferral and it has a real cost: competitors ship three modes today.
4. **B30 + no image content.** Removed every page action, custom cover, share, and every image-viewer setting. **~12 surfaces.**

### What we did NOT take from Mihon

- **No notes, no bookmarks in v1.** Both are Mihon features and neither is in the PRD.
- **No user-defined categories.** Mihon's most-used organisation feature. Ours come from the sources, which is a real reduction in control and is recorded as such rather than disguised.
- **No random-manga exclusion** — we kept it, because it is one line and genuinely useful.
- **No Cloudflare cookie harvesting** (ADR-014). Mihon's `CloudflareInterceptor` grows the bypass surface; ours declines it, and `17-security.md` rule 5 carries the measured measurement showing why.

### What Mihon has that we should reconsider

Three things in this inventory look like they earn their place, and they are **not** in the current v1:

| Mihon feature | Source | The case for it |
|---|---|---|
| **History's "Resume" per entry** | `HistoryTab.kt:68-76` | Already **adopted** — copied. Listed here because it is the template for the others |
| **Re-tap tab to resume the last chapter** | `HistoryTab.kt:57-59` | Already **adopted** — copied |
| **`SourceFilterDialog`'s generic filter renderer** | `SourceFilterDialog.kt:34-60` | Already **adopted** — copied, and it is the mechanism that makes ADR-013 cheap |
| **Page slider with prev/next chapter buttons** | `ChapterNavigator.kt:66` | Already **adopted** |
| **One-item "continue reading" on the library row** | `LibraryToolbar.kt:267-287` | Already **adopted** and promoted to the top of the screen |
| **Random novel** | `LibrarySettingsDialog.kt:186-195` | Already **adopted** |
| **Per-series reader settings** | `ReadingModePage.kt:32` | Real value — orientation and size per novel rather than globally. **Worth a v2 look**; v1 keeps size and theme global because B27/B26 do not require per-novel |
| **Mihon's two-stage up-navigation** | `BrowseSourceScreen.kt:85-90` | Already **adopted** |