---
type: implementation-plan
slice: http-client
module: core
status: draft
generated_at: 2026-10-03
derived_from:
  - .forge/prd.md
  - .forge/architecture.md
  - .forge/design/design-system.md
  - .forge/conventions.md
conventions_ref: .forge/conventions.md
---

# Plan d'implémentation — http-client

> Fondation, pas slice de feature. `state.json` ne la range pas dans `slices`,
> donc `coverage-check.js slice` **ne vérifie pas ses `rule_ids`** : l'outil
> répond `{"error": "Slice \"http-client\" not found in state.json"}` et
> `check_plans.py` ne peut voir que les quatre vérifications qu'il ajoute. C'est
> le finding **F-003**. Les deux règles sont donc tracées à la main en § 6, et
> **une relecture humaine de § 6 est le contrôle réel** de cette fondation.
>
> **Ce document décrit *comment implémenter* cette fondation**, de façon qu'un
> implémentateur n'ait rien à décider et n'ait pas à lire le PRD.

---

## Sources

- **PRD** : `.forge/prd.md` — règles **B29**, **B22** (côté transport) ; contraintes **C7**, **C2**, **C5**, **C6**, **C11**, **C12**
- **Architecture** : `.forge/architecture.md` — § 1.1 (la ligne `dio`), § 1.2 (la couche `core/network`), § 2.2 (`FetchResult`, « le premier producteur est `core/network` »), § 2.3 (**cette fondation**), § 3.1 (ligne `1.6`), § 4.7 (`shared_preferences` : réglages seulement), § 5.2 (la taxonomie), § 5.3 (ce que l'app promet du réseau), ADR-013, ADR-014
- **Design** : `.forge/design/screens/source-unavailable.md` § 5 (le réessai est une décision du lecteur, jamais automatique), § 8 (`causeEvidence` : un statut HTTP ou un hôte, jamais une URL) ; `.forge/design/screens/settings-about.md` § 8 (« the update request is the only outbound request this screen can make, and it carries nothing ») — hors périmètre ici, cité pour la forme du POSTURE
- **Design system** : aucun composant. Cette fondation ne produit aucun widget.
- **Conventions** : `.forge/conventions.md` — pile technique (ligne `dio`), § Erreurs réseau, § Erreurs de validation, § Patterns retenus
- **Règles projet** : `17-security.md` règles 3, 5, 6, 7, 8, `13-error-handling.md` règles 1, 2, 4, 6, 7, `02-architecture.md` (table des couches), `03-source-system.md` règles 2, 3, 4, 10, `08-coding-standards.md`, `15-performance.md`, `10-testing.md` règle 7

---

## 1. Résumé de la slice

`http-client` construit **le seul moyen par lequel cette application parle à un
site**. Elle produit cinq fichiers Dart purs dans `lib/core/network/`, sans un
seul import de `package:flutter`, et **aucun widget**.

`architecture.md` § 2.3 dit pourquoi la fondation existe : `core/network/` a été
nommé par trois documents (`conventions.md`, la table des couches de § 1.2, et
trois slices) et **possédé par aucun**. *Une couche qu'aucune slice ne construit
est une couche qu'aucune slice ne peut appeler.* Cette slice est ce propriétaire.

| Livré | Pourquoi il est transversal et pas dans `2-1` |
|---|---|
| Une instance `dio` configurée | En-têtes partagés, timeouts, et le **User-Agent honnête** que chaque site mesuré a exigé |
| Attraper le primitif, **relancer un typé** | `conventions.md` : jamais une `DioException` qui atteint une source |
| **Le limiteur de débit** | **C7** — la politesse envers les sites, appliquée à un seul endroit |
| `baseUrl` par source + `versionId` | `03-source-system.md` règle 2 |
| **Aucune politique de réessai** | Mihon a déprécié son aide équivalente parce qu'elle *masquait* le comportement ; un réessai est une **décision**, et elle appartient à l'appelant qui peut la justifier |

**La règle unique qui gouverne tout le fichier** : `17-security.md` règle 5.
L'User-Agent est `LumenTale/<version> (personal reader)`, et **jamais** une
usurpation de navigateur. Ce n'est pas de la prudence, c'est une mesure : Novel
Fire répond **403** à un User-Agent navigateur et **200** à un User-Agent honnête
(ADR-014). Feindre d'être un navigateur est précisément ce qui déclenche le
blocage.

**Aucune journalisation, aucun cache, aucun secret.** `B29` interdit jusqu'aux
diagnostics, donc le client ne journalise rien : le `DioException` d'origine
voyage comme `cause` d'une exception typée, et c'est l'appelant — le seul
autorisé — qui décide s'il le montre.

**User stories couvertes** : US-16 (être prévenu qu'un site ne fonctionne plus) —
par son mécanisme, pas par son écran ; US-01, US-03, US-04 par leur chemin
réseau
**Règles métier couvertes** : B29
**Contraintes couvertes** : C7, C2, C5, C6, C11, C12
**Edge cases couverts** : aucun attribué par `state.json` ; les deux qui touchent
le transport (**E5**, `NoConnection` ; et le `429` de **C7**) sont traités en § 3
et en § 6.2

---

## 2. Contrats de données (code)

> Traduction mécanique de `architecture.md` § 2.3, § 5.2 et § 5.3, plus
> `conventions.md` § Erreurs réseau. **Aucune règle inventée** : chaque champ est
> soit nommé par `FetchResult` (`failure-discriminator` § 2.2), soit exigé par
> `17-security.md`, soit une valeur qu'aucun document ne fixe et qui est donc
> déclarée ici comme le choix de ce plan (§ 2.4).

### 2.1 Schémas de validation

**Aucun nouveau schéma, aucune colonne, aucune migration.** Cette fondation ne
touche pas la base et ne lit rien dans `shared_preferences`. `schemaVersion` reste
à 1, et **B31 n'est pas touché**.

Le seul point de stockage à mentionner : `17-security.md` règle 8 — aucun cookie,
aucun jeton, aucun identifiant de session n'est écrit par ce client, et le
`cookieJar` de `dio` est **interdit** (voir § 7).

### 2.2 Types et interfaces

```dart
// lib/core/network/fetch_result.dart
//
// ⚠️ LE FICHIER EST À CE PLAN, PAS À CELUI DU CLASSIFIEUR.
//
// `http-client` est vague **0** et `failure-discriminator` est vague **2**, qui
// le déclare dans `depends_on`. Un producteur qui n'écrirait pas le type dont son
// consommateur a besoin aurait une dépendance inversée : le vague 2 importerait
// un type qu'il aurait lui-même défini. Donc **cette fondation écrit
// `FetchResult`**, et `failure-discriminator` fait
// `import 'package:lumen_tale/core/network/fetch_result.dart';` sans y toucher.
//
// Ce que ce type est : **le discriminant du transport**. Il dit ce que le
// transport a fait, jamais ce que le site a répondu — `HttpResponse` (§ 2.2)
// porte la réponse. Les deux voyagent ensemble, et `FetchResult` ne se déplace
// jamais seul.
//
// Un 4xx ou un 5xx n'est **PAS** un cas distinct ici : il arrive en
// `FetchSucceeded` avec son statut, et le classifieur décide. Décider « ceci est
// un refus » au transport mettrait la taxonomie de B22 en deux endroits.

sealed class FetchResult {
  const FetchResult();
}

/// A response was received. [status] may be any HTTP status; 2xx is the only
/// range the classifieur reads as content.
final class FetchSucceeded extends FetchResult {
  const FetchSucceeded({required this.status});

  final int status;
}

/// No response was received at all. E5.
final class FetchTransportFailed extends FetchResult {
  const FetchTransportFailed({required this.host});

  final String host;
}

/// 429, or any status the shared limiter turned into a backoff.
/// `17-security.md` règle 6: `Retry-After` is honoured.
///
/// ⚠️ **Pas de `host`, et surtout pas de `sourceId`.** Un 429 appartient à un
/// HÔTE, pas à une source : deux sources peuvent partager un `baseUrl`, et un
/// hôte peut servir les deux. L'hôte est déjà dans le slot du limiteur, keyed by
/// host (§ 3.2) ; le porter ici serait une seconde copie d'un fait qui existe,
/// libre de diverger. `architecture.md` § 5.2 le dit dans les mêmes termes.
final class FetchRateLimited extends FetchResult {
  const FetchRateLimited({required this.retryAfter, required this.status});

  final Duration retryAfter;
  final int status;
}
```

```dart
// lib/core/network/http_response.dart
//
// Le transport EST le premier producteur de `FetchResult` — et il en est aussi
// le **seul** propriétaire du fichier, § 2.2 juste au-dessus. `FetchResult`
// lui-même ne porte que trois faits — un statut, un hôte, une durée — et aucun
// corps. Ce que ce fichier ajoute est le CORPS de la réponse, sans lequel
// `ContentProbe`, `parseDocument` et `fetchChapterContent` n'ont rien à
// examiner.

import 'fetch_result.dart';

/// Une réponse lue, avec le corps qui va avec.
///
/// `FetchResult` ne peut pas voyager seul : il décrit *ce que le transport a fait*,
/// pas *ce que le site a répondu*. Les deux vont ensemble, et ce type est le seul
/// endroit où ils sont assemblés. `2-1` § 2.3 rend **ce** type, jamais
/// `FetchResult` : une source a besoin du statut pour classer **et** du corps
/// pour parser, et rendre le seul discriminant l'empêcherait de lire une page.
final class HttpResponse {
  const HttpResponse({
    required this.outcome,
    required this.status,
    required this.body,
    required this.contentType,
  });

  /// Ce que la classification consomme tel quel. Jamais nul.
  final FetchResult outcome;

  /// Le statut HTTP. `0` quand aucune réponse n'est arrivée du tout — et alors
  /// [outcome] est un `FetchTransportFailed`, jamais un `FetchSucceeded(0)`.
  final int status;

  /// Le corps **décodé**. Vide quand [status] vaut `0` : il n'y avait rien à
  /// décoder, et un corps vide présenté comme un corps lu serait le défaut miroir
  /// de E8.
  final String body;

  /// Le `Content-Type` de la réponse, **brut** — il sert de preuve et il décide
  /// du décodage (§ 3.1). Jamais localisé, jamais réécrit.
  final String? contentType;

  /// `true` quand une réponse est réellement arrivée, quel que soit son statut.
  /// C'est ce prédicat que `failure-discriminator` utilise pour son bras 2.
  bool get hasResponse => status != 0;
}
```

```dart
// lib/core/network/http_client.dart
//
// `architecture.md` § 2.3, et la signature que `2-1` § 2.3 attend déjà.

import 'fetch_result.dart';
import 'http_response.dart';

/// Le contrat que `sources/implementations` utilise. `02-architecture.md` :
/// cette couche n'a le droit d'importer que `domain/sources` et `core/network`.
abstract interface class HttpClient {
  /// `GET` d'un chemin **relatif** et résolu contre la `baseUrl` de la source.
  ///
  /// Ne lève jamais pour une panne réseau, une absence de connexion, un refus du
  /// site ou un 429 : ces quatre cas sont des [FetchResult], pas des exceptions,
  /// parce que `B22` exige que l'appelant puisse les distinguer d'un succès.
  ///
  /// Ne lève que [CancelledException] — une annulation n'est pas un échec et ne
  /// doit jamais devenir `NoConnection` sur l'écran.
  Future<HttpResponse> get(String relativePath, {Map<String, String>? query});

  /// Résout un chemin relatif contre la `baseUrl` de cette source.
  ///
  /// `03-source-system.md` règle 2 : **pas de barre oblique finale** sur
  /// `baseUrl`, et c'est ici — et nulle part ailleurs dans le projet — qu'une URL
  /// absolue est composée.
  Uri resolve(String relativePath);
}

/// La règle 3 de `03-source-system.md`, en un seul endroit.
///
/// `setUrlWithoutDomain` et `resolve` sont les deux moitiés du même contrat : l'un
/// compose, l'autre décompose. Elles vivent dans le même fichier **parce que deux
/// implémentations de la même règle seraient deux réponses à « quelle est la
/// forme canonique d'une URL ? »**.
String setUrlWithoutDomain(Uri absolute);
```

```dart
// lib/core/error/app_exception.dart
//
// ⚠️ CHEMIN TRANCHÉ — `lib/core/error/`, voir § 7, question 1.
//
// Il régnait deux chemins pour la même classe : `13-error-handling.md` écrivait
// `core/utils/errors/`, `architecture.md` § 1.2 et § 5.2 écrivaient
// `core/error/`. **`lib/core/error/` est canonique**, pour trois raisons qui ne
// sont pas des préférences : la table des couches de `architecture.md` § 1.2 —
// l'autorité sur les chemins — le nomme ; `failure-discriminator` y a déjà écrit
// `SourceFailure` ; et `13-error-handling.md` a été corrigé sur ce point, son
// chemin précédent est noté dans le fichier lui-même.
//
// La hiérarchie est celle de `13-error-handling.md`, mot pour mot. Elle est
// **cachée derrière `core/error/` et non `core/utils/`** pour une seconde
// raison, mécanique : la table des couches de `02-architecture.md` dit que `core`
// n'importe « que des paquets externes, aucun autre répertoire de `lib/` » — et
// `core/utils/` est un autre répertoire de `core`, donc un import interne.

/// La racine de toute erreur applicative nommée.
sealed class AppException implements Exception {
  const AppException(this.message, {this.cause});

  /// **Développeur, jamais utilisateur.** L'UI ne l'affiche pas : elle mappe le
  /// *type* vers un message localisé (`13-error-handling.md` règle 5, B28).
  final String message;

  /// L'erreur primitive d'origine, pour le diagnostic sur l'appareil.
  ///
  /// C'est ici que vit le `DioException`. `B29` interdit de le transmettre, donc
  /// personne ne le fait : il est porté, jamais envoyé.
  final Object? cause;

  @override
  String toString() => '$runtimeType: $message';
}

/// Échec réseau — timeouts, DNS, TLS, 5xx, socket.
final class NetworkException extends AppException {
  const NetworkException(super.message, {super.cause, this.host, this.status});

  /// Le nom d'hôte, jamais un chemin ni une requête. `C5` / `17-security.md`
  /// règle 1 : une cause qui traverse une couche d'erreur ne transporte pas une
  /// URL, donc jamais la chaîne que le lecteur a tapée.
  final String? host;

  /// `null` quand aucune réponse n'est arrivée.
  final int? status;
}

/// Annulation par le lecteur. `13-error-handling.md` règle 7 : l'appelant
/// distingue « annulé » de « échoué » et **n'affiche pas d'erreur**.
final class CancelledException extends AppException {
  const CancelledException({super.cause})
      : super('the request was cancelled by the reader');
}
```

```dart
// lib/core/network/source_endpoint.dart
//
// Règle 2 de `03-source-system.md`, appliquée une fois pour toutes.

/// L'aboutissement réseau d'**une** source : sa `baseUrl` et son `versionId`.
///
/// `versionId` n'appartient pas à cette classe et n'est pas lu ici : il est lu par
/// `03-source-system.md` règle 1 pour **calculer l'id** de la source. Cette
/// fondation n'a donc aucun accès à `versionId`, et c'est correct — si elle en
/// avait, elle pourrait réécrire une identité.
final class SourceEndpoint {
  const SourceEndpoint({required this.baseUrl});

  /// Sans barre oblique finale. Une assertion le vérifie au construction (§ 3.1).
  final String baseUrl;

  /// `https://www.fanmtl.com` + `/novel/ke383028.html`.
  ///
  /// La jointure se fait **ici**, avec `Uri`, jamais par interpolation de chaîne :
  /// un chemin de site est une entrée non fiable (`17-security.md` règle 1) et une
  /// interpolation laisserait passer un `//evil.example` en `path`.
  Uri resolve(String relativePath, {Map<String, String>? query}) {
    final base = Uri.parse(baseUrl.endsWith('/')
        ? baseUrl.substring(0, baseUrl.length - 1)
        : baseUrl);
    return base.replace(
      path: '${base.path}$relativePath',
      queryParameters: (query == null || query.isEmpty) ? null : query,
    );
  }

  /// Le nom d'hôte seul, pour le limiteur et pour `NoConnection.host`.
  ///
  /// `Uri.host` est déjà le nom d'hôte : jamais `Uri.toString()`, jamais
  /// `Uri.path`. C'est ce qui garantit qu'aucune cause ne peut transporter une
  /// requête de lecteur.
  String get host => Uri.parse(baseUrl).host;
}
```

### 2.3 Contrats API

**Aucun appel sortant ne part d'ici.** Cette fondation ne connaît aucun site. Le
seul contrat qu'elle promet à l'extérieur est déjà écrit en § 2.2 : `HttpClient`,
et l'exception typée qu'elle peut laisser remonter.

Ce qui est promis, en une phrase : *une `baseUrl` relative, un `User-Agent`
honnête, un délai minimum entre deux requêtes vers le même hôte, un `Retry-After`
respecté, et jamais un `DioException`.*

```dart
// Signatures seules — ce que `2-1` et `6-1` consomment.
Future<HttpResponse> get(String relativePath, {Map<String, String>? query});
Uri resolve(String relativePath);
String setUrlWithoutDomain(Uri absolute);
```

### 2.4 Les valeurs qu'aucun document ne fixe, déclarées ici

Trois nombres manquent dans tous les documents du projet. Un implémentateur ne
doit pas les inventer dans son fichier : ils sont dans une seule classe, et les
changer ne demande qu'une ligne.

```dart
// lib/core/network/http_policy.dart
//
// Les trois valeurs qu'aucun document ne fixe. Elles sont regroupées ici parce
// que « où est le délai minimum entre deux requêtes » est une question à une
// réponse, et que deux réponses seraient deuxclidean politiques de politesse.

final class HttpPolicy {
  const HttpPolicy._();

  /// C7 — l'intervalle minimum entre deux **débuts** de requêtes vers le même
  /// hôte. `17-security.md` règle 6 dit « rate limit and back off » sans donner
  /// de chiffre ; `architecture.md` § 2.3 dit « enforced in one place ». Une
  /// seconde est l'unité qui rend « on arrête de marteler le site » vérifiable
  /// dans un test, et le test est la seule preuve qu'un délai existe.
  static const Duration minIntervalPerHost = Duration(seconds: 1);

  /// La durée d'attente appliquée quand un `429` (ou un `503`) arrive **sans**
  /// en-tête `Retry-After`. Un `Retry-After` est honoré quand il est
  /// présent et lisible ; quand il est absent, on ne devine pas zéro, on applique
  /// cette valeur et on le dit.
  static const Duration fallbackRetryAfter = Duration(seconds: 30);

  /// Plafond du `Retry-After` accepté. Un site qui répond `Retry-After: 86400`
  /// ne peut pas bloquer l'application jusqu'au lendemain : la valeur est
  /// ramenée à ce plafond, et `source-unavailable.md` § 5 compte à rebours sur
  /// **60 secondes**, ce qui reste le maximum que l'écran affiche.
  static const Duration maxRetryAfter = Duration(minutes: 10);

  /// `17-security.md` règle 3 — plafond de taille d'un corps-HTML lu en mémoire.
  /// Une source qui renvoie un « chapitre » de 500 Mo est un bug ou une attaque.
  ///
  /// Ce plafond est **transport**, pas persistance : il protège la mémoire. Le
  /// plafond de persistance est celui de `2-3` / `5-1` (`07-downloads-offline.md`)
  /// et il est distinct.
  static const int maxBodyBytes = 4 * 1024 * 1024;
}

/// Les trois délais. `17-security.md` — « Does any new network call lack a
/// timeout, a User-Agent, or rate limiting? » — est une question de revue, donc
/// les trois réponses sont dans une seule constante nommée.
final class HttpTimeouts {
  const HttpTimeouts._();

  /// Connexion + TLS + requête. Dix secondes : au-delà, le téléphone est dans un
  /// tunnel ou le site est mort, et les deux se disent « pas de connexion ».
  static const Duration connect = Duration(seconds: 10);

  /// Envoi de la requête. Un GET sans corps : la même valeur que [connect].
  static const Duration send = Duration(seconds: 10);

  /// Réception de la réponse. Vingt secondes : une page de catalogue met
  /// légitimement plus de dix secondes à descendre, et tuer une lecture parce que le serveur est lent
  /// produirait un `NoConnection` qui n'en est pas un.
  static const Duration receive = Duration(seconds: 20);
}
```

---

## 3. Algorithmes critiques

### 3.1 Construction du client (couvre **C7**, et les règles 5 et 7 de `17-security.md**)

```
HttpClient build(SourceEndpoint endpoint, {required String appVersion}):
  assert(!endpoint.baseUrl.endsWith('/'))
      # 03-source-system.md règle 2. Une assertion, pas un runtime throw : une
      # baseUrl avec barre finale produit `https://host//novel/x.html`, qui est
      # un 404 silencieux sur certains sites.

  dio = Dio(BaseOptions(
      baseUrl:        endpoint.baseUrl,
      userAgent:      userAgent(appVersion),
      connectTimeout: HttpTimeouts.connect,
      sendTimeout:    HttpTimeouts.send,
      receiveTimeout: HttpTimeouts.receive,

      # ── Un 4xx/5xx est une RÉPONSE, pas une exception dio ──────────────
      validateStatus: (s) => s >= 200 && s < 300,
      #   Ce choix est ce qui rend § 3.4 possible : sans lui, dio avale le corps
      #   d'un 429 et ne le livre qu'en `DioExceptionType.badResponse`. Avec lui,
      #   tout statut non-2xx arrive au mapper avec SON CORPS, ce qui est
      #   nécessaire pour lire `Retry-After` et pour distinguer un 404 « not
      #   found » d'une page de refus.

      # ── TLS only (règle 7). Rien ici n'est configuré, et c'est le but :
      #   aucun `badCertificateCallback`, aucune validation désactivée. Un test
      #  grep le fichier et échoue si le mot apparaît.

      followRedirects: true,
      maxRedirects:    5,
  ))

  dio.httpClientAdapter = <non touché>   # aucune référence à webview, à un proxy,
                                          # à un_certificate, à un trust-all
  dio.interceptors.add(QueuedInterceptorsWrapper(
      onRequest: (options, handler) async {
        # ── C7 : l'unique porte d'entrée réseau de l'application ──────────
        await rateLimiter.acquire(endpoint.host);
        handler.next(options);
      },
  ))

  return SourceHttpClient(dio, endpoint, rateLimiter)

userAgent(appVersion):
  # 17-security.md règle 5 / architecture.md § 5.3 : LumenTale/<version>
  # (personal reader). Jamais `Mozilla/5.0`, jamais `Chrome/`, jamais
  # `Safari/`. ADR-014 : l'usurpation est mesurée, elle fait 403 là où l'honnêteté
  # fait 200.
  return 'LumenTale/${appVersion.isEmpty ? "unknown" : appVersion} (personal reader)'

  # ⚠️ La version arrive en PARAMÈTRE, pas par une deuxième lecture de
  # String.fromEnvironment. `3-5` lit `kBuildName` dans
  # `lib/core/app/app_version.dart` ; si cette fondation lisait le même
  # --dart-define, il y aurait deux lecteurs d'une constante de compilation dans
  # deux répertoires, et http-client (vague 0) dépendrait alors d'un fichier écrit
  # par 3-5 (vague 1). Un paramètre supprime l'ordre de dépendance.
```

### 3.2 Le limiteur par hôte (couvre **C7**)

```
rateLimiter.acquire(host):
  # ──état par hôte, jamais global ────────────────────────────────────────
  # B23 : deux sites ne doivent rien partager. Un limiteur global serait un
  # limiteur où la lenteur d'un site retarde un autre site — et, pire, un état
  # partagé entre deux sources, ce que `failure-discriminator` § 3.6 interdit
  # explicitement.

  state = slots[host] ??= SlotState(lastStart: null, blockedUntil: null)

  # ── branche 1 : le site a demandé un arrêt (429 + Retry-After) ──────────
  now = clock()
  if state.blockedUntil != null:
      wait = state.blockedUntil.difference(now)
      if wait > 0:
          await sleep(wait)                       # C7 : on attend, on ne martèle pas
          # ⚠️ On NE SUPPRIME PAS l'attente après le sleep : une requête annulée
          # pendant le sleep ne doit pas pouvoir repartir immédiatement.
      else:
          state.blockedUntil = null                # la fenêtre est passée

  # ── branche 2 : l'intervalle minimum ──────────────────────────────────
  if state.lastStart != null:
      elapsed = now.difference(state.lastStart!)
      remaining = HttpPolicy.minIntervalPerHost - elapsed
      if remaining > 0:
          await sleep(remaining)

  state.lastStart = clock()          # posé AU DÉBUT de la requête, pas à la fin
                                      # : c'est la période entre deux ENVOIS
                                      # qu'un site mesure, pas la durée
                                      # du service
```

| Situation | Ce qui se passe | Pourquoi c'est correct |
|---|---|---|
| Deux requêtes vers le même hôte, 10 ms d'écart | la seconde attend ~990 ms | C7 : l'intervalle existe et il est mesurable |
| Deux requêtes vers **deux hôtes différents** | aucune attente croisée | B23 : aucun état partagé entre deux sites |
| Un `429` avec `Retry-After: 120` | `blockedUntil = now + 120s` | règle 6 : `Retry-After` est honoré, jamais deviné |
| Un `429` **sans** `Retry-After` | `blockedUntil = now + HttpPolicy.fallbackRetryAfter` | « pas d'en-tête » n'est pas « zéro » |
| `Retry-After: 86400` | ramené à `HttpPolicy.maxRetryAfter` | un site ne verrouille pas l'application |
| Le lecteur annule pendant le `sleep` | `CancelledException`, `blockedUntil` **conservé** | une annulation n'est pas une permission de repartir |
| Le même hôte est demandé par deux livres simultanés | sérialisés par `QueuedInterceptorsWrapper` | l'ordre des intercepteurs de dio est FIFO ; aucune requête ne dépasse une autre |

### 3.3 `Retry-After` : les deux formats, et le piège du format ignoré

```
parseRetryAfter(headerValue, now):
  # HTTP dit deux choses par cet en-tête, et le piège est de n'en lire qu'une.

  # ── format 1 : delta-seconds ───────────────────────────────────────────
  #   `Retry-After: 120`     →  120 secondes
  if headerValue != null && headerValue is all-digits:
      seconds = int.parse(headerValue)
      return clamp(Duration(seconds: seconds))

  # ── format 2 : une date HTTP ───────────────────────────────────────────
  #   `Retry-After: Wed, 21 Oct 2026 07:28:00 GMT`
  # ⚠️ Ce format EXISTE et une implémentation qui n'en lit qu'un seul produit
  #    un délai arbitraire. Parse avec `HttpDate.parse`, qui est dans `dart:io`.
  if headerValue != null:
      try:
          at = HttpDate.parse(headerValue)      # dart:io, RFC 7231
          delta = at.difference(now)
          return clamp(delta.isNegative ? Duration.zero : delta)
      on FormatException:
          pass

  # ── branche 3 : absent ou illisible ────────────────────────────────────
  # On n'invente pas. On applique la valeur de repli, et la preuve affichée à
  # l'écran dira que le site n'a rien indiqué.
  return HttpPolicy.fallbackRetryAfter

clamp(d):
  # ⚠️ Un delta NÉGATIF (une date déjà passée) est un délai ZÉRO, pas un délai
  #    négatif. `sleep(negative)` est une erreur et `Future.delayed` avec une
  #    durée négative est un délai nul silencieux : les deux font « le site a
  #    demandé d'arrêter » disparaître en moins d'une seconde.
  return min(d, HttpPolicy.maxRetryAfter)
```

### 3.4 Le mapping de **chaque** type d'exception de dio (les neuf bras)

C'est le cœur de cette fondation : `conventions.md` § Erreurs réseau — *catch the
primitive, rethrow a typed one carrying `cause`* — et `13-error-handling.md` règle 2.
Les **dix** `DioExceptionType` de dio 5.11.1 sont écrits un par un, sans « et
quelques autres ».

```
get(relativePath, query):

  # ── AVANT toute chose : la résolution d'URL, qui ne peut pas échouer ─────
  uri = endpoint.resolve(relativePath, query)

  try:
      response = await dio.get<List<int>>(
        uri.toString(),
        options: Options(
          responseType: ResponseType.bytes,   # le décodage est à nous (§ 3.5)
          headers: {'Accept-Encoding': 'gzip'},
        ),
      )

      # ── branche 1 : la réponse est arrivée ─────────────────────────────
      return HttpResponse(
        outcome:     FetchSucceeded(status: response.statusCode!),
        status:      response.statusCode!,
        body:        decodeBody(response.data, contentTypeOf(response), limit: HttpPolicy.maxBodyBytes),
        contentType: contentTypeOf(response),
      )

  # ═══ les dix bras de DioExceptionType ═══════════════════════════════════

  on DioException catch (e, st):
      host = endpoint.host

      switch e.type:

        # ── 1 ──────────────────────────────────────────────────────────────
        case connectionTimeout:
          # Le site n'a pas répondu à l'établissement de la connexion.
          # E5 : « pas de connexion » est une CAUSE, pas une page vide.
          → HttpResponse(FetchTransportFailed(host), status: 0, body: '', …)
            cause: NetworkException(host: host, cause: e)

        # ── 2 ──────────────────────────────────────────────────────────────
        case sendTimeout:
          # Même classe, même écran, même action : le téléphone n'a pas de
          # connexion exploitable. Les fusionner en un seul bras serait correct ;
          # les écrire séparément dit pourquoi le mapping est exhaustif.
          → HttpResponse(FetchTransportFailed(host), status: 0, …)
            cause: NetworkException(host: host, cause: e)

        # ── 3 ──────────────────────────────────────────────────────────────
        case receiveTimeout:
          # La connexion s'est ouverte et le site n'a rien renvoyé à temps.
          # MÊME issue que 1 et 2 : l'écran ne peut pas distinguer ces trois,
          # donc il ne doit pas prétendre le faire.
          → HttpResponse(FetchTransportFailed(host), status: 0, …)
            cause: NetworkException(host: host, cause: e)

        # ── 4 ──────────────────────────────────────────────────────────────
        case transformTimeout:
          # La réponse est arrivée mais n'a pas pu être transformée. Le transport
          # ne peut pas savoir si c'est un délai ou un défaut de décodeur : il dit
          # la seule chose vraie, « je n'ai pas obtenu de contenu exploitable ».
          → HttpResponse(FetchTransportFailed(host), status: 0, …)
            cause: NetworkException(host: host, cause: e)

        # ── 5 ──────────────────────────────────────────────────────────────
        case badCertificate:
          # 17-security.md règle 7 : TLS seulement. Un certificat invalide n'est
          # PAS une panne de réseau et ne doit jamais être rejoué, ni contourné,
          # ni « corrigé » par un badCertificateCallback.
          → HttpResponse(FetchTransportFailed(host), status: 0, …)
            cause: NetworkException(message: 'TLS certificate rejected', host: host, cause: e)
          # ⚠️ La cause ne devient PAS `SourceUnavailable(status: 0)` : un
          #    certificat rejeté est un problème de poste, et l'écran doit le dire
          #    dans les mots de C12.

        # ── 6 ──────────────────────────────────────────────────────────────
        case badResponse:
          # Ici la seule exception est levée, et c'est PARCE QUE validateStatus
          # rejette tout non-2xx (§ 3.1). Le statut est donc disponible.
          status = e.response?.statusCode ?? 0
          retryAfterHeader = headerOf(e.response, 'retry-after')

          # 6a. 429, ou tout statut porteur d'un Retry-After → C7 / règle 6
          if status == 429 or retryAfterHeader != null:
              wait = parseRetryAfter(retryAfterHeader, now: clock())
              rateLimiter.block(host, until: now().add(wait))     # § 3.2 branche 1
              → HttpResponse(
                  FetchRateLimited(retryAfter: wait, status: status),
                  status: status, body: bodyOf(e.response), contentType: …)
                cause: NetworkException(status: status, cause: e)

          # 6b. tout autre non-2xx → ce n'est PAS une erreur de transport.
          #     `failure-discriminator` § 2.2 l'a dit : « A 4xx or 5xx is NOT a
          #     distinct case here: it arrives as FetchSucceeded with its status,
          #     and the classifieur decides ». Le client NE DÉCIDE PAS si un 404
          #     est un roman retiré et si un 503 est un site occupé.
          → HttpResponse(
              FetchSucceeded(status: status),
              status: status, body: bodyOf(e.response), contentType: …)
            cause: NetworkException(status: status, cause: e)

        # ── 7 ──────────────────────────────────────────────────────────────
        case cancel:
          # 13-error-handling.md règle 7. ⚠️ C'est le seul bras qui REMONTE :
          #     il ne produit pas de FetchResult. Une annulation transformée en
          #     `FetchTransportFailed` afficherait « aucune connexion » à un
          #     lecteur qui vient d'appuyer sur « annuler », ce qui est la pire
          #     des trois réponses possibles.
          throw CancelledException(cause: e)

        # ── 8 ──────────────────────────────────────────────────────────────
        case connectionError:
          # SocketException, DNS, réseau de l'appareil. E5, textuellement.
          → HttpResponse(FetchTransportFailed(host), status: 0, …)
            cause: NetworkException(host: host, cause: e)

        # ── 9 ──────────────────────────────────────────────────────────────
        case unknown:
          # Le seul cas que dio ne sait pas nommer. Il est traité comme un échec
          # de transport — PAS comme un succès et PAS comme une page vide — et il
          # remonte son `cause` pour que le propriétaire puisse le lire.
          → HttpResponse(FetchTransportFailed(host), status: 0, …)
            cause: NetworkException(host: host, cause: e)

        # ── le neuvième et dernier membre de l'enum ─────────────────────────
        # `DioExceptionType` a exactement neuf membres dans dio 5.11.1 :
        #  connectionTimeout, sendTimeout, receiveTimeout, transformTimeout,
        #  badCertificate, badResponse, cancel, connectionError, unknown.
        #  Le compilateur fait le dixième contrôle : ajouter un membre à l'enum
        #  casse ce switch à la compilation. Il n'y a donc pas de `default:` —
        #  un `default` rendrait le fichier tolérant à une erreur d'inventaire,
        #  ce qui est exactement le défaut qu'un mapping exhaustif doit attraper.)

  # ── le cas qui n'est pas un DioException ────────────────────────────────
  on Exception catch (e, st):
      # Un décodeur, un transformateur ou `Uri.parse` peut lever autre chose.
      # 13-error-handling.md règle 1 : jamais une `Exception` nue qui sort.
      → HttpResponse(FetchTransportFailed(endpoint.host), status: 0, …)
        cause: NetworkException(host: endpoint.host, cause: e)

  on Object catch (e, st):
      # FileSystemException, StackOverflowError, OutOfMemoryError. Même règle :
      # rien de nu ne franchit cette frontière.
      → HttpResponse(FetchTransportFailed(endpoint.host), status: 0, …)
        cause: NetworkException(host: endpoint.host, cause: e)
```

**Le tableau des dix bras, en une ligne chacun :**

| # | `DioExceptionType` | Issue produite | `status` | Remonté en exception ? |
|---|---|---|---|---|
| 1 | `connectionTimeout` | `FetchTransportFailed(host)` | 0 | non |
| 2 | `sendTimeout` | `FetchTransportFailed(host)` | 0 | non |
| 3 | `receiveTimeout` | `FetchTransportFailed(host)` | 0 | non |
| 4 | `transformTimeout` | `FetchTransportFailed(host)` | 0 | non |
| 5 | `badCertificate` | `FetchTransportFailed(host)` | 0 | non |
| 6a | `badResponse` + `429` / `Retry-After` | `FetchRateLimited(retryAfter, status)` | réel | non |
| 6b | `badResponse`, autre non-2xx | **`FetchSucceeded(status)`** | réel | non |
| 7 | `cancel` | — | — | **`CancelledException`** |
| 8 | `connectionError` | `FetchTransportFailed(host)` | 0 | non |
| 9 | `unknown` | `FetchTransportFailed(host)` | 0 | non |
| + | tout `Exception` / `Object` non-dio | `FetchTransportFailed(host)` | 0 | non |

### 3.5 Le décodage, et pourquoi ce n'est pas le travail de dio

```
decodeBody(bytes, contentType, limit):
  # 17-security.md règle 3 : un plafond, sinon le site gagne.
  if bytes.length > limit:
      # → NetworkException. Le corps n'est PAS tronqué : un corps tronqué est un
      #   HTML malformé qui « se parse » et produit zéro élément attendu, ce qui
      #   serait rapporté comme SourceLayoutChanged — un diagnostic FAUX pour un
      #   problème de taille. § 3.4 : c'est un échec de transport.
      throw NetworkException('body exceeds the transport ceiling')

  # 04-html-to-markdown.md règle 5 : le charset vient de la RÉPONSE, jamais d'un
  # ASCII supposé. Un chapitre en latin-1 décodé en UTF-8 donne des « Ã© » dans le
  # texte du lecteur, et E18 compte des caractères — donc un page mal décodée peut
  # franchir le seuil de 100 caractères du mauvais côté.
  charset = charsetFrom(contentType) ?? charsetFromMetaTag(bytes) ?? utf8
  return decodeWith(charset, bytes)   # utf8, latin1 ou celui de l'en-tête
```

> `decodeBody` est **volontairement** dans `core/network` et pas dans chaque
> source : `2-1` et `6-1` ont besoin de la même règle, et deux implémentations
> du charset seraient deux réponses à « qu'est-ce qu'un caractère ? ». Le
> `parseDocument` de `package:html`, lui, reste du ressort de la source
> (`2-1` § 2.3) — c'est du DOM, pas du transport.

### 3.6 **Aucune** politique de réessai, et c'est une décision (couvre **C7**)

```
# Ce que ce fichier ne contient PAS, et pourquoi c'est un choix plutôt qu'un oubli :

retry() sur DioExceptionType                     → ABSENT
onError qui rejoue la requête                     → ABSENT
retry sur connexion revenue                       → ABSENT
backoff exponentiel                              → ABSENT

# 03-source-system.md : « Mihon deprecated its equivalent ... so keep this thin:
# selectors + mappers only, no hidden request building, no implicit retry policy ».
# architecture.md § 2.3 : « Mihon deprecated its equivalent helper for hiding
# behaviour; a retry is a *decision* and belongs to the caller that can justify it ».
# source-unavailable.md § 5 : « Automatic retry — Does not exist. No timed retry,
# no retry on app open, no retry on reconnect, no background check. Ever ».

# ⚠️ Le limiteur (§ 3.2) N'EST PAS un réessai. Il espace des requêtes que le
#    LECTEUR a demandées. La différence est totale : le limiteur modifie QUAND
#    une requête part, jamais SI elle part.
```

### 3.7 Ce que cette fondation ne fait pas

```
NE FAIT PAS                                POURQUOI
────────────                                ────────
aucune réessai                              § 3.6
aucun journalisation                        B29 : « no diagnostics, no crash
                                             reports ». Un `logger` dans
                                             `core/network` créerait le seul
                                             endroit du produit d'où une donnée
                                             pourrait sortir
aucun cookieJar                             17-security.md règle 8 ; et
                                             B4 : aucun compte, aucune identité
aucune en-tête Authorization                idem — un lecteur est un client anonyme
aucun cache de réponse                      C7 : « minimal requests ». Un cache
                                             HTTP de l'application serait aussi
                                             une deuxième source de vérité sur
                                             « ce que le site a dit »
aucune horloge murale callsite              testabilité : `clock()` est injecté
aucune écriture disque, aucune base          § 2.1
aucune référence à un site                   § 3.1 : `baseUrl` vient de la source
aucun sélecteur, aucun HTML                 17-security.md règle 4 : le transport ne
                                             sait pas ce qu'il cherche
aucune dépendance à `domain/`               02-architecture.md : `core` n'importe
                                             que des paquets externes
```

---

## 4. Plan composants

### 4.1 Arbre de composants

```
Aucun composant d'interface. Cette fondation produit cinq fichiers Dart purs et
leurs tests. Le premier écran à les consommer est `3-1`
(`/browse/:sourceId/unavailable`, dont la ligne de preuve est le `status` et
l'`host` de ces types).

HttpClient (interface Dart)                    lib/core/network/http_client.dart
└── SourceHttpClient                          lib/core/network/source_http_client.dart
    ├── Dio                                    une instance, injectée
    ├── SourceEndpoint                         baseUrl de CETTE source
    ├── HostRateLimiter                        un état par hôte
    ├── HttpTimeouts · HttpPolicy              les valeurs de § 2.4
    └── _mapper(DioException)                  § 3.4, les dix bras

HttpResponse                                  lib/core/network/http_response.dart
FetchResult (3 cas)                           lib/core/network/fetch_result.dart
                                              ⚠️ DÉFINI ICI — vague 0. C'est le
                                              PLAN QUI L'ÉCRIT, parce que
                                              failure-discriminator est vague 2
                                              et l'a en dépendance (§ 7 q. 2)
SourceEndpoint                                lib/core/network/source_endpoint.dart
HostRateLimiter                               lib/core/network/host_rate_limiter.dart
HttpPolicy · HttpTimeouts                     lib/core/network/http_policy.dart
AppException · NetworkException               lib/core/error/app_exception.dart
└── CancelledException
```

### 4.2 Composants

| Composant | Type | Fichier cible | Props | State | Événements |
|---|---|---|---|---|---|
| `HttpClient` | interface Dart | `lib/core/network/http_client.dart` | — | — | — |
| `SourceHttpClient` | `final class` | idem | `Dio`, `SourceEndpoint`, `HostRateLimiter`, `DateTime Function()` | **par hôte, dans le limiteur** | `get` · `resolve` |
| `setUrlWithoutDomain` | fonction top-level | idem | — | aucun | — |
| `HttpResponse` | valeur immuable | `lib/core/network/http_response.dart` | 4 champs nommés | aucun | — |
| `FetchResult` + 3 | hiérarchie `sealed` — **propriété de cette fondation** | `lib/core/network/fetch_result.dart` | — | aucun | — |
| `SourceEndpoint` | valeur immuable | `lib/core/network/source_endpoint.dart` | `baseUrl` | aucun | `resolve` · `host` |
| `HostRateLimiter` | `final class` | `lib/core/network/host_rate_limiter.dart` | `Duration Function()` (attente), `DateTime Function()` | `Map<String, SlotState>`, **jamais global** | `acquire` · `block` · `slot` |
| `HttpPolicy` · `HttpTimeouts` | classes de constantes | `lib/core/network/http_policy.dart` | — | aucun | — |
| `AppException` + 2 | hiérarchie `sealed` | `lib/core/error/app_exception.dart` | `message`, `cause` | aucun | — |

**Riverpod** (`05-state-management.md`) : cette fondation **ne déclare aucun
provider**, et c'est délibéré. Un limiteur est un état **modifiable partagé par
toutes les sources**, donc c'est exactement le cas où la règle 10 demande
`keepAlive` — mais la règle 7 demande d'« préférer des overrides explicites aux
singletons globaux », et le limiteur doit être **unique dans l'application**, pas
unique par écran.

**Décision** : `0-5` déclare l'unique provider, dans le bootstrap où il construit
ses enfants, et toutes les sources le reçoivent par le `SourceManager` :

```dart
// Déclaré par 0-5, PAS par cette fondation. Écrit ici pour fixer le nom et la
// portée, parce qu'un limiteur construit deux fois est deux politiques de
// politesse, et que C7 se respecte à un seul endroit.
final hostRateLimiterProvider =
    Provider<HostRateLimiter>((Ref ref) => HostRateLimiter(clock: DateTime.now));
```

### 4.3 États par écran

**Aucun.** Aucun écran n'est produit ni modifié. `source-unavailable.md` — l'écran
qui rend ces causes — appartient entièrement à `3-6`, et
`settings-about.md` à `3-5`.

Ce que cette fondation **fournit** aux écrans, et rien de plus :

| Ce qu'un écran lit | Où il vient |
|---|---|
| la ligne de preuve `HTTP {status}` | `HttpResponse.status` |
| la ligne de preuve `aucune connexion à {host}` | `FetchTransportFailed.host` |
| « De nouveau disponible dans {mm:ss} » | `FetchRateLimited.retryAfter` |
| « Ce site n'a pas pu être lu » | `FetchTransportFailed` → `NoConnection` → `BrowseFailed` |

### 4.4 Formulaires

Aucun. Aucun champ, aucun bouton, aucune permission. Cette fondation ne demande
**jamais** de permission réseau : Android n'en a pas pour un `GET` en clair, et
une demande de permission sur un écran d'échec serait le pire endroit du produit
pour la poser.

---

## 5. Gestion d'état (state management)

| Donnée | Portée | Stockage | Initialisation | Mise à jour |
|---|---|---|---|---|
| Instance `dio` par source | application | une par `SourceEndpoint`, tenue par le `SourceManager` | au démarrage (`0-5`) | jamais |
| Slot par hôte (`lastStart`, `blockedUntil`) | application | `Map<String, SlotState>` **dans le limiteur** | à la première requête vers cet hôte | `acquire` · `block` |
| `blockedUntil` | hôte | le même slot | sur un 429 ou un `Retry-After` | à l'expiration de la fenêtre |
| Corps d'une réponse | appel | `String` en mémoire, **jamais persisté par cette fondation** | `get()` | jamais |

**Ce qui n'est délibérément pas de l'état** :

- **Un cache de réponses.** `C7` dit *minimal requests* ; un cache serait une
  deuxième source de vérité sur ce que le site a dit, et B23 exige qu'une panne
  d'un site ne change rien pour les autres.
- **Une liste d'historique d'échecs.** `sources.last_error_code` est le lieu de
  cette vérité (`architecture.md` § 4.6) ; un historique en mémoire serait un
  second endroit où une cause pourrait s'accumuler.
- **Une horloge propre.** `DateTime.now` est **injecté** dans le limiteur. La
  raison n'est pas la pureté : c'est que `Retry-After` et `blockedUntil` sont des
  durées, et une durée testable est une durée qu'un test peut avancer sans
  attendre.

---

## 6. Traçabilité des règles

### 6.1 Règles métier (B*)

| ID | Règle (PRD) | Implémentée où | Approche |
|---|---|---|---|
| **B29** | No user data leaves the device: no library, no reading progress, no history, no diagnostics, no analytics, no crash reports, no telemetry of any kind. | § 3.7, § 4.1, § 5 | **Aucun `print`, aucun `debugPrint`, aucun `logger`, aucun client d'analytics, aucun `Crashlytics` — dans `lib/core/network/`.** Un test fait `grep -rn "print(\|debugPrint(\|logger\|analytics\|crash" lib/core/network` et exige **zéro** résultat. Le `DioException` d'origine est porté comme `cause` d'une `NetworkException` pour le propriétaire, jamais transmis. `HttpResponse` ne contient **que** `status`, `body` et `content-type` : aucune clé, aucun identifiant, aucun en-tête de session, donc il n'y a rien à transmettre par accident |
| **B22** | When a site cannot be read the app states that it could not read it, and never presents an empty list as an answer. | § 3.4 bras 6b | **Le transport ne décide pas si un site est cassé, et ne peut pas le faire.** Un `404`, un `429` et un `503` arrivent tous en `FetchSucceeded(status)` — sauf le `429`, qui devient `FetchRateLimited` — et c'est `failure-discriminator` qui décide. C'est sa troisième colonne : le client qui classerait lui-même les statuts mettrait la taxonomie de B22 en deux endroits |

### 6.2 Contraintes (C*)

| ID | Contrainte (PRD) | Comment elle est respectée |
|---|---|---|
| **C7** | Source reliability — sites change their pages without warning and can stop working overnight. The app silently returning nothing is the main failure mode to avoid (B22, E4). | **Un seul limiteur, un seul endroit, une seule horloge.** `HostRateLimiter` espace les requêtes d'un même hôte de `HttpPolicy.minIntervalPerHost`, et un `429` ou un `Retry-After` ouvre une fenêtre pendant laquelle toute requête vers cet hôte attend. Le `Retry-After` est lu dans ses **deux** formats (§ 3.3) et **plafonné** à `maxRetryAfter` pour qu'un site ne verrouille pas l'application. La politesse est mesurable : `acquire` est le point d'injection de l'attente, donc le test avance une horloge factice et affirme que la seconde requête a bien attendu. **Aucun réessai automatique n'existe** (§ 3.6) : le limiteur modifie *quand* une requête part, jamais *si* elle part |
| **C2** | Privacy — no account, no server, no telemetry of any kind. Reading data never leaves the phone (B4, B29). | Aucun compte, aucun jeton, aucun `cookieJar`, aucun en-tête `Authorization` : un lecteur est un client anonyme et il n'y a rien à authentifier. Le client n'a aucun champ d'identification, donc il ne peut rien transmettre de plus que la page demandée et son User-Agent |
| **C5** | User skill — the only technical user cannot write code. Repairing a site that has changed must be deliverable to them as a new installable file with no manual step on their side (US-17). | `SourceLayoutChanged.failedSelector` est produit en aval par la source, et `HttpResponse.status` est le fait que l'écran écrit. **Cette fondation ne produit aucun texte affichable** : chaque cause qu'elle fabrique porte un fait, jamais une phrase, donc aucun écran ne peut afficher une trace d'exception au lecteur. `NetworkException.message` est explicitement *développeur* (`13-error-handling.md`) |
| **C6** | No server, no support, no telemetry means the app has no way to learn why it failed. Failures must therefore be recognisable on the device and reported there (B24, B22). | Le `DioException` d'origine est **conservé** comme `cause` et `NetworkException.host` / `.status` portent les deux faits que l'écran écrit en clair (`HTTP 429`, `aucune connexion à www.fanmtl.com`). Rien n'est perdu au passage, et rien n'est envoyé : le diagnostic est sur l'appareil, ce qui est exactement ce que C6 demande |
| **C11** | Usage context — reading happens one-handed, on a phone, at night or in transit, frequently with poor or no connectivity (C11 also constrains gestures, text size and error legibility). | Les trois délais existent et sont bornés : au-delà de `receive = 20s`, un lecteur dans un train voit « aucune connexion » au lieu d'attendre. Les trois timeouts sont regroupés dans `HttpTimeouts` précisément pour qu'un seul endroit les change si la mesure dit qu'ils sont trop longs |
| **C12** | Privacy of failure reporting — because a borrowed-device reader cannot send anything back (C2), the app must make its own failure state obvious enough for that reader to describe it to the owner **in words** — a message that can be read aloud and reported back — and actionable, not merely present. | `FetchTransportFailed.host` est un **nom d'hôte** et `FetchRateLimited.retryAfter` une **durée** — jamais une chaîne d'exception. C'est ce qui permet à `source-unavailable.md` § 4.1 d'écrire « Erreur de transport — aucune connexion à {hôte} », une phrase qu'un lecteur peut dicter. `Uri.host` et non `Uri.toString()` : c'est mécanique, et c'est testé |

### 6.3 Edge cases (E*) — aucun attribué, deux traités

`state.json` n'attribue **aucun** `edge_case_id` à `http-client` (une fondation
n'a pas de slice dans `slices`, et `state.json` ne lui donne que des `rule_ids`).
Les deux cas qui touchent le transport sont donc traités **parce qu'ils existent**,
et aucun n'est perdu de vue.

| ID | Cas (PRD) | Où il est traité | Approche |
|---|---|---|---|
| **E5** | No connection while browsing or searching → un message « no connection » avec un réessai ; bibliothèque et chapitres stockés restent utilisables | § 3.4, bras 1, 2, 3, 4, 5, 8, 9 | **Six `DioExceptionType` produisent le même `FetchTransportFailed(host)`**, et c'est délibéré : l'écran ne peut pas distinguer « le téléphone n'a pas de réseau » de « le site ne répond pas dans le délai », donc il ne doit pas prétendre le distinguer. Un seul `status: 0`, un seul `body: ''` — un corps vide présenté comme un corps lu serait le défaut miroir de E8. La branche est testée pour les **six** types, pas pour un seul |
| **C7 / § 5.2** | `RateLimited(retryAfter)` — `17-security.md` règle 6 : `Retry-After` est honoré | § 3.3, § 3.4 bras 6a | Les **deux** formats HTTP sont lus, un `Retry-After` illisible ou absent prend `fallbackRetryAfter`, et la valeur est plafonnée. Un test lit `Retry-After: 120`, `Retry-After: Wed, 21 Oct 2026 07:28:00 GMT`, un en-tête vide et un `Retry-After: -5` — et affirme, pour le dernier, un délai **zéro** et non une durée négative |

---

## 7. Pièges à éviter

- **⚠️ Ne pas mettre une politique de réessai dans l'intercepteur `onError`.**
  Le comportement correct (**C7**, `03-source-system.md`, `source-unavailable.md`
  § 5) est : aucune reprise automatique, jamais. `Mihon` a déprécié son aide
  équivalente parce qu'elle masquait le comportement ; un réessai est une
  **décision**, et elle appartient à l'appelant qui peut la justifier — ici, le
  lecteur, via le bouton `Réessayer` de `3-6`.
- **⚠️ Ne pas transformer une annulation en « pas de connexion ».** Le comportement correct (**C7**, `13-error-handling.md` règle 7) est :
  `DioExceptionType.cancel` remonte une `CancelledException` et **ne produit
  aucun** `FetchResult`. Un lecteur qui vient d'appuyer sur « annuler » et qui lit
  « aucune connexion » vient de recevoir le pire des trois messages possibles.
- **⚠️ Ne pas classer un 4xx/5xx dans le client.** Le comportement correct
  (**B22**) est : `FetchSucceeded(status)` pour tout non-2xx qui n'est pas un
  `429`, et c'est `failure-discriminator` qui décide si un `404` est un roman
  retiré ou un lien mort. Un client qui décide met la taxonomie de B22 en deux
  endroits, et le deuxième ne sera pas mis à jour quand le premier changera.
- **⚠️ Ne pas valider le TLS « pour que ça marche ».** Le comportement correct
  (**C7**, `17-security.md` règle 7) est : aucun `badCertificateCallback`, aucune
  validation désactivée, aucun proxy. Un `badCertificate` est un `NoConnection`
  et **jamais** un contournement — c'est aussi ce qu'ADR-014 décide pour le
  Cloudflare de Novel Fire.
- **⚠️ Ne pas écrire un User-Agent de navigateur.** Le comportement correct
  (**C7**, `17-security.md` règle 5, ADR-014) est
  `LumenTale/<version> (personal reader)`. Mesuré : Novel Fire renvoie **403**
  avec un UA navigateur et **200** avec l'UA honnête. Feindre d'être un
  navigateur est littéralement ce qui déclenche le blocage.
- **⚠️ Ne pas journaliser le corps d'une réponse.** Le comportement correct
  (**B29**, **C2**, `architecture.md` § 5.3) est : **aucun** `logger` dans
  `lib/core/network/`. Le `DioException` voyage comme `cause`, et le texte d'un
  chapitre n'est jamais écrit, à aucun niveau, y compris en debug.
- **⚠️ Ne pas rendre `FetchResult` à la place de `HttpResponse`.** Le
  comportement correct (**B22**, `2-1` § 2.3) est
  `Future<HttpResponse> get(...)` : `FetchResult` est le **discriminant** — ce
  que le transport a fait — et il ne porte aucun corps. Rendre le discriminant
  seul ne laisse à la source ni page à parser ni HTML à rendre, donc
  `ContentProbe` reste `ParseBroke` sur toutes les pages, donc tout devient
  `SourceLayoutChanged`, donc SC-6 devient indiscernable d'un site qui marche.
  C'est pour cela que `FetchResult` reste **sans champ** : lui en ajouter un
  ferait de lui une réponse mal formée au lieu d'un discriminant.
- **⚠️ Ne pas laisser `failure-discriminator` écrire `fetch_result.dart`.** Le
  comportement correct (§ 7 question 2, dépendance `state.json`) est : le vague 0
  écrit le type, le vague 2 l'importe. Un producteur qui écrit le type de son
  consommateur a une dépendance inversée, donc un cycle — et deux réponses à
  « qu'est-ce que le transport a fait ? ».
- **⚠️ Ne pas mettre de `cookieJar`.** Le comportement correct
  (`17-security.md` règle 8, **B4**) est : aucun cookie, aucun jeton, aucune
  identité. Un `cookieJar` persistant est un secret à disque et une identité à
  effacer.
- **⚠️ Ne pas plafonner le corps en le tronquant.** Le comportement correct
  (**C7**, `17-security.md` règle 3) est : lever `NetworkException` et jeter le
  corps. Un corps tronqué est un HTML malformé qui « se parse » et rend zéro
  élément attendu — donc rapporté comme `SourceLayoutChanged`, un diagnostic
  **faux** pour un problème de taille.
- **⚠️ Ne pas lire `Retry-After` comme un nombre de secondes seulement.** Le comportement correct (**C7**, règle 6) est : lire les **deux** formats — delta
  et date HTTP — plafonner à `maxRetryAfter`, et prendre `fallbackRetryAfter` quand
  l'en-tête est absent ou illisible. Un delta négatif est un délai **zéro**, pas
  une durée négative.
- **⚠️ Ne pas partager un état entre deux sources.** Le comportement correct
  (**B23**) est : `HostRateLimiter` tient un slot **par hôte**. Un limiteur
  global ferait qu'un site lent retarde un autre site, et `failure-discriminator`
  § 3.6 interdit explicitement un état partagé entre deux lectures.
- **⚠️ Ne pas lire `--dart-define` dans cette couche pour le User-Agent.** Le comportement correct (**C7**, `B3`) est : `appVersion` est un **paramètre de
  construction**, et c'est `0-5` qui le fournit. Lire la même constante de
  compilation dans deux répertoires créerait une dépendance de la vague 0 vers un
  fichier écrit en vague 1.

**Trois questions qui étaient ouvertes. Les trois sont tranchées, et il faut
écrire par quoi — une question ouverte qu'on laisse en place en prétendant
l'inverse est la forme la plus courante d'un document qui ment.**

1. **`AppException` avait deux chemins dans trois documents — TRANCHÉE :
   `lib/core/error/`.** `13-error-handling.md` écrivait `core/utils/errors/` ;
   `architecture.md` § 1.2 et § 5.2 écrivaient `core/error/`. Les deux sont dans
   la table des couches comme « core », donc ni l'un ni l'autre ne viole
   `02-architecture.md` — mais **un même nom de classe à deux endroits est
   exactement la seconde source de vérité que B22 interdit ailleurs.** Décision :
   `lib/core/error/`, parce que la table des couches de `architecture.md` § 1.2 —
   l'autorité sur les chemins — le nomme, que `failure-discriminator` y a déjà
   écrit `SourceFailure`, et que **`13-error-handling.md` a été corrigé** : il
   écrit désormais `core/error/` et note sur place que le chemin précédent était
   `core/utils/errors/` et pourquoi il a bougé. Une décision qui ne corrige que
   les copies qu'on a sous les yeux laisse les autres ; le fichier corrigé porte
   donc la trace, pour que la prochaine occurrence puisse être reconnue.
2. **`FetchResult` était écrit par le consommateur — TRANCHÉE : c'est cette
   fondation qui l'écrit.** `http-client` est vague 0, `failure-discriminator`
   vague 2, et `state.json` donne
   `failure-discriminator.depends_on = ['0-1','0-2','http-client']` : le
   producteur est censé exister avant le consommateur, donc le **type** doit être
   dans le fichier du producteur. `lib/core/network/fetch_result.dart` est donc
   écrit ici, en § 2.2, avec exactement les trois cas — `FetchSucceeded`,
   `FetchTransportFailed`, `FetchRateLimited` — et `failure-discriminator`
   l'importe sans y ajouter un champ. Il n'y a **pas** d'amendement
   `state.js` à faire : la dépendance déclarée est déjà dans le bon sens, c'est
   l'appartenance du fichier qui était à l'envers. Réponse à « la dépendance
   actuelle suffit-elle ? » : oui, et le graphe n'a pas bougé d'un cran.
3. **`2-1` déclarait `Future<FetchResult> get(String relativePath)` alors que
   `FetchResult` ne porte aucun corps — TRANCHÉE : `2-1` rend un
   `HttpResponse`.** `Source.fetchChapterContent` doit renvoyer du HTML brut
   (`03-source-system.md` règle 11) et `ContentProbe` doit examiner un document
   analysé : ni l'un ni l'autre n'a quelque chose à examiner dans un objet qui
   ne porte qu'un statut. `HttpResponse` (§ 2.2) —
   `outcome` + `status` + `body` + `contentType` — est l'unique endroit où le
   discriminant et le corps voyagent ensemble, et `2-1` a été amendé en
   conséquence : § 2.3 rend `Future<HttpResponse>`, § 3.3 / § 3.7 / § 3.8 font
   `fetch = response.outcome` puis `parseDocument(response.body)`, et § 7 porte
   le piège. **`FetchResult` reste ce que § 2.2 définit ici** et garde ses trois
   cas : il n'a ni perdu son rôle ni gagné un champ.

---

## 8. Dépendances

| Dépend de | Nature | Statut | Fallback si absent |
|---|---|---|---|
| `dio` 5.11.1 | data — le client HTTP | installé | aucun. Sans lui il n'y a pas de réseau, et il n'y a pas de repli : `HttpClient` est une abstraction sur `dio`, pas sur `dart:io` |
| `failure-discriminator` | data — **aucune**. La dépendance est dans l'autre sens | `identified`, vague 2 | **Pas bloquant du tout, et c'est le point.** Cette fondation **possède** `lib/core/network/fetch_result.dart` : `FetchResult`, `FetchSucceeded`, `FetchTransportFailed` et `FetchRateLimited` sont écrits ici, en § 2.2, à la vague **0**. `failure-discriminator` (vague 2) les **importe** et n'y ajoute aucun champ — `state.json` le déclare dans son `depends_on`, ce qui est cohérent : le vague 2 dépend du vague 0. Une dépendance inverse aurait été un cycle. Voir § 7 question 2 |
| `0-5` | data — le bootstrap, `SourceManager`, le provider du limiteur | `identified` | **Le limiteur est instancié par `0-5`**, pas ici. Sans lui, `core/network` est complet et simplement non câblé |
| `apk-pipeline` | data — fournit `LUMEN_BUILD_NAME` par `--dart-define` | `identified` | **Aucun impact sur le fonctionnement.** `appVersion` est un paramètre ; une version vide donne `LumenTale/unknown (personal reader)`, qui nomme toujours l'application honnêtement |
| `package:crypto` | data — non utilisé ici | installé | aucun. `versionId` n'est **pas** lu par cette fondation : il sert à calculer `Source.id`, et `SourceManager` le fait |

**Dépendants** (ne font rien tant que cette fondation n'est pas là) :
`failure-discriminator` (le vocabulaire de transport), `2-1` (FanMTL),
`6-1` (Royal Road), `6-2` (la recherche conditionnelle), `5-1`/`5-2`/`5-3` (la file
de téléchargement, qui passe par `fetchChapterContent`), `6-4` (la vérification
manuelle), `3-1` et `3-6` (les écrans de browse et d'échec).

---

## 9. Checklist de tâches

### Phase 1 — Couche de données

- [ ] Créer `lib/core/error/app_exception.dart` : `AppException` `sealed` + `NetworkException` + `CancelledException` (§ 2.2) — **chemin `lib/core/error/`, tranché en § 7 question 1**
- [ ] Créer `lib/core/network/http_policy.dart` : `HttpPolicy` + `HttpTimeouts` (§ 2.4)
- [ ] Créer `lib/core/network/fetch_result.dart` : `FetchResult` + les **trois** cas, ici et nulle part ailleurs (§ 2.2, § 7 question 2 — cette fondation est le propriétaire, vague 0)
- [ ] Créer `lib/core/network/http_response.dart` : `HttpResponse` (§ 2.2)
- [ ] **Aucun schéma de base.** Aucune migration, `schemaVersion` reste à 1

### Phase 2 — Logique métier

- [ ] Créer `lib/core/network/source_endpoint.dart` : `resolve` + `host` (§ 2.2)
- [ ] Créer `lib/core/network/host_rate_limiter.dart` : `acquire` · `block` · slot **par hôte**, horloge et attente injectées (§ 3.2)
- [ ] `parseRetryAfter` — les **deux** formats, le plafond, le repli (§ 3.3)
- [ ] Créer `lib/core/network/http_client.dart` : `HttpClient`, `SourceHttpClient`, `setUrlWithoutDomain` (§ 2.2)
- [ ] `buildDio` — UA honnête, trois timeouts, `validateStatus`, TLS intact, `QueuedInterceptorsWrapper` branché sur `acquire` (§ 3.1)
- [ ] `_mapDioException` — **les dix bras** de § 3.4, exhaustifs, plus les deux `catch` non-dio
- [ ] `decodeBody` — plafond, charset de la réponse puis meta puis UTF-8 (§ 3.5)
- [ ] **Aucun réessai, aucun journal, aucun cookieJar, aucun cache** (§ 3.6, § 3.7)

### Phase 3 — Interface utilisateur

- [ ] **Aucun.** Cette fondation ne produit aucun widget, et le premier écran qui consomme une `FetchResult` est `3-1`. Ne pas créer de « composant d'erreur réseau » par souci de complétude : `design-system.md` § 2.7 déclare `ErrorState`, et `3-6` l'assemble avec les causes
- [ ] **Ne déclarer aucun provider** : le limiteur est instancié par `0-5` (§ 4.2). Ne pas créer un second limiteur « pour être sûr »

### Phase 4 — Intégration

- [ ] `0-5` déclare `hostRateLimiterProvider` et le passe à `buildSourceRegistry({required HttpClient client})` — **c'est `0-5` qui câble, pas cette slice**
- [ ] Vérifier que `lib/core/network/` **n'importe rien** de `lib/` (`02-architecture.md` : `core` → paquets externes seulement) — y compris pas `core/error`, ce qui est la raison du placement en § 2.2
- [ ] Vérifier que `lib/core/error/` **n'importe rien** de `lib/`
- [ ] Aucun routage, aucune permission, aucun `AndroidManifest`

### Phase 5 — Tests et polish

- [ ] Tests unitaires (§ 11.1) — **les dix bras du mapping**, les deux formats de `Retry-After`, l'intervalle minimal, l'isolation par hôte
- [ ] Test « rien ne sort » : `grep` sur `lib/core/network` (§ 10)
- [ ] Test « pas de TLS désactivé » : `grep` sur `lib/core/network` (§ 10)
- [ ] Aucun test d'interface : il n'y a pas d'interface
- [ ] Aucun test qui atteint le réseau — `10-testing.md` règle 7

### Vérifications finales

- [ ] `dart format .` — propre
- [ ] `flutter analyze` — **zéro** issue, zéro `info`
- [ ] `flutter test` — tout passe
- [ ] `coverage-check.js slice /workspaces/lumen_tale http-client` → **ne vérifie rien pour une fondation** (**F-003**) : la relecture humaine de § 6 est le contrôle réel

---

## 10. Critères d'acceptation

- [ ] **C7** — deux requêtes vers le même hôte à 10 ms d'écart : la seconde attend `minIntervalPerHost - 10ms`, vérifié sur une horloge injectée, sans `sleep` réel dans le test.
- [ ] **C7** — deux requêtes vers **deux hôtes différents** n'attendent pas l'une l'autre : un test l'affirme, parce que c'est la propriété qui distingue un limiteur par site d'un limiteur global.
- [ ] **C7** — un `Retry-After: 120` ouvre une fenêtre de 120 s sur ce hôte et seule ; un `Retry-After` en date HTTP est lu et donne la même durée à ±1 s ; un en-tête absent donne `fallbackRetryAfter` ; `Retry-After: -5` donne **zéro**, pas une durée négative ; `Retry-After: 86400` donne `maxRetryAfter`.
- [ ] **C7** — `DioExceptionType.cancel` remonte `CancelledException` et **ne produit aucun** `HttpResponse`. Le test affirme l'absence de tout `FetchTransportFailed` sur ce bras.
- [ ] **C7** — un `429` produit `FetchRateLimited(retryAfter, status)` avec le **vrai** statut, et l'état du limiteur contient `blockedUntil`.
- [ ] **C7** — un `503` **et** un `404` produisent `FetchSucceeded(status)`, jamais `FetchRateLimited`, jamais `FetchTransportFailed`.
- [ ] **C7** — `grep -rn "onError\|retry\|RetryInterceptor" lib/core/network` ne trouve **aucune** reprise de requête ; une seule occurrence de `dio.retry` est un échec.
- [ ] **C7** — `grep -rni "badCertificateCallback\|validateCertificate\|trustAll\|proxy" lib/core/network` ne renvoie **rien** (`17-security.md` règle 7).
- [ ] **C7** — le `User-Agent` est exactement `LumenTale/<version> (personal reader)` pour une version donnée, et `LumenTale/unknown (personal reader)` pour une version vide ; il **ne contient** ni `Mozilla`, ni `Chrome`, ni `Safari`, ni `Android`, ni `WebKit` (ADR-014).
- [ ] **C7** — `BaseOptions` porte les trois timeouts, et `validateStatus` rejette tout statut hors `[200, 300)`.
- [ ] **B29** — `grep -rn "print(\|debugPrint(\|logger\|analytics\|crash" lib/core/network` ne renvoie **rien**. Un second grep sur `HttpResponse` ne trouve aucun champ nommé `token`, `cookie`, `session`, `deviceId` ou `userId`.
- [ ] **B29** — l'instance `dio` n'a **ni** `cookieJar` **ni** en-tête `Authorization`, et le test le prouve en inspectant l'objet construit.
- [ ] **B22** — les **six** `DioExceptionType` de transport (`connectionTimeout`, `sendTimeout`, `receiveTimeout`, `transformTimeout`, `connectionError`, `unknown`) produisent tous `FetchTransportFailed(host)` avec `status == 0` et `body == ''`, et le test les parcourt en boucle plutôt que d'en écrire six.
- [ ] **B22** — `badCertificate` produit `FetchTransportFailed` et **jamais** `SourceUnavailable(status: 0)`, et la `cause` porte le mot `certificate`.
- [ ] **B22** — aucun `DioException` ne sort de `HttpClient.get` : le test capture `expect(() async => …, throwsA(isNot(isA<DioException>())))` sur les neuf bras.
- [ ] **B22** — un `Exception` et un `Object` non-`DioException` produisent tous deux `FetchTransportFailed`, jamais une exception nue (`13-error-handling.md` règle 1).
- [ ] **B22** — `grep -rn "sealed class FetchResult" lib/` ne renvoie qu'**une** ligne, dans `lib/core/network/fetch_result.dart` : le discriminant a un propriétaire et un seul (§ 7 question 2).
- [ ] **B22** — `HttpClient.get` rend un `HttpResponse`, jamais un `FetchResult` : `grep -rn "Future<FetchResult>" lib/` ne renvoie rien, et `2-1` compile sans modification (§ 7 question 3).
- [ ] **B22 / § 2.2** — `HttpResponse.body` alimente `parseDocument` sur une page réelle : le test passe une `HttpResponse` de `http-client` à `FanMtlSource` et obtient un `ContentProbe` (`test/sources/fanmtl_source_http_test.dart`).
- [ ] **B22** — `FetchRateLimited` ne porte **ni** `host` **ni** `sourceId` : le test l'assert sur le type, parce qu'un `429` appartient à un hôte et que le slot du limiteur est déjà keyed by host (§ 2.2, `architecture.md` § 5.2).
- [ ] **C5** — `AppException` est dans `lib/core/error/` et **nulle part ailleurs** : `grep -rn "class AppException" lib/` ne renvoie qu'une ligne, sous `lib/core/error/`, et `grep -rn "core/utils/errors" lib/` ne renvoie **rien** (§ 7 question 1). Les documents qui citent encore l'ancien chemin sont signalés au rapport de revue — `13-error-handling.md` est corrigé, les autres sont hors du périmètre de cette slice.
- [ ] **C5 / C12** — `NoConnection.host` et `NetworkException.host` sont un nom d'hôte : `Uri.parse(endpoint.baseUrl).host`, jamais `toString()`. Un test l'affirme sur une `baseUrl` avec une porte (`https://www.fanmtl.com:443`) et sur une requête contenant une chaîne (`?q=secret`).
- [ ] **C5** — `SourceEndpoint.baseUrl` sans barre oblique finale résout `/novel/x.html` en `https://www.fanmtl.com/novel/x.html` ; avec une barre finale, l'**assertion** de § 3.1 déclenche.
- [ ] **C11** — `HttpTimeouts` déclare exactement `connect`, `send`, `receive`, toutes positives, et le test les lit depuis la classe plutôt que de répéter les chiffres.
- [ ] **C6** — une réponse au-dessus du plafond lève `NetworkException` et **aucun** corps tronqué ne sort : le test vérifie qu'aucun `HttpResponse` n'est construit dans ce cas.
- [ ] **C12** — une annulation faite pendant l'attente du limiteur laisse `blockedUntil` **inchangé** : le test avance l'horloge, annule, puis vérifie l'état du slot.
- [ ] **B31** — `schemaVersion` reste à 1 et aucune migration n'est produite par cette fondation.
- [ ] **C7** — `lib/core/network/` n'importe **aucun** chemin de `lib/` : un `grep -rn "package:lumen_tale" lib/core/network` ne renvoie que `package:dio` et `package:flutter_test` (dans `test/`, pas dans `lib/`).

---

## 11. Plan de tests

### 11.1 Tests unitaires

Emplacement : `test/core/network/http_client_test.dart`

| Groupe | Test (nom exact) | Scénario | IDs couverts |
|---|---|---|---|
| Construction | `the User-Agent names the app and never a browser` | `appVersion: '1.2.3'` → `LumenTale/1.2.3 (personal reader)`, sans `Mozilla`/`Chrome`/`Safari` | C7, ADR-014 |
| | `an unknown version still names the app` | `appVersion: ''` → `LumenTale/unknown (personal reader)` | C7 |
| | `the three timeouts are declared` | `connect` 10 s, `send` 10 s, `receive` 20 s, tous > 0 | C11 |
| | `a non-2xx status is a response and not an exception` | `validateStatus(404)` est faux, `validateStatus(200)` est vrai | B22 |
| | `the client carries no cookie jar and no authorization` | inspecte l'objet `dio` construit | B29, B4 |
| Limiteur | `a second request to the same host waits` | horloge injectée, deux `acquire` à 10 ms | C7 |
| | `two hosts do not wait for each other` | deux `acquire` sur deux hôtes, aucun délai | C7, B23 |
| | `a Retry-After opens a window on that host only` | `block(h1)` puis `acquire(h2)` | C7, B23 |
| | `a cancellation during the wait does not clear the window` | `slot` reste `blockedUntil != null` | C7, C12 |
| | `the window closes once it has expired` | horloge avancée au-delà | C7 |
| | `the slot is per host and never global` | après deux hôtes, `slots.length == 2` | B23 |
| `Retry-After` | `a delta-seconds Retry-After is read` | `120` → 120 s | C7 |
| | `an HTTP-date Retry-After is read` | `Wed, 21 Oct 2026 07:28:00 GMT` → la durée correspondante à ±1 s | C7 |
| | `a negative Retry-After is a zero delay, not a negative one` | `-5` → `Duration.zero` | C7 |
| | `a huge Retry-After is clamped` | `86400` → `maxRetryAfter` | C7 |
| | `a missing or unparseable Retry-After takes the fallback` | `null`, `bientôt` | C7 |
| Mapping | `a connection timeout is NoConnection` | `connectionTimeout` → `FetchTransportFailed`, `status == 0` | C7, E5 |
| | `every transport failure type is NoConnection` | les six types en boucle | E5, B22 |
| | `a bad certificate is a transport failure and never a source failure` | `badCertificate` → `FetchTransportFailed`, cause contenant `certificate` | C7, B22 |
| | `a 429 is RateLimited with the real status` | `badResponse(429)` → `FetchRateLimited(429, 120 s)` | C7 |
| | `a 503 with a Retry-After is RateLimited, not a source failure` | `badResponse(503)` + en-tête | C7 |
| | `a 404 is a success carrying its status` | `badResponse(404)` → `FetchSucceeded(404)` | B22 |
| | `a 503 without Retry-After is a success carrying its status` | idem | B22 |
| | `a cancellation throws and produces no response` | `cancel` → `CancelledException`, aucun `HttpResponse` | C7, `13-…` règle 7 |
| | `a non-dio exception becomes a transport failure` | `Exception('boom')` | B22 |
| | `no DioException escapes the client` | les neuf bras, `expect(..., isNot(isA<DioException>()))` | B22 |
| Décodage | `a body over the ceiling is refused, not truncated` | `maxBodyBytes + 1` → `NetworkException` | C7, `17-…` règle 3 |
| | `the charset comes from the response, not from an assumption` | `Content-Type: text/html; charset=iso-8859-1` | C6 |
| URLs | `a baseUrl without a trailing slash resolves correctly` | `/novel/x.html` | C5 |
| | `a relative path is never stored as an absolute URL` | `setUrlWithoutDomain(resolve('/a?b=c')) == '/a?b=c'` | C5, `03-…` règle 3 |
| | `a host is a hostname and never a path or a query` | `:443` et `?q=secret` | C12, C5 |
| `FetchResult` | `FetchResult is declared once and only in core/network` | grep `sealed class FetchResult` | § 7 q. 2 |
| | `the rate-limited case carries no host and no source id` | `FetchRateLimited` n'expose ni `host` ni `sourceId` | § 2.2, C5 |
| `HttpResponse` | `the response carries the body and the discriminator together` | `response.outcome is FetchSucceeded(200)` **et** `response.body` non vide | § 7 q. 3 |
| | `a body that was empty is an empty body and not a missing one` | `status != 0` avec `body == ''` reste un `FetchSucceeded` | § 2.2 |

Emplacement complémentaire : `test/core/network/no_telemetry_test.dart`

| Groupe | Test (nom exact) | Scénario | IDs couverts |
|---|---|---|---|
| Posture | `the network layer logs nothing` | grep `print(`, `debugPrint(`, `logger` | B29, C2 |
| | `the network layer carries no telemetry client` | grep `analytics`, `crash`, `sentry`, `firebase` | B29 |
| | `the network layer disables no certificate validation` | grep `badCertificateCallback`, `trustAll`, `proxy` | C7, `17-…` règle 7 |
| | `the network layer imports nothing from lib/` | grep `package:lumen_tale/` dans `lib/core/network` | `02-architecture.md` |
| | `the network layer has no retry` | grep `onError`, `dio.retry`, `retryInterceptor` | C7 |

### 11.2 Tests de composants

Aucun. Cette fondation ne produit aucun widget, et un test de widget sur un
limiteur de débit serait un test qui ne teste rien.

### 11.3 Tests d'intégration

| Flow | Scénario | IDs couverts |
|---|---|---|
| `http-client → failure-discriminator` | une `HttpResponse` réelle de chaque type donne le `BrowseOutcome` attendu par les neuf bras du classifieur | B22, C7 |
| `http-client → 2-1` | `FanMtlSource` passe par `HttpClient.get` et rend un `ContentProbe` **à partir de `response.body`** | B22, E8, § 7 q. 3 |
| `http-client → 3-6` | la ligne de preuve affichée sur `/browse/:sourceId/unavailable` est `status` ou `host`, jamais une exception | B24, C12 |

### 11.4 Tests E2E

Aucun pour cette fondation : **Q-008** (un téléphone réel) n'est pas résolu, et un
E2E qui n'a pas pu être exécuté n'est pas un test, c'est un souhait.

### 11.5 Vérifications manuelles

| Vérification | Écran / Composant | État |
|---|---|---|
| Overflows horizontaux | — | sans objet : pas d'interface |
| Éléments hors écran | — | sans objet |
| Navigation | — | sans objet |
| Politesse mesurée sur un vrai site | un `GET` du catalogue, deux fois de suite, en journalisant l'horodatage de chaque envoi | écart ≥ `minIntervalPerHost` |
| `Retry-After` réel | une source qui répond 429 une fois | la fenêtre est ouverte et aucune requête ne part avant |
| User-Agent réel | l'UA émis par le client, comparé à `LumenTale/<version> (personal reader)` | identique, aucune chaîne de navigateur |

---

## Checklist de gate

- [x] Sources explicitement référencées (PRD, architecture, design, conventions, rules).
- [x] Chaque ID B*/C* du périmètre apparaît en § 6 — **B29**, **B22**, **C2**, **C5**, **C6**, **C7**, **C11**, **C12**, plus **E5** traité en § 6.3.
- [x] Les contrats de données (§ 2) sont du **vrai Dart**, pas de la prose.
- [x] Les algorithmes (§ 3) sont en pseudocode avec **chaque** branche écrite — les **dix** bras de `DioExceptionType`, les **deux** formats de `Retry-After`, les branches de repli et de plafond, et l'annulation qui est la seule à remonter.
- [x] La checklist de tâches (§ 9) couvre les cinq phases, en signalant explicitement que la Phase 3 est vide et pourquoi.
- [x] Les critères d'acceptation (§ 10) sont vérifiables individuellement.
- [x] Le plan de tests (§ 11) couvre tous les IDs, et nomme le fichier de test.
- [x] **Les quatre valeurs qu'aucun document ne fixe** — délai minimum, `Retry-After` de repli, plafond, taille maximale, et les trois timeouts — sont regroupées dans `HttpPolicy` / `HttpTimeouts` et déclarées en § 2.4, pas laissées au choix de l'implémentateur.
- [ ] `coverage-check.js slice` **ne s'applique pas** à une fondation (**F-003**) : `state.json` ne range `http-client` que dans `foundations`, donc ses `rule_ids` ne sont jamais lus par la garde. La vérification de § 6 est manuelle.

**Statut** : `draft` → en attente de validation.