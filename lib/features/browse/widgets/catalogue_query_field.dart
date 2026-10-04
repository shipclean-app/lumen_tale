// Lumen Tale — the catalogue's query field, and the three rules it exists to hold.
//
// `6-2` § 3.1 and § 3.2.
//
// ## ⚠️ It is RENDERED or it is NOT. There is no disabled state.
//
// A disabled text field is a promise about a version that does not exist, and it takes a line
// on the most comparative screen in the app. So [CatalogueQueryField] is built only when
// `supportsSearch` is true, and the test is a `find` on the widget type — the least ambiguous
// assertion in the slice.
//
// ## ⚠️ The field NEVER turns red
//
// `browse-catalogue.md` § 4: the query was well-formed and accepted; what failed is the site's
// answer. Marking the input as errored tells the reader they typed something wrong, which is
// the one thing that is not true. There is deliberately no `errorText` and no error colour here,
// and a row asserts the widget carries neither.
//
// ## ⚠️ The words leave byte for byte
//
// B41. No `trim`, no `toLowerCase`, no `split(' ')`, no relevance. "mother  of" is what the
// reader typed, and trimming it answers a question they did not ask.

import 'package:flutter/material.dart';

import 'package:lumen_tale/l10n/generated/app_localizations.dart';

/// The row: a label, a field, and a submit affordance that is the field's own keyboard action.
class CatalogueQueryField extends StatefulWidget {
  const CatalogueQueryField({
    required this.initialWords,
    required this.onSubmitted,
    super.key,
  });

  /// ⚠️ **The words as they arrive in the URL**, which may be anything the reader typed. Shown
  /// verbatim so a typo is visible and correctable rather than silently re-interpreted.
  final String initialWords;

  final ValueChanged<String> onSubmitted;

  @override
  State<CatalogueQueryField> createState() => _CatalogueQueryFieldState();
}

class _CatalogueQueryFieldState extends State<CatalogueQueryField> {
  late final TextEditingController _controller = TextEditingController(
    text: widget.initialWords,
  );

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      child: TextField(
        controller: _controller,
        // ⚠️ **The keyboard's own "search" action, not a button.** A submit button beside a
        // field is a second control for one action, and `09-widgets-ui.md` asks for one action
        // to have one affordance.
        textInputAction: TextInputAction.search,
        onSubmitted: widget.onSubmitted,
        style: theme.textTheme.bodyLarge,
        decoration: InputDecoration(
          // ⚠️ **The hint is the field's own purpose, from the app's copy**, not a Material
          // string: `MaterialLocalizations` has no search hint, and inventing one from a
          // tooltip would put a menu's label in a text field.
          hintText: widget.initialWords.isEmpty
              ? AppLocalizations.of(context).browseSearchHint
              : null,
          border: const OutlineInputBorder(),
          // ⚠️ **No `errorText` and no `errorBorder`, and that is the design.** The query was
          // accepted; what failed is the site's answer. A red field tells the reader they typed
          // something wrong, which is the one thing that is not true.
        ),
      ),
    );
  }
}

/// Whether a source's search field is rendered at all.
///
/// ⚠️ **A predicate rather than a widget, so the decision is in one place.** A screen that
/// remembered "if supportsSearch, render a disabled field" would put a line on screen for every
/// site, and a screen that remembered the wrong direction would show a field that does nothing.
bool rendersQueryField({required bool supportsSearch}) => supportsSearch;
