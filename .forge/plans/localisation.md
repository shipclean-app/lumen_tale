---
type: implementation-plan
slice: localisation
module: foundations
status: validated
generated_at: 2026-10-02
derived_from:
  - .forge/prd.md
  - .forge/architecture.md
  - .forge/design/design-system.md
  - .forge/design/screens/
conventions_ref: .forge/conventions.md
---

# Plan d'implémentation — `localisation` (fondation 1.4)

> Ce plan décrit **comment implémenter** la fondation `localisation`, de façon
> qu'un implémentateur n'ait rien à décider et n'ait pas à lire le PRD. Lire
> `.forge/plans/README.md` d'abord.
>
> **`.forge/plans/README.md` § 2 avertit :** `coverage-check slice` ne lit que
> `state.slices`, donc **les `rule_ids` d'une fondation ne sont jamais vérifiées
> mécaniquement**. `localisation` doit être vérifié **en lisant ce plan**.
> `coverage-check.js slice /workspaces/lumen_tale localisation` renvoie donc
> `Slice "localisation" not found in state.json` — **c'est attendu, et ce n'est
> pas un échec de ce plan** (finding **F-003**).

---

## Sources

- **PRD** : `.forge/prd.md` § 4 (**B28**), § 6 (**E12**), § 7.4 (internationalisation), § 10 (**SC-4**)
- **Architecture** : `.forge/architecture.md` § 2 (table des fondations : « ARB
  plumbing with a French fallback — **mechanism only** (B28) »), § 3.1 (ligne
  `1.4`)
- **Roadmap** : `.forge/roadmap.md` § 8 Wave 1, ligne `1.4`
- **Règles projet** : `.opencode/rules/16-i18n.md` (règles 1 à 7 — **le
  propriétaire de cette fondation**), `13-error-handling.md` règle 5, `10-testing.md`
- **État existant** : `l10n.yaml`, `lib/l10n/app_en.arb`, `lib/l10n/app_fr.arb`,
  `lib/l10n/generated/` (trois fichiers), `lib/main.dart` (§ 2.7 du plan `0-5`),
  `pubspec.yaml` (`flutter: generate: true`)
- **Écrans, pour l'inventaire des chaînes** : `settings.md` § 4.1,
  `settings-reader.md` § 4.1, `settings-about.md` § 4.1, `onboarding.md` § 4.1,
  `source-unavailable.md` § 4.1 (le catalogue d'erreurs), `library.md`,
  `more.md`, `design-system.md` § 3.2 (les cinq libellés d'onglet)

---

## 1. Résumé de la slice

Cette fondation **existe déjà à moitié**, et la moitié manquante est celle qui
compte.

**Ce qui est livré et qu'il ne faut pas refaire** :

| Élément | Où | État |
|---|---|---|
| `l10n.yaml` | racine | `arb-dir: lib/l10n`, `template-arb-file: app_en.arb`, `output-dir: lib/l10n/generated`, `output-class: AppLocalizations`, `nullable-getter: false` — **complet** |
| `flutter: generate: true` | `pubspec.yaml` | présent. Sans lui `gen-l10n` sort du code non importable et non-zéro (`16-i18n.md`) |
| Les deux ARB | `lib/l10n/` | **16 clés**, FR et EN, plus deux blocs `@` |
| La sortie générée | `lib/l10n/generated/` | trois fichiers, committed |
| Le câblage | `lib/main.dart` | delegates, `supportedLocales`, `localeListResolutionCallback` avec le repli FR |

**Ce qui manque, et c'est grave** : **rien ne vérifie que les deux fichiers ARB
ont le même ensemble de clés.** Vérifié empiriquement sur le SDK installé :

> Une clé présente dans `app_en.arb` et absente de `app_fr.arb` produit
> `String get onlyEn => 'Only English';` **dans `app_localizations_fr.dart`**.
> `flutter gen-l10n` **sort 0**. `flutter analyze` ne signale rien. `flutter
> test` passe.

Autrement dit : le projet peut livrer une application **qui se dit française et
affiche de l'anglais sur certains écrans**, et les trois outils du projet
rapportent tout vert. C'est littéralement le critère d'acceptation d'US-13 qui
échoue — *« No screen ever displays a string in a locale other than the active
one »* — sans qu'aucun garde ne le voie. **C'est ce que cette fondation
répare**, et c'est la seule chose qu'elle répare qui ne soit pas déjà faite.

Trois autres trouvailles, toutes mesurées sur Flutter 3.47.6, qui rendent la
garde non optionnelle (détail en § 3.3) :

1. **Renommer un placeholder dans une traduction n'est pas gratuit.**
   `{status}` en anglais et `{statut}` en français produisent
   `String siteUnavailable(Object source, Object status, Object statut)` — le
   paramètre renommé est **ajouté**, pas substitué, et il est **obligatoire**.
   Quarante-et-une clés de `source-unavailable.md` § 4.1 sont écrites avec des
   noms de placeholder français.
2. **Une traduction peut introduire un placeholder absent du template**, et il
   devient lui aussi un paramètre obligatoire de type `Object` non typé.
3. **`required-resource-attributes: true` échoue vraiment** (sortie 1) quand une
   clé n'a pas son bloc `@clé`. C'est le seul garde-fou de la chaîne d'outils
   qui ait un code de sortie non nul — et il est désactivé aujourd'hui.

**Trois choses à livrer, donc** :

1. **La garde de complétude** — un test qui échoue si les deux ARB n'ont pas le
   même ensemble de clés, si une valeur est vide, ou si un placeholder diffère
   entre les deux fichiers. Plus les deux options de `l10n.yaml` qui rendent le
   diagnostic visible.
2. **La règle de nommage des clés** — les fichiers d'écran écrivent
   `cause.noConnection.kicker` et `16-i18n.md` règle 3 interdit le
   point-namespace. La traduction est un algorithme déterministe (§ 3.1), pas un
   choix.
3. **Le catalogue**, y compris **toute la famille d'erreurs** — c'est la
   exigence explicite de cette tranche, et c'est `source-unavailable.md` § 4.1
   qui en porte le texte, déjà rédigé dans les deux langues.

**User stories couvertes** : US-13 (français et anglais), US-16 (messages
d'erreur), US-08 (messages de statut de téléchargement).
**Règles métier couvertes** : **B28**
**Edge cases couverts** : **E12** tracé en § 6.2 ; `state.json` n'attribue aucun
edge case à cette fondation.

---

## 2. Contrats de données (code)

### 2.1 Schémas de validation

**Aucun nouveau schéma.** Aucun drift `Table`, aucun modèle `freezed`, aucune
colonne, aucune migration.

Le « schéma » de cette fondation, c'est **l'invariant entre deux fichiers JSON**
et il n'est pas vérifié par le toolchain. Le contrat est donc écrit ici, en Dart,
sous forme exécutable.

### 2.2 Le catalogue — les seize clés existantes

État vérifié le 2026-10-02. Ce tableau est **l'inventaire de départ**, pas la
cible.

| Clé | EN | FR | Bloc `@` | Consommée par |
|---|---|---|---|---|
| `appTitle` | `Lumen Tale` | `Lumen Tale` | **non** | `main.dart` `onGenerateTitle` |
| `navLibrary` | `Library` | `Bibliothèque` | **non** | `0-5`, `library.md` |
| `navUpdates` | `Updates` | `Mises à jour` | **non** | `0-5`, `updates.md` |
| `navHistory` | `History` | `Historique` | **non** | `0-5`, `history.md` |
| `navBrowse` | `Browse` | `Parcourir` | **non** | `0-5`, `browse-sources.md` |
| `navDownloads` | `Downloads` | `Téléchargements` | **non** | `more.md` |
| `navSettings` | `Settings` | `Paramètres` | **non** | `more.md`, `settings.md` |
| `commonRetry` | `Retry` | `Réessayer` | **non** | `ErrorState`, `EmptyState` |
| `commonCancel` | `Cancel` | `Annuler` | **non** | dialogues, feuilles |
| `commonErrorTitle` | `Something went wrong` | `Une erreur est survenue` | **non** | `PlaceholderScreen` (`0-5` § 3.5) |
| `commonErrorBody` | `The operation could not be completed.` | `L'opération n'a pas pu être terminée.` | **non** | idem |
| `libraryEmptyTitle` | `Your library is empty` | `Votre bibliothèque est vide` | **non** | `design-system.md` § 2.7 `library-empty` |
| `libraryEmptyBody` | `Add a novel from Browse to start reading.` | `Ajoutez un roman depuis Parcourir pour commencer à lire.` | **non** | idem |
| `browseEmptyBody` | `No source is available yet.` | `Aucune source n'est encore disponible.` | **non** | `browse-sources.md` |
| `chapterCount` | `{count, plural, =0{No chapters} =1{1 chapter} other{{count} chapters}}` | `{count, plural, =0{Aucun chapitre} =1{1 chapitre} other{{count} chapitres}}` | **oui** (`@chapterCount`) | `novel-details.md`, `library.md` |
| `coverSemanticsLabel` | `Cover of {title}` | `Couverture de {title}` | **oui** | `coverSemanticsLabel` — `14-design-tokens.md` § Accessibilité |

**Trois observations, chacune avec sa conséquence.**

1. **`navMore` n'existe pas.** `design-system.md` § 3.2 exige le libellé
   « More / Plus » pour la cinquième destination de la barre d'onglets ; les
   quatre autres existent. Cette fondation écrit la clé — voir § 9 Phase 1.
2. **Quatorze clés sur seize n'ont pas de bloc `@`.** `required-resource-attributes:
   true` les refuserait toutes. Les écrire fait partie de cette tranche (§ 3.2).
3. **Trois `EmptyState` nommés sont exigés par le design system**
   (`design-system.md` § 2.7 : `library-empty`, `search-unsupported`,
   `no-chapters`). Deux des trois existent en parties (`libraryEmptyTitle` /
   `libraryEmptyBody`). `search-unsupported` est **entièrement absent**, et c'est
   celui que **B50** rend obligatoire : il explique qu'un site n'a pas de
   recherche et propose les genres à la place. Il est livré ici avec le texte
   de `design-system.md` § 2.7, qui le nomme mais ne le rédige pas — voir § 7
   question ouverte 2.

### 2.3 La famille d'erreurs — le catalogue que cette tranche doit livrer

**C'est l'exigence explicite** : « every user-visible string including error
strings ». Le texte existe déjà, dans les deux langues, dans
`source-unavailable.md` § 4.1 — **quarante-et-une clés**. Elles sont donc
recopiées telles quelles, avec la transformation de nommage de § 3.1 et la
correction de placeholder de § 3.3.

| Clé (après § 3.1) | EN | FR | Placeholders |
|---|---|---|---|
| `sourceUnavailableCauseNoConnectionKicker` | `NO CONNECTION` | `AUCUNE CONNEXION` | — |
| `sourceUnavailableCauseNoConnectionTitle` | `{source} could not be reached from this phone.` | `{source} n'a pas pu être joint depuis ce téléphone.` | `source` |
| `sourceUnavailableCauseNoConnectionBody` | `The phone has no usable connection. The app cannot tell whether {source} is working, so it does not guess.` | `Le téléphone n'a pas de connexion exploitable. L'application ne peut pas savoir si {source} fonctionne : elle ne devine pas.` | `source` |
| `sourceUnavailableCauseNoConnectionEvidence` | `Transport error — no connection was made to {host}.` | `Erreur de transport — aucune connexion à {host}.` | `host` |
| `sourceUnavailableCauseNoConnectionRetry` | `Try again later.` | `Réessayer plus tard.` | — |
| `sourceUnavailableCauseLayoutChangedKicker` | `THIS SITE'S PAGES HAVE CHANGED` | `LES PAGES DE CE SITE ONT CHANGÉ` | — |
| `sourceUnavailableCauseLayoutChangedTitle` | `{source}'s pages can no longer be read.` | `Les pages de {source} ne peuvent plus être lues.` | `source` |
| `sourceUnavailableCauseLayoutChangedBody` | `The site answered, but the structure this app reads has changed. This is a fault in the app's copy of {source} — not in {source}, and not in anything you did. Until a new version of Lumen Tale fixes it, this site cannot be read.` | `Le site a répondu, mais la structure que l'application lit a changé. C'est une faute dans la copie que l'application a de {source} — pas dans {source}, et rien n'est dû à votre utilisation. Tant qu'une nouvelle version de Lumen Tale ne l'aura pas corrigé, ce site reste illisible.` | `source` |
| `sourceUnavailableCauseLayoutChangedEvidence` | `The page loaded (HTTP {status}) and none of the expected elements were found.` | `La page a été chargée (HTTP {status}) et aucun des éléments attendus n'a été trouvé.` | `status` |
| `sourceUnavailableCauseLayoutChangedDictation` | `Say: {source} cannot be read. The app loaded the page and found none of the elements it looks for.` | `Dites : {source} est illisible. L'application a chargé la page et n'a trouvé aucun des éléments qu'elle cherche.` | `source` |
| `sourceUnavailableCauseLayoutChangedRetryNote` | `Sometimes this fixes itself while the site finishes a change. Usually it does not.` | `Parfois cela se résout tout seul pendant que le site termine une modification. Rarement.` | — |
| `sourceUnavailableCauseSiteUnavailableKicker` | `THE SITE IS NOT SERVING REQUESTS` | `LE SITE NE RÉPOND PAS` | — |
| `sourceUnavailableCauseSiteUnavailableTitle` | `{source} is busy, or is refusing requests from this app.` | `{source} est occupé, ou refuse les requêtes de cette application.` | `source` |
| `sourceUnavailableCauseSiteUnavailableBody` | `This is on {source}'s side and is usually temporary. Trying again immediately is more likely to be refused than accepted — wait a while.` | `Cela vient de {source} et dure d'ordinaire peu de temps. Réessayer tout de suite a plus de chances d'être refusé qu'accepté : attendez un moment.` | `source` |
| `sourceUnavailableCauseSiteUnavailableEvidenceStatus` | `{source} answered HTTP {status}.` | `{source} a répondu HTTP {status}.` | `source`, `status` |
| `sourceUnavailableCauseSiteUnavailableEvidenceChallenge` | `{source} returned an anti-bot challenge. This app does not attempt to get past one.` | `{source} a renvoyé un défi anti-robot. Cette application n'essaie pas de le franchir.` | `source` |
| `sourceUnavailableCauseSiteUnavailableCountdown` | `Available again in {mmss}` | `De nouveau disponible dans {mmss}` | `mmss` |
| `sourceUnavailableCauseContentRemovedKicker` | `REMOVED AT THE SOURCE` | `RETIRÉ DE LA SOURCE` | — |
| `sourceUnavailableCauseContentRemovedTitle` | `{novel} is no longer at {source}.` | `{novel} n'existe plus sur {source}.` | `novel`, `source` |
| `sourceUnavailableCauseContentRemovedBody` | `{source} answered and confirmed this title is gone. Everything already downloaded from it is still on this phone, and still opens.` | `{source} a répondu et confirme que ce titre a disparu. Tout ce qui en a déjà été téléchargé reste sur ce téléphone, et s'ouvre toujours.` | `source` |
| `sourceUnavailableCauseContentRemovedEvidence` | `{source} answered HTTP {status} and the page carries the site's own "not found" signal.` | `{source} a répondu HTTP {status} et la page porte le signal « introuvable » du site.` | `source`, `status` |
| `sourceUnavailableCauseContentRemovedNoRetry` | `There is nothing to retry here.` | `Il n'y a rien à réessayer ici.` | — |
| `sourceUnavailableCauseContentRemovedOpenNovel` | `Open the novel` | `Ouvrir le roman` | — |
| `sourceUnavailableCauseContentRemovedBrowseOthers` | `Browse other sites` | `Parcourir les autres sites` | — |
| `sourceUnavailableCauseGenericKicker` | `THIS SITE COULD NOT BE READ` | `CE SITE N'A PAS PU ÊTRE LU` | — |
| `sourceUnavailableCauseGenericTitle` | `This site could not be read, and the details of why were lost.` | `Ce site n'a pas pu être lu, et les détails de la raison ont été perdus.` | — |
| `sourceUnavailableCauseGenericBody` | `The app will not guess which of the four causes it was. Try again, and the reason will be recorded this time.` | `L'application ne devinera pas laquelle des quatre causes il s'agissait. Réessayez : la raison sera enregistrée cette fois.` | — |
| `sourceUnavailableStillWorksLabel` | `WHAT STILL WORKS` | `CE QUI MARCHE TOUJOURS` | — |
| `sourceUnavailableStillWorksOffline` | `Your {library} kept novels and {downloaded} downloaded chapters open with no connection.` | `Vos {library} romans conservés et vos {downloaded} chapitres téléchargés s'ouvrent sans connexion.` | `library`, `downloaded` |
| `sourceUnavailableStillWorksOtherSource` | `{source} is unaffected — keep reading from it.` | `{source} n'est pas concerné : continuez à y lire.` | `source` |
| `sourceUnavailableStillWorksPositions` | `Your {positions} reading positions are untouched.` | `Vos {positions} positions de lecture ne sont pas touchées.` | `positions` |
| `sourceUnavailableStillWorksOpenLibrary` | `Open the library` | `Ouvrir la bibliothèque` | — |
| `sourceUnavailableStillWorksOpenOtherSource` | `Open {source}` | `Ouvrir {source}` | `source` |
| `sourceUnavailableRetryAgain` | `Try again` | `Réessayer` | — |
| `sourceUnavailableRetryAgainSame` | `It failed again at {time}. Same cause: {cause}.` | `Cela a encore échoué à {time}. Même cause : {cause}.` | `time`, `cause` |
| `sourceUnavailableRetryChangedCause` | `This is a different problem from last time.` | `C'est un problème différent de la dernière fois.` | — |
| `sourceUnavailableCopyMessage` | `Copy this message` | `Copier ce message` | — |
| `sourceUnavailableCopyDone` | `Message copied.` | `Message copié.` | — |
| `sourceUnavailableButtonBack` | `Go back` | `Revenir` | — |
| `sourceUnavailableResolvedTitle` | `{source} is working again.` | `{source} fonctionne de nouveau.` | `source` |
| `sourceUnavailableResolvedOpen` | `Open {source}` | `Ouvrir {source}` | `source` |
| `sourceUnavailableResolvedLastChecked` | `Last checked {relative}.` | `Dernière vérification {relative}.` | `relative` |
| `sourceUnavailableResolvedNeverChecked` | `Never checked.` | `Jamais vérifiée.` | — |

**Trois corrections par rapport au texte de l'écran, et chacune est une
intervention, pas une traduction.**

| Tel quel dans l'écran | Ici | Pourquoi |
|---|---|---|
| `{mm:ss}` | `{mmss}` | **Un nom de placeholder ICU ne peut pas contenir `:`** — le parseur le lit comme un séparateur d'argument. C'est une contrainte du format, pas une préférence. Le libellé garde le `:` à l'affichage ; seul le nom change |
| `{statut}`, `{roman}`, `{hôte}`, `{heure}`, `{thème}`, `{taille}`, `{actifs}` côté français | **`{status}`, `{novel}`, `{host}`, `{time}`, `{theme}`, `{size}`, `{enabled}`** dans **les deux** fichiers | § 3.3, mesuré : un placeholder renommé **ajoute** un paramètre obligatoire à la signature générée. Le nom n'est **jamais** vu du lecteur — il ne sert qu'à la signature |
| `{source}` dans `cause.generic.*` | **inchangé**, et il n'y a pas de `{source}` dans `cause.generic.*` | le générique est, par construction, celui qui n'a pas de source nommée. Rien à corriger |

**Les deux chaînes que cet écran interdit, et qu'il faut donc ne pas créer.**
`source-unavailable.md` § 4.1 interdit en toutes lettres, dans les deux langues :
`0 results` / `0 résultat` et `No results` / `Aucun résultat`. Ce sont les
vocabulaires du signal de résultat vide du site, qui vit sur la surface de
parcours, pas ici. La garde de § 2.5 les vérifie.

### 2.4 Les deux options de `l10n.yaml` à activer

```yaml
# l10n.yaml — les six lignes existantes, plus deux
arb-dir: lib/l10n
template-arb-file: app_en.arb
output-dir: lib/l10n/generated
output-localization-file: app_localizations.dart
output-class: AppLocalizations
nullable-getter: false

# ── ajouté par cette fondation ───────────────────────────────────────────
# Échoue (sortie 1) si une clé n'a pas son bloc `@clé` de métadonnées.
# C'est le SEUL garde-fou de la chaîne d'outils qui ait un code de sortie
# non nul — vérifié sur le SDK installé. Off par défaut.
required-resource-attributes: true

# Écrit un rapport JSON des clés non traduites par locale. ATTENTION :
# gen-l10n ÉCRIT LE FICHIER ET SORT QUAND MÊME EN 0. Ce n'est pas une garde,
# c'est un rapport — c'est le test de § 2.5 qui le transforme en garde.
untranslated-messages-file: lib/l10n/generated/untranslated-messages.json
```

**Pourquoi `untranslated-messages-file` est dans le fichier généré.** Il doit
être écrit dans le même commit que la sortie générée (règle 4 de `AGENTS.md` :
« Generated code is committed »), et dans `lib/l10n/generated/` pour qu'il soit
régénéré et versionné avec le reste. **Il ne doit jamais être commité avec du
contenu** : § 9 Phase 5 le fait échouer tant qu'il n'est pas vide.

### 2.5 La garde — vrai Dart, copiable

```dart
// test/l10n/arb_completeness_test.dart
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// The only thing in this project that checks the two ARB files against each
/// other. Everything else in the toolchain reports success on a half-French
/// app — see § 3.1.
const String arbDir = 'lib/l10n';
const String templateArb = 'app_en.arb';
const String frenchArb = 'app_fr.arb';

/// Strings `source-unavailable.md` § 4.1 forbids, in both languages.
///
/// They belong to the site's own empty-result signal, which renders on the
/// browse surface and never routes to a failure screen. SC-6 is only
/// demonstrable if the two states share no vocabulary at all.
const List<String> forbiddenAnywhere = <String>[
  '0 results',
  '0 résultat',
  'No results',
  'Aucun résultat',
  'Nothing found',
  'Empty',
];

Map<String, dynamic> _loadArb(String fileName) {
  final File file = File('$arbDir/$fileName');
  expect(
    file.existsSync(),
    isTrue,
    reason: '16-i18n.md: $fileName must exist. Two languages, from day one.',
  );
  final Object? decoded = jsonDecode(file.readAsStringSync());
  expect(
    decoded,
    isA<Map<String, dynamic>>(),
    reason: '$fileName must be a JSON object',
  );
  return decoded as Map<String, dynamic>;
}

/// Keys, excluding `@@`-metadata, `@key` metadata blocks and the placeholder
/// sub-objects. `16-i18n.md` rule 3: keys are flat and camelCase; a key with a
/// dot in it does not become a namespaced getter, it becomes a Dart
/// identifier the linter rejects.
Set<String> _messageKeys(Map<String, dynamic> arb) => arb.keys
    .where((String k) => !k.startsWith('@'))
    .expand((String k) => k.startsWith('@') ? const <String>[] : <String>[k])
    .toSet();

Set<String> _placeholderNames(String message) => RegExp(r'\{\s*([A-Za-z0-9_]+)')
    .allMatches(message)
    .map((Match m) => m.group(1)!)
    .toSet();

void main() {
  late Map<String, dynamic> en;
  late Map<String, dynamic> fr;

  setUp(() {
    en = _loadArb(templateArb);
    fr = _loadArb(frenchArb);
  });

  test('the French file has every key the English template has', () {
    final Set<String> missing = _messageKeys(en).difference(_messageKeys(fr));
    expect(
      missing,
      isEmpty,
      reason:
          'B28 / US-13: every user-visible string exists in French. A key '
          'missing from app_fr.arb is emitted VERBATIM IN ENGLISH inside '
          'app_localizations_fr.dart, and flutter gen-l10n still exits 0.',
    );
  });

  test('the English template has every key the French file has', () {
    final Set<String> extra = _messageKeys(fr).difference(_messageKeys(en));
    expect(
      extra,
      isEmpty,
      reason: 'A key only in app_fr.arb generates nothing: gen-l10n builds '
          'the API from the template. The string is dead weight, and the '
          'guard that would have caught it is this one.',
    );
  });

  test('no message is empty in either language', () {
    for (final Map<String, dynamic> arb in <Map<String, dynamic>>[en, fr]) {
      for (final String key in _messageKeys(arb)) {
        expect(
          (arb[key] as String).trim(),
          isNotEmpty,
          reason: '$key is empty. An empty label is worse than a missing one: '
              'it renders, and it says nothing.',
        );
      }
    }
  });

  test('placeholder names are identical in both languages', () {
    // Verified on the installed SDK: gen-l10n takes the UNION of placeholders
    // across locales and emits them ALL as required parameters of the getter.
    // Renaming a placeholder in a translation ADDS a parameter rather than
    // renaming one, and every call site then has to pass both.
    for (final String key in _messageKeys(en)) {
      final Set<String> inEn = _placeholderNames(en[key] as String);
      final Set<String> inFr = _placeholderNames(fr[key] as String);
      expect(
        inFr,
        inEn,
        reason: 'B28: placeholder names are part of the generated signature, '
            'not prose. $key uses ${inEn.toString()} in English and '
            '${inFr.toString()} in French.',
      );
    }
  });

  test('every message has its @key metadata block', () {
    for (final String key in _messageKeys(en)) {
      expect(
        en.containsKey('@$key'),
        isTrue,
        reason: 'required-resource-attributes: true makes gen-l10n exit 1 '
            'without it, and a description is how the next session knows what '
            '$key is for.',
      );
    }
  });

  test('no ARB value contains a forbidden empty-result string', () {
    for (final Map<String, dynamic> arb in <Map<String, dynamic>>[en, fr]) {
      for (final String key in _messageKeys(arb)) {
        for (final String banned in forbiddenAnywhere) {
          expect(
            (arb[key] as String).contains(banned),
            isFalse,
            reason: '$key contains "$banned". Those strings belong to the '
                "site's own empty-result signal, which renders on the browse "
                'surface in EmptyState and never on a failure screen. '
                'SC-6 is only demonstrable if the two states share no '
                'vocabulary at all.',
          );
        }
      }
    }
  });

  test('gen-l10n left no untranslated message behind', () {
    final File report = File(
      'lib/l10n/generated/untranslated-messages.json',
    );
    expect(
      report.existsSync(),
      isTrue,
      reason: 'l10n.yaml must set untranslated-messages-file. Without it '
          'gen-l10n prints a summary nobody reads.',
    );
    expect(
      jsonDecode(report.readAsStringSync()),
      isEmpty,
      reason: 'B28 / SC-4: both languages are complete, including every error '
          'message. The report is written by gen-l10n and then NOT checked by '
          'anything, so this test is the check.',
    );
  });
}
```

### 2.6 Contrats API

**Aucun appel réseau, aucune base, aucun `shared_preferences`.** Cette fondation
ne lit rien du monde ; elle lit deux fichiers du dépôt.

Ce que `6-7` et `0-5` consomment — signature, pas implémentation :

```dart
// Consommé par 0-5 (barre d'onglets) et par chaque écran
class AppLocalizations {          // généré, jamais écrit à la main
  static AppLocalizations of(BuildContext context);
  static const List<LocalizationsDelegate<Object>> localizationsDelegates;
  static const List<Locale> supportedLocales;
  String get navLibrary; String get navBrowse; String get navUpdates;
  String get navHistory; String get navMore;          // ← ajouté ici
  String chapterCount(int count);
  String sourceUnavailableCauseLayoutChangedTitle(String source);
  // … les 41 clés de la famille d'erreurs, § 2.3
}
Locale resolveLocale(Iterable<Locale>? preferred, Iterable<Locale> supported);
```

---

## 3. Algorithmes critiques

### 3.1 Ce que font les outils — et pourquoi ils ne suffisent pas

Les quatre comportements ci-dessous sont **mesurés** sur le SDK installé
(Flutter 3.47.6, `flutter_tools/lib/src/localizations/gen_l10n.dart`), et
chacun est un code de sortie **zéro**.

```
1. clé absente de app_fr.arb
   -> app_localizations_fr.dart contient  String get onlyEn => 'Only English';
   -> gen-l10n écrit un avertissement, ou remplit untranslated-messages.json
   -> SORT 0
   -> flutter analyze : 0 issue
   -> flutter test   : passe

2. placeholder renommé dans une traduction
   EN : "{source} answered HTTP {status}."
   FR : "{source} a répondu HTTP {statut}."
   -> String siteUnavailable(Object source, Object status, Object statut)
   -> le paramètre renommé est AJOUTÉ, pas substitué
   -> SORT 0, et l'appelant doit passer status ET statut

3. placeholder introduit seulement dans la traduction
   EN : "Hello {name}"          FR : "Bonjour {name} et {ville}"
   -> String a(String name, Object ville)
   -> le paramètre est non typé et obligatoire
   -> SORT 0

4. clé sans bloc @clé, avec required-resource-attributes: true
   -> "Resource attribute "@both" was not found."
   -> SORT 1            ← le seul garde-fou qui échoue vraiment
```

**Le point 4 est le seul levier natif, et il ne couvre qu'un quart du
problème** : il vérifie la présence d'une description, pas l'égalité des deux
fichiers. Les points 1, 2 et 3 exigent le test de § 2.5.

### 3.2 Transformer une table de copie d'écran en clés — l'algorithme

Les fichiers d_screen écrivent `cause.noConnection.kicker`.
`16-i18n.md` règle 3 écrit : « **Not** dot-namespaced — `gen-l10n` flattens keys
into camelCase getters, so `library.emptyTitle` does not become a namespaced
getter ». Il faut donc une transformation, et elle doit être **déterministe**,
sinon deux sessions produisent deux noms pour la même chaîne et l'app a
doublé.

```
deriveKey(screenSlug, dottedKey):
  # screenSlug : le `slug:` du front matter de l'écran
  #   settings.md -> "settings"
  #   source-unavailable.md -> "source-unavailable"

  prefix  = camelCase(screenSlug)          # "sourceUnavailable"
  segments = dottedKey.split(".")

  # 1. retirer un segment de tête identique au prefix, pour eviter
  #    "settingsGroupReading" quand l'ecran ecrit deja "settings.group.reading"
  if segments.first.toLowerCase() == screenSlug.toLowerCase():
      segments = segments.sublist(1)

  # 2. chaque segment : minuscules -> camelCase conservee
  #    "noConnection"  -> "NoConnection"   (deja camel : on ne casse rien)
  #    "kicker"        -> "Kicker"
  #    "evidence"      -> "Evidence"
  parts = segments.map(capitalizeFirst).join()

  return prefix + parts                    # "sourceUnavailableCauseNoConnectionKicker"

  # Regles du transformation, et chacune a un cas :
  #  - un segment deja en camelCase est conserve tel quel
  #      "noConnection" ne devient pas "NoConnection" -> "Noconnection"
  #  - un segment chiffre garde ses chiffres
  #      "12h" -> "12h"
  #  - un segment avec un trait devient deux morceaux
  #      "source-unavailable" -> "SourceUnavailable"
  #  - un segment vide est ERREUR, jamais ignore en silence
  #      "row..label" -> echec de test, pas une cle "rowLabel"
```

**Les branches.**

| Entrée | Sortie | Raison |
|---|---|---|
| `('source-unavailable', 'cause.noConnection.kicker')` | `sourceUnavailableCauseNoConnectionKicker` | cas nominal |
| `('settings', 'group.reading')` | `settingsGroupReading` | cas nominal |
| `('settings', 'settings.group.reading')` | `settingsGroupReading` | le segment redondant de tête est retiré, sinon la clé devient `settingsSettingsGroupReading` |
| `('settings', 'retention.1w')` | `settingsRetention1w` | un chiffre ne se capitalise pas |
| `('settings', 'interval.12h')` | `settingsInterval12h` | idem |
| `('settings', 'dialog.clearHistory.confirm')` | `settingsDialogClearHistoryConfirm` | trois segments |
| `('source-unavailable', 'cause.siteUnavailable.evidence.status')` | `sourceUnavailableCauseSiteUnavailableEvidenceStatus` | cinq segments, aucun tronqué |
| `('settings', 'row..label')` | **échec** | un segment vide est une faute de frappe dans le tableau de l'écran ; la cléserait silencieusement |
| `('settings', 'error.countUnavailable')` | `settingsErrorCountUnavailable` | **attention** : `error.countUnavailable` existe aussi dans `settings.md` § 4.1. Une même clé, deux écrans, une seule chaîne : c'est correct et voulu |
| deux écrans produisent la même clé | **échec** | une clé qui pointe vers deux copies d'écran est une chaîne qui divergera |

### 3.3 Écrire une chaîne — la règle des placeholders, mesurée

```
write(key, en, fr, placeholders):
  # placeholders : declare dans le bloc @key, avec un `type`

  # ⚠️ LES NOMS DE PLACEHOLDER VIENNENT DE L'ANGLAIS, DANS LES DEUX FICHIERS.
  # C'est la regle la plus contre-intuitive de cette fondation, et elle est
  # mesuree (§ 3.1, point 2).
  #
  #   "status" en anglais ET en francais. Pas "statut".
  #   Le nom n'est JAMAIS vu du lecteur ; il ne sert qu'a la signature
  #   generee. "{source} a repondu HTTP {status}." est du francais correct.
  #
  # ⚠️ ET SI LE NOM CHANGE, LA SIGNATURE GRANDIT.
  #   {status} + {statut}  ->  siteUnavailable(Object source, Object status,
  #                                              Object statut)
  #   et l'appelant doit passer les DEUX. Sur quarante-et-une cles, c'est
  #   quarante-et-une signatures qui portent un parametre fantome.

  # ⚠️ LE NOM NE PEUT PAS CONTENIR ":" — le parseur ICU le lit comme un
  # separateur d'argument. "{mm:ss}" n'est pas un placeholder, c'est une
  # erreur de generation. Utiliser "{mmss}" et garder le ":" dans le texte.

  # ⚠️ LE TEXTE DU LECTEUR N'EST JAMAIS UN PLACEHOLDER.
  #   Un titre de roman, un nom de site et un statut HTTP sont des DONNEES,
  #   pas de la copie : ils passent en parametre, meme si leur nom change.
  #   C'est 16-i18n.md regle 4 : "chapter and novel titles are source data,
  #   not localized".
  #
  # EXCEPTION : ce qui est un FAIT DE PROTOCOLE ne se traduit pas.
  #   "HTTP 429" reste "HTTP 429" en francais — source-unavailable.md § 7 le
  #   dit. Il passe en parametre ({status}), il n'est pas traduit.

  # ⚠️ UNE CHAINE RESERVEE SUR UN ECRAN NE VAUT PAS UNE CLE PARTAGEE.
  #   "Try again" existe en sourceUnavailableRetryAgain ET dans commonRetry.
  #   Les deux sont volontaires : commonRetry est generique, l'autre porte le
  #   reessai d'une source. Regle 3 : "one concept, one key" — deux concepts
  # distincts, deux cles. Ne pas factoriser "pour eviter une repetition".
```

**Les branches.**

| Situation | Ce qui se passe |
|---|---|
| mêmes noms de placeholder dans les deux fichiers | une signature, un paramètre par placeholder. Le cas correct |
| nom différent dans la traduction | **paramètre supplémentaire obligatoire**. Il faut revenir au nom anglais |
| placeholder absent du côté français alors qu'il est présent en anglais | `{source}` écrit une fois, il est remplacé par sa valeur dans les deux langues — pas d'erreur. C'est le cas normal |
| placeholder présent en français, absent en anglais | paramètre `Object` non typé **obligatoire**. À corriger, pas à garder |
| nom contenant `:` | échec de génération. `{mmss}`, et le `:` reste dans le texte |
| pluriel ou sélection ICU | déclarés **à l'identique** dans les deux fichiers (`16-i18n.md` règle 6). `chapterCount` est l'exemple de référence et il est déjà conforme |
| un mot à ne pas traduire : `HTTP`, `Lumen Tale`, un titre | littéral dans les deux fichiers, jamais un placeholder de traduction |

### 3.4 La chaîne de repli FR

```
_resolveLocale(preferredLocales, supportedLocales):       # dans lib/main.dart
  for preferred in preferredLocales ?? []:
      for supported in supportedLocales:
          if preferred.languageCode == supported.languageCode:
              return supported                # par CODE DE LANGUE, pas par chaine
  return Locale('fr')                          # B28 : repli FRANCAIS
```

**⚠️ Cette fonction vit dans `lib/main.dart` et n'est pas écrite par cette
fondation.** `16-i18n.md` règle 5 la nomme et lui donne son fichier ;
`architecture.md` § 3.1a dit que `MaterialApp.router` « **keeping** the existing
`localeListResolutionCallback` ». Elle est **déjà écrite**, elle est **correcte**,
et elle est rappelée ici pour que personne ne la réécrive dans `app/`.

**Trois branches qui ne sont pas des cas nominaux.**

| Situation | Sans la callback | Avec la callback |
|---|---|---|
| `de` | repli sur la **première** locale supportée, c'est-à-dire `en` — le modèle ARB | `fr` (**B28**) |
| `fr_CA` | ne rejoint pas `Locale('fr')` par égalité de chaîne | `fr`, par `languageCode` |
| liste vide ou `null` | `en` | `fr` |

### 3.5 Ce que cette fondation **ne** fait pas

Trois choses qu'un plan de localisation trop enthousiaste ferait, et qui ont
toutes déjà été décidées ailleurs.

- **Pas de sélecteur de langue dans l'app.** **B28** : « **No in-app
  language switch.** » `settings.md` § 5 le dit de l'écran : la ligne «
  Language » est **en lecture seule, sans chevron et sans effet de Ripple**,
  parce que B28 interdit un sélecteur. Aucune clé pour une destination, aucune
  clé pour un choix.
- **Pas de traduction du contenu des chapitres.** **B28** § 7.4 : « Chapter
  content itself is never translated or altered by the app — it is displayed as
  the site published it ». Le contenu d'un chapitre n'est **jamais** une chaîne
  localisée ; il est affiché tel quel, dans la langue dans laquelle il a été
  écrit. Une source chinoise reste en chinois sur un téléphone français.
- **Pas de formatage maison des dates et des nombres.** `16-i18n.md` règle 4 :
  `intl` `DateFormat` / `NumberFormat` pour la locale active. Un `{relative}`
  comme celui de `sourceUnavailableResolvedLastChecked` est un **placeholder**,
  et c'est l'appelant qui le formate avec `intl`.

---

## 4. Plan composants

### 4.1 Arbre de composants

```
Aucun composant d'interface. Cette fondation ne produit aucun widget :
elle produit deux fichiers JSON, la sortie générée, et un test.

lib/l10n/
├── app_en.arb          16 clés existantes + navMore + searchUnsupported* + 41 erreurs
├── app_fr.arb          les MÊMES clés, dans les MÊMES langues
└── generated/
    ├── app_localizations.dart        ← regenere, committe
    ├── app_localizations_en.dart     ← regenere, committe
    ├── app_localizations_fr.dart     ← regenere, committe
    └── untranslated-messages.json    ← doit etre VIDE (§ 2.4)

l10n.yaml           + required-resource-attributes, + untranslated-messages-file

test/l10n/
└── arb_completeness_test.dart   ← LA GARDE (§ 2.5)
```

### 4.2 Composants

| Composant | Type | Fichier cible | Rôle | State |
|---|---|---|---|---|
| `app_en.arb` | source ARB | `lib/l10n/` | le **modèle** : il définit l'API générée | — |
| `app_fr.arb` | source ARB | idem | la traduction ; **jamais** une clé de moins | — |
| `l10n.yaml` | configuration | racine | `gen-l10n` | — |
| `AppLocalizations` | **généré** | `lib/l10n/generated/` | les getters ; **jamais écrit à la main** | — |
| `untranslated-messages.json` | **généré** | `lib/l10n/generated/` | le rapport ; lu par la garde | — |
| `arb_completeness_test.dart` | test Dart | `test/l10n/` | la seule vérification d'égalité des deux fichiers | aucun |

**Riverpod** (`05-state-management.md`) : **aucun provider**. La locale est un
paramètre de `MaterialApp`, résolu par une callback ; la porter dans un provider
serait un état sans propriétaire, et `0-5` § 5 le dit déjà.

**Placement** : `lib/l10n/`, sortie dans `lib/l10n/generated/`. **Pas** de
`synthetic-package` dans `l10n.yaml` : c'est un no-op dans cette version de
Flutter et il émet un avertissement de dépréciation à chaque exécution
(`16-i18n.md`).

### 4.3 États par écran

**Aucun.** Aucun écran n'est produit ni modifié. Les états d'interface dont cette
fondation livre les chaînes sont ceux de `3-1`, `source-unavailable`, `settings`
et `settings-reader` — et le texte est déjà écrit dans leurs fichiers.

Une remarque qui compte : **`EmptyState`, `ErrorState` et `LoadingState` sont
définis par `design-system.md` § 2.7**, qui exige pour chacun une instance
nommée avec **du vrai texte**. Deux des trois instances de `EmptyState` ont leur texte ; `ErrorState` a `commonErrorTitle` / `commonErrorBody` /
`commonRetry` — mais **pas** l'instance nommée avec sa copie, et `ErrorState`
exige aussi « a sentence naming **what failed and what still works** ». La copie
n'existe dans aucun écran. Voir § 7 question ouverte 2.

### 4.4 Formulaires

Aucun. `09-widgets-ui.md` § Deferred : « Form focus navigation — when text forms
arrive ». Aucune forme de texte n'existe, donc aucun libellé de champ, aucun
message de validation.

---

## 5. Gestion d'état (state management)

| Donnée | Portée | Stockage | Initialisation | Mise à jour |
|---|---|---|---|---|
| Catalogue FR | application | `lib/l10n/app_fr.arb` + sortie générée | compilation | à chaque nouvelle chaîne, **dans le même commit** (`16-i18n.md` règle 2) |
| Catalogue EN | application | `lib/l10n/app_en.arb` — c'est le **modèle**, donc il **pilote** l'API | compilation | idem |
| Locale active | application | `MaterialApp.locale`, résolue par `localeListResolutionCallback` | `_resolveLocale` | quand le téléphone change de langue (**E12**) |
| Surcharge de langue | **inexistante** | — | — | **jamais**. **B28** : il n'y a pas de sélecteur de langue dans l'app |
| Placeholder nommé | par chaîne | bloc `@clé` dans l'ARB | avec la clé | jamais seul : la clé et son bloc vont ensemble |

**Ce qui n'est pas de l'état** : la langue choisie par l'utilisateur. Elle n'existe
pas — la langue est **une propriété du téléphone**, et la seule chose que l'app en
fait est de la lire. Un champ `localeOverride` dans `shared_preferences` serait
une seconde source de vérité pour une valeur que la plateforme possède déjà, et
`settings.md` § 11 le refuse : « An in-app language picker — B28 — the app
follows the phone ».

**Riverpod : aucun provider, aucune invalidation.** Rien ici ne vit dans le cycle
de vie de l'application ; tout est compilé dans la sortie générée.

---

## 6. Traçabilité des règles

### 6.1 Règles métier (B*)

| ID | Règle (PRD) | Implémentée où | Approche |
|---|---|---|---|
| **B28** | « Every user-visible string exists in French and in English, including all error and download-status messages. The app's language follows the phone's language setting, and an unrecognised language falls back to French. » | § 2.3 (la famille d'erreurs, 41 clés), § 2.5 (la garde), § 3.3 (les placeholders), § 3.4 (le repli) | Trois moitiés. **Le texte** : la famille d'erreurs de `source-unavailable.md` § 4.1, plus `navMore` et `searchUnsupported*` qui manquent, dans les deux langues, dans le même commit. **La garantie** : `arb_completeness_test.dart`, parce qu'aucun outil du projet ne la prend — une clé absente de l'ARB français produit une application à moitié française et `gen-l10n` sort **0**. **La signature** : la règle des placeholders de § 3.3, mesurée, parce que quarante-et-une clés sont écrites avec des noms français et que les prendre telles quelles ajouteraient quarante-et-unes signatures fantômes. Et le repli FR, **déjà écrit**, rappelé pour qu'il ne soit pas reecrit ailleurs |

### 6.2 Edge cases (E*)

`state.json` n'attribue **aucun** edge case à `localisation`. **E12** est tracé
ici parce que c'est le seul edge case dont cette fondation est un acteur.

| ID | Cas (PRD) | Approche de gestion | Où |
|---|---|---|---|
| **E12** | « The phone's language changes — Trigger: The reader switches the phone from French to English or back — Expected: The app's text, **including every error message**, follows the new language, with no loss of library, downloads or progress (B28) — Severity: medium » | La moitié « **including every error message** » est exactement ce que la famille de § 2.3 livre : quarante-et-une clés d'erreur, toutes dans les deux fichiers, donc aucune ne peut rester sur l'anglais quand le téléphone passe à l'anglais. La moitié « **no loss of library, downloads or progress** » n'est pas de cette fondation : c'est `0-5` § 3.6 correction 1 (un `GoRouter` reconstruit perd la pile) et le fait que la langue ne vit dans **aucune** base et **aucune** clé de prefs. Le test de § 11.1 vérifie la première moitié ; la seconde est un test de `0-5` | § 2.3, § 3.4, test de § 11.1 |

### 6.3 Contraintes (C*)

| ID | Contrainte (PRD) | Comment elle est respectée |
|---|---|---|
| **C2** | « Privacy — no account, no server, no telemetry of any kind. Reading data never leaves the phone (B4, B29). » | Aucune clé ne contient de donnée lecteur. Les titres de roman, les noms de site et les statuts HTTP sont des **placeholders**, jamais du texte figé dans l'ARB — donc aucune chaîne ne peut embarquer le nom d'un roman que le lecteur a ouvert. `flutter_localizations` est le seul paquet nonlocal, et il est local |
| **C5** | « User skill — the only technical user cannot write code. Repairing a site that has changed must be deliverable to them as a new installable file with no manual step on their side (US-17). » | Aucune clé ne dépend d'une action du lecteur. Le repli FR est automatique, le changement de langue est celui du téléphone, et il n'y a **aucun** sélecteur à utiliser |
| **C12** | « Privacy of failure reporting — … the app must make its own failure state obvious enough for that reader to describe it to the owner **in words** — a message that can be read aloud and reported back … » | C'est **la** raison d'être de `sourceUnavailableCauseLayoutChangedDictation` (`Say: {source} cannot be read. …`). Le nom de la source est un placeholder, donc le lecteur peut dire à voix haute le nom **réel** du site qui ne marche pas, et le propriétaire l'écrit. Une chaîne à trous est ici un mécanisme, pas une lacune |

---

## 7. Pièges à éviter

- **⚠️ Ne pas considérer « `flutter gen-l10n` est sorti 0 » comme « les deux
  langues sont complètes ».** Le comportement correct (**B28**) est : la clé est
  présente dans les deux ARB, et `test/l10n/arb_completeness_test.dart` le
  prouve. Le comportement observé est qu'une clé absente de `app_fr.arb`
  produit `String get onlyEn => 'Only English';` **dans la classe française**,
  avec `gen-l10n` au code 0, `flutter analyze` à zéro issue et `flutter test` au
  vert. C'est le même genre de garde qui a déjà trompé ce projet : `drift_dev
  schema dump` avec un argument sort 0 sans rien faire.
- **⚠️ Ne pas renommer un placeholder dans la traduction.** Le comportement
  correct (**B28**, § 3.3) est : le nom vient de l'ARB **anglais** et est le
  même dans les deux fichiers. Le comportement mesuré du renommage est
  `siteUnavailable(Object source, Object status, Object statut)` : le paramètre
  renommé est **ajouté** et devient obligatoire, donc chaque appel doit passer les
  deux. Le nom n'est jamais vu du lecteur.
- **⚠️ Ne pas écrire `{mm:ss}`.** Le comportement correct (§ 3.3) est :
  `{mmss}` comme nom, `:` conservé dans le texte. Un nom de placeholder ICU ne
  peut pas contenir `:` — le parseur le prend pour un séparateur d'argument, et
  la génération échoue.
- **⚠️ Ne pas mettre de point dans une clé.** Le comportement correct
  (`16-i18n.md` règle 3) est : la clé est plate et préfixée par l'écran, obtenue
  par l'algorithme de § 3.1. `cause.noConnection.kicker` ne devient pas un
  getter namespacé ; il devient un identifiant Dart que le linter refuse.
- **⚠️ Ne pas désactiver `required-resource-attributes`.** Le comportement
  correct (**B28**, `16-i18n.md` règle 2 — « Keep `@@locale`, `@key` metadata
  blocks » ») est : il reste `true`, et les quatorze blocs `@` manquants sont ecrits. C'est le **seul** levier de la chaîne d'outils qui échoue avec un code de sortie non
  nul ; le désactiver pour se débarrasser du travail rend le reste du plan sans garde.
- **⚠️ Ne pas traiter `untranslated-messages.json` comme une garde.** Le
  comportement correct (**B28**, § 2.4) est : c'est un **rapport** que `gen-l10n` écrit en
  sortant **0**, et c'est `arb_completeness_test.dart` qui le lit et échoue.
  L'ajouter à `l10n.yaml` sans le test ajoute un fichier vide de sens.
- **⚠️ Ne pas créer de sélecteur de langue.** Le comportement correct (**B28**) est
  : il n'y en a pas. La ligne « Language » de `settings.md` est en lecture seule,
  sans chevron et sans Ripple, et son texte dit que l'app suit le téléphone.
- **⚠️ Ne pas traduire le contenu des chapitres.** Le comportement correct
  (`16-i18n.md` règle 4, `prd.md` § 7.4) est : le contenu d'un chapitre n'est
  jamais une chaîne localisée. Une source chinoise reste en chinois sur un
  téléphone français — et c'est ce que le produit promet.
- **⚠️ Ne pas écrire `Locale('en')` comme valeur de repli.** Le comportement
  correct (**B28**) est : `Locale('fr')`. Sans la callback, `MaterialApp` replie
  sur la première locale supportée, qui est `en` — le modèle ARB. Le français est
  la langue principale du projet, et le repli doit donc être explicite.

### Questions ouvertes — à trancher, pas à deviner

1. **Aucune tranché ne possède le texte de `search-unsupported`, ni celui
   d'`ErrorState`.** `design-system.md` § 2.7 exige trois instances nommées de
   `EmptyState` avec **du vrai texte** : `library-empty` (les deux clés
   existent), `search-unsupported` (**aucune clé n'existe**) et `no-chapters`
   (**aucune clé n'existe**). Et `ErrorState` exige « a sentence naming **what
   failed and what still works** », ce que `commonErrorBody` — *« The operation
   could not be completed. »* — ne fait pas. **Option la moins chère et
   réversible** : cette fondation livre le **mécanisme** et la garde ; le texte de
   ces trois instances appartient à l'écran qui les rend (`3-1` pour
   `search-unsupported`, `3-2` pour `no-chapters`, `3-1` pour `ErrorState`), et
   chacune l'écrira dans les deux fichiers dans le même commit. Ce qui manque
   aujourd'hui, ce sont des cles d'écran est une
   chaîne orpheline. **Qui écrit ces trois textes ?**
2. **Le tableau `source-unavailable.md` § 4.1 utilise des placeholders français.**
   `{statut}`, `{roman}`, `{hôte}`, `{heure}`, `{thème}`, `{taille}`,
   `{actifs}` côté français ; `{status}`, `{novel}`, `{host}`, `{time}`,
   `{theme}`, `{size}`, `{enabled}` côté anglais. Ce plan les **uniformise sur
   l'anglais**, parce que c'est mesuré (§ 3.1, point 2) et parce que
   l'alternative coûte quarante-et-unes signatures fantômes. Mais l'écran est un
   document approuvé, et le changer est une édition que cette tranche n'a pas le
   droit de faire. **La règle à écrire est donc dans ce plan et dans
   `16-i18n.md`, pas dans l'écran** — et l'écran devrait être corrigé pour dire
   la même chose, sinon deux documents autorisent deux conventions.
3. **Les libellés des cinq onglets vivent dans deux endroits.** `design-system.md`
   § 3.2 les porte dans un tableau (Library / Bibliothèque, …) **et** les ARB
   les portent (`navLibrary`, `navUpdates`, `navHistory`, `navBrowse`) —
   `navMore` **manquant**. Le même contenu existe donc en prose et en JSON, et
   c'est un lieu où ils peuvent diverger. **Option la moins chère et
   réversible** : l'ARB fait autorité pour la valeur, `design-system.md` § 3.2
   fait autorité pour l'**ordre** et les **scores**, et la garde de § 2.5 vérifie
   que les cinq libellés sont non vides dans les deux langues — sans vérifier
   qu'ils correspondent au tableau, parce que cela demanderait de parser du
   Markdown dans un test.

---

## 8. Dépendances

| Dépend de | Nature | Statut | Fallback si absent |
|---|---|---|---|
| `flutter_localizations` (SDK) | data — delegates globaux | installé | **BLOCK.** Sans lui `MaterialApp` ne résout pas les delegates globaux et les widgets Material, qui affichent les dates et les nombres dans la locale du système plutôt que dans celle de l'app |
| `intl` 0.20.3 | data — `DateFormat`, `NumberFormat` pour les placeholders | installé | aucun |
| `flutter: generate: true` | configuration — `pubspec.yaml` | présent | **BLOCK.** Sans lui `gen-l10n` produit du code non importable et sort non nul |
| réseau | **aucun** | — | cette fondation n'en a pas besoin |

**Dépendants** : `6-7` (les traductions anglaises, y compris chaque message
d'erreur) et `0-5` (la barre d'onglets, qui consomme `navMore`). Plus, indirectement,
chacune des dix-huit tranches d'écran — mais aucune ne **dépend** d'elle dans
`state.json`, parce qu'elles utilisent `AppLocalizations` par le chemin Dart
normal. C'est le même genre de fan-in invisible que `architecture.md` § 6.6
décrit, mais ici il est bénin : une clé manquante **échoue** au lieu de
diverger.

---

## 9. Checklist de tâches

### Phase 1 — Données

- [ ] **Ne rien réécrire** : `l10n.yaml`, les deux ARB existants, la sortie
  générée et le câblage de `main.dart` sont déjà là et sont corrects. Cette
  fondation **ajoute**, elle ne réécrit pas
- [ ] Ajouter `required-resource-attributes: true` et
  `untranslated-messages-file:` à `l10n.yaml` (§ 2.4)
- [ ] **Écrire les quatorze blocs `@` manquants** dans `app_en.arb`, un par clé,
  avec une `description` qui dit à quoi sert la chaîne. Les deux clés qui en ont
  déjà un (`@chapterCount`, `@coverSemanticsLabel`) sont laissées telles quelles
- [ ] Ajouter `navMore` dans les deux ARB — `More` / `Plus`, la valeur de
  `design-system.md` § 3.2
- [ ] Ajouter les **quarante-et-une** clés de la famille d'erreurs (§ 2.3) dans
  les deux ARB, avec les **noms de placeholder anglais** des deux côtés, et
  `{mmss}` pour `{mm:ss}`
- [ ] Ajouter le bloc `@` de chacune des quarante-et-une clés
- [ ] Lancer `flutter gen-l10n` et **regarder la sortie**, pas seulement le code
  de retour (§ 3.1)

### Phase 2 — Logique métier

- [ ] Créer `test/l10n/arb_completeness_test.dart` — § 2.5, les sept tests
- [ ] Écrire l'algorithme `deriveKey` de § 3.1 **dans un commentaire exécutable**
  ou dans le nom des clés, et vérifier ses branches par des cas de test —
  notamment `settings` / `settings.group.reading` et `settings` / `row..label`
- [ ] Vérifier que `lib/l10n/generated/untranslated-messages.json` est
  **vide** — c'est le seul moyen de savoir que les deux fichiers sont
  alignés, parce que `gen-l10n` ne le signale pas autrement

### Phase 3 — Interface utilisateur

- [ ] **Aucun.** Cette fondation ne produit **aucun** écran et **aucun** widget.
  Elle produit deux fichiers JSON, la sortie générée, et un test. Les chaînes
  qu'elle livre sont destiné à être rendues par `3-1`, `source-unavailable`,
  `settings` et `settings-reader` — et le texte est déjà écrit dans leurs
  fichiers, dans les deux langues. Écrire un écran de démonstration des chaînes
  serait exactement ce que `main.dart` était avant `0-5` : une démonstration qui
  ne rend aucun service et que quelqu'un lira comme l'app.
- [ ] Aucun texte n'est ajouté à `main.dart`, et `_resolveLocale` n'y est pas
  touché

### Phase 4 — Intégration

- [ ] `flutter gen-l10n` — puis **committer les quatre fichiers générés** dans
  le même commit que les deux ARB (règle 4 de `AGENTS.md`)
- [ ] Aucun DDL, aucune migration, aucun provider
- [ ] Aucun paquet ajouté : `flutter_localizations` et `intl` sont déjà là
- [ ] `pubspec.yaml` n'est **pas** touché : `generate: true` est déjà présent et
  `08-coding-standards.md` interdit d'éditer le fichier à la main

### Phase 5 — Tests et polish

- [ ] Tests unitaires (§ 11.1)
- [ ] `test/widget_test.dart` passe **sans modification** : il teste déjà
  `navLibrary` dans les deux langues et le pluriel de `chapterCount`, et il doit
  continuer de passer. S'il casse, la correction est dans les ARB
- [ ] `dart format .` — propre
- [ ] `flutter analyze` — **zéro** issue, zéro `info`
- [ ] `flutter test` — tout passe
- [ ] `flutter gen-l10n` **après** les tests, pour vérifier que le rapport est
  toujours vide

### Vérifications finales

- [ ] `app_en.arb` et `app_fr.arb` ont **exactement** le même ensemble de clés
- [ ] Aucun nom de placeholder ne diffère entre les deux fichiers
- [ ] `untranslated-messages.json` est commité et **vide**
- [ ] Aucun des fichiers de `lib/l10n/generated/` n'est édité à la main
- [ ] Aucune clé ne contient `0 results`, `0 résultat`, `No results`,
  `Aucun résultat`, `Nothing found` ni `Empty`

---

## 10. Critères d'acceptation

- [ ] **B28** — `test/l10n/arb_completeness_test.dart` existe et ses sept tests
  passent.
- [ ] **B28** — `app_en.arb` et `app_fr.arb` ont exactement le même ensemble de
  clés, et la différence dans les deux sens est vide.
- [ ] **B28** — aucune valeur n'est vide ni composée d'espaces, dans les deux
  fichiers.
- [ ] **B28** — pour chaque clé, l'ensemble des noms de placeholder est
  **identique** dans `app_en.arb` et dans `app_fr.arb`.
- [ ] **B28** — `untranslated-messages.json` existe et vaut `{}`.
- [ ] **B28** — `required-resource-attributes: true` est dans `l10n.yaml`, et
  `flutter gen-l10n` sort **0** avec les quatorze blocs `@` ajoutés. Retirer une
  description fait sortir `gen-l10n` en **1** — vérifié une fois pour prouver que
  la garde sait échouer.
- [ ] **B28** — `navMore` existe dans les deux fichiers avec les valeurs `More` /
  `Plus` de `design-system.md` § 3.2.
- [ ] **B28** — les **quarante-et-une** clés de la famille d'erreurs existent
  dans les deux fichiers, et chacune a son bloc `@`.
- [ ] **B28** — aucune clé ne contient `0 results`, `0 résultat`,
  `No results`, `Aucun résultat`, `Nothing found` ni `Empty`.
- [ ] **B28** — la clé du compte à rebours s'appelle `…Countdown` et son
  placeholder s'appelle `mmss`, **pas** `mm:ss`, dans les deux fichiers.
- [ ] **B28** — aucune clé ne contient de valeur destinée à être traduite :
  `Lumen Tale` et `HTTP` sont des littéraux dans les deux, un titre de roman et
  un nom de site sont des placeholders.
- [ ] **B28** — il n'existe **aucune** clé de sélection de langue, et
  `shared_preferences` n'a **aucune** clé de langue. Le seul appelant de la
  locale est `_resolveLocale`, dans `lib/main.dart`, inchangé.
- [ ] **E12** — un test passe la locale `Locale('fr')`, construit
  `AppLocalizations.of(context)` pour `sourceUnavailableCauseLayoutChangedTitle`
  et vérifie le français ; puis repasse en `en` et vérifie l'anglais. C'est la
  moitié « including every error message » d'E12, démontrée sur une **clé
  d'erreur**, pas sur un libellé de navigation.
- [ ] — `flutter gen-l10n` a été exécuté **et sa sortie lue**, pas seulement son
  code de retour surveyor.
- [ ] — les quatre fichiers de `lib/l10n/generated/` sont committés dans le
  même commit que les deux ARB.
- [ ] — `l10n.yaml` ne contient pas `synthetic-package`, et `pubspec.yaml`
  contient toujours `generate: true`.
- [ ] — `test/widget_test.dart` passe sans avoir été modifié.

---

## 11. Plan de tests

### 11.1 Tests unitaires

Emplacement : `test/l10n/arb_completeness_test.dart` — **c'est le fichier de la
section 2.5**, il n'y en a pas d'autre.

| Test (nom choisi ici) | Scénario | IDs couverts |
|---|---|---|
| `the French file has every key the English template has` | une clé EN sans équivalent FR fait échouer le test | **B28** |
| `the English template has every key the French file has` | une clé FR sans équivalent EN fait échouer le test | **B28** |
| `no message is empty in either language` | `" "` et `""` font échouer le test | B28 |
| `placeholder names are identical in both languages` | `{status}` / `{statut}` fait échouer le test, et le message nomme les deux ensembles | **B28** |
| `every message has its @key metadata block` | une clé sans `@clé` fait échouer le test | B28 |
| `no ARB value contains a forbidden empty-result string` | `No results` dans une valeur fait échouer le test | **B28**, B22 |
| `gen-l10n left no untranslated message behind` | un `untranslated-messages.json` non vide fait échouer le test | **B28** |

Emplacement : `test/l10n/arb_key_derivation_test.dart`

| Test (nom choisi ici) | Scénario | IDs couverts |
|---|---|---|
| `a dotted screen key becomes one flat camelCase key` | `('source-unavailable', 'cause.noConnection.kicker')` → `sourceUnavailableCauseNoConnectionKicker` | B28 |
| `a leading segment matching the screen slug is dropped` | `('settings', 'settings.group.reading')` → `settingsGroupReading`, jamais `settingsSettingsGroupReading` | B28 |
| `a digit segment is preserved verbatim` | `('settings', 'retention.1w')` → `settingsRetention1w` ; `('settings', 'interval.12h')` → `settingsInterval12h` | B28 |
| `a five segment key keeps all five` | `('source-unavailable', 'cause.siteUnavailable.evidence.status')` → `sourceUnavailableCauseSiteUnavailableEvidenceStatus` | B28 |
| `an empty segment fails instead of being skipped` | `('settings', 'row..label')` échoue, et ne produit pas `settingsRowLabel` | B28 |
| `a key present on two screens is one key` | `settings.md` et `settings-reader.md` écrivent tous deux `error.write` → une seule clé `settingsErrorWrite` | B28 |

Emplacement : `test/l10n/localized_strings_test.dart`

| Test (nom choisi ici) | Scénario | IDs couverts |
|---|---|---|
| `an error message resolves in French` | locale `fr`, `sourceUnavailableCauseLayoutChangedTitle` rend le texte français de § 2.3 | **B28** |
| `an error message resolves in English` | locale `en`, la même clé rend le texte anglais | **B28** |
| `the error message family resolves in both languages` | les **quarante-et-une** clés se résolvent sans exception dans les deux langues — aucune ne renvoie l'anglais en `fr` | **B28**, E12 |
| `an unrecognised system locale resolves to French` | `resolveLocale([Locale('de')], supported)` == `Locale('fr')` | **B28** |
| `the nav labels resolve in both languages` | les cinq libellés, dont `More` / `Plus`, sont non vides dans les deux | B28 |
| `the countdown placeholder renders a colon` | `sourceUnavailableCauseSiteUnavailableCountdown('mmss' → '01:30')` rend `Available again in 01:30` | B28 |

### 11.2 Tests de composants

Un seul, et il existe déjà : `test/widget_test.dart` couvre
`configures localization for both supported locales`,
`provides light and dark themes and honours the system mode`,
`resolves English strings`, `resolves French strings` et
`plural forms are wired for both locales`. Il doit continuer à passer **sans
modification**. Ce n'est pas un test de composant de cette fondation, c'est un
test d'interface qui a une dépendance sur elle — et le dire est plus honnête que
d'en écrire un nouveau qui ne ferait que le même travail.

### 11.3 Tests d'intégration

Aucun pour cette fondation : elle n'a qu'un bord, le système de fichiers, et la
garde de § 11.1 le couvre. Le test d'intégration qui compte — « une recherche
qui ne trouve rien n'affiche jamais les chaînes de la famille d'erreurs, et une
source cassée affiche toujours la sienne » — appartient à `3-1` et au gate SC-6,
où l'interface existe enfin.

### 11.4 Tests E2E

Aucun pour cette fondation : **Q-008** n'est pas résolu, et changer la langue du
téléphone — le geste qui déclenche **E12** — ne peut pas être fait dans
`flutter test`. Ce qui **est** vérifiable ici est que les deux locales se
résolvent et que les deux catalogues sont alignés ; le reste est une
vérification manuelle d'appareil, listée en § 11.5.

### 11.5 Vérifications manuelles

| Vérification | Où | Attendu |
|---|---|---|
| Retirer une clé de `app_fr.arb` à la main, lancer `flutter test` | terminal | `the French file has every key the English template has` **échoue** avec le nom de la clé. C'est la preuve que la garde sait échouer |
| Retirer un bloc `@clé` à la main, lancer `flutter gen-l10n` | terminal | sortie **1**, message `Resource attribute "@…" was not found` |
| Renommer `{status}` en `{statut}` côté français, `flutter gen-l10n` | `lib/l10n/generated/app_localizations.dart` | la signature porte `Object status, Object statut` — la démonstration visuelle du piège |
| Lancer `flutter gen-l10n` avec une clé EN non traduite | `lib/l10n/generated/untranslated-messages.json` | le rapport la nomme, et `gen-l10n` sort **0** quand même |
| Passer le téléphone en allemand et ouvrir l'app | appareil | tout s'affiche en **français**, jamais en anglais, jamais en allemand |
| Passer le téléphone de `fr_CA` à `fr` et ouvrir l'app | appareil | aucune différence de langue — la comparaison est par code de langue |

---

## Checklist de gate

- [x] Sources explicitement référencées (PRD, architecture, roadmap, `16-i18n.md`, `13-error-handling.md`, `10-testing.md`, écrans, conventions, rules).
- [x] **B28** apparaît en § 6 avec le texte du PRD ; **E12** tracé en § 6.2 avec le motif de son inclusion, `state.json` n'attribuant aucun edge case à cette fondation.
- [x] Les contrats de données (§ 2) sont du **vrai Dart**, avec les imports, et la sortie générée est identifiée comme générée.
- [x] Les algorithmes (§ 3) sont en pseudocode avec **chaque** branche écrite, y compris `de`, `fr_CA`, liste vide, placeholder renommé, placeholder introduit, nom contenant `:`, segment vide et clé en double.
- [x] La checklist de tâches (§ 9) couvre les cinq phases, en signalant explicitement que la Phase 3 est vide et pourquoi — exactement comme le fait l'exemplaire pour `2-3`.
- [x] Les critères d'acceptation (§ 10) sont vérifiables individuellement, aucun ne dit « fonctionne bien ».
- [x] Le plan de tests (§ 11) couvre tous les IDs et nomme les trois fichiers de test.
- [x] **`README.md` § 2, finding F-003** : cette fondation n'est pas vérifiée mécaniquement par `coverage-check slice`, qui ne lit que `state.slices`. Sa vérification est **la lecture de ce plan**, et c'est écrit en tête de document.
- [ ] `coverage-check.js slice /workspaces/lumen_tale localisation` → **renvoie `Slice "localisation" not found in state.json`** — **attendu, ce n'est pas un échec**. C'est finding **F-003** de `README.md` § 2, et il n'y a pas de clé de fondation dans `state.slices` à passer au script.

**Statut** : `draft` → en attente de validation.