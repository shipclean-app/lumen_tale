// Lumen Tale — the filters a source declares, and the states it interprets.
//
// `03-source-system.md` rule 5: *a source **declares** filters in `filterList`
// and **interprets** their states itself; the platform never interprets the
// values.* That rule is the reason this file is generic in the state type rather
// than a bag of `Object?`, and the reason the values in a `SelectFilter` are the
// **site's own slugs** (`contemporary-romance`, `xianxia`) rather than anything
// this app invented.
//
// Pure Dart.

import 'dart:collection';

/// A filter a source declares.
///
/// **Generic in its state** — that is the point. `SelectFilter<V>` holds an `int`
/// index, `TextFilter` a `String`, `CheckBoxFilter` a `bool`, `TriStateFilter`
/// an `int`, `GroupFilter<V>` a `List<V>`, `SortFilter` a [Selection]. A caller
/// that has to cast to read a state has learned nothing, and a `Object?` state
/// would let a source put a `bool` where the UI expects an index with no
/// complaint from the compiler.
///
/// [state] is **the source's own value**. `16-i18n.md` applies to names too: a
/// filter's [name] is a `String` here because `FilterList` lives in `domain`,
/// which carries no Flutter import and no `AppLocalizations`. A source that must
/// speak to the reader translates at the point it renders.
sealed class Filter<T> {
  const Filter({required this.name, required this.state});

  /// The label, as the source writes it. Never a key into this app's strings —
  /// rule 5 gives the wording to the site.
  final String name;

  /// The current value. Interpreted by the source that declared it, and by
  /// nobody else.
  final T state;

  /// A copy with a different [state]. Every subclass is immutable, so this is
  /// the only way any of them changes.
  Filter<T> withState(T newState);
}

/// A non-interactive heading. It carries a state so it can be acted on — FanMTL's
/// `all` pseudo-entry is a header that also *selects*, and modelling it as an
/// inert separator would make it unselectable.
final class HeaderFilter extends Filter<String> {
  const HeaderFilter({required super.name, required super.state});

  @override
  Filter<String> withState(String newState) =>
      HeaderFilter(name: name, state: newState);
}

/// A non-interactive gap between groups. [state] is always `null` and always
/// will be; the type is there so a `FilterList` can hold it without a special
/// case.
final class SeparatorFilter extends Filter<Object?> {
  const SeparatorFilter({required super.name}) : super(state: null);

  /// ⚠️ Keeps [name]. A copy that dropped the label would leave a separator with
  /// no heading after the first repaint — and the base signature is what makes
  /// this override possible at all, since a separator's state can never change.
  @override
  Filter<Object?> withState(Object? newState) => SeparatorFilter(name: name);
}

/// One option in a [SelectFilter].
///
/// [value] goes into the site's URL verbatim — `contemporary-romance` becomes
/// `/list/contemporary-romance/…` — and [name] is what a reader reads. They are
/// deliberately allowed to differ: the site's slug is often not a sentence.
final class SelectOption<V> {
  const SelectOption({required this.value, required this.name});

  final V value;
  final String name;

  @override
  bool operator ==(Object other) =>
      other is SelectOption<V> && other.value == value && other.name == name;

  @override
  int get hashCode => Object.hash(value, name);

  @override
  String toString() => 'SelectOption($name)';
}

/// A choice among [values], held as the **index** of the choice.
///
/// An index and not a [SelectOption]: rule 5 says the source interprets the
/// state, and the only thing it needs from here is which slot is current. Storing
/// the value would invite a `Select<V>` to be read by something that then has to
/// know what a genre slug is.
final class SelectFilter<V> extends Filter<int> {
  SelectFilter({
    required super.name,
    required super.state,
    required List<SelectOption<V>> values,
  }) : values = List<SelectOption<V>>.unmodifiable(values);

  /// The options, in the order the site lists them. The order is the site's.
  final List<SelectOption<V>> values;

  /// The option currently selected, or `null` when [state] is out of range.
  ///
  /// Out of range is reachable: a source persists a selection, the site drops an
  /// option in a release, and the stored index now points past the end. Returning
  /// `null` is the honest answer; throwing would take down a screen that could
  /// perfectly well show the other options.
  SelectOption<V>? get selected =>
      (state >= 0 && state < values.length) ? values[state] : null;

  @override
  Filter<int> withState(int newState) =>
      SelectFilter<V>(name: name, state: newState, values: values);
}

/// A free-text field. The text is **untrusted input** the moment it is typed —
/// `17-security.md` rule 1 — and it reaches a site as a URL parameter, never as
/// a path fragment and never into a log.
final class TextFilter extends Filter<String> {
  const TextFilter({required super.name, required super.state});

  @override
  Filter<String> withState(String newState) =>
      TextFilter(name: name, state: newState);
}

/// A yes/no field.
final class CheckBoxFilter extends Filter<bool> {
  const CheckBoxFilter({required super.name, required super.state});

  @override
  Filter<bool> withState(bool newState) =>
      CheckBoxFilter(name: name, state: newState);
}

/// A three-way field, held as an `int` so that "leave this alone" is a value and
/// not the absence of one.
///
/// ⚠️ **`[stateIgnore]` is not [ignored] and is not "no value".** It is what the
/// field carries when the source is told not to send it. A `null`-able `int`
/// would make "ignore" and "not set yet" the same state, and those two mean
/// different things to a URL builder.
final class TriStateFilter extends Filter<int> {
  const TriStateFilter({required super.name, required super.state});

  /// Excluded from the request. `-1` because the three meaningful values are
  /// `0`, `1`, `2`.
  static const int stateIgnore = -1;

  /// The three states a source can name. Named so no caller retypes an `int`
  /// literal and no reader has to infer which is which.
  static const int checked = 0;
  static const int unchecked = 1;
  static const int uncheckable = 2;

  @override
  Filter<int> withState(int newState) =>
      TriStateFilter(name: name, state: newState);
}

/// Several values of the same kind at once — the tags a novel must carry, the
/// genres a catalogue is restricted to.
///
/// **Not optional** (`03-source-system.md` § Models): Mihon ships it and sources
/// use it. Modelling it as "a select that happens to allow more than one" is
/// what makes a screen forget to ask whether multi-select is on.
final class GroupFilter<V> extends Filter<List<V>> {
  GroupFilter({
    required super.name,
    required super.state,
    required List<SelectOption<V>> values,
  }) : values = List<SelectOption<V>>.unmodifiable(values);

  final List<SelectOption<V>> values;

  @override
  Filter<List<V>> withState(List<V> newState) =>
      GroupFilter<V>(name: name, state: newState, values: values);
}

/// A sort order: which column, and which way.
final class Selection {
  const Selection({required this.index, required this.ascending});

  /// A stable value, because two sorts that look identical must compare equal —
  /// a filter list compared by identity would report a change that is not one.
  @override
  bool operator ==(Object other) =>
      other is Selection &&
      other.index == index &&
      other.ascending == ascending;

  @override
  int get hashCode => Object.hash(index, ascending);

  /// Index into the sort's option list, and whether that column is ascending.
  final int index;
  final bool ascending;

  @override
  String toString() => 'Selection($index, ascending: $ascending)';
}

/// A sort control. [values] are the site's own sort keys.
///
/// ⚠️ **Not `const`,** and neither are [SelectFilter] and [GroupFilter]: each
/// copies its options into an unmodifiable list at construction, and a
/// constructor that allocates cannot be a constant. A `const` here would hand out
/// a list a caller could mutate after the fact, which is rule 5's prohibition
/// reached from the other direction.
final class SortFilter extends Filter<Selection> {
  SortFilter({
    required super.name,
    required super.state,
    required List<SelectOption<Selection>> values,
  }) : values = List<SelectOption<Selection>>.unmodifiable(values);

  final List<SelectOption<Selection>> values;

  @override
  Filter<Selection> withState(Selection newState) =>
      SortFilter(name: name, state: newState, values: values);
}

/// A source's declared filters, usable directly as a list.
///
/// `03-source-system.md` § Models: *"implements `List<Filter<Object?>>` by
/// delegation, so a source's declared filters can be iterated directly."*
///
/// ## Why it extends `ListBase` and does not delegate through `noSuchMethod`
///
/// Both satisfy "by delegation". The difference is what a **failed** attempt to
/// mutate looks like, and that difference is a rule rather than a nicety:
///
/// ```
/// final FilterList filters = source.filterList;
/// filters.add(HeaderFilter(name: 'x', state: 'y'));
/// ```
///
/// | Shape | Result |
/// |---|---|
/// | `implements List` + a `noSuchMethod` forward | `NoSuchMethodError` — the unmodifiable inner list has no `add` |
/// | `extends ListBase` (this file) | `UnsupportedError` — *"Cannot grow list"* |
///
/// A `NoSuchMethodError` says the caller used a method that does not exist. Here
/// the method **does** exist, is part of the type this object advertises, and is
/// refused on purpose: `add` on a declared filter list would mean the platform
/// had changed what a source declared, which is rule 5's exact prohibition. That
/// is `UnsupportedError` — "supported type, unsupported operation" — and a
/// programming-error signal would send the next reader hunting for a typo
/// instead of at rule 5.
///
/// The first form also produced its error **by accident**: it reached
/// `NoSuchMethodError` only because the unmodifiable inner list happens not to
/// have `add`. A rejection that depends on an implementation detail of another
/// object is not a contract.
final class FilterList extends ListBase<Filter<Object?>> {
  FilterList(List<Filter<Object?>> filters)
    : _inner = List<Filter<Object?>>.unmodifiable(filters);

  final List<Filter<Object?>> _inner;

  @override
  int get length => _inner.length;

  @override
  bool get isEmpty => _inner.isEmpty;

  @override
  bool get isNotEmpty => _inner.isNotEmpty;

  @override
  Filter<Object?> operator [](int index) => _inner[index];

  @override
  Filter<Object?> get first => _inner.first;

  @override
  Filter<Object?> get last => _inner.last;

  @override
  Iterator<Filter<Object?>> get iterator => _inner.iterator;

  /// Rule 5. [ListBase] routes every remaining mutator — `add`, `insert`, `clear`,
  /// `sort`, `removeWhere`, the `Range` family — through one of these two, so
  /// writing them out is enough to refuse all of them, and the refusal names the
  /// rule rather than the missing method.
  @override
  void operator []=(int index, Filter<Object?> value) {
    throw UnsupportedError(
      'a source declared its filters; the platform does not change them '
      '(03-source-system.md rule 5)',
    );
  }

  @override
  set length(int newLength) {
    throw UnsupportedError(
      'a source declared its filters; the platform does not resize them '
      '(03-source-system.md rule 5)',
    );
  }

  @override
  String toString() => 'FilterList(${_inner.length})';
}
