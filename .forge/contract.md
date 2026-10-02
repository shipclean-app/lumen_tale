---
type: contract
status: approved
generated_at: 2026-10-02
---

# Contrat de projet — Lumen Tale

> Ce que vous signez. **Après cette signature, vous n'êtes plus interrupté que pour un écart au présent contrat, ou pour une décision qui vous appartient nommément.**
>
> Un rapport à chaque phase produirait l'inverse de ce qu'on cherche : une formalité que vous approuvez sans lire, donc une porte vide.

*Mihon est l'application libre et gratuite de lecture de bandes dessinées et de romans dont ce projet s'inspire. Quand les deux diffèrent, c'est ce document qui décide — pas Mihon.*

## Les quatre raisons pour lesquelles ce document existe

| Bloc | Ce qu'il évite |
|---|---|
| Ce qui sera livré | un périmètre qu'on découvre en Phase 4 |
| Ce qui ne sera pas livré | une exclusion non dite, découverte à la livraison |
| Ce qui est irréversible | un engagement entré sans que personne ne l'ait vu |
| Ce que Forge décidera seul | quatre-vingt questions techniques par phase |

---

## 1. Ce qui sera livré

Dans vos mots, pas les nôtres. Vous devez pouvoir relire chaque ligne et l'imaginer sur un téléphone.

| Slice | Ce que vous aurez | Pour qui |
|---|---|---|
| Une bibliothèque | Vos romans, avec couvertures, cherchables et triables, sur votre téléphone | Vous |
| Parcourir un site | Vous ouvrez le catalogue d'un site de romans et le parcourez comme n'importe quelle liste | Vous |
| Chercher dans un site | Vous cherchez à l'intérieur d'un site, avec les filtres que ce site propose | Vous |
| Lire un chapitre | Vous ouvrez un chapitre et le lisez, dans un lecteur clair conçu pour du texte | Vous |
| Garder un chapitre | Un chapitre que vous avez lu est enregistré sur votre téléphone : il s'ouvre sans internet — **tant que l'application reste installée sur ce téléphone** | Vous |
| Télécharger un roman | Vous lancez le téléchargement d'un roman entier ; il continue pendant que l'application est fermée | Vous |
| Savoir ce qui est nouveau | Vous voyez lesquels de vos romans suivis ont de nouveaux chapitres | Vous |
| Reprendre où vous en étiez | L'application s'ouvre au chapitre et au paragraphe où vous vous êtes arrêté | Vous |
| Lire en français ou en anglais | Tous les mots de l'application, y compris les messages d'erreur | Vous |
| Lire dans le noir | Un lecteur qui respecte le mode clair/sombre de votre téléphone | Vous |
| Support des gros caractères | Le lecteur suit le réglage de taille de police de votre téléphone au lieu de l'ignorer | Vous |

**Chaque ligne est une chose que vous pouvez tenir dans la main sur un téléphone.** Rien ici n'est un composant, un service, ou une couche technique.

**Quels sites.** La première version lit **trois sites** :

- **FanMTL** (fanmtl.com) — le premier. Romans de fan-fiction et web novels, genres xianxia, xuanhuan, shoujo, romance. Texte lisible sans navigateur, et ses règles autorisent la lecture : vérifié.
- **Royal Road** (royalroad.com) — romans web en anglais. Ses règles autorisent la lecture : vérifié.
- **Novel Fire** (novelfire.net) — **seulement si vous confirmez ses conditions** avant le 16 octobre (§5). Nous ne le développons pas avant votre réponse.

Pour ajouter un site plus tard : c'est nous qui faisons le travail, il faut une nouvelle version de l'application sur votre téléphone, et nous vous annonçons le prix avant de commencer. Vous n'écrivez aucun code et n'installez rien.

**Où ça sera livré.** Il n'y a **pas de Play Store ni d'App Store**. À chaque fusion sur la branche principale, nos machines construisent automatiquement les fichiers APK, que vous récupérez et installez sur votre téléphone. Chaque version est numérotée, donc vous savez toujours laquelle vous avez.

**Ordre approximatif, pas une promesse.** La lecture vient en premier — votre bibliothèque, un site, un chapitre, enregistré hors-ligne — et le reste suit. Nous vous demanderons de l'essayer sur votre téléphone quelques fois en cours de route ; chaque round prend quelques minutes de votre temps et nous vous prévenons. **Nous ne donnerons pas de dates au calendrier** : une date que nous ne pouvons pas tenir est pire que pas de date du tout.

**Ce dont nous avons besoin de vous.** Trois réponses (§5), et quelques minutes pour essayer l'application quand nous le demandons. Rien d'autre.

**Comment saurons-nous que c'est fini ?** Les cinq conditions sont au § 6.

## 2. Ce qui ne sera pas livré

Le bloc le plus utile, et le plus souvent omis. Une exclusion non écrite est une trahison future : elle ne se découvre qu'à la livraison, quand il est trop tard pour discuter.

| Non livré | Pourquoi | Réexamen |
|---|---|---|
| **Une version iPhone** | Nous construisons sur une machine qui ne peut ni produire ni tester d'application iPhone. Il faut un autre matériel et un compte développeur Apple payant | Jamais, sauf si vous le demandez et que nous le chiffrons |
| **L'application sur le Play Store ou l'App Store** | Mettre une application sur un magasin, c'est payer, passer une revue, et une application qui doit marcher sur des milliers de téléphones que nous n'avons jamais touchés. Pour une première version, **vous installez le fichier vous-même** | Si vous voulez que d'autres personnes l'installent — demandez-le au §5 |
| Des sources en plug-in installables | Délibéré. Vous avez demandé qu'aucun système de plug-in n'existe en v1 : les sites sont intégrés à l'application. Mihon permet d'installer des sites de lecture depuis l'extérieur — celui-ci non, en v1 | Si vous voulez ajouter un site sans nouvelle version de l'application |
| Comptes, connexion, synchronisation cloud | Rien de ce que vous lisez n'est stocké ailleurs que sur votre téléphone. Pas de compte signifie rien qui fuite, et rien à payer | Si vous voulez lire sur deux appareils |
| Intégrations de suivis (Anilist, MyAnimeList) | Mihon les a ; vous les avez mis hors v1 | Si vous voulez publier des stats de lecture quelque part |
| Partager un chapitre, ou exporter un roman | Usage personnel uniquement. Exporter transforme ceci en outil de redistribution et pose des questions auxquelles nous ne répondons pas en v1 | Si vous voulez garder votre bibliothèque en quittant l'application |
| **Sortir votre bibliothèque : impossible** | Vos romans et chaque chapitre téléchargé vivent uniquement dans l'application, sur ce téléphone. Désinstallez l'application, perdez le téléphone, ou réinitialisez-le, et **ils sont perdus — aucune copie n'existe ailleurs.** Un export est prévu en v2 | v2 |
| Sauvegarde et restauration | Découle de la ligne ci-dessus | v2 |
| Lecture en mode paginé | En v1 le défilement est continu, comme une page web. Le tourne-page, les modes de lecture (sur le côté, deux pages) et les filtres de couleur sont prévus en v2 — Mihon les a tous et nous les reprendrons | v2 |
| Lire vos propres fichiers `.txt` / EPUB / PDF | Lecture de sites uniquement | Si vous avez des fichiers à mettre dans l'application |
| Mise en page tablette | Téléphone uniquement. Elle s'ouvre sur une tablette mais n'est pas conçue pour | Plus tard, si vous le demandez |
| Chapitres téléchargés visibles par d'autres applications | Les chapitres sont stockés là où seule cette application peut les lire. Cela veut dire aussi que rien ne peut les copier pour vous | Jamais, sauf si vous le demandez |

**Tout ce qui n'est pas listé ci-dessus n'est pas promis.** Si ce n'est pas au § 1, nous ne le construisons pas.

## 3. Ce qui est irréversible

C'est ce bloc qui rend vraie la promesse de ne plus vous interrompre. Chaque ligne porte un prix ou une durée.

| Engagement | Choix | Prix / durée | Réversible ? |
|---|---|---|---|
| Hébergement (hosting) | **Aucun.** L'application est une application normale sur votre téléphone. Aucun serveur, aucun compte, rien qui coûte de l'argent chaque mois | 0 €/mois, à vie | Oui |
| Identité (identity provider) | **Aucun.** Il n'y a aucun compte à créer | 0 €/mois, à vie | Oui |
| Achat / licence | **Aucun.** Rien n'est acheté, rien n'est facturé | 0 € une fois | Oui |
| Exécution de fond (background job) | Le téléchargement d'un roman entier continue pendant que l'application est fermée : c'est ce qui permet de finir la nuit. Cela consomme un peu de batterie et de data mobile. Votre téléphone liste les applications qui font cela dans les réglages batterie — celle-ci y apparaîtra, et vous pouvez la désactiver ; les téléchargements n'auront alors lieu que lorsque l'application est ouverte | 0 €. **Nous n'avons pas encore mesuré le coût en batterie ; nous vous donnerons le chiffre quand nous l'aurons** | Oui — un interrupteur dans les réglages |
| **Données des autres (lecture de sites tiers)** | C'est la seule chose ici qu'on ne peut pas défaire. L'application récupère des pages sur les sites des autres. C'est tout l'intérêt du produit, et c'est le seul point qui porte un risque que vous détenez personnellement | Aucun coût — le risque est permanent et vous appartient | **Non.** Une fois livré, c'est livré |

**Sur cette dernière ligne, en termes simples.** Les règles de FanMTL pour l'accès automatisé autorisent aujourd'hui un lecteur comme le nôtre : nous avons lu son fichier `robots.txt` nous-mêmes, et il n'interdit que des dossiers techniques du site, pas les romans ni les chapitres. Le site est bien derrière Cloudflare — contrairement à ce qu'on croyait — mais il ne nous a rien demandé de spécial lorsque nous nous sommes identifiés honnêtement. S'il se met un jour à nous bloquer, **nous ne nous ferons pas passer pour un navigateur** : ce serait un choix qui vous engage, et nous vous le demanderions d'abord. Les règles de Novel Fire, nous ne les avons **pas** confirmées — c'est pourquoi cette source est bloquée jusqu'à votre décision. En pratique, les pires conséquences réalistes sont : le site bloque votre connexion ou l'adresse de votre téléphone, le site vous demande d'arrêter, ou l'application cesse de fonctionner après un changement du site. Nous ne sommes pas juristes et cela ne remplace pas un conseil. Cela enregistre une décision que vous avez prise en connaissance de cause — lecture personnelle, pas redistribution — et le risque reste le vôtre.

**Quand un site change.** Les sites changent de présentation sans prévenir. Nous ne contrôlons pas cela, et ce n'est pas un bug de l'application. **En v1 nous corrigeons l'application quand un site que vous utilisez cesse de fonctionner, jusqu'à 3 fois et jusqu'au 31 décembre 2026.** Ensuite, c'est une nouvelle conversation, et nous vous annonçons le prix avant de commencer.

## 4. Ce que Forge décidera seul

Énumérer ce qui est réversible et gratuit, c'est ce qui rend le silence légitime — parce que vous savez que vous n'avez rien à dire là-dessus.

| Décision | Pourquoi Forge peut la prendre seul |
|---|---|
| Structure du code, noms de fichiers, découpage | Réversible, gratuit |
| Quelle bibliothèque implémente un outil choisi | Réversible, gratuit |
| Format de stockage | Réversible, et vos données restent extractibles par nous si vous en avez besoin |
| Outillage de test | Réversible, gratuit |
| Détails de design écran par écran, tant qu'ils servent le § 1 | Réversible, gratuit |
| Nombre de tentatives, tailles de cache, timeouts | Réversible, gratuit |
| Laquelle de deux façons équivalentes de construire un écran | Réversible, gratuit |

**Si vous lisez cette liste et ne la contestez pas, vous avez délégué ces décisions.** Le silence ici est une délégation, parce que le prix de corriger l'une d'elles est nul.

## 5. Ce qui reviendra au client

Les décisions qui vous appartiennent — **chacune avec une échéance, et chacune avec ce que nous faisons par défaut si vous ne répondez pas.**

> **Chaque défaut ci-dessous est celui qui ne vous coûte rien et ne vous risque rien.** Si un défaut devait vous coûter ou vous risquer quelque chose, nous vous redemanderions au lieu de supposer.

| Décision | Options | Échéance | Si vous ne répondez pas, nous faisons |
|---|---|---|---|
| Royal Road et Novel Fire restent-ils en v1 ? | Les deux en plus de FanMTL, ou reportés en v2 | 2026-10-16 | **Déjà répondu : les deux restent en v1** |
| Les règles de Novel Fire autorisent-elles la lecture ? | Autoriser, ou retirer de la version | 2026-10-16 | **On la retire de la version.** Une source dont on n'a pas vérifié les conditions n'est pas une source. FanMTL et Royal Road restent |
| Voulez-vous une mise en page tablette ? | Oui, ou téléphone seul | 2026-10-16 | **Téléphone seul** |
| Voulez-vous l'application sur le Play Store un jour ? | Oui, ou non définitivement | 2026-10-16 | **Non.** On la garde personnelle : une publication en magasin exige un compte payant et une version éprouvée sur du matériel réel, et nous vous chiffrerons le prix le jour où vous demanderez |

> Ces décisions sont **déjà réglées pour v1** : les trois sites y sont, pas de magasin, pas de tablette, et la construction automatique à chaque fusion. Les deux dernières restent listées parce que « pas pour v1 » et « jamais » ne sont pas la même chose, et la différence vous appartient.
>
> Passé l'échéance sans réponse, nous appliquons le défaut ci-dessus et le signalons dans le bilan suivant. Le silence n'est pas une approbation — mais avec ces défauts, le silence ne vous coûte rien, c'est tout l'intérêt de les afficher.
>
> **Ces dates supposent qu'on vous entende.** Si vous êtes absent ou occupé, dites-le et nous les repoussons.

---

## 6. Comment saurons-nous que c'est fini

Cinq conditions. **Toutes** doivent être vraies — une seule qui manque, ce n'est pas fini.

1. **FanMTL et Royal Road** se parcourent, se cherchent, et leurs chapitres se lisent du début à la fin. **Novel Fire** aussi, si vous avez confirmé ses conditions d'ici la date du §5 — sinon il ne compte pas.
2. **Cinquante chapitres** se téléchargent, puis se lisent **réseau coupé** — vérifié en coupant vraiment la connexion, pas en supposant que le fichier existe.
3. La bibliothèque, l'historique et les pastilles « non lu » sont justes.
4. **Le français et l'anglais sont complets** — y compris les messages d'erreur.
5. **Une installation vérifiée sur votre téléphone**, depuis un fichier produit automatiquement.

Ce n'est volontairement **ni** la parité avec Mihon, **ni** « ça compile et les tests passent ».

---

## Ce que ce contrat ne dit pas

- Il ne décrit pas la technique. Vous n'avez pas à la choisir, et les noms de frameworks ne vous intéressent pas — le **prix** vous intéresse, et il est au § 3.
- Il ne contient aucune règle de code. Elles appartiennent au jeu de règles du projet, écrit après que la technique est arrêtée.
- Ce n'est pas un rapport d'avancement. Il ne bouge pas d'une phase à l'autre ; seul le § 3 se remplit, quand un engagement est découvert — et uniquement sous la règle ci-dessous.

## Après votre signature

Nous ne pouvons ajouter une ligne au § 3 que pour un coût ou une durée **déjà listés ci-dessus**. Tout nouveau coût, toute nouvelle obligation permanente, et toute décision qui vous appartient nommément, nous vous ramenons pour un oui ou un non avant d'agir. **Nous ne réécrivons jamais une ligne signée** — nous en ajoutons une nouvelle, nous la datons, et nous vous montrons les deux côte à côte.

## Comment répondre

Écrivez une ligne par question, ici :

```
Novel Fire :         autoriser / retirer
Version non éprouvée : livrer pour tester / attendre
Mise en page tablette : oui / non
Play Store plus tard : oui / non
```

Rien d'autre n'est nécessaire, et nous vous répéterons votre réponse avant d'agir. Répondez en français — l'application sera en français.

## Signature

| | |
|---|---|
| Client | Le propriétaire du projet — **signé le 2026-10-02** |
| Date | 2026-10-02 |
| Forge | Forge, dans cette session |

> Signed after one `client-liaison check` round (11 questions, all addressed), and after the client answered §5: **no store, no tablet, GitHub Actions builds on merge, all three sites in v1.**