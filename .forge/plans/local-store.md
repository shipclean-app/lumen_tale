---
type: implementation-plan
slice: local-store
module: foundation
status: draft
generated_at: 2026-10-02
derived_from:
  - .forge/prd.md
  - .forge/architecture.md
  - .forge/design/design-system.md
conventions_ref: .forge/conventions.md
---

# Plan d'implémentation — local-store

> **Cette fondation est DÉJÀ LIVRÉE.** Ce plan ne prescrit pas une
> implémentation à écrire : il **documente** ce qui existe, nomme ses
> **41 colonnes** et ses **5 index**, et reproduit les **24 noms de test**
> réellement présents dans `test/core/database/` — **29 avec**
> `test/widget_test.dart`.
>
> **Aucune modification de schéma n'est proposée ici.** `schemaVersion` reste à
> **1**, et le plan le dit en toutes lettres dans chaque section où ce serait
> tentant.

---

## Sources

- **PRD** : `.forge/prd.md` — règles **B7**, **B29**, **B31**, **B32**, **B46**
- **Architecture** : `.forge/architecture.md` — § 2.1 (`local-store` **implémenté**), § 4.1 à § 4.9 (les six tables, champ par champ, puis les index), § 4.7 (ce qui n'est **pas** en base), § 4.8 (les 22 contraintes et **comment elles ont été prouvées**), § 6.1 (vague 0), § 7 (ADR-022)
- **DECISIONS** : `DECISIONS.md` **ADR-022** (la marque de téléchargement est une colonne, écrite après le renommage), **ADR-024** (`novels.author` et `novels.description` sont stockés, affichés, jamais cherchés), **ADR-013** (le registre des sources est du code, pas des lignes)
- **Code** : `lib/core/database/app_database.dart` (415 lignes), `lib/core/database/app_database.g.dart`, `lib/core/database/schema.json`
- **Tests** : `test/core/database/app_database_test.dart` (21 tests),
  `test/core/database/schema_snapshot_test.dart` (3 tests)
- **Règles projet** : `06-database.md` (règles 1 à 9), `02-architecture.md`, `13-error-handling.md`, `17-security.md`

---

## 1. Résumé de la slice

`local-store` a **deux moitiés**, et c'est la seconde qui mord.

**La moitié relationnelle** : six tables drift / SQLite dans
`lib/core/database/app_database.dart` — 41 colonnes, 5 index, `schemaVersion`
**1**, un instantané commité dans `lib/core/database/schema.json`, et
`test/core/database/schema_snapshot_test.dart` qui échoue quand l'instantané et
le schéma qui tourne divergent.

**La moitié qui n'est pas en base** : le **corps** d'un chapitre est un fichier
`.md` sur le disque, sous le répertoire **support** de l'application, indexé par
`<support>/chapters/<novelId>/<ordinal>.md`. B6 exige qu'un chapitre soit
*entièrement présent ou entièrement absent*, et c'est une propriété de système de
fichiers, pas de ligne. L'écriture atomique — fichier temporaire dans le **même**
dossier, puis `rename()` — appartient à la slice **`2-3`**, et ce plan la
mentionne parce que la colonne `downloaded_at` est **la** moitié de base de cette
propriété.

**Le fait qui a façonné cette fondation.** L'application des clés étrangères est
**désactivée par défaut, par connexion**, et n'est pas partie du format de
fichier. Une base créée avec le pragma actif s'ouvre avec lui inactif sauf si
chaque connexion le rallume. Sans cette ligne, toutes les contraintes
`references(...)` du fichier étaient **déclarées et jamais appliquées** — y
compris la `RESTRICT` de `history_entries.novelId`, qui est **la seule
application de B32**. B32 se lisait correctement dans le schéma, dans la relecture
et dans la documentation, et ne tenait pas. Le pragma est maintenant posé dans un
hook `setup` sur la connexion réelle, et un test affirme
`PRAGMA foreign_keys == 1` pour qu'une refactorisation future échoue au lieu
d'éteindre B32 en silence. **Toute seconde connexion doit le répéter** — c'est le
résidu de risque que `architecture.md` § 8 nomme.

**User stories couvertes** : US-03, US-05, US-07, US-09, US-11, US-12, US-17
**Règles métier couvertes** : B7, B29, B31, B32, B46
**Edge cases couverts** : aucun déclaré pour cette fondation dans `state.json`

---

## 2. Contrats de données (code)

> **Aucune modification n'est proposée.** Les six classes ci-dessous sont
> reproduites **telles qu'elles existent aujourd'hui**. Toute différence entre ce
> qui suit et `lib/core/database/app_database.dart` est un défaut de ce plan.

### 2.1 Les six tables — 41 colonnes

```dart
// lib/core/database/app_database.dart — À LIRE, PAS À MODIFIER
import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path_provider/path_provider.dart';
import 'package:sqlite3/sqlite3.dart';

part 'app_database.g.dart';

/// 11 colonnes. `idx_novels_title`.
@DataClassName('NovelRow')
/// **Index `idx_novels_title`.** **B45** — la recherche de bibliothèque est
/// **titre seul**. Cet index existe pour que « non cherchable par auteur ou
/// genre » soit imposé par l'**absence** d'index sur ces colonnes, et pas
/// seulement par une règle que personne ne lit.
@TableIndex(name: 'idx_novels_title', columns: {#title})
class Novels extends Table {
  /// B3 — stable d'une session à l'autre. MD5 de
  /// `'${name.toLowerCase()}/$lang/$versionId'` selon la règle 1 de
  /// `03-source-system.md`, combiné à l'id de la source. Jamais écrit à la main.
  TextColumn get id => text()();

  /// B2 — le seul site d'où vient ce roman. B40 interdit de fusionner les
  /// romans de deux sites, donc c'est partie de l'identité primaire et jamais
  /// nullable.
  TextColumn get sourceId => text()();

  /// Règle 3 de `03-source-system.md` — relatif (chemin + requête), jamais une
  /// URL complète. Les hôtes changent ; une URL absolue stockée casse en
  /// silence.
  TextColumn get url => text()();

  /// Adjacent à B10 — affiché tel quel le site le présente. Jamais normalisé,
  /// jamais mis en capitale, jamais rogné au-delà des espaces de bord.
  TextColumn get title => text()();

  /// **Affiché, jamais cherché** (ADR-024). **Nullable, parce que le site peut
  /// n'en publier aucun.** `library.md` spécifie qu'un auteur absent fait
  /// s'effondrer le sous-titre au lieu d'afficher un tiret cadratin, donc une
  /// chaîne vide ici serait un mensonge sur une valeur que personne ne nous a
  /// donnée. Absent et vide sont deux états différents, et c'est ici qu'ils se
  /// distinguent.
  ///
  /// **Aucun index, et c'est le but.** B45 promet une recherche par titre seul ;
  /// `idx_novels_title` existe pour que cette promesse soit imposée par
  /// l'**absence** d'index ici plutôt que par une règle que personne ne lit.
  TextColumn get author => text().nullable()();

  /// **Affiché, jamais cherché** (ADR-024) — le résumé de la fiche.
  ///
  /// **B44 : le balisage n'est ni exécuté ni stocké.** Le site peut publier ceci
  /// en HTML ; le convertisseur écrit du texte ici et supprime les balises, donc
  /// il n'y a aucun balisage dans cette base à assainir plus tard.
  TextColumn get description => text().nullable()();

  /// Règle 8 de `03-source-system.md` — chaînes propres au site converties vers
  /// l'énumération partagée. Vide signifie que le site n'a rien dit.
  TextColumn get status => text().withDefault(const Constant(''))();

  /// Nullable parce qu'un site omet souvent une couverture, et qu'une couverture
  /// inventée est pire que pas de couverture. Null signifie « ce roman n'a pas de
  /// couverture », pas « nous avons échoué ».
  TextColumn get coverUrl => text().nullable()();

  /// B11 — garder un roman dans la bibliothèque et le suivre sont le même acte.
  /// Un seul drapeau, pas deux.
  BoolColumn get inLibrary => boolean().withDefault(const Constant(false))();

  /// B49 — quand ce roman a été vérifié pour la dernière fois. **Null signifie
  /// « jamais vérifié »** et cette distinction porte du poids : B48 interdit de
  /// présenter un compte local comme s'il venait d'une vérification.
  DateTimeColumn get lastCheckedAt => dateTime().nullable()();

  /// B12 — quand le lecteur l'a ajouté ; utilisé seulement pour le tri de B17 et
  /// un départage. Null tant que `inLibrary` est faux.
  DateTimeColumn get addedAt => dateTime().nullable()();

  @override
  Set<Column> get primaryKey => {id};

  @override
  List<Set<Column>> get uniqueKeys => [];
}
```

```dart
/// 9 colonnes. `idx_chapters_novel_ordinal`, `idx_chapters_novel_read`.
@DataClassName('ChapterRow')
/// **Index `idx_chapters_novel_ordinal`.** **B9** — la liste de chapitres est
/// l'ordre complet du site et doit rester complète quelle que soit sa longueur,
/// donc elle se lit dans l'ordre `(novelId, ordinal)`.
@TableIndex(name: 'idx_chapters_novel_ordinal', columns: {#novelId, #ordinal})
/// **Index `idx_chapters_novel_read`.** **B14 / B48** — le compte des non-ouverts
/// est `count(chapters.is_read = 0)` groupé par roman. Un compte dérivé sur
/// 10 000 lignes par roman est la requête que B48 existe pour garder **exacte**,
/// et c'est cet index qui en fait une opération de liste plutôt qu'un balayage.
@TableIndex(name: 'idx_chapters_novel_read', columns: {#novelId, #isRead})
class Chapters extends Table {
  /// B3 — stable. Dérivé de l'id du roman plus l'url propre du chapitre.
  TextColumn get id => text()();

  /// CASCADE à la suppression : B32 — retirer un roman supprime ses
  /// *enregistrements* de chapitres, mais **jamais ses fichiers téléchargés**.
  /// Les fichiers sont indexés par chemin et ne sont pas touchés par cette
  /// suppression ; voir `07-downloads-offline.md`.
  TextColumn get novelId =>
      text().references(Novels, #id, onDelete: KeyAction.cascade)();

  /// B10 — affiché exactement tel que le site le présente.
  TextColumn get name => text()();

  /// Règle 9 de `03-source-system.md` — `ChapterRecognition`. **-1 signifie
  /// illisible et doit rendre un tiret cadratin, jamais 0.** 0 est un vrai
  /// numéro de chapitre (un extra, un omake, une note d'auteur) et confondre les
  /// deux est une violation de B10.
  RealColumn get number => real().withDefault(const Constant(-1))();

  /// Url relative, règle 3 de `03-source-system.md`.
  TextColumn get url => text()();

  /// B13 — un chapitre compte comme nouveau jusqu'à ce que le lecteur l'ouvre ;
  /// l'ouvrir efface le marqueur. C'est tout le modèle de comptage de B14 : le
  /// compte des non-ouverts est `count(isRead == false)`, **dérivé, jamais
  /// stocké**, donc il ne peut pas diverger des chapitres qu'il compte (B48).
  BoolColumn get isRead => boolean().withDefault(const Constant(false))();

  /// Quand il est devenu lu. Null tant que `isRead` est faux.
  DateTimeColumn get readAt => dateTime().nullable()();

  /// **La marque de B6.** Null signifie « non téléchargé ». Non null signifie que
  /// le fichier `.md` était **entièrement** présent quand ceci a été écrit.
  ///
  /// La marque est écrite **après** le renommage atomique dans `2-3`, jamais
  /// avant. Cet ordre est toute l'intention de B6 : un crash entre les deux
  /// étapes laisse un fichier sans marque, qui est le **sens sûr** — le chapitre
  /// se propose au téléchargement au lieu de s'ouvrir comme s'il était complet.
  /// L'inverse, une marque sans fichier, est inatteignable, et c'est cela qui rend
  /// B6 exprimable plutôt que seulement vrai du chemin heureux.
  DateTimeColumn get downloadedAt => dateTime().nullable()();

  /// B9 — l'ordre de lecture est l'ordre du site, donc c'est un ordinal explicite
  /// et non quelque chose de re-dérivé de `number`. Les sites entremêlent
  /// volumes, histoires annexes et trous numériques ; re-trier par `number` les
  /// remettrait dans le désordre.
  IntColumn get ordinal => integer()();

  @override
  Set<Column> get primaryKey => {id};
}
```

```dart
/// 3 colonnes. Aucun index.
@DataClassName('PositionRow')
class ReadingPositions extends Table {
  /// B16 — une position ne peut pas outliver son chapitre.
  TextColumn get chapterId =>
      text().references(Chapters, #id, onDelete: KeyAction.cascade)();

  /// B16 / ADR-009 — un **décalage de défilement**, pas un index de page ni un
  /// numéro de page. ADR-009 reporte les modes paginés en v2, et un décalage est
  /// la seule représentation depuis laquelle v2 peut reprendre sans la
  /// convertir.
  RealColumn get offset => real().withDefault(const Constant(0))();

  DateTimeColumn get updatedAt => dateTime()();

  @override
  Set<Column> get primaryKey => {chapterId};
}

/// 4 colonnes. `idx_history_opened_at`.
@DataClassName('HistoryRow')
/// **Index `idx_history_opened_at`.** **B17** — « récemment ouverts, le plus
/// récent d'abord », avec la borne de rétention de **B47** sur la même colonne.
@TableIndex(name: 'idx_history_opened_at', columns: {#openedAt})
class HistoryEntries extends Table {
  TextColumn get id => text()();

  /// **RESTRICT, pas CASCADE.** B32 — retirer un roman **conserve** ses
  /// chapitres téléchargés, et l'historique de ce qui a été lu survit aussi. Un
  /// `CASCADE` ici supprimerait le relevé du lecteur comme effet secondaire
  /// d'une opération sur les fichiers — l'échec exact de B32, exprimé comme
  /// valeur par défaut du schéma, et invisible à la relecture parce que `CASCADE`
  /// a l'air correct partout ailleurs dans ce fichier.
  TextColumn get novelId =>
      text().references(Novels, #id, onDelete: KeyAction.restrict)();

  TextColumn get chapterId =>
      text().references(Chapters, #id, onDelete: KeyAction.cascade)();

  /// B17 — la colonne de tri, décroissante.
  DateTimeColumn get openedAt => dateTime()();

  @override
  Set<Column> get primaryKey => {id};
}
```

```dart
/// 9 colonnes. `idx_queue_state`.
@DataClassName('QueueRow')
/// **Index `idx_queue_state`.** Le filtre en pause / en file, lu à chaque
/// reprise.
@TableIndex(name: 'idx_queue_state', columns: {#state})
class QueueItems extends Table {
  TextColumn get id => text()();

  TextColumn get chapterId =>
      text().references(Chapters, #id, onDelete: KeyAction.cascade)();

  /// Déclaré `TextColumn`, pas `DownloadState` : `ColumnBuilder.map` est un
  /// builder à type fantôme dont le type de retour déclaré est `ColumnBuilder<T>`
  /// du type **sous-jacent**, donc un type non-String ici fait échouer
  /// `flutter analyze` avant même que drift_dev ne s'exécute. La table déclare
  /// `TextColumn`, et c'est le générateur qui fait que la ligne générée expose
  /// `DownloadState`.
  TextColumn get state => text()
      .map(const DownloadStateConverter())
      .withDefault(const Constant('queued'))();

  /// B18 — l'ordre d'insertion. C'est **lui**, et non `chapters.ordinal`, que la
  /// file lit, pour qu'un ordre choisi à la main soit honoré.
  IntColumn get queuePosition => integer()();

  DateTimeColumn get addedAt => dateTime()();

  DateTimeColumn get startedAt => dateTime().nullable()();

  DateTimeColumn get finishedAt => dateTime().nullable()();

  /// B20 — un téléchargement interrompu reprend plutôt que de recommencer, donc
  /// c'est le nombre de tentatives qui distingue une reprise d'une fetching.
  IntColumn get attempts => integer().withDefault(const Constant(0))();

  /// B24 / B22 — un code typé de la hiérarchie de `13-error-handling.md`, pour que
  /// l'interface puisse dire **pourquoi** quelque chose a échoué. « failed » sans
  /// raison est exactement l'état que B22 existe pour empêcher.
  TextColumn get errorCode =>
      text().nullable().withDefault(const Constant(''))();

  @override
  Set<Column> get primaryKey => {id};
}

/// 5 colonnes. Aucun index.
@DataClassName('SourceRow')
class Sources extends Table {
  /// Règle 1 de `03-source-system.md` — l'id du registre, jamais écrit à la main.
  TextColumn get id => text()();

  /// B1 — masquer une source cache ses romans à la navigation et **conserve
  /// tous les téléchargements**.
  BoolColumn get enabled => boolean().withDefault(const Constant(true))();

  /// B49 — null signifie « jamais vérifié », ce que l'interface doit afficher.
  DateTimeColumn get lastCheckedAt => dateTime().nullable()();

  /// B22 — le code typé du dernier échec, pour que `sources` puisse rendre
  /// `unavailable` sans avoir tenté un fetch.
  TextColumn get lastErrorCode =>
      text().nullable().withDefault(const Constant(''))();

  /// Règle 6 de `03-source-system.md` — valeurs `ConfigurableSource`,
  /// namespacées `source_<id>`. Texte JSON, **opaque pour la plateforme** : la
  /// règle de B41 qui dit que la plateforme n'interprète jamais les valeurs d'une
  /// source s'applique aux filtres, et elle s'applique ici aussi.
  TextColumn get settings => text().withDefault(const Constant('{}'))();

  @override
  Set<Column> get primaryKey => {id};
}
```

**Le décompte, vérifiable par le test de l'instantané :**

| Table | Colonnes | Index |
|---|---|---|
| `novels` | **11** | `idx_novels_title` |
| `chapters` | **9** | `idx_chapters_novel_ordinal`, `idx_chapters_novel_read` |
| `reading_positions` | **3** | — |
| `history_entries` | **4** | `idx_history_opened_at` |
| `queue_items` | **9** | `idx_queue_state` |
| `sources` | **5** | — |
| **Total** | **41** | **5** |

### 2.2 La connexion, et la ligne qui compte

```dart
/// La base de données locale de l'application.
///
/// **La version 1 est le premier schéma livré.** `06-database.md` possède les
/// migrations : un changement de version livre un pas de `MigrationStrategy`, et
/// `dart run drift_dev schema dump lib/core/database/app_database.dart
/// lib/core/database/schema.json` exporte l'instantané commité à côté de ce
/// fichier. **Deux arguments** — avec un seul, la commande affiche son usage et
/// sort avec 0, donc elle a l'air d'avoir tourné. B31 est la raison pour laquelle
/// cette discipline n'est pas facultative : installer une nouvelle version par
///-dessus une existante doit préserver chaque ligne, donc une migration qui supprime
/// une table est une migration qui rompt la seule promesse que cette application
/// fait et que ses concurrentes rompent.
@DriftDatabase(tables: [Novels, Chapters, ReadingPositions, HistoryEntries, QueueItems, Sources])
class AppDatabase extends _$AppDatabase {
  /// `LazyDatabase`, et non un exécuteur ouvert-Phurinement : résoudre le
  /// répertoire support traverse un canal de plateforme, et faire cela dans le
  /// constructeur toucherait la plateforme avant que quoi que ce soit ait demandé
  /// une requête.
  AppDatabase() : super(_openLazy());

  /// Instance en mémoire pour les tests. Nommée pour qu'un test ne puisse pas
  /// ouvrir par accident la vraie bibliothèque du lecteur.
  AppDatabase.forTesting(super.executor);

  @override
  int get schemaVersion => 1;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    // B31 — `beforeOpen` est le seul endroit où une erreur de schéma peut être
    // attrapée pendant que les données sont encore intactes. Un pas destructif
    // ici serait la pire ligne de la base de code, donc il n'y a **délibérément**
    // aucune implémentation de `onUpgrade` pour l'instant : la version 1 n'a pas
    // de prédécesseur, et en ajouter une est la première chose à faire à la
    // prochaine table.
    onCreate: (m) async => m.createAll(),
  );
}

/// Ouvre le vrai fichier de base, sous le répertoire **support** de l'application
/// et non ses répertoires documents ou cache.
///
/// **Support, pas cache.** Le système d'exploitation peut vider n'importe quoi du
/// répertoire cache, et B7 exige qu'un chapitre stocké reste lisible — donc une
/// base qui détient la bibliothèque, les positions de lecture et l'historique ne
/// doit pas vivre là où le système a le droit de la récupérer. Cette seule ligne,
/// c'est B7 et B31 s'appliquant à l'emplacement du stockage plutôt qu'au code.
LazyDatabase _openLazy() => LazyDatabase(() async {
  final dir = await getApplicationSupportDirectory();
  return NativeDatabase.createInBackground(
    File('${dir.path}/lumen.db'),
    setup: _setup,
  );
});

/// **C'est la fonction la plus importante de la couche base de données.**
///
/// SQLite livre l'application des clés étrangères **désactivée**, par connexion,
/// et ce n'est pas partie du format de fichier : une base créée avec le pragma
/// actif s'ouvre avec lui inactif sauf si chaque connexion le rallume. Sans la
/// ligne ci-dessous, chaque `references(...)` de ce fichier est *déclaré* et puis
/// *jamais appliqué* — le `CASCADE` qui nettoie les chapitres d'un roman, et plus
/// importantement le `RESTRICT` de `history_entries.novelId` qui est **la seule
/// application de B32**. B32 se lirait correctement dans le schéma, dans la
/// relecture et dans la documentation, et ne tiendrait pas.
///
/// Deux tests l'ont attrapé : un qui affirme le `CASCADE`, un qui affirme que le
/// `RESTRICT` refuse la suppression. Les deux ont échoué face à un schéma qui
/// semblait parfaitement correct. Un `CHECK` que personne n'a exécuté est
/// l'échec exact décrit par SKILL.md § 4.5 — et celui-ci est pire, parce que
/// l'échec est **invisible** plutôt que bruyant : l'application se comporte
/// comme si les contraintes étaient là.
///
/// `foreign_keys` est affirme à 1 dans `app_database_test.dart`, pour qu'une
/// refactorisation future qui supprime cette ligne échoue à un test au lieu
/// d'éteindre B32 en silence.
/// Synchrone, et il prend le propre [Database] de sqlite3 — `DatabaseSetup` est
/// déclaré `void Function(Database database)` (`lib/native.dart:30`), donc un
/// `await` ici ne compile pas et n'est pas voulu.
void _setup(Database db) {
  db.execute('PRAGMA foreign_keys = ON');
}
```

Et l'énumération qui est stockée **par nom**, jamais par ordinal :

```dart
/// Cycle de vie d'un chapitre dans la file de téléchargement.
///
/// `queued` et `downloading` sont délibérément distincts : B19 laisse le lecteur
/// mettre une file en pause, et un élément en pause est `queued` avec la file
/// arrêtée, pas un quatrième état. Les confondre rendrait « en pause »
/// non représentable.
enum DownloadState {
  /// B18 — en file, dans l'ordre de lecture, non démarré.
  queued,
  /// B18 — B19 — en cours de récupération.
  downloading,
  /// B6 — le chapitre est présent et complet sur le téléphone.
  done,
  /// B24 — la dernière tentative a échoué ; `queueItems.errorCode` dit pourquoi.
  failed,
}

/// Stocke l'énumération par **nom**, et non par ordinal.
///
/// Lu dans le paquet installé plutôt que de mémoire : dans drift 2.35.1
/// `textEnum<T>()` est déclaré `ColumnBuilder<String> textEnum<T extends Enum>()`
/// (`lib/src/dsl/table.dart:157`) — un constructeur String à paramètre de type
/// fantôme, qui ne donne donc **pas** de `Column<DownloadState>`.
class DownloadStateConverter extends TypeConverter<DownloadState, String> {
  const DownloadStateConverter();

  @override
  DownloadState fromSql(String fromDb) => DownloadState.values.byName(fromDb);

  @override
  String toSql(DownloadState value) => value.name;
}
```

### 2.3 Contrats API

**Aucun appel réseau, aucune écriture en dehors de la base.** Cette fondation
n'a pas de surface réseau parce qu'elle n'a pas de source.

L'API qu'elle **expose** aux slices supérieures, et qui est le contrat à
respecter :

```dart
// lib/core/database/app_database.dart — la surface qu'une slice au-dessus
// utilise, et RIEN de plus. Les six accesseurs viennent du générateur drift.
class AppDatabase extends _$AppDatabase {
  /// La connexion réelle, sous le répertoire **support**.
  AppDatabase();

  /// En mémoire, pour les tests. Nommée pour qu'un test ne puisse pas ouvrir par
  /// accident la vraie bibliothèque du lecteur.
  AppDatabase.forTesting(super.executor);

  /// Les six tables, générées par `drift_dev` :
  ///   db.novels           → TableInfo<Novels, NovelRow>            (11 colonnes)
  ///   db.chapters         → TableInfo<Chapters, ChapterRow>        ( 9 colonnes)
  ///   db.readingPositions → TableInfo<ReadingPositions, PositionRow> (3 colonnes)
  ///   db.historyEntries   → TableInfo<HistoryEntries, HistoryRow>  ( 4 colonnes)
  ///   db.queueItems       → TableInfo<QueueItems, QueueRow>        ( 9 colonnes)
  ///   db.sources          → TableInfo<Sources, SourceRow>         ( 5 colonnes)
}

/// Ce que cette surface n'expose PAS, volontairement — et c'est la moitié de sa
/// valeur :
///
/// - **aucun** getter « chapitres téléchargés » qui sonderait le disque
///   (ADR-022 : `chapters.downloaded_at` EST la marque)
/// - **aucun** getter « non-ouverts » qui serait un compteur stocké
///   (B48 : `COUNT(is_read = 0)`, dérivé à chaque lecture)
/// - **aucun** DAO : ce fichier est le schéma ; les DAO vivent dans `data/`
/// - **aucune** colonne d'identité, de synchronisation ou de télémétrie (B29)
/// - **aucune** colonne de concurrence dans `queue_items` (B18 : une constante
///   exprimée par une colonne est quelque chose qu'une implémentation pourrait
///   changer — le test en affirme l'absence)
```

---

## 3. Algorithmes critiques

### 3.1 L'ouverture d'une connexion (couvre **B32**)

```
openConnection():
  dir = getApplicationSupportDirectory()          # ⚠️ SUPPORT, jamais cache
  return NativeDatabase.createInBackground(
      File('${dir.path}/lumen.db'),
      setup: (db) => db.execute('PRAGMA foreign_keys = ON'),
  )
  # ⚠️ LE SETUP EST DANS LE CONSTRUCTEUR. Anywhere else, and the pragma is
  # declared and not applied.

# ── branche 1 : la vraie connexion (application) ─────────────────────
# → pragmata posés par _setup. PRAGMA foreign_keys == 1.

# ── branche 2 : une connexion de test ────────────────────────────────
# AppDatabase.forTesting(NativeDatabase.memory(
#     setup: (e) => e.execute('PRAGMA foreign_keys = ON')))
# ⚠️ LE SETUP N'EST PAS APPLIQUÉ PAR forTesting. Un test qui l'oublierait
# n'aurait aucune application de clés étrangères — ce qui est précisément le bug
# que ces tests existent pour attraper, et c'est pourquoi app_database_test.dart
# passe le setup explicitement dans son setUp.

# ── branche 3 : l'isolate de fond de 6-10 ───────────────────────────
# Une **deuxième** connexion, dans un autre isolate. Elle DOIT passer par le même
# helper de setup. C'est le seul résidu de risque que architecture.md § 8 nomme
# pour cette fondation.

# ── branche 4 : la base n'existe pas ────────────────────────────────
# → onCreate → m.createAll(). Les six tables, les cinq index, version 1.
# ⚠️ AUCUNE branche onUpgrade. La version 1 n'a pas de prédécesseur ; en écrire
# une sans migration serait un pas destructif déguisé.
```

### 3.2 Le cycle de vie d'une migration (couvre **B31**)

```
# Quand — et SEULEMENT quand — la prochaine table ou le prochain changement
# de forme arrive :

1. Écrire le pas de migration EXPLICITE dans MigrationStrategy.
   ⚠️ JAMAIS stepNo transactionné, JAMAIS deleteAll(), JAMAIS
   beforeOpen: (details) async { await customStatement('DROP TABLE novels'); }
   → c'est la pire ligne possible dans ce fichier, et B31 la rend
   irréparable : il n'y a ni sauvegarde ni export (ADR-010).

2. Bumper schemaVersion. La version 1 → 2.

3. Régénérer :  dart run build_runner build

4. Ré-exporter l'instantané :
     dart run drift_dev schema dump \
       lib/core/database/app_database.dart \
       lib/core/database/schema.json
   ⚠️ DEUX ARGUMENTS. Avec un seul, la commande affiche son usage et sort avec 0 :
   elle a l'air d'avoir tourné. C'est un piège de ce projet, pas une hypothèse.

5. flutter test  →  schema_snapshot_test.dart échoue si l'instantané et le
   schéma qui tourne divergent.
   ⚠️ Si ce test est rouge, le correctif est d'ECRIRE LA MIGRATION et de
   ré-exporter. Ré-exporter et continuer n'est JAMAIS le correctif.

6. Rejouer le drill d'upgrade-safety (gate:upgrade-safety, hors du graphe de
   slices). ⚠️ Les FICHIERS téléchargés sont vérifiés, pas seulement les lignes :
   la garantie de B31 porte sur ce qui survit sur le téléphone, et une migration
   qui supprime une table passerait un contrôle limité aux lignes.
```

### 3.3 Les cinq index, et la façon dont on sait qu'ils existent (couvre **B14**, **B17**, **B45**, **B9**)

```
# Chaque index est déclaré PAR L'ANNOTATION, au-dessus de `class X extends
# Table {`, jamais dans le corps.

@TableIndex(name: 'idx_novels_title', columns: {#title})                        # B45
@TableIndex(name: 'idx_chapters_novel_ordinal', columns: {#novelId, #ordinal})   # B9
@TableIndex(name: 'idx_chapters_novel_read', columns: {#novelId, #isRead})       # B14 / B48
@TableIndex(name: 'idx_history_opened_at', columns: {#openedAt})                # B17
@TableIndex(name: 'idx_queue_state', columns: {#state})                         # la file

# ── Ce que la preuve couvre, et ce qu'elle ne couvre pas ────────────
#
# 1. schema_snapshot_test.dart prouve qu'un index **retiré** est détecté :
#    l'instantané enregistre les index à côté des tables.
#    ⚠️ Il a dû être APPRIS à sauter les entités non-table. Lire `columns` sur
#    une entité index lève, et c'est ainsi que cette boucle a découvert que
#    l'instantané avait grandi d'une catégorie qu'elle n'avait jamais gérée.
#    ⚠️ Et avant aujourd'hui, l'instantané ne contenait AUCUNE entité index : une
#    catégorie vide dans un instantané a exactement l'air d'une catégorie
#    couverte.
#
# 2. app_database_test.dart lit `sqlite_master` DIRECTEMENT, et prouve que les
#    cinq existent dans la base VIVANTE. C'est un échec DIFFÉRENT : un index
#    déclaré en Dart et jamais créé — ce qu'aucun instantané ne peut voir.
#
# 3. Les deux pièges de placement, tous deux rencontrés, tous deux SILENCIEUX :
#    ⚠️ @TableIndex est @Target({TargetKind.classType}) : l'annotation va
#       AU-DESSUS de `class X extends Table {`. À l'intérieur, le générateur
#       n'émet rien et drift ne prévient pas.
#    ⚠️ Un nom de getter erroné produit `CREATE INDEX x ON t ()` — assez
#       valide pour compiler, fatal à `createAll()`. `#readAt` sur
#       `HistoryEntries`, dont la colonne est `openedAt`, a fait tomber toute la
#       suite de tests avec `near ")": syntax error`.
#    Aucun des deux ne produit de diagnostic d'analyseur.

# ── Aucun de ces index ne fait monter schemaVersion ────────────────
# Un index n'est pas une colonne : le sens d'aucune ligne ne change, donc c'est
# du DDL additif à la version 1, sans pas de migration. C'est la raison de les
# avoir déclarés avant une publication plutôt qu'après le premier rapport de
# bogue sur 10 000 chapitres. B31 n'est pas affecté.
```

---

## 4. Plan composants

### 4.1 Arbre de composants

```
Aucun composant d'interface. Cette fondation produit un schéma et une connexion.

AppDatabase extends _$AppDatabase
├── schemaVersion = 1
├── migration      → onCreate: m.createAll()   (aucun onUpgrade)
│
└── _openLazy()    → LazyDatabase
    ├── getApplicationSupportDirectory()          ⚠️ SUPPORT, jamais cache
    ├── File('<support>/lumen.db')
    ├── NativeDatabase.createInBackground(…, setup: _setup)
    └── _setup(Database) → PRAGMA foreign_keys = ON   ⚠️ la ligne la plus
                                                          importante du fichier

Les 6 Table classes : Novels · Chapters · ReadingPositions · HistoryEntries ·
                      QueueItems · Sources
+ DownloadState (enum) et DownloadStateConverter (par NOM, pas par ordinal)
+ app_database.g.dart   (généré par drift_dev, commité)
+ schema.json           (instantané commité, 41 colonnes, 5 index, format 1.3.0)
```

### 4.2 Composants

| Composant | Type | Fichier | Colonnes / taille | Rôle |
|---|---|---|---|---|
| `AppDatabase` | classe drift | `lib/core/database/app_database.dart` | — | la base, version 1 |
| `Novels` | `Table` | idem | **11** | B2, B3, B10, B11, B12, B45, B48, B49, ADR-024 |
| `Chapters` | `Table` | idem | **9** | B6, B9, B10, B13, B14, B48, ADR-022 |
| `ReadingPositions` | `Table` | idem | **3** | B16, ADR-009, **B46** |
| `HistoryEntries` | `Table` | idem | **4** | B17, B32, B47 |
| `QueueItems` | `Table` | idem | **9** | B18, B19, B20, B24 |
| `Sources` | `Table` | idem | **5** | B1, B13, B22, B49, ADR-013 |
| `DownloadState` | enum, 4 valeurs | idem | — | B18, B19, B6, B24 |
| `DownloadStateConverter` | `TypeConverter` | idem | — | stocke par **nom** |
| `_setup` | fonction | idem | **1 ligne** | `PRAGMA foreign_keys = ON` |
| `schema.json` | instantané | `lib/core/database/schema.json` | 6 tables, 5 index, `_meta.version = "1.3.0"` | la vérité committée |

**Riverpod** : **aucun provider dans cette fondation.** Un provider de base de
données serait un singleton dont l'état n'est pas observable, et `data/` déclare
le sien quand une slice a besoin de l'injecter. `05-state-management.md` est la
règle ; cette fondation lui obéit en ne fournissant rien.

### 4.3 États par écran

**Aucun.** Aucun écran n'est produit ni modifié. Aucun état d'interface
n'appartient à cette fondation — et c'est la bonne répartition : `library.md`,
`history.md` et `updates.md` appartiennent à `2-5`, `6-5` et `6-4`.

### 4.4 Formulaires

Aucun. Il n'y a rien à saisir et rien à valider.

---

## 5. Gestion d'état (state management)

| Donnée | Portée | Stockage | Initialisation | Mise à jour |
|---|---|---|---|---|
| Bibliothèque et ses métadonnées | application | table `novels`, 11 colonnes | `onCreate` | `2-1` (données du site), `2-5` (`in_library`, `added_at`) |
| Liste de chapitres | application | table `chapters`, 9 colonnes | `2-1` | `2-1` fusionne, **jamais** `2-5` ; `2-3` écrit `downloaded_at` **après** le renommage |
| Non-ouverts | application | **dérivé** `COUNT(is_read = 0)` | à chaque lecture | jamais stocké (B14, B48) |
| Position de lecture | application | table `reading_positions`, 3 colonnes | `2-6` | à chaque stabilisation de défilement ; **jamais** par une règle de rétention (B46) |
| Journal | application | table `history_entries`, 4 colonnes | `2-7` via `recordOpened` | borné par le temps (B47), jamais par un nombre |
| File | application | table `queue_items`, 9 colonnes | `5-1` | `5-2` pour l'état, `5-3` pour `error_code` |
| État local des sources | application | table `sources`, 5 colonnes | ADR-013 : **code**, pas des lignes | `6-4` |

**Ce qui n'est délibérément pas de l'état, et qui est la moitié de la valeur de
cette fondation :**

| Absent | Où il vit | Pourquoi son absence est un choix |
|---|---|---|
| **Corps de chapitre** | `<support>/chapters/<novelId>/<ordinal>.md` | L'atomicité de B6 est une propriété de système de fichiers. Un blob de 40 Ko par ligne ferait de « présent et complet » une propriété de transaction au lieu d'un renommage |
| **Sonde d'existence de fichier** | rien — `chapters.downloaded_at` **est** la marque | ADR-022 : B33 supprime la copie d'un chapitre, donc une sonde ne pourrait pas distinguer *supprimé exprès* de *fichier perdu*, et B9 exige 10 000 chapitres visiblement marqués, ce qui n'est pas une opération de liste |
| **Compteur de non-ouverts** | dérivé : `count(chapters.is_read = 0)` | B48. Une valeur stockée est une deuxième source de vérité libre de contredire les lignes qu'elle compte — B14 violé **par construction** |
| **Colonne de concurrence** | rien | B18 fait de la concurrence une constante de un. Une constante exprimée par une colonne est quelque chose qu'une implémentation pourrait changer — c'est pourquoi `app_database_test.dart` affirme l'**absence** de la colonne, la seule façon de remarquer qu'on l'ajoute |
| **Colonne de position dans `history_entries`** | rien | B47 borne la liste par le temps. Il n'existe délibérément aucun moyen de demander « les 50 derniers » par nombre, parce qu'une borne par nombre est le comportement que B47 refuse |
| **Image de couverture** | cache disque de `cached_network_image` | Jamais une ligne. Une couverture manquante se dégrade en initiales du titre et ne doit jamais bloquer une lecture |
| **Préférences de lecture** | `shared_preferences` | Non relationnel. `theme-type` en est propriétaire |
| **Registre des sources** | code Dart | ADR-013 : un registre statique, pas des lignes. `sources` ne contient que l'**état local** de chaque source compilée |

**Emplacement du stockage** (`architecture.md` § 4.7) : répertoire **support** de
l'application, **jamais** cache. Le système d'exploitation peut vider un cache à
tout moment, et B7 exige qu'un chapitre stocké reste lisible.

---

## 6. Traçabilité des règles

### 6.1 Règles métier (B*)

| ID | Règle (PRD) | Implémentée où | Approche |
|---|---|---|---|
| **B7** | Once a chapter is stored, it is readable with no connection, independently of the site's current reachability or of any future change to that site. | `_openLazy()` — `getApplicationSupportDirectory()` | Le répertoire **support**, jamais le cache ni les documents. Le système peut vider un cache à tout moment, et une base qui détient la bibliothèque, les positions et l'historique ne peut pas vivre là où le système a le droit de la récupérer. La **première** moitié de la règle — le fichier `.md` sous le même répertoire — appartient à `2-3` et à son `ChapterStore` |
| **B29** | No user data leaves the device: no library, no reading progress, no history, no diagnostics, no analytics, no crash reports, no telemetry of any kind. | § 2.1 à § 2.3 : aucune table ne contient d'identifiant de personne, d'e-mail, ni de jeton ; aucune n'a de colonne « synchronisé à » | Le schéma **n'a aucune colonne d'identité**, et c'est la forme structurelle de B4 et de B29. Le compte de non-ouverts est dérivé, donc il n'y a pas de valeur d'usage nulle part. Une table de télémétrie serait la seule façon de violer cette règle, et il n'y en a pas |
| **B31** | A new version of the app is delivered as an installable file. Installing a new version over an existing one preserves the library, every downloaded chapter, all reading positions and the history. | `schemaVersion = 1` ; `MigrationStrategy` **sans** `onUpgrade` ; `schema_snapshot_test.dart` ; l'emplacement **support** | Quatre verrous, dont aucun n'est une promesse. **Aucun pas destructif** n'existe dans ce fichier, donc la seule manière de casser B31 par le schéma est de l'écrire — et le commentaire de `migration` dit pourquoi. **L'instantané commité** rend une dérive visible avant qu'elle n'atteigne un téléphone. **Aucune migration n'est écrite tant qu'aucune n'est nécessaire**, donc `schemaVersion` reste à 1. Et **support, pas cache**, parce qu'un fichier de base dans un cache est une perte de données qui ne respecte pas B31 du tout. La **preuve** est `gate:upgrade-safety`, qui vérifie les **fichiers** et pas seulement les lignes |
| **B32** | Removing a novel from the library **keeps its downloaded chapters on the phone**. Deleting those chapters is a separate choice the user makes explicitly, off by default. No path removes a novel and silently destroys chapters that cannot be recovered. | `chapters.novelId` `CASCADE` ; `history_entries.novelId` **`RESTRICT`** ; `_setup()` : `PRAGMA foreign_keys = ON` | **La seule application de B32 dans ce dépôt est la contrainte `RESTRICT`**, et elle est **inerte** sans le pragma — parce que SQLite désactive l'application des clés étrangères par défaut, par connexion, et que ce n'est pas partie du format de fichier. La ligne `_setup` n'est donc pas une précaution : c'est ce qui rend la contrainte réelle. Et l'**asymétrie** est le point : `CASCADE` sur `chapters` supprime des **enregistrements** de chapitres, jamais des **fichiers** ; `RESTRICT` sur `history_entries` empêche la suppression du novel tant que son journal existe, parce qu'un journal supprimé comme effet secondaire d'une opération de bibliothèque est l'échec de B32 exprimé par le schéma. Deux tests l'attrapent : `deleting a novel cascades to its chapters` et `B32 — history survives the novel, and the FK refuses the delete` — **les deux ont échoué** face à un schéma qui semblait correct |
| **B46** | **Reading position and reading history are different things and are never conflated.** The position […] is **never trimmed by any retention rule** […] The history *list* is bounded separately (B47). | `reading_positions` : 3 colonnes, clé primaire `chapterId`, **aucune** colonne de temps d'ouverture ; `history_entries` : 4 colonnes, **aucune** colonne d'offset | Deux tables, deux clés primaires, **aucune colonne en commun**. `reading_positions` n'a **aucune** colonne de date d'ouverture, donc rien ne peut la roigner ; `history_entries` n'a **aucune** colonne de décalage, donc rien ne peut la transformer en position. Le modèle ne rend pas la confusion exprimable — c'est la forme structurelle de B46, et c'est pourquoi `architecture.md` § 4.3 note que cette table **n'est jamais lue comme un relevé de ce qui a été lu**. La borne par temps de B47 ne peut pas s'y propager, parce qu'il n'y a rien sur quoi s'appliquer |

### 6.2 Edge cases (E*)

| ID | Cas (PRD) | Approche de gestion | Où |
|---|---|---|---|
| *(aucun déclaré)* | `state.json` n'attribue **aucun** `edge_case_id` à `local-store`. C'est exact pour une fondation de schéma : les edge cases du PRD (`E6`, `E7`, `E15`, `E20`) concernent des **inter interruptions de téléchargement**, et une ligne n'est pas interrompue — elle est complète ou absente. Deux d'entre elles ont néanmoins une **trace** dans le schéma, et elle est écrite ici pour qu'elle ne soit pas perdue | **E6** → `chapters.downloaded_at` est la marque, écrite **après** le renommage par `2-3` (ADR-022) ; une interruption laisse la ligne **complète mais non marquée**, ce qui est le seul état qu'une transaction ne peut pas produire à moitié. **E7** → `queue_items.state` distingue `downloading` de `queued` : un élément en pause est `queued` avec la file arrêtée, **pas** un quatrième état, et confondre les deux rend « en pause » non représentable. **E20** → `queue_items.attempts` et `error_code` permettent de dire qu'un arrêt était le stockage et non le réseau, et `start ≈ finished` reste vrai | § 2.1, commentaires de `downloaded_at`, `state` et `attempts` ; § 11.1 |

### 6.3 Contraintes (C*)

| ID | Contrainte (PRD) | Comment elle est respectée |
|---|---|---|
| **C2** | Privacy — no account, no server, no telemetry of any kind. Reading data never leaves the phone | Aucune colonne d'identité, aucune colonne de synchronisation, aucun appel réseau dans tout le fichier. Les seuls imports sont `dart:io`, `drift`, `path_provider` et `sqlite3` — vérifiable en une ligne |
| **C4** | Content ownership — store only what is needed, keep it on the device, remove it when the user removes the chapter. **Removing a novel does not remove what has been downloaded** | Le schéma ne stocke **jamais** un corps de chapitre : c'est un fichier, et il n'est pas dans la base. Le `CASCADE` de `chapters` supprime des enregistrements de lignes, et la suppression des **fichiers** est une opération distincte, explicite, et hors de cette fondation |
| **C5** | User skill — the only technical user cannot write code | Aucune action de maintenance manuelle. Un changement de schéma passe par un commit, pas par une commande que le lecteur doit lancer sur son téléphone |
| **C8** | Data loss is structurally accepted — an interrupted or partially written download must therefore never be presented as complete | `schemaVersion` 1 sans pas destructif ; une transaction SQLite est atomique par construction ; et la seule moitié de B6 qui vit en base — la marque — a été conçue pour que **l'état impossible** (marqué sans fichier) soit inatteignable |
| **C14** | No network call may be required to open the app, open the library, list stored chapters, open history, or read a stored chapter | Cette fondation ne contient **aucun** code réseau. `import 'dart:io'` sert au `File` du chemin de la base, et rien d'autre |

---

## 7. Pièges à éviter

- **⚠️ Ne pas retirer `PRAGMA foreign_keys = ON` de `_setup`. Le comportement
  correct (B32)** est : la ligne reste dans le hook `setup` de la **connexion**,
  et le test `foreign-key enforcement is ON, not merely declared` la protège.
  SQLite désactive les clés étrangères **par défaut et par connexion**, et ce
  n'est pas partie du format de fichier : sans cette ligne, le `CASCADE` et le
  `RESTRICT` sont **déclarés et jamais appliqués**. B32 se lirait correctement
  partout — schéma, relecture, documentation — et ne tiendrait pas. Le test a
  **déjà** échoué une fois sur un schéma qui semblait parfait.
- **⚠️ Ne pas ouvrir une seconde connexion sans répéter le pragma. Le comportement
  correct (B32)** est : toute connexion — y compris celle de `6-10` dans l'isolate
  de fond, et y compris `AppDatabase.forTesting` — passe par le **même** helper de
  setup. C'est le seul résidu de risque que `architecture.md` § 8 nomme pour cette
  fondation, et il est réel : une connexion qui l'oublie cesse d'appliquer
  `history_entries`'s `RESTRICT`.
- **⚠️ Ne pas écrire une migration destructrice. Le comportement correct (B31)** est :
  un pas `MigrationStrategy` explicite et additif, `schemaVersion` incrémenté, un
  instantané ré-exporté, et le drill `gate:upgrade-safety` rejoué. `stepNo
  transactionné`, `deleteAll()`, et un `beforeOpen` qui fait un `DROP TABLE` sont
  la pire ligne possible dans ce fichier : il n'y a **ni sauvegarde ni export**
  (ADR-010), donc une table supprimée est une perte définitive.
- **⚠️ Ne pas exécuter `drift_dev schema dump` avec un seul argument. Le comportement
  correct (B31, `06-database.md` règle 2)** est : **deux** arguments — le fichier
  Dart et le chemin de sortie. Avec un seul, la commande affiche son usage et sort
  avec **0**, donc elle a l'air d'avoir tourné et l'instantané reste périmé. C'est
  un piège de ce projet, pas une hypothèse.
- **⚠️ Ne pas ré-exporter l'instantané pour faire passer le test. Le comportement
  correct (B31)** est : quand `schema_snapshot_test.dart` échoue, le correctif est
  d'**écrire la migration** puis de ré-exporter. Ré-exporter et continuer rend le
  garde vert et la base fausse.
- **⚠️ Ne pas mettre `@TableIndex` **dans** le corps de la classe. Le comportement
  correct** est : l'annotation va **au-dessus** de `class X extends Table {`.
  `@TableIndex` est `@Target({TargetKind.classType})` ; à l'intérieur, le
  générateur n'émet **rien** et drift ne prévient pas. Le second piège est voisin :
  un nom de getter erroné produit `CREATE INDEX x ON t ()` — assez valide pour
  compiler, fatal à `createAll()`, avec `near ")": syntax error`. Ni l'un ni l'autre
  ne produit de diagnostic d'analyseur.
- **⚠️ Ne pas ajouter de colonne `unread_count`, ni de colonne de concurrence dans
  `queue_items`. Le comportement correct (B14, B48, B18)** est : le compte des
  non-ouverts est `COUNT(is_read = 0)` et la file est séquentielle par constante.
  Le test `the queue has no concurrency column to mis-set` existe **pour** surveiller
  l'absence — c'est la seule façon de remarquer qu'on l'ajoute. Une constante
  exprimée par une colonne est quelque chose qu'une implémentation pourrait
  changer.
- **⚠️ Ne pas utiliser `COUNT(*)` avec un `LEFT JOIN` pour compter les non-ouverts
  d'un roman. Le comportement correct** est : `COUNT(c.id)`. Avec un `LEFT JOIN`,
  `COUNT(*)` rend `1` pour un roman sans aucun chapitre — un nombre faux, ce qui
  est pire qu'un nombre absent.
- **⚠️ Ne pas stocker `DownloadState` par ordinal. Le comportement correct** est :
  `value.name`. Réordonner l'énumération remapperait silencieusement un historique
  persisté : une ligne écrite `downloading` (index 1) commencerait à se lire
  `done` (index 1) après le changement.
- **⚠️ Ne pas mettre la base dans le répertoire cache. Le comportement correct
  (B7, B31)** est : `getApplicationSupportDirectory()`. Le système peut vider un
  cache à tout moment, et une base qui détient la bibliothèque, les positions de
  lecture et l'historique n'est pas récupérable par le système.

> **Question ouverte — le compte de test du brief ne correspond pas à
> l'arborescence.** Ce plan a été commandé avec « 29 tests qui passent dans
> `test/core/database/` ». La suite complète fait **29**, mais **24** sont dans
> `test/core/database/` (**21** dans `app_database_test.dart` et **3** dans
> `schema_snapshot_test.dart`) ; les **5** autres sont dans
> `test/widget_test.dart` et couvrent le **bootstrap** de `main.dart`, pas la base.
> Aucun nom de test n'a été inventé pour faire tenir le compte : § 11 reproduit les
> **24** noms réels, vérifiés en exécutant `flutter test test/core/database/`
> plutôt qu'en les relisant. **Le déclencheur de clôture** : aucun — c'est un
> constat, pas une décision. **Le nombre à citer dans une documentation est 24 pour
> `test/core/database/`, et 29 pour l'ensemble de la suite.**

> **Question ouverte — le mot « 41 colonnes » est cohérent partout, et la
> numérotation de `architecture.md` ne l'est pas.** La table de § 4.9 est
> nommée `§ 4.9` et se trouve **après** `§ 4.6`, tandis que `§ 4.7` et `§ 4.8`
> suivent. `architecture.md` § 9 dit « étendre, jamais renuméroter » — et
> l'amendement en question **respecte** cette règle : rien n'a été déplacé, une
> section a été **ajoutée**. Le § 4 le déclare lui-même : *« nothing is renumbered
> for real »*. **Aucune modification n'est proposée ici** : ce plan ne touche pas
> `architecture.md`. Le déclencheur de clôture est une relecture qui le déclare
> assumé, ce qu'il fait déjà.

---

## 8. Dépendances

| Dépend de | Nature | Statut | Fallback si absent |
|---|---|---|---|
| — | — | vague **0** | Aucune. C'est la fondation la plus basse du graphe, avec `apk-pipeline`, `localisation` et `theme-type` |
| `sqlite3` | data — le moteur | installé (3.7.0) | aucun. ADR-005 : `sqlite3_flutter_libs` est inutilisable (`0.6.0+eol`) |
| `drift` | data — l'ORM | installé (2.35.1) | aucun |
| `path_provider` | data — le répertoire support | installé (2.1.6) | aucun |
| `drift_dev` | outil — la génération et l'instantané | installé (2.35.1) | **aucun en pratique**, mais l'instantané ne peut plus être régénéré |

**Dépendants** : `2-1`, `2-5`, `2-6`, `6-3` selon `state.json`, et **en pratique**
`2-3` (la marque), `6-4` (la vérification), `6-5` (le journal), `6-6` (le badge
et la recherche), `6-10` (la connexion de fond), `5-1`/`5-2`/`5-3` (la file).

---

## 9. Checklist de tâches

### Phase 1 — Couche de données

- [ ] **Aucune tâche.** Le schéma est livré : 6 tables, **41 colonnes**, 5 index,
  `schemaVersion = 1`. Ce plan ne propose **aucun** changement
- [ ] Vérifier que `app_database.g.dart` est **commité** et **exclu** de
  l'analyse
- [ ] Vérifier que `schema.json` est commité, et que `_meta.version` est `"1.3.0"`

### Phase 2 — Logique métier

- [ ] **Aucune tâche.** Il n'y a pas de logique métier ici : le schéma n'est pas
  une règle, et les règles vivent dans les slices qui les appliquent
- [ ] `_setup` reste **la seule** fonction qui touche un `Database` brut dans tout
  le dépôt, et elle reste d'une ligne

### Phase 3 — Interface utilisateur

- [ ] **Aucun, et c'est légitime.** Cette fondation ne produit aucun widget,
  aucune chaîne ARB, aucun jeton de design, et aucun état d'écran. Elle produit
  une base et un fichier de configuration. Un « écran de configuration de base »
  serait un écran qui n'a aucune raison d'exister et que personne a demandé —
  c'est la même faute qu'une classe d'utilitaires préemptive, et
  `AGENTS.md` § Définition de Done, point 5, l'interdit explicitement

### Phase 4 — Intégration

- [ ] Vérifier que `PRAGMA foreign_keys = ON` est posé par **toute** connexion
  ouverte dans le dépôt, y compris `AppDatabase.forTesting` et la connexion de
  fond de `6-10`
- [ ] Aucun routage, aucune permission, aucun provider Riverpod
- [ ] `dart run drift_dev identify-databases` liste bien `lib/core/database/
  app_database.dart` en version 1

### Phase 5 — Tests et polish

- [ ] Les **24** tests de `test/core/database/` passent — ils passent
  aujourd'hui, ce plan ne les modifie pas
- [ ] Le garde de dérive a été **vu rouge au moins une fois** : ajouter une
  colonne, régénérer sans ré-exporter, doit produire exactement
  `columns drifted on chapters`. Un garde jamais vu rouge est une décoration
- [ ] Aucun test d'interface : il n'y a pas d'interface

### Vérifications finales

- [ ] `dart format .` — propre
- [ ] `flutter analyze` — **zéro** issue, zéro `info`
- [ ] `flutter test` — **29** tests, tous verts (24 ici, 5 dans
  `test/widget_test.dart`)
- [ ] `coverage-check.js` **ne peut pas** vérifier une fondation : il ne lit que
  `state.slices` (finding **F-003**). Cette vérification est **manuelle**, par
  relecture de ce fichier

---

## 10. Critères d'acceptation

- [ ] **B32** — `grep -n "PRAGMA foreign_keys = ON" lib/core/database/app_database.dart`
  trouve la ligne, et elle est dans le hook `setup` de la connexion.
- [ ] **B32** — le test `foreign-key enforcement is ON, not merely declared` passe
  et lit `PRAGMA foreign_keys` depuis la base **vivante**.
- [ ] **B32** — le test `B32 — history survives the novel, and the FK refuses the delete`
  passe : la suppression du novel **lève**, et l'entrée d'historique est **restée**.
- [ ] **B32** — `grep -n 'cascade' lib/core/database/app_database.dart` ne trouve
  le mot que sur `chapters.novelId`, `reading_positions.chapterId`,
  `history_entries.chapterId` et `queue_items.chapterId` — **jamais** sur
  `history_entries.novelId`.
- [ ] **B46** — `reading_positions` a **exactement trois** colonnes
  (`chapter_id`, `offset`, `updated_at`) et **aucune** colonne de date
  d'ouverture : rien ne peut la roigner.
- [ ] **B46** — `history_entries` a **exactement quatre** colonnes et **aucune**
  colonne de décalage : rien ne peut la transformer en position.
- [ ] **B31** — `schemaVersion == 1`, et `MigrationStrategy` ne contient **que**
  `onCreate`.
- [ ] **B31** — `grep -n 'onUpgrade\|deleteAll\|DROP TABLE\|stepNo' lib/core/database/app_database.dart`
  ne retourne **rien**.
- [ ] **B31** — le test `the committed snapshot matches the schema that actually
  runs` passe, et `grep -c '"type": "table"' lib/core/database/schema.json` vaut 6.
- [ ] **B31** — le test `the snapshot still records B32's RESTRICT` passe :
  `history_entries.novel_id` porte `on_delete == 'restrict'` dans l'instantané.
- [ ] **B7** — `grep -n 'getApplicationSupportDirectory' lib/core/database/app_database.dart`
  trouve la ligne, et `getApplicationCacheDirectory` et
  `getTemporaryDirectory` ne sont **pas** présents.
- [ ] **B29** — aucune table ne contient de colonne d'identité, de colonne de
  synchronisation ni de colonne de télémétrie : un test vérifie l'ensemble exact
  des 41 noms de colonnes contre une liste écrite dans le test.
- [ ] **B14 / B48** — le test `opening a chapter clears exactly one unread` passe :
  3 non-ouverts, on en ouvre 1, il reste 2.
- [ ] **B14 / B48** — le test `the count is derived by SQL, not by a per-row loop`
  passe, et `grep -n 'unread_count\|unreadCount' lib/core/database/` ne retourne
  rien.
- [ ] **B18** — le test `the queue has no concurrency column to mis-set` passe.
- [ ] **B18** — le test `DownloadState round-trips as a name, not an ordinal` passe
  et lit `'queued'` en SQL brut.
- [ ] **B10** — le test `the default is -1 and 0 stays reachable` passe.
- [ ] **B49** — le test `a null lastCheckedAt is null, not epoch` passe.
- [ ] **B6** — les trois tests de `downloadedAt` passent : absent par défaut, effacé
  par chapitre seulement, indépendant de `isRead`.
- [ ] **B45** — le test `B45 — neither column is indexed, so neither is searchable`
  passe : `idx_novels_title` existe, et aucun index ne contient `author` ni
  `description`.
- [ ] **B44** — le test `B44 — a description round-trips as plain text with no
  markup` passe.
- [ ] **ADR-024** — le test `they default to null, because the site may publish
  neither` passe.
- [ ] **Les cinq index** — le test `every declared index is present in the live
  database` passe, et `sqlite_master` contient les cinq noms.
- [ ] `flutter analyze` ne signale **aucun** problème sur `app_database.g.dart`,
  qui est exclu de l'analyse.

---

## 11. Plan de tests

> **Les noms ci-dessous sont ceux qui existent aujourd'hui**, reproduits depuis
> `test/core/database/app_database_test.dart` et
> `test/core/database/schema_snapshot_test.dart`, et vérifiés en exécutant
> `flutter test test/core/database/ --reporter expanded`. **Aucun nom n'a été
> inventé et aucun test n'est ajouté par ce plan.**

### 11.1 Tests unitaires

Emplacement : `test/core/database/app_database_test.dart` — **21 tests**

| Groupe | Nom du test (tel qu'il existe) | IDs couverts |
|---|---|---|
| `the DDL executes` | `every table is created, and the schema version is 1` | B2, B3, B6, B16, B17, B18, B1 |
| `the DDL executes` | `foreign-key enforcement is ON, not merely declared` | **B32** |
| `the DDL executes` | `the foreign keys are actually declared` | **B32** |
| `B48 — the unread count is derived, so it cannot drift` | `opening a chapter clears exactly one unread` | **B14**, B48, B13 |
| `B6 — a chapter row is only ever present and complete` | `deleting a novel cascades to its chapters` | B6, B9 |
| `B6 — a chapter row is only ever present and complete` | `B32 — history survives the novel, and the FK refuses the delete` | **B32** |
| `ADR-024 — author and description are stored, displayed, never searched` | `they default to null, because the site may publish neither` | ADR-024 |
| `ADR-024 — author and description are stored, displayed, never searched` | `B45 — neither column is indexed, so neither is searchable` | **B45** |
| `ADR-024 — author and description are stored, displayed, never searched` | `B44 — a description round-trips as plain text with no markup` | **B44** |
| `06-database rule 7 — the hot-path indexes exist` | `every declared index is present in the live database` | B9, **B14**, B17, **B45** |
| `06-database rule 7 — the hot-path indexes exist` | `the count is derived by SQL, not by a per-row loop` | **B14**, B48 |
| `B6 — the download mark is a column, not a probe` | `downloadedAt defaults to null: not downloaded` | **B6** |
| `B6 — the download mark is a column, not a probe` | `B33 — deleting one chapter clears only that chapter's mark` | **B6**, B33 |
| `B6 — the download mark is a column, not a probe` | `the unread count is unaffected by the download mark` | **B6**, **B14**, B48 |
| `B16 — a position is per chapter` | `two chapters of one novel hold independent offsets` | B16, **B46** |
| `B18 — the queue is sequential and stores the state by name` | `DownloadState round-trips as a name, not an ordinal` | B18, B24 |
| `B18 — the queue is sequential and stores the state by name` | `the queue has no concurrency column to mis-set` | B18 |
| `B49 — never-checked is distinct from checked` | `a null lastCheckedAt is null, not epoch` | **B49** |
| `B10 — an unparseable chapter number is -1, not 0` | `the default is -1 and 0 stays reachable` | B10 |
| `the schema is the only definition` | `an unknown column is rejected — proof the table really exists` | — |
| `the schema is the only definition` | `the queue stores a failure reason, so "failed" is never bare` | **B24**, B22 |

Emplacement : `test/core/database/schema_snapshot_test.dart` — **3 tests**

| Nom du test (tel qu'il existe) | IDs couverts |
|---|---|
| `the committed snapshot matches the schema that actually runs` | **B31** |
| `the snapshot still records B32's RESTRICT` | **B32**, B31 |
| `the schema version in the snapshot is the version in the code` | **B31** |

**Total : 24 tests dans `test/core/database/`.** Les 5 autres de la suite —
`configures localization for both supported locales`, `provides light and dark
themes and honours the system mode`, `resolves English strings`, `resolves French
strings`, `plural forms are wired for both locales` — sont dans
`test/widget_test.dart` et couvrent le bootstrap, pas la base.

### 11.2 Tests de composants

**Aucun, et c'est exact.** Cette fondation ne produit aucun widget. Un test de
widget pour une table drift serait un test qui ne teste rien.

### 11.3 Tests d'intégration

| Flow | Scénario | IDs couverts |
|---|---|---|
| `2-3 → local-store` | écrire `downloaded_at` après le renommage ; **l'ordre** appartient au plan de tests de `2-3`, pas au schéma — `architecture.md` § 4.8 le dit : *« that is a property of `2-3`'s write sequence and it belongs to slice `2-3`'s test plan, not to the schema's »* | **B6** |
| `6-4 → local-store` | `recordChecked` écrit `last_checked_at` ; un échec **n'y touche pas** | B49, **B48** |
| `6-5 → local-store` | `clearAll` supprime des lignes de `history_entries` et **zéro** de `reading_positions` | **B46**, B47 |
| `6-10 → local-store` | la connexion de l'isolate de fond a `PRAGMA foreign_keys == 1` | **B32** |
| `gate:upgrade-safety` | *(hors du graphe de slices)* — avec bibliothèque, chapitres téléchargés, positions et historique, installer l'APK suivant et affirmer que **les quatre** sont intacts, **fichiers compris** | **B31** |

### 11.4 Tests E2E

Aucun pour cette fondation : **Q-008** n'est pas résolu, et le drill
d'upgrade-safety — la seule preuve qui compte pour B31 — en dépend.

### 11.5 Vérifications manuelles

| Vérification | Écran / Composant | État |
|---|---|---|
| Overflows horizontaux | — | sans objet : pas d'interface |
| Éléments hors écran | — | sans objet |
| Navigation | — | sans objet |
| Fichiers présents après écriture | `<support>/lumen.db` après l'ajout d'un chapitre | 1 base, 0 `-wal` orphelin, 0 `-shm` oublié |
| `PRAGMA` à la volée | `sqlite3 lumen.db 'PRAGMA foreign_keys'` **sur le téléphone** | **1** — cette commande est la seule façon de le vérifier hors des tests, et elle doit être refaite à chaque nouvelle connexion |

---

## Checklist de gate

- [x] Sources explicitement référencées (PRD, architecture, DECISIONS, conventions, rules) **et le code lui-même**.
- [x] Chaque ID B*/E*/C* du périmètre apparaît en § 6 — **B7**, **B29**, **B31**,
  **B32**, **B46**, plus **B2**, **B3**, **B6**, **B9**, **B10**, **B13**, **B14**,
  **B16**, **B17**, **B18**, **B22**, **B24**, **B33**, **B44**, **B45**, **B48**,
  **B49**, ADR-024, et **C2**, **C4**, **C5**, **C8**, **C14**. L'absence de
  `edge_case_ids` est **signalée** en § 6.2 et les deux traces réelles (E6, E7)
  sont écrites.
- [x] Les contrats de données (§ 2) sont du **vrai Dart**, reproduit depuis
  `lib/core/database/app_database.dart`, avec les **41 colonnes** nommées et les
  **5 index** déclarés.
- [x] Les algorithmes (§ 3) sont en pseudocode avec **chaque** branche écrite :
  quatre branches de connexion, six étapes de cycle de vie de migration, et les
  trois ce que la preuve d'index couvre **et** ne couvre pas.
- [x] La checklist de tâches (§ 9) couvre les cinq phases, et la **Phase 3 est
  explicitement vide — avec la raison**, exactement comme le fait l'exemplaire
  pour ses propres phases vides.
- [x] Les critères d'acceptation (§ 10) sont vérifiables individuellement ; six
  sont des **greps**, parce que la moitié des fautes possibles sur cette
  fondation sont des fautes d'**absence** — un `onUpgrade`, un `unread_count`, une
  colonne de concurrence, un `CASCADE` au mauvais endroit.
- [x] Le plan de tests (§ 11) reproduit les **24 noms de test réels**, vérifiés
  par exécution, et n'en invente **aucun**.
- [ ] `coverage-check.js` **ne peut pas** vérifier une fondation — il ne lit que
  `state.slices` (finding **F-003**). La vérification de cette slice est
  **manuelle**, par relecture des § 6 et § 10 de ce fichier.

**Statut** : `draft` → en attente de validation. **Fondation livrée ; ce plan
documente, il ne prescrit rien à écrire.**