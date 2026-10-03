---
type: implementation-plan
slice: apk-pipeline
module: foundation
status: validated
generated_at: 2026-10-02
derived_from:
  - .forge/prd.md
  - .forge/roadmap.md
  - .forge/architecture.md
conventions_ref: .forge/conventions.md
---

# Plan d'implémentation — apk-pipeline

> **Cette fondation est la plus petite du plan et celle qui en débloque le
> plus.** ADR-011 : une compilation Android est produite par GitHub Actions à
> chaque fusion sur la branche principale. Pas de magasin, pas de compte de
> magasin, pas de distribution publique — **C9** veut qu'il n'y ait **aucune**
> procédure manuelle du côté du propriétaire.
>
> Le déclencheur est `master`, **pas** `main` : ADR-011 le dit, et Q-006 est
> fermé dans ce sens. Un workflow dont `on:` nomme une branche inexistante
> **ne s'exécute jamais et signale un succès** — la même forme d'échec silencieux
> qu'un glob d'instructions qui ne correspond à rien.

---

## Sources

- **PRD** : `.forge/prd.md` — règles **B31**, **B34** ; § 7.2 Security (livraison), US-17
- **Architecture** : `.forge/architecture.md` — § 2.3 (`apk-pipeline`), § 1.1, § 8 (Q-008 comme risque, `apk-pipeline` comme vague 0), § 6.1 (`apk-pipeline` en vague 0)
- **DECISIONS** : `DECISIONS.md` **ADR-011** (GitHub Actions sur la branche par défaut `master`, `pubspec.yaml` comme source unique de version, `--build-name` / `--build-number` surchargés), **ADR-010** (ni magasin, ni sauvegarde), Q-006 (la branche s'appelle `master`)
- **Roadmap** : `.forge/roadmap.md` § 8 Wave 1 item `1.1` — *« APK built automatically on merge, with a version number (C9, B34, ADR-011) »*, qui bloque *« SC-5, Q-008, everything measurable »*
- **Code** : `pubspec.yaml` (`version: 1.0.0+1`, `flutter: generate: true`),
  `android/app/build.gradle.kts`,
  `android/settings.gradle.kts`, `android/build.gradle.kts`,
  `android/gradle.properties`, `android/gradle/wrapper/gradle-wrapper.properties`,
  `android/.gitignore`, `android/app/src/main/AndroidManifest.xml`,
  `android/app/src/debug/AndroidManifest.xml`, `android/app/src/profile/AndroidManifest.xml`
- **État du dépôt** : `.github/` **n'existe pas** ; la branche courante de travail
  est `feat/basics`, la branche principale est `master`
- **Règles projet** : `08-coding-standards.md` § Dependencies, `11-git-workflow.md`, `17-security.md` (règle 13 : une dépendance native exige une ADR)

---

## 1. Résumé de la slice

`apk-pipeline` est une **fondation** : un fichier de workflow, une clé de
signature stable, et un contrat de version que l'application peut lire à
l'exécution. Trois choses, et **aucune** interface.

**1. Le build automatique à la fusion.** `.github/workflows/apk.yml` se déclenche
sur `push` vers `master`, installe le **même** Flutter que le projet
(`3.47.6`, via `subosito/flutter-action` avec `flutter-version`), joue
`flutter pub get`, `flutter analyze`, `flutter test`, puis `flutter build apk
--release`, et dépose l'artefact. Aucune étape manuelle. C'est **C9** :
« installable from a file on the owner's phone, repeatedly, without the owner
performing a manual procedure ».

**2. Une clé de signature stable.** C'est le point que ce plan met en avant, et
il est **le** porteur de B31. `android/app/build.gradle.kts` signe actuellement
la variante *release* avec la clé de **débogage**
(`signingConfig = signingConfigs.getByName("debug")`). Une clé de débogage
fonctionne pour une installation manuelle, mais elle n'est pas **durable** : si
elle change un jour, Android refuse l'installation par-dessus l'existante pour
**signatures incompatibles** — ce qui est exactement le scénario que B31 promet
de survivre. Une clé de signature est donc **une dépendance** de B31, pas un
détail d'empaquetage, et elle est traitée ici comme telle.

**3. Un contrat de version.** `pubspec.yaml` `version:` est la source unique
(ADR-011) ; le workflow surcharge `--build-name` et `--build-number` avec le tag
git et le numéro d'exécution Actions, pour que **deux compilations du même commit
ne soient jamais indiscernables**. B43 (l'écran *À propos*) lit la version
installée, et elle doit venir de là.

**Ce que cette fondation ne fait pas** : elle ne publie rien dans un magasin, ne
configure aucune signature de magasin, ne produit aucune métadonnée de magasin,
et ne demande au propriétaire **aucune** action manuelle. `architecture.md` § 2.3
et ADR-010 le disent : chaque slice qui aurait produit une de ces choses aurait
ajouté du travail sans contrepartie.

Cette fondation existe **avant** toute fonctionnalité parce que **Q-008** bloque
toute vérification sur appareil, et **SC-5** est infaisable sans elle. ADR-011 la
rend en plus une dépendance de **CI** et non de machine : le SDK Android n'a pas
besoin d'exister sur le poste de travail.

**User stories couvertes** : US-17
**Règles métier couvertes** : B31, B34
**Edge cases couverts** : aucun déclaré pour cette fondation dans `state.json`

---

## 2. Contrats de données (code)

### 2.1 Schémas de validation

**Aucun.** Une chaîne de compilation n'a pas de schéma. Elle a **trois** entrées
et une sortie, et chacune est nommée :

| Entrée | Où elle vit | Qui la fournit |
|---|---|---|
| `version: <major>.<minor>.<patch>+<build>` | `pubspec.yaml` | le propriétaire, à la main, dans le commit |
| Le tag git | le dépôt | le propriétaire, à la main, à la publication |
| Le numéro d'exécution Actions | `GITHUB_RUN_NUMBER` | l'infrastructure, jamais écrit |
| L artefacts sortants | `build/app/outputs/flutter-apk/` | le workflow |

```dart
// Le contrat de version, tel que `3-5` (écran *À propos*, B43) le consomme.
// C'est du Dart parce que B43 a besoin de la version À L'EXÉCUTION, et que
// pubspec.yaml n'est pas lisible depuis un APK installé.

/// La version **installée**, telle que l'OS la rapporte.
///
/// **Trois états, pas deux** : `buildName` peut être absent, `buildNumber` peut
/// être absent, et les deux absents ensemble doivent rendre `Version —` et
/// **jamais** un numéro inventé. `settings.md` § 8 le dit en toutes lettres :
/// *« Absent → the About row reads `Version —` and never an invented number »*.
///
/// **Aucun getter ne lève et aucun n'a de valeur par défaut.** Un `?? '0.0.0'`
/// dans ce type produirait un écran *À propos* qui affiche `0.0.0` sur un APK
/// dont la version n'a pas été lue, et c'est exactement le mensonge que B31 et
/// C9 interdisent : le propriétaire doit pouvoir savoir quelle version il a
/// réellement.
final class AppBuildInfo {
  const AppBuildInfo({required this.buildName, required this.buildNumber});

  /// `versionName` côté Android. `null` quand l'OS ne le rapporte pas.
  final String? buildName;

  /// `versionCode` côté Android — le `+build` de `pubspec.yaml`, ou le numéro
  /// d'exécution Actions lorsqu'ADR-011 le surcharge. `null` quand l'OS ne le
  /// rapporte pas.
  final String? buildNumber;

  /// `true` si **rien** n'a pu être lu. Dans ce cas l'écran *À propos* rend
  /// `Version —` et **rien d'autre** : pas de date, pas de nom de branche, pas
  /// de chaîne de remplacement.
  bool get isUnknown => buildName == null && buildNumber == null;

  /// La ligne affichable. **Un seul** cas produit autre chose qu'un tiret, et
  /// c'est quand **les deux** sont connus : afficher `Version 1.0.0` sans le
  /// numéro de build serait un numéro partiel, et B31 est une promesse sur des
  /// **deux** identifiants.
  String get displayLine => isUnknown ? '—' : '$buildName ($buildNumber)';
}

/// La lecture. **Une seule source de vérité par version installée**, et c'est
/// l'OS.
///
/// ⚠️ CETTE FONCTION N'EST PAS ENCORE POSSIBLE. `package_info_plus` **n'est pas**
/// dans `pubspec.yaml`. Voir la question ouverte de § 7 : c'est une dépendance
/// nouvelle, donc elle passe par `flutter pub add` et par le comité de
/// `AGENTS.md` / `17-security.md` règle 13. **Ne pas lire `pubspec.yaml` au
/// runtime** : ce serait lire le fichier source de la compilation, pas la version
/// installée, et les deux divergent dès la première surcharge `--build-name`
/// d'ADR-011 — c'est-à-dire dès la première compilation CI.
abstract interface class BuildInfoReader {
  Future<AppBuildInfo> readInstalledBuild();
}
```

```dart
// Le contrat de la chaîne, du côté de `main.dart`. L'implémentation réelle
// est le paquet de métadonnées ; la forme ci-dessus est ce que `3-5` consomme,
// et elle est testable avec un faux sans dépendre du paquet.

/// Ce que le pipeline doit garantir à `3-5`, et qui est vérifiable **sans**
/// téléphone : le numéro de build d'un artefact est **monotone** et **unique**
/// par exécution. Deux compilations du même commit ne doivent jamais produire le
/// même couple `buildName` / `buildNumber`.
bool isDistinguishable(
  String buildNameA,
  String buildNumberA,
  String buildNameB,
  String buildNumberB,
) =>
    buildNumberA != buildNumberB || buildNameA != buildNameB;
```

### 2.2 Le manifeste Android — les permissions que la livraison exige

Ce ne sont pas des « contrats de données », mais ce sont les seules données que
cette slice écrit en dehors du dépôt.

```xml
<!-- android/app/src/main/AndroidManifest.xml — l'état AUJOURD'HUI -->
<manifest xmlns:android="http://schemas.android.com/apk/res/android">
    <application
        android:label="lumen_tale"
        android:name="${applicationName}"
        android:icon="@mipmap/ic_launcher">
        <activity
            android:name=".MainActivity"
            android:exported="true"
            android:launchMode="singleTop"
            ... />
        <meta-data android:name="flutterEmbedding" android:value="2" />
    </application>
    <queries>
        <intent>
            <action android:name="android.intent.action.PROCESS_TEXT" />
            <data android:mimeType="text/plain" />
        </intent>
    </queries>
</manifest>

<!-- android/app/src/debug/AndroidManifest.xml et …/profile/… :
     ILS NE DÉCLARENT QUE android.permission.INTERNET, avec un commentaire qui
     explique que c'est pour le rechargement à chaud. C'est correct : INTERNET
     n'a pas besoin d'être déclaré pour une publication, et l'ajouter au
     manifeste principal serait une permission qu'aucune règle ne réclame.
     ⚠️ NE PAS Y TOUCHER. Toute permission ajoutée ici entre dans la
     publication. -->
```

**Aucune permission n'est ajoutée par cette fondation.** C'est un point, pas un
oubli : le pipeline construit et publie, il ne demande rien.

### 2.3 Contrats API

**Aucun appel réseau de l'application.** Le pipeline en fait un, et c'est le seul
endroit du dépôt qui en fait un par conception : il tire le code et le SDK.
L'application, elle, n'a aucune surface réseau dans cette slice.

---

## 3. Algorithmes critiques

### 3.1 La chaîne de version (couvre **B34**, ADR-011)

```
# Trois entrées, une sortie. La règle : AUCUNE n'est dérivée d'une autre.

# ── étape 1 : la version de base ─────────────────────────────────────
version = read pubspec.yaml → version: 1.0.0+1
#        major = 1, minor = 0, patch = 0, build = 1
# ADR-011 : « pubspec.yaml `version: <major.minor.patch>+<build>` is the single
# source of truth ».
# ⚠️ LE FICHIER EST LU, PAS COPIÉ DANS LE WORKFLOW. Un workflow qui répète
# "1.2.3" en dur est une deuxième source de vérité, et c'est la forme exacte de
# l'échec qu'ADR-011 existe pour empêcher.

# ── étape 2 : le nom de build ────────────────────────────────────────
build_name = version.minor_part                    # "1.0.0"
# ⚠️ JAMAIS le tag git dans --build-name. Le nom de build est ce que le
# propriétaire lit dans Paramètres ▸ Applications ▸ Lumen Tale, et un nom comme
# "v1.0.0-3-g9bc4aa" est illisible dans une fiche d'application. Le tag sert à
# l'ARCHIVER, pas à s'afficher.

# ── étape 3 : le numéro de build ─────────────────────────────────────
build_number = max(version.build_part, GITHUB_RUN_NUMBER)
# ADR-011 : « the workflow overrides --build-name and --build-number from the git
# tag and the Actions run number, so two builds of the same commit are never
# indistinguishable ».
# ⚠️ GITHUB_RUN_NUMBER est MONOTONE et CROISSANT pour un dépôt. Il est la seule
# chose qui distingue deux compilations du même commit.
#
# ⚠️ ET IL DOIT ÊTRE UN ENTIER POSITIF. `versionCode` Android est un entier 32
# bits signé : une valeur négative ou non entière fait échouer aapt. D'où le max()
# avec le `+build` de pubspec, qui garantit au moins 1.
#
# ⚠️ Le tag git EST ENREGISTRÉ DANS L'ARTEFACT, jamais dans le nom de build :
# c'est ce qui permet, six mois plus tard, de retrouver la compilation qui
# correspond à un commit.

# ── étape 4 : l'artefact ─────────────────────────────────────────────
build/app/outputs/flutter-apk/app-release.apk      → uploadé en artefact
```

**Les quatre branches de la version :**

| Situation | `build-name` | `build-number` | Pourquoi |
|---|---|---|---|
| Premier build, `pubspec` dit `1.0.0+1` | `1.0.0` | `max(1, 1)` = 1 | correct |
| Deuxième build, même commit, `run_number` 2 | `1.0.0` | `max(1, 2)` = **2** | **ADR-011** : les deux compilations sont distinguables |
| Le propriétaire monte `version:` à `2.0.0+1` | `2.0.0` | `max(1, N)` | le nom suit le fichier, jamais le workflow |
| `GITHUB_RUN_NUMBER` dépasse `2^31-1` | `1.0.0` | **échec explicite** | `versionCode` est un entier signé 32 bits. Un `2.1e9` est à peine 65 compilations ; c'est un seuil qu'il faut surveiller, pas un problème théorique |

### 3.2 L'installation par-dessus (couvre **B31**)

```
# Ce que B31 promet : « Installing a new version over an existing one preserves
# the library, every downloaded chapter, all reading positions and the history. »
#
# Ce qui le garantit — et ce n'est PAS le pipeline seul :
#
# 1. LA MÊME CLÉ DE SIGNATURE.        → § 3.3
# 2. LE MÊME applicationId.           → § 3.3
# 3. AUCUNE MIGRATION DESTRUCTRICE.   → le plan local-store, § 3.2 de ce dépôt
# 4. LE MÊME RÉPERTOIRE DE DONNÉES.   → support, jamais cache (local-store)
# 5. schemaVersion monotone.          → local-store
#
# ⚠️ 1 et 2 sont des PROPRIÉTÉS DU PIPELINE. Si l'une change, Android refuse
# l'installation par-dessus — et le résultat est que le propriétaire doit
# désinstaller, ce qui EST la perte irréversible que B31 promet d'éviter. C'est
# pourquoi la clé de signature est traitée ici comme une dépendance de règle et
# non comme un détail d'empaquetage.
```

**Ce que le pipeline ne peut pas prouver.** Il peut prouver qu'un artefact existe,
qu'il s'installe, et que sa version est lisible. Il ne peut **pas** prouver que la
bibliothèque survit : cela demande deux installations successives et un appareil
réel — c'est **Q-008**, et c'est le drill `gate:upgrade-safety`, qui est
délibérément hors du graphe de slices.

### 3.3 La clé de signature et l'identifiant (couvre **B31**)

```
# L'ÉTAT ACTUEL, dans android/app/build.gradle.kts :

android {
    namespace = "app.shipclean.lumen_tale"
    defaultConfig {
        applicationId = "app.shipclean.lumen_tale"      # ⚠️ PLACEHOLDER Flutter
        versionCode  = flutter.versionCode              # depuis pubspec
        versionName  = flutter.versionName
    }
    buildTypes {
        release {
            signingConfig = signingConfigs.getByName("debug")   # ⚠️ TODO
        }
    }
}
```

**Les deux choses à faire, et pourquoi chacune est une règle et non une finition.**

**L'identifiant d'application.** `app.shipclean.lumen_tale` est le
**placeholder généré par `flutter create`**. Il est déjà dans le dépôt, donc le
changement est sans risque de migration — une nouvelle application sous un
identifiant installs **à côté** de l'ancienne. Mais il est faux, il contient un
nom d'organisation qui n'est pas le nôtre, et il est **immuable** après la
première publication : le changer plus tard ferait installer l'application à côté
de l'ancienne et la laisserait orpheline. **Il est donc à changer maintenant, pas
plus tard.**

**La clé.** `android/.gitignore` exclut déjà `key.properties`, `**/*.keystore` et
`**/*.jks` — c'est le `.gitignore` de Flutter lui-même, et il est correct. Donc :

```
# android/key.properties — GÉNÉRÉ EN CI, JAMAIS COMMITÉ
storeFile=upload-keystore.jks
storePassword=<secret>
keyAlias=upload
keyPassword=<secret>

# Le fichier .jks lui-même :
#   - stocké comme secret base64 dans GitHub (jamais commité en clair)
#   - écrit dans l'espace de travail au début de l'étape de compilation
#   - SUPPRIMÉ à la fin de l'étape, y compris en cas d'échec
#     (if: always())
#
# ⚠️ PERDRE CETTE CLÉ, C'EST PERDRE LA MISE À JOUR. Si la clé disparaît des
# secrets, le propriétaire ne peut plus installer aucune version par-dessus les
# versions déjà installées, et doit désinstaller — donc perdre sa bibliothèque,
# ses téléchargements, ses positions et son historique. C'est B31 qui disparaît,
# et il n'y a aucune sauvegarde (ADR-010). La clé est donc le SEUL élément de ce
# pipeline à traiter comme une donnée irremplaçable.
```

### 3.4 Le pipeline lui-même

```
on:
  push: { branches: [ master ] }      # ⚠️ master, PAS main — ADR-011, Q-006
  # PAS de pull_request, PAS de workflow_dispatch en v1 : C9 demande que le
  # propriétaire n'ait RIEN à faire, et un déclencheur manuel est une
  # procédure manuelle.

permissions:
  contents: read                       # ⚠️ le strict minimum. Ni packages:
                                      # write, ni deployments: write, ni
                                      # id-token. Un workflow de compilation
                                      # n'écrit nulle part ailleurs.

jobs:
  build:
    runs-on: ubuntu-latest
    steps:
      1. actions/checkout@v4   (fetch-depth: 0 — les tags sont nécessaires à l'étape 2)
      2. subosito/flutter-action@v2
           flutter-version: 3.47.6         # ⚠️ LE MÊME que pubspec/AGENTS.md
           channel: stable
           cache: true
      3. flutter pub get
      4. flutter analyze         # DoD point 2 : zéro issue, zéro info
      5. flutter test            # DoD point 3
      6. restore the keystore from secrets → android/key.properties + .jks
      7. compute BUILD_NAME / BUILD_NUMBER    # § 3.1
      8. flutter build apk --release \
             --build-name="$BUILD_NAME" \
             --build-number="$BUILD_NUMBER"
      9. upload build/app/outputs/flutter-apk/app-release.apk
           name: lumen-tale-$BUILD_NAME-$BUILD_NUMBER
      10. write the tag + commit into a text file next to the APK
      11. delete the keystore  (if: always())
```

**Les cinq branches du déclencheur :**

| Situation | Ce qui se passe | Pourquoi c'est correct |
|---|---|---|
| Fusion sur `master` | le workflow s'exécute, l'artefact est publié | ADR-011 : le build est produit **à la fusion** |
| Fusion sur une autre branche | **rien** | le `branches: [master]` est le seul déclencheur. Une branche de travail n'a pas à produire d'APK |
| Le tag `v1.0.0` existe déjà | il est **lu** et inscrit dans l'artefact, rien de plus | ADR-011 ne demande pas de publier depuis un tag ; il demande que la version soit lisible |
| `flutter analyze` signale une issue | **le job échoue**, aucun artefact | C9 : « le build est répétable automatiquement ». Un APK produit depuis du code qui ne compile pas proprement n'est pas une livraison |
| `flutter test` échoue | **le job échoue**, aucun artefact | DoD point 3 |
| La clé est absente des secrets | **le job échoue**, aucun artefact | Une compilation non signée est un fichier que le propriétaire ne peut pas installer par-dessus l'existant — c'est-à-dire un fichier qui casse B31 sans le dire |
| `GITHUB_RUN_NUMBER` ≥ 2^31 | **le job échoue** explicitement | `versionCode` est un entier signé 32 bits |

### 3.5 La publication des artefacts

```
# ADR-011 « Details still open, and deliberately so » nomme trois choix comme
# devant être réglés AU MOMENT où le workflow est écrit, pas avant :
#
#   (a) quelles variantes d'APK publier — split-per-abi ou universelle
#   (b) si un artefact de débogage est publié à côté
#   (c) si `main` est fusionné directement ou par PR
#
# LES TROIS SONT RÉSOLUS ICI, ET LES TROIS SONT RÉVERSIBLES.

(a) VARIANTE UNIQUE, UNIVERSELLE. ⚠️ UNE SEULE, pas de --split-per-abi.
    Motifs, par ordre de poids :
      1. C'est un APK pour UN téléphone. Le fractionnement par ABI économise de la
         place que le propriétaire n'a pas de problème, et lui ajoute une
         décision à prendre au moment de l'installation — donc un pas manuel.
      2. Un choix réversible : ajouter `--split-per-abi` plus tard ne casse
         aucune installation, parce que l'identifiant d'application est le même
         et qu'Android remplace un APK par un autre de même package.
      3. C9 prime : une seule procédure manuelle, qui est « installer le
         fichier », pas « choisir le bon fichier parmi trois ».
    Le nom de l'artefact est EXPLICITE pour la même raison : un tiroir de
    téléchargements qui contient app-arm64-v8a-release.apk et app-armeabi-v7a-
    release.apk et debug-release.apk oblige à choisir.

(b) AUCUN ARTEFACT DE DÉBOGAGE. Le test est déjà exécuté à l'étape 5, et il
    produit un résultat lisible dans le journal du job. Un APK de débogage
    installé par erreur est un fichier signé avec une clé de débogage : c'est-à-
    dire exactement le scénario qui casse B31.

(c) FUSION DIRECTE SUR master, SANS PULL REQUEST. ⚠️ Le propriétaire est la
    seule personne sur ce dépôt (C13), donc une pull request est une formalité
    qui lui fait cliquer deux fois pour obtenir la même chose. Et aucune
    branche ne protège quoi que ce soit : le seul risque réel est un test rouge,
    et l'étape 5 l'attrape.
```

---

## 4. Plan composants

### 4.1 Arbre de composants

```
Aucun composant d'interface. Cette fondation produit un fichier, une clé et un
contrat.

.github/workflows/apk.yml
└── job « build » (ubuntu-latest, permissions: contents: read)
    ├── actions/checkout@v4            fetch-depth: 0
    ├── subosito/flutter-action@v2     flutter-version: 3.47.6
    ├── flutter pub get
    ├── flutter analyze                DoD 2
    ├── flutter test                   DoD 3
    ├── restore du keystore            secrets → android/key.properties + .jks
    ├── calcul BUILD_NAME / BUILD_NUMBER
    ├── flutter build apk --release
    ├── upload de l'artefact          lumen-tale-<name>-<number>
    └── suppression du keystore        if: always()

android/
├── key.properties                     GÉNÉRÉ EN CI, JAMAIS COMMITÉ
└── app/build.gradle.kts               signingConfig branché sur key.properties

pubspec.yaml                           version: la source unique (ADR-011)

lib/app/build_info.dart                AppBuildInfo, BuildInfoReader   ← 3-5
```

### 4.2 Composants

| Composant | Type | Fichier | Rôle |
|---|---|---|---|
| `apk.yml` | workflow GitHub Actions | `.github/workflows/apk.yml` | la compilation et la publication |
| `AppBuildInfo` | valeur immuable | `lib/app/build_info.dart` | la version **installée**, trois états, jamais un nombre inventé |
| `BuildInfoReader` | interface Dart | idem | le point d'injection de `3-5`, testable avec un faux |
| `key.properties` | fichier généré | `android/key.properties` | **jamais commité** — excluded par `android/.gitignore` |
| `upload-keystore.jks` | fichier généré | `android/` | **jamais commité** — excluded par `android/.gitignore` |
| `signingConfigs.release` | config Gradle | `android/app/build.gradle.kts` | lit `key.properties`, échoue bruyamment s'il est absent |

**Riverpod** : **aucun.** Une version installée n'est pas de l'état
d'application ; `3-5` en fera un `FutureProvider` à partir de
`BuildInfoReader`, et c'est le seul endroit où cela a lieu.

### 4.3 États par écran

**Aucun.** Aucun écran n'est produit ni modifié. La seule lecture attributable à
cette fondation est la ligne *Version {buildName} · build {buildNumber}* de
`settings-about.md` (B43), et elle appartient à `3-5`, qui consomme
`AppBuildInfo`.

### 4.4 Formulaires

Aucun. Il n'y a rien à saisir.

**Et surtout pas de « clé de signature » à saisir dans l'application**, pas de
« numéro de build » à entrer, et pas de « mode développeur » à activer : **tout
ce que le propriétaire fait tient en une installation de fichier**.

---

## 5. Gestion d'état (state management)

| Donnée | Portée | Stockage | Initialisation | Mise à jour |
|---|---|---|---|---|
| Version de base | dépôt | `pubspec.yaml`, `version:` | à la main, dans le commit | à la main, à la publication |
| Numéro de build d'un artefact | build | `GITHUB_RUN_NUMBER` | l'infrastructure | jamais |
| Tag de l'artefact | artefact | fichier texte à côté de l'APK | le workflow | jamais |
| Clé de signature | **secrets du dépôt** | `key.properties` + `.jks` en base64 | à créer **une fois** | **jamais** |
| Version installée | appareil | `versionName` / `versionCode` de l'OS | à l'installation | à l'installation de la version suivante |

**Ce qui n'est délibérément pas de l'état :**

- **Aucun compteur de compilations** dans l'application. Il n'y a rien à
  compter, et `GITHUB_RUN_NUMBER` est déjà unique par exécution.
- **Aucun « dernier build réussi »** stocké. Un pipeline n'a pas d'historique
  locally ; son historique est le journal d'exécutions de GitHub, et il est déjà
  là.
- **Aucun identifiant de commit affiché à l'utilisateur final.** Le tag vit dans
  l'artefact, pour le propriétaire et pour le débogage ; il n'a pas sa place sur
  l'écran *À propos*, qui parle au lecteur et pas à l'opérateur.
- **Aucune clé de signature lisible depuis l'application**, et aucun moyen de la
  changer. Une application qui sait lire sa propre clé est une application qui
  peut être réinstallée par n'importe qui.

---

## 6. Traçabilité des règles

### 6.1 Règles métier (B*)

| ID | Règle (PRD) | Implémentée où | Approche |
|---|---|---|---|
| **B31** | A new version of the app is delivered as an installable file. Installing a new version over an existing one preserves the library, every downloaded chapter, all reading positions and the history. | § 3.2, § 3.3 ; `.github/workflows/apk.yml` ; `key.properties` ; le `applicationId` | B31 a **cinq** conditions, dont **deux** sont des propriétés de ce pipeline et que rien d'autre ne peut garantir. **La clé de signature** : l'application *release* est actuellement signée avec la clé de **débogage**, qui n'est pas durable ; si elle change, Android refuse l'installation par-dessus pour signatures incompatibles, et le propriétaire doit désinstaller — c'est-à-dire perdre exactement ce que B31 promet de préserver. La clé est donc traitée ici comme une **donnée irremplaçable**, stockée en secret et **jamais** committée. **L'`applicationId`** : le placeholder `app.shipclean.lumen_tale` de `flutter create` est **immuable après la première publication** — le changer plus tard ferait installer l'application **à côté** de l'ancienne. Les trois autres conditions sont des propriétés de `local-store` : répertoire **support**, aucune migration destructive, `schemaVersion` monotone. Ce que le pipeline **ne peut pas** prouver est écrit en § 10 : la survie elle-même exige deux installations et un appareil réel, donc **Q-008** et le drill `gate:upgrade-safety` |
| **B34** | The app runs on Android phones only and is delivered as an installable file built automatically. No app store, no store account, no public distribution. | `.github/workflows/apk.yml` ; `permissions: contents: read` ; une seule variante d'APK | **Téléphones Android** : le pipeline ne produit aucun artefact iOS, aucun bundle d'app, et aucune cible de bureau — `flutter build apk` ne construit que de l'Android. **Installable** : un fichier `.apk` signé, déposé en artefact d'une exécution. **Construit automatiquement** : le déclencheur est `push` vers `master`, et rien d'autre. **Aucun magasin** : il n'y a ni étape de publication Play, ni `credentials.json`, ni clé de publication, ni métadonnées de magasin dans le dépôt. **Aucune distribution publique** : le dépôt est privé, l'artefact n'est lisible que par qui a accès au dépôt, et le `permissions: contents: read` est le strict minimum — un workflow qui publierait ailleurs n'aurait rien à écrire dans ce fichier |

### 6.2 Edge cases (E*)

| ID | Cas (PRD) | Approche de gestion | Où |
|---|---|---|---|
| *(aucun déclaré)* | `state.json` n'attribue **aucun** `edge_case_id` à `apk-pipeline`. C'est exact : aucun edge case du PRD ne concerne la livraison — ils concernent le **site**, le **téléchargement**, l'**appareil** et la **langue**. Les trois qui touchent cette fondation sont nevertheless écrites ici, parce qu'une fondation sans edge case est une fondation dont on n'a pas regardé les bords | **E11** (désinstallation, téléphone perdu) → le pipeline **ne peut rien** pour cette perte, et ne prétend rien : c'est `3-4` qui la divulgue, et ADR-010 (ni sauvegarde ni export) est la raison pour laquelle elle est irréversible. Le pipeline rend seulement le **récupérable** : un artefact reste téléchargeable et réinstallable, donc une réinstallation accidentelle ne demande pas de recompiler. **E21 / C10** (Novel Fire) → le pipeline ne mentionne aucune source, donc aucunsite conditionnel n'a d'effet sur lui. **B34** → un changement de `applicationId` après publication est le seul risque de « distribution publique » involontaire : il est traité en § 3.3 | § 3.3 ; § 10 |

### 6.3 Contraintes (C*)

| ID | Contrainte (PRD) | Comment elle est respectée |
|---|---|---|
| **C1** | Legal — reading is for personal use only, from sites whose rules permit automated reading. No redistribution of any content | L'artefact est une **application**, pas du contenu. Le pipeline ne compile aucun site, ne contient aucune liste de sources, et ne produit aucun paquet de contenu. ADR-010 : ni compte, ni synchronisation, ni export — donc rien à distribuer |
| **C2** | Privacy — no account, no server, no telemetry of any kind | Le workflow ne construit pas de télémétrie. `permissions: contents: read` — il n'écrit nulle part, ne lit aucun secret en dehors de ceux du dépôt, et ne contacte aucun service de mesure |
| **C3** | Platform — Android phones only. Delivered as an installable file, installed by hand (B34) | `flutter build apk --release` ne produit que de l'Android. Aucun `.ipa`, aucun `.app`, aucune cible de bureau. L'`ios/` du dépôt est le squelette par défaut de `flutter create` et n'est **pas** construit |
| **C5** | User skill — the only technical user cannot write code. Repairing a site that has changed must be deliverable to them as a new installable file with no manual step on their side | **La procédure complète du propriétaire est :|Download the file, install it, done.** Pas de compte, pas de SDK, pas de ligne de commande, pas de `adb`, pas de « activer les sources inconnues » autre que l'opérateur Android standard, et **une seule** variante d'APK à choisir. C'est l'objet entier de C5 |
| **C9** | Delivery — the app must be buildable without a store account and installable from a file on the owner's phone, repeatedly, without the owner performing a manual procedure | Le déclencheur est un `push`, pas un `workflow_dispatch`. Les frais sont nuls, le compte est déjà là (le dépôt), et le résultat est un fichier. ADR-011 : *« Item 5 of ADR-012 means Q-003 closes through CI, not through a local SDK install »* |
| **C13** | One device, one reader — lending the app file is the whole distribution model | Un seul artefact, installable sur le téléphone du propriétaire et sur celui d'un ami. Aucun compte par appareil, aucun profil, aucune donnée par utilisateur dans l'application — donc rien à configurer au premier lancement |

---

## 7. Pièges à éviter

- **⚠️ Ne pas écrire `main` dans le déclencheur. Le comportement correct (ADR-011,
  Q-006)** est : `branches: [ master ]`. La branche s'appelle `master` dans ce
  dépôt, et un workflow dont `on:` nomme une branche **inexistante ne s'exécute
  jamais tout en signalant un succès** — exactement la forme d'échec silencieux
  qu'ADR-011 a été écrit pour éviter. Si la branche est renommée un jour, le
  déclencheur **suit**.
- **⚠️ Ne pas signer la variante *release* avec la clé de débogage. Le
  comportement correct (B31)** est : une clé de signature **durable**, stockée en
  secret GitHub, jamais committée. La clé de débogage qui est là aujourd'hui
  fonctionne pour une installation manuelle, mais si elle change un jour Android
  refuse l'installation par-dessus pour signatures incompatibles — et le
  propriétaire doit alors désinstaller, ce qui est **la perte irréversible que
  B31 promet d'éviter**. `android/.gitignore` exclut déjà `key.properties`,
  `*.keystore` et `*.jks` : ne pas neutraliser ces lignes.
- **⚠️ Ne pas committer la clé de signature. Le comportement correct (B31,
  C2)** est : `key.properties` et le `.jks` sont générés en CI à partir de secrets
  et **supprimés à la fin de l'étape, `if: always()`** — donc aussi quand le job
  échoue. Un secret de signature dans l'historique git est irrattrapable : le
  réécrire ne le retire pas.
- **⚠️ Ne pas changer `applicationId` après la première publication. Le
  comportement correct (B31)** est : le fixer **maintenant**, pendant que
  l'application n'existe sur aucun téléphone. Le changer plus tard installerait
  l'application **à côté** de l'ancienne et la laisserait orpheline — deux
  applications, deux bibliothèques, et le propriétaire qui ne sait plus laquelle
  il ouvre.
- **⚠️ Ne pas coder en dur la version dans le workflow. Le comportement correct
  (B34, ADR-011)** est : **lire** `pubspec.yaml`. Un workflow qui répète
  `1.2.3` en dur est une deuxième source de vérité, et c'est exactement
  l'échec qu'ADR-011 existe pour empêcher.
- **⚠️ Ne pas mettre le tag git dans `--build-name`. Le comportement correct
  (B34, C5)** est : `--build-name` porte `1.0.0`, lisible dans Paramètres ▸
  Applications. Le tag va dans l'artefact, à côté de l'APK, pour le propriétaire.
  Un nom de build comme `v1.0.0-3-g9bc4aa` est illisible dans une fiche
  d'application, et B43 demande au lecteur de savoir quelle version il a.
- **⚠️ Ne pas publier plusieurs variantes d'APK. Le comportement correct (C5,
  C9)** est : **un** APK universel. Trois fichiers obligent le propriétaire à
  choisir, donc à comprendre, donc à poser une question — et il ne peut pas
  écrire de code. Le fractionnement par ABI reste réversible plus tard.
- **⚠️ Ne pas publier un artefact de débogage. Le comportement correct (B31)** est :
  `flutter test` est déjà exécuté et son résultat est dans le journal. Un APK de
  débogage installé par erreur est signé avec une clé de débogage : exactement
  le scénario qui casse B31.
- **⚠️ Ne pas laisser le job continuer quand `flutter analyze` signale une issue ou
  quand `flutter test` échoue. Le comportement correct (C9, `AGENTS.md`)** est :
  ces deux étapes **précèdent** la compilation, et un artefact n'est publié que
  si les deux passent. Un APK produit depuis du code qui ne compile pas
  proprement n'est pas une livraison, c'est un fichier que le propriétaire
  installera et qui plantera.
- **⚠️ Ne pas lire `pubspec.yaml` à l'exécution pour afficher la version. Le
  comportement correct (B43)** est : lire `versionName` / `versionCode` **de
  l'OS**. Ce sont deux valeurs différentes dès la première surcharge
  `--build-name` d'ADR-011 — donc dès la première compilation CI. Lire le
  fichier source afficherait au propriétaire une version qui n'est pas celle qu'il
  a installée.
- **⚠️ Ne pas mettre de valeur de repli sur la version. Le comportement correct
  (B43)** est : `AppBuildInfo.isUnknown` existe, et l'écran *À propos* rend
  `Version —`. Un `?? '0.0.0'` afficherait un numéro inventé, ce qui est
  précisément ce que B31 et C9 interdisent : le propriétaire doit pouvoir savoir
  quelle version il a **réellement**.

> **Question ouverte — B43 a besoin de la version à l'exécution, et aucun paquet ne
> la fournit.** `settings-about.md` et `settings.md` § 4.1 portent tous deux
> `row.about.value` = `Version {buildName} · build {buildNumber}`, et `3-5` est la
> slice qui la rend. Or **`package_info_plus` n'est pas dans `pubspec.yaml`**, et
> rien dans le dépôt lit `versionName` / `versionCode`. Les trois voies sont
> les suivantes :
> **(a)** ajouter `package_info_plus` — c'est une **dépendance** nouvelle, donc
> elle passe par `flutter pub add` et par l'examen de `AGENTS.md` (« the **only**
> way to change dependencies ») ; et `17-security.md` règle 13 exige une ADR pour
> toute nouvelle dépendance native ;
> **(b)** écrire un `MethodChannel` vers un petit plugin Kotlin dans
> `android/app/src/main/kotlin/` — du code natif écrit à la main, ce qui est
> précisément ce que `AGENTS.md` veut éviter ;
> **(c)** lire `pubspec.yaml` au moment de la compilation et l'injecter par
> `--dart-define` — gratuit, sans dépendance, **et faux** dès qu'ADR-011 surcharge
> `--build-name`, donc c'est exclu par la règle précédente.
> **L'option réversible la moins chère est retenue : (a), `package_info_plus`,
> ajouté par `flutter pub add`, et une ADR courte qui le justifie** — parce que
> c'est la seule voie qui lit la version **réellement installée** sans écrire de
> code natif à la main, et parce que c'est le paquet endorsed de Flutter pour cela.
> **Le déclencheur de clôture** : `flutter pub add package_info_plus` et une ADR
> dans `DECISIONS.md`. **Ne pas écrire de `MethodChannel` en attendant, et ne pas
> lire `pubspec.yaml` au runtime.**

> **Question ouverte — l'identifiant d'application final n'est pas décidé.**
> `android/app/build.gradle.kts` porte le placeholder `app.shipclean.lumen_tale`
> de `flutter create`, et `MainActivity.kt` vit dans
> `android/app/src/main/kotlin/app/shipclean/lumen_tale/`. Les deux portent le même
> renommage automatique, donc changer l'un **et** l'autre est mécanique — mais le
> choix du nom est du ressort du propriétaire et **aucun document approuvé ne le
> fixe**. **L'option réversible la moins chère est retenue : ne rien changer dans
> cette slice**, parce que l'identifiant est immuable après la première
> publication et qu'aucune urgence ne le rende faux à l'usage —
> c'est laid, pas cassé. Mais **il doit être fixé avant la première publication**,
> c'est-à-dire avant le premier artefact téléchargé sur un téléphone. **Le
> déclencheur de clôture** : le propriétaire choisit, et le même commit change
> `applicationId`, `namespace` et le chemin du paquet Kotlin.

> **Question ouverte — `flutter build apk` n'a jamais été exécuté dans ce dépôt.**
> `AGENTS.md` porte « **unvalidated here**, no Android SDK (Q-003) » et le
> § 3.4 de ce plan ne l'a pas validé non plus : il n'y a pas de SDK Android dans
> cet environnement, donc **la compilation n'a pas été essayée**. Ce qui est
> vérifié ici est le *contenu* du workflow et des fichiers Gradle, par lecture —
> pas la fin de la chaîne. **Le déclencheur de clôture** : la première exécution
> réelle du workflow, qui est aussi le premier candidat pour fermer Q-008.
> **Ne pas déclarer cette fondation vérifiée tant que l'artefact n'a pas
> existé.**

---

## 8. Dépendances

| Dépend de | Nature | Statut | Fallback si absent |
|---|---|---|---|
| — | — | vague **0**, **sans aucune dépendance** | Aucune. C'est la seule fondation du projet qui n'en a aucune |
| `actions/checkout@v4` | outil — le code | externe | aucun |
| `subosito/flutter-action@v2` | outil — Flutter 3.47.6 en CI | externe | aucun |
| Le dépôt GitHub lui-même | plate-forme | existant | **aucun sans lui** — c'est la seule dépendance de `apk-pipeline` |
| `android/` | code — Gradle, manifeste, `MainActivity.kt` | **livré** par `flutter create`, non modifié | aucun |
| `17-security.md` règle 13 | contrat — une dépendance native exige une ADR | règle de projet | bloque `package_info_plus` (question ouverte de § 7) |

**Dépendants** : `3-5` (l'écran *À propos* qui lit `AppBuildInfo`, **B43**), et
— par le graphe — rien d'autre : `state.json` déclare `apk-pipeline → 3-5`. En
pratique, **tout le projet** en dépend par Q-008 : sans artefact, aucun test sur
appareil n'est possible, et donc ni SC-5, ni le MVP gate, ni le drill
d'upgrade-safety, ni aucune des trois cibles mesurables de `prd.md` § 7.1.

---

## 9. Checklist de tâches

### Phase 1 — Couche de données

- [ ] Aucun schéma, aucune table, aucun DAO
- [ ] `android/key.properties` : **jamais commité**. Vérifier que les trois lignes
  d'`android/.gitignore` (`key.properties`, `**/*.keystore`, `**/*.jks`) sont
  intactes et que `git check-ignore -v android/key.properties` répond
- [ ] La clé `.jks` : générée **une fois**, stockée en secret GitHub **base64**,
  **jamais** dans le dépôt
- [ ] `AppBuildInfo` + `BuildInfoReader` dans `lib/app/` — trois états, aucune
  valeur de repli
- [ ] `package_info_plus` : **ne pas l'ajouter dans cette slice** sans l'ADR de
  la question ouverte de § 7

### Phase 2 — Logique métier

- [ ] Le calcul de version : `build_name` depuis `pubspec.yaml`,
  `build_number = max(version.build, GITHUB_RUN_NUMBER)`, avec un **échec
  explicite** au-delà de `2^31 - 1` (§ 3.1)
- [ ] `android/app/build.gradle.kts` : `signingConfigs.release` lit
  `key.properties` et **échoue bruyamment** s'il est absent — pas de repli
  silencieux sur la clé de débogage
- [ ] `isDistinguishable(aName, aNumber, bName, bNumber)` : deux artefacts du même
  commit ne doivent jamais produire le même couple

### Phase 3 — Interface utilisateur

- [ ] **Aucun, et c'est légitime.** Un workflow de compilation ne produit aucun
  widget, aucune chaîne ARB, aucun jeton de design et aucun état d'écran. Il
  produit un fichier sur un serveur. La seule ligne d'interface concernée est
  `row.about.value` de `settings-about.md` (B43), et elle appartient à **`3-5`**,
  qui consommera `AppBuildInfo`. Créer ici un écran *À propos* serait dupliquer
  la sortie de la slice qui la possède

### Phase 4 — Intégration

- [ ] `.github/workflows/apk.yml` : `on.push.branches: [master]`,
  `permissions: contents: read`, `fetch-depth: 0`
- [ ] Étapes dans cet ordre : checkout → Flutter 3.47.6 → `pub get` →
  **`analyze`** → **`test`** → keystore → version → build → upload → **suppression
  du keystore `if: always()`**
- [ ] Une **seule** variante d'APK, nom d'artefact explicite, aucun artefact de
  débogage
- [ ] Vérifier que le keystore est supprimé **même quand le job échoue** —
  `if: always()` sur l'étape de nettoyage, pas `if: success()`
- [ ] Le dépôt est **privé**. Un artefact d'un dépôt public serait de la
  distribution publique, ce que B34 interdit

### Phase 5 — Tests et polish

- [ ] **Aucun test `flutter test`** : il n'y a pas de Dart à tester ici, et écrire
  un test qui vérifie le contenu d'un fichier YAML serait un test qui teste le
  fichier de cette slice et pas le dépôt réel — donc il serait vert et faux
- [ ] À la place, et c'est mieux : **une exécution réelle du workflow**, puis la
  vérification de § 11.3
- [ ] `flutter analyze` et `flutter test` **sur le job lui-même** — c'est la
  seule façon que `DoD` points 2 et 3 soient vérifiés sur **le** commit qui
  produit l'artefact

### Vérifications finales

- [ ] `dart format .` — propre
- [ ] `flutter analyze` — **zéro** issue, zéro `info`
- [ ] `flutter test` — tout passe (les 29 de la suite)
- [ ] `coverage-check.js` **ne peut pas** vérifier une fondation : il ne lit que
  `state.slices` (finding **F-003**). Cette vérification est **manuelle**, par
  relecture des § 6 et § 10 de ce fichier
- [ ] **Première exécution réelle du workflow** — c'est le gate de cette
  fondation, et il n'a pas été passé

---

## 10. Critères d'acceptation

- [ ] **B34** — `.github/workflows/apk.yml` existe, et son `on.push.branches`
  contient `master` et **pas** `main`. `grep -n 'branches' .github/workflows/apk.yml`
  le montre.
- [ ] **B34** — le workflow ne contient **aucune** étape de publication Play :
  `grep -rn 'play\|app-bundle\|uploadPlay' .github/workflows/` ne retourne rien.
- [ ] **B34** — le workflow ne construit **qu'un** APK : `grep -c 'flutter build apk'`
  vaut 1, et `--split-per-abi` est absent.
- [ ] **B34** — `permissions:` vaut `contents: read`. Ni `packages: write`, ni
  `deployments: write`, ni `id-token: write`.
- [ ] **B34** — `flutter-version:` est `3.47.6`, identique à `AGENTS.md` et à
  `architecture.md` § 1.1.
- [ ] **B34** — le nom de l'artefact contient le nom **et** le numéro de build.
- [ ] **B31** — `git check-ignore -v android/key.properties` et
  `git check-ignore -v android/upload-keystore.jks` répondent tous deux : **aucun**
  fichier de clé n'est suivi par git.
- [ ] **B31** — `grep -n 'signingConfigs.getByName("debug")' android/app/build.gradle.kts`
  ne retourne **rien** : la variante *release* n'est plus signée par la clé de
  débogage.
- [ ] **B31** — `android/app/build.gradle.kts` déclare un `signingConfigs.release`
  qui lit `key.properties`, et qui **échoue** si le fichier est absent.
- [ ] **B31** — le workflow supprime `key.properties` et le `.jks` dans une étape
  marquée `if: always()`, **après** l'étape de compilation.
- [ ] **B31** — `grep -n 'pubspec.yaml' .github/workflows/apk.yml` montre que la
  version est **lue**, et le workflow ne contient **aucune** chaîne de version en
  dur. `grep -nE '[0-9]+\.[0-9]+\.[0-9]+' .github/workflows/apk.yml` ne retourne
  que `3.47.6`.
- [ ] **B31** — deux exécutions successives produisent deux `build-number`
  **différents** : c'est la propriété `isDistinguishable`, vérifiable sur les deux
  artefacts d'un même commit.
- [ ] **B31** — `build-number` est un entier positif et inférieur à `2^31`, sinon
  le job **échoue explicitement** plutôt que de produire un `versionCode` invalide.
- [ ] **B31** — le tag git de la compilation est présent **dans l'artefact**, et
  **absent** de `--build-name`.
- [ ] **B31** — `applicationId` et `namespace` portent une valeur **décidée**, et
  le paquet Kotlin correspond. ⚠️ ⚠️ **Ce point n'est pas validé tant que la
  question ouverte de § 7 n'est pas close** : la valeur actuelle
  `app.shipclean.lumen_tale` est un placeholder de `flutter create`.
- [ ] **C9** — le déclencheur est `push`, et il n'y a **ni** `workflow_dispatch`
  **ni** `schedule` dans le fichier. `grep -n 'workflow_dispatch\|schedule'`
  ne retourne rien.
- [ ] **C9** — l'étape `flutter analyze` **précède** `flutter build apk`, et le job
  échoue si elle signale une issue.
- [ ] **C9** — l'étape `flutter test` **précède** `flutter build apk`, et le job
  échoue si un test échoue.
- [ ] **C5** — **une seule** procédure pour le propriétaire : télécharger l'artefact,
  l'installer. Aucun autre fichier n'est publié.
- [ ] **C2** — le dépôt est **privé**, et le workflow ne contacte aucun service de
  mesure, d'analyse ou de télémétrie de build.
- [ ] **B43** *(prévu)* — `AppBuildInfo.isUnknown` rend `Version —`, et
  `displayLine` ne produit un couple que si **les deux** moitiés sont connues. Un
  test unitaire avec un `BuildInfoReader` faux couvre les trois états.

---

## 11. Plan de tests

### 11.1 Tests unitaires

Emplacement : `test/app/build_info_test.dart` — **seul** fichier Dart que cette
fondation produit, et il ne teste **pas** le workflow.

| Cible | Scénario | IDs couverts |
|---|---|---|
| `AppBuildInfo.isUnknown` | les deux `null` → `true` | **B43** |
| `AppBuildInfo.isUnknown` | `buildName` seul → `false` | B43 |
| `AppBuildInfo.displayLine` | les deux connus → `1.0.0 (42)` | B43 |
| `AppBuildInfo.displayLine` | **`buildNumber` absent** → `—`, **pas** `1.0.0` seul | **B43** |
| `AppBuildInfo.displayLine` | **`buildName` absent** → `—` | **B43** |
| `AppBuildInfo.displayLine` — aucune valeur inventée | aucune chaîne de sortie ne contient `0.0.0`, `unknown`, `null` ou `undefined` | **B43** |
| `isDistinguishable` | même commit, numéros 1 et 2 → `true` | **B31**, ADR-011 |
| `isDistinguishable` | même nom, numéros différents → `true` | **B31** |
| `isDistinguishable` | couple identique → `false` | **B31** |
| `BuildInfoReader` | un faux rend `AppBuildInfo` ; l'appelant n'a pas besoin du paquet | B43 |

### 11.2 Tests de composants

**Aucun, et c'est exact.** Cette fondation ne produit aucun widget. L'écran *À
propos* qui affiche `displayLine` appartient à `3-5`, et ses tests de composants
appartiement à `3-5`.

### 11.3 Vérifications du pipeline

Emplacement : **aucun fichier Dart.** Ces vérifications sont des **lectures de
fichiers** et une **exécution réelle**. Elles sont listées ici parce que la
Checklist de gate exige que § 11 nomme ce qui est vérifié — et la réponse
honnête est que la moitié de cette fondation ne se teste pas avec `flutter test`.

| Vérification | Où | Attendu |
|---|---|---|
| Le fichier existe | `.github/workflows/apk.yml` | présent, `on.push.branches: [master]` |
| Aucune dépendance superflue | `permissions:` | `contents: read`, une seule clé |
| Le déclencheur est `master` | `grep -n 'branches'` | `master`, **jamais** `main` |
| La version est lue, pas codée en dur | `grep -nE '[0-9]+\.[0-9]+\.[0-9]+'` | seulement `3.47.6` |
| `analyze` et `test` précèdent `build` | ordre des étapes | oui |
| La clé n'est pas suivie | `git check-ignore -v` | les deux fichiers ignorés |
| La clé de débogage n'est plus utilisée | `grep -n 'getByName("debug")'` | absent |
| La clé est supprimée en cas d'échec | `if: always()` | présent sur l'étape de nettoyage |
| **Exécution réelle** | l'onglet *Actions* du dépôt | le job est vert, et l'artefact existe |
| L'artefact s'installe | `aapt dump badging` ou l'installation manuelle | `package: app.shipclean.lumen_tale`, `versionCode` = le numéro d'exécution |
| **Deux exécutions du même commit** | deux artefacts | deux `version-code` **différents** |
| **Installation par-dessus** | **appareil réel** | l'application **se met à jour** et ne demande pas de désinstaller |

### 11.4 Tests E2E

**Le drill d'upgrade-safety**, `gate:upgrade-safety` — délibérément **hors** du
graphe de slices, précisément pour que `dependency-check` ne le confonde pas avec
une slice à planifier. C'est **la** preuve de B31, et elle porte un nom qui
l'exclut du graphe pour une raison : le contrôle « les lignes sont intactes » passerait pour une
migration qui supprime une table.

> Avec une entrée de bibliothèque, des chapitres téléchargés, des positions de
> lecture et un historique en place, **installer l'APK suivant par-dessus le
> précédent** et affirmer que **chacun** de ces quatre éléments est intact
> ensuite. Les **fichiers** téléchargés sont vérifiés, pas seulement les lignes.

| Occasion | Bibliothèque | Ce qu'il prouve |
|---|---|---|
| **MVP gate** — roadmap Wave 4 | petite | B31 tient sur un cas simple |
| **V1 gate** — roadmap Wave 7 | grande | Une migration qui ne casse qu'à l'échelle ne se voit qu'ici |

**Bloqué par Q-008** : un téléphone réel, et un moyen d'y installer un APK.
Ce drill **ne peut pas** être exécuté ici, et **aucun des deux gates** ne peut
clore sans lui. C'est enregistré comme tel dans `roadmap.md` § 7.1, et
`apk-pipeline` est la moitié **CI** de Q-008 : le SDK Android devient une
dépendance du pipeline plutôt que du poste de travail.

### 11.5 Vérifications manuelles

| Vérification | Écran / Composant | État |
|---|---|---|
| Overflows horizontaux | — | sans objet : pas d'interface |
| Éléments hors écran | — | sans objet |
| Navigation | — | sans objet |
| **L'artefact s'installe par-dessus l'existant** | téléphone du propriétaire | **B31**, et le seul test qui compte |
| **La version affichée correspond à l'installée** | Paramètres ▸ Applications | le `build-number` de l'écran *À propos* est celui de l'artefact |
| **La bibliothèque survit** | après la mise à jour | bibliothèque, téléchargements, positions, historique |

---

## Checklist de gate

- [x] Sources explicitement référencées (PRD, roadmap, architecture, DECISIONS, conventions, rules) **et les fichiers du dépôt** — `pubspec.yaml`, les trois `.gradle.kts`, `gradle.properties`, les trois manifestes, `android/.gitignore`.
- [x] Chaque ID B*/E*/C* du périmètre apparaît en § 6 — **B31**, **B34**, plus **B43** *(prévision)*, et **C1**, **C2**, **C3**, **C5**, **C9**, **C13**.
- [x] Les contrats de données (§ 2) sont du **vrai Dart** avec les imports — `AppBuildInfo` et `BuildInfoReader` — plus l'état réel du manifeste Android.
- [x] Les algorithmes (§ 3) sont en pseudocode avec **chaque** branche écrite : quatre branches de version, cinq conditions de B31, sept branches de déclencheur, et les trois questions d'ADR-011 explicitement résolues avec leur motif.
- [x] La checklist de tâches (§ 9) couvre les cinq phases, et la **Phase 3 est explicitement vide — avec la raison**, et avec la ligne *À propos* nommée comme appartenant à `3-5`.
- [x] Les critères d'acceptation (§ 10) sont vérifiables individuellement ; **onze** sont des `grep`, `git check-ignore` ou des **négations**, parce que la moitié des fautes possibles ici sont des fautes de **présence** — une branche `main`, une étape Play, un `split-per-abi`, une clé de débogage, un déclencheur manuel.
- [x] Le plan de tests (§ 11) couvre tous les IDs, nomme le **seul** fichier Dart (`test/app/build_info_test.dart`) et reconnaît explicitement que le workflow **ne se teste pas** avec `flutter test`.
- [ ] `coverage-check.js` **ne peut pas** vérifier une fondation : il ne lit que `state.slices` (finding **F-003**). La vérification de cette slice est **manuelle**, par relecture des § 6 et § 10 de ce fichier.
- [ ] **La première exécution réelle du workflow n'a pas eu lieu.** `AGENTS.md` porte « **unvalidated here**, no Android SDK (Q-003) », et cette slice **hérite** de cette limite : le workflow est écrit et relu, jamais exécuté. La fondation est donc **écrite mais non prouvée**, et c'est le gate qui la ferme.

**Statut** : `draft` → en attente de validation.