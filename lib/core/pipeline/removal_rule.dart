// Lumen Tale — one element to drop, and why.
//
// `04-html-to-markdown.md` rule 2: **cleaning is per source.** The shared cleaner removes
// what every page contains; a source declares in addition what is its own.
//
// ## `why` is never empty, and that is the rule
//
// A removal nobody can justify is a removal nobody should be able to change without
// thinking. `0-4` produces this list from real captured pages and records each entry in
// `18-external-contracts.md`; this type makes "no reason" unrepresentable rather than
// merely discouraged.
//
// ## A removal is by SELECTOR, never by text content
//
// "The paragraph that begins with…" is a rule that breaks at the first chapter an author
// writes differently, and it breaks by *deleting prose*. A CSS selector breaks when the
// site changes its furniture, which `18-external-contracts.md` is for.

/// One element to drop.
final class RemovalRule {
  const RemovalRule({
    required this.selector,
    required this.why,
    this.matchesSubtree = true,
  });

  /// A CSS selector, per `package:html`.
  final String selector;

  /// Why this element is furniture. **Never empty.**
  ///
  /// Developer-facing, and never reaches a user-visible surface (B28) — a reader does not
  /// need to know that a `div.share-buttons` was dropped, they need the chapter.
  final String why;

  /// When true the whole subtree goes; when false only the element's own tags go and its
  /// text stays.
  ///
  /// ⚠️ **`true` for `<script>` and `<style>`, and that is the whole reason the flag
  /// exists**: their text is code, not prose. Dropping only the tags would leave a
  /// reader staring at a page of JavaScript.
  final bool matchesSubtree;
}

/// What the source hands over, per call.
final class ConversionRequest {
  const ConversionRequest({
    required this.rawHtml,
    required this.baseUrl,
    this.additionalRemovals = const <RemovalRule>[],
    this.keepImages = false,
  });

  /// The article HTML returned by `2-1`. **Already extracted** — rule 1: *extract first,
  /// convert after*. Never convert a whole page.
  ///
  /// The source's own test suite proves the extraction: `fetchChapterContent` returns
  /// `div.chapter-inner.chapter-content`'s inner HTML and nothing else.
  final String rawHtml;

  /// The source's `baseUrl`, used to resolve `href` and `src` (rule 3).
  final String baseUrl;

  /// What is furniture **on this site**, in addition to [kDefaultRemovals].
  final List<RemovalRule> additionalRemovals;

  /// ⚠️ **`false` by default, and the default is the rule.**
  ///
  /// Rule 3: *"By default, drop decorative images."* A web-novel chapter's images are
  /// almost always the site's furniture — badges, avatars, chapter-number watermarks —
  /// and a reader scrolling a chapter does not want them. A source that wants its
  /// illustrations sets this, and **the download pipeline fetches the files — not this
  /// converter** (rule 3, verbatim).
  final bool keepImages;
}

/// What every page contains and no chapter does.
///
/// ⚠️ **The union, never a replacement.** `ConversionRequest.additionalRemovals` is added
/// to this list; a source cannot re-introduce a `<script>` by omitting it, because
/// omitting is not an operation this type offers.
const List<RemovalRule> kDefaultRemovals = <RemovalRule>[
  RemovalRule(
    selector: 'script',
    why: 'Its text is code, not prose (rule "Escaping").',
  ),
  RemovalRule(
    selector: 'style',
    why: 'Its text is CSS, not prose — the same reason as <script>.',
  ),
  RemovalRule(
    selector: 'noscript',
    why:
        'A fallback that only renders when scripting is off, which this reader is not.',
  ),
  RemovalRule(
    selector: 'iframe',
    why:
        'Third-party content this app does not download, does not licence and cannot '
        'render; leaving it produces an empty hole the reader scrolls past.',
  ),
  RemovalRule(
    selector: 'form',
    why:
        'A search box or a comment form is the SITE\'s furniture, not the chapter.',
    matchesSubtree: false,
  ),
  RemovalRule(
    selector: 'input',
    why:
        'A form control carries no prose; keeping it emits nothing and costs a token.',
  ),
  RemovalRule(selector: 'button', why: 'Same as <input>: a control, not text.'),
  RemovalRule(
    selector: 'nav',
    why:
        'Site navigation inside an article is furniture on every page of every site.',
  ),
  RemovalRule(
    selector: 'footer',
    why:
        "Site furniture. The reader-facing place a chapter ends is the reader's own "
        'scroll position, not a <footer> the site prints.',
  ),
  RemovalRule(
    selector: 'aside',
    why: 'A sidebar is the site\'s, not the author\'s.',
  ),
];

/// The icon set every site uses for "share", "comment", "report".
///
/// ⚠️ **Not in [kDefaultRemovals], and that is deliberate.** These class names are shared
/// across unrelated sites, so they are a *convention* rather than a site fact — and
/// `18-external-contracts.md` is for site facts. A source that finds one on its own pages
/// adds it to `additionalRemovals` with its own `why`.
const List<RemovalRule> kConventionRemovals = <RemovalRule>[
  RemovalRule(
    selector: '.chapter-number, .chnumber',
    why:
        'A printed chapter number is the site\'s furniture; the chapter list already '
        'says which chapter this is.',
  ),
];
