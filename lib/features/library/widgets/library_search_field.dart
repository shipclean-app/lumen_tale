// Lumen Tale — the library's title-only search field.
//
// `design-system.md` § 2.4, `library.md` § 5. `features/library/widgets/`.
//
// ## ⚠️ THE PLACEHOLDER IS *Search by title*, AND IT IS NOT COSMETIC
//
// `library.md` § 2.1 names the non-obvious choice this screen makes: **a row's author is
// displayed and is not searchable**, and *a field shown next to a search box teaches that
// the box searches it*. So the placeholder says *title* rather than *your library*, and the
// helper says *Search your library by title*.
//
// ## ⚠️ THE HELPER COUNT IS **THE SAME NUMBER** AS THE LIST LENGTH
//
// `library.md` § 5: *result count in the field's helper text: 3 novels*. § 3.1 branch 11:
// the count and the field's helper text must say the same thing — two numbers on one page
// disagreeing is B22 in another costume. So the count is passed **in**, not counted here;
// counting it here would be a second measurement of a list this widget does not own.
//
// ## ⚠️ NO *APPLY*, NO VALIDATION, NO AUTHOR FIELD
//
// § 4.4: *One field of input. No validation, no Apply button, no author field, no genre
// picker.* Facets apply live because a filter that needs confirming is a filter the reader
// distrusts.
//
// ⚠️ **`onSubmitted` CLOSES THE FIELD AND KEEPS THE FILTER** (§ 5: *Submit closes the field
// keeping the filter*), and `X` clears both. Two different gestures, two different promises,
// and neither one writes anything.

import 'package:flutter/material.dart';

import 'package:lumen_tale/app/theme/lumen_colors.dart';
import 'package:lumen_tale/app/theme/lumen_radius.dart';
import 'package:lumen_tale/app/theme/lumen_spacing.dart';
import 'package:lumen_tale/l10n/generated/app_localizations.dart';

/// The one input on this screen.
class LibrarySearchField extends StatelessWidget {
  const LibrarySearchField({
    required this.controller,
    required this.resultCount,
    required this.onChanged,
    required this.onCleared,
    required this.onSubmitted,
    super.key,
  });

  final TextEditingController controller;

  /// ⚠️ **The number of rows the list is showing.** Passed rather than derived — see the
  /// file header.
  final int resultCount;

  final ValueChanged<String> onChanged;
  final VoidCallback onCleared;

  /// Submit keeps the filter and closes the field.
  final VoidCallback onSubmitted;

  /// § 2.4 / § 6: the field is **56dp**, not Material's default.
  static const double fieldHeight = 56;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final AppLocalizations copy = AppLocalizations.of(context);
    final LumenSpacing spacing = LumenSpacing.of(context);
    final LumenRadius radius = LumenRadius.of(context);
    final LumenColors colors = LumenColors.of(context);

    return Padding(
      padding: EdgeInsets.symmetric(
        horizontal: spacing.lg,
        vertical: spacing.sm,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          SizedBox(
            height: fieldHeight,
            child: TextField(
              key: const Key('library.search-field'),
              controller: controller,
              autofocus: true,
              textInputAction: TextInputAction.search,
              onChanged: onChanged,
              onSubmitted: (String _) => onSubmitted(),
              style: theme.textTheme.bodyLarge,
              decoration: InputDecoration(
                isDense: true,
                filled: true,
                fillColor: theme.colorScheme.surfaceContainerHighest,
                contentPadding: EdgeInsets.symmetric(
                  horizontal: spacing.md,
                  vertical: spacing.md,
                ),
                border: OutlineInputBorder(
                  borderRadius: radius.mdAll,
                  borderSide: BorderSide.none,
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: radius.mdAll,
                  borderSide: BorderSide.none,
                ),
                focusedBorder: OutlineInputBorder(
                  // ⚠️ **2dp `--color-border-focus`, and it is never removed.** § 1.1
                  // measures it at 6.07:1 / 8.86:1, non-text per WCAG 1.4.11.
                  borderRadius: radius.mdAll,
                  borderSide: BorderSide(
                    color: colors.borderFocus,
                    width: LumenRadius.borderWidthStrong,
                  ),
                ),
                // ⚠️ **B45, IN WORDS.** *Search by title* — not *Search your library*.
                hintText: copy.librarySearchHint,
                prefixIcon: const Icon(Icons.search),
                suffixIcon: controller.text.isEmpty
                    ? null
                    : IconButton(
                        key: const Key('library.search-clear'),
                        icon: const Icon(Icons.close),
                        tooltip: copy.librarySearchClearAction,
                        onPressed: onCleared,
                      ),
              ),
            ),
          ),
          // ⚠️ **THE HELPER IS ALWAYS THERE**, even at zero results, and it says *No novel*
          // rather than *0 novels*. § 4.3: a local search that matched nothing is a
          // sentence naming the query — not a result count, because the register of a
          // failed *site* query (B22/E19) would be a lie about where the answer came from.
          Padding(
            padding: EdgeInsets.only(
              left: spacing.md,
              top: spacing.xs,
              bottom: spacing.xs,
            ),
            child: Semantics(
              label: copy.librarySearchResults(resultCount),
              excludeSemantics: true,
              child: Text(
                copy.librarySearchResults(resultCount),
                key: const Key('library.search-result-count'),
                style: theme.textTheme.labelSmall,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
