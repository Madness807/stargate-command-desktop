# SG-1 3D — direction RTS

La campagne et la base du SGC restent le parcours principal : accueil → continuer ou nouvelle campagne → SGC → missions. L'expédition RTS P3X-742 reste accessible séparément depuis l'accueil. La campagne et la base sont conservées ; toutes les rencontres et tous les boss des six planètes utilisent le moteur temps réel.

## Menus

- Accueil : porte 3D visible, navigation à gauche, continuer la campagne comme action principale.
- Préparation : briefing, équipe, engagement. Le résumé et le déploiement restent hors du défilement.
- Commandes : page intégrée au briefing, accessible au tactile et au clavier.
- Options : difficulté choisie dans Engagement ; les réglages de campagne restent accessibles et leur portée est indiquée.
- Pause : simulation suspendue, reprise, options, commandes, confirmation avant abandon ou redémarrage.

## Validation

`godot47 --headless --path . res://dev/menu_ui_tests.tscn`

`godot47 --headless --path . res://dev/expedition_tests.tscn`

`./start.sh res://dev/rts_menu_visual.tscn` capture briefing, équipe, engagement, commandes, options et pause dans /tmp/sg1-*.png.

## Limites actuelles

La campagne conserve ses six planètes, toutes jouées avec des combats en temps réel. La construction d'avant-poste reste propre à l'expédition P3X-742. Campagne et expédition disposent chacune d'une sauvegarde d'opération ; la reprise se fait en pause.

## Corrections de règles issues de l'audit

La traduction de Daniel ne réduit les dégâts d'un gardien qu'une fois par combat, de 25 % avec arrondi à l'entier le plus proche. Les utilisations suivantes conservent la diversion sur les gardes, sans cumuler l'affaiblissement du boss.

L’ancien scénario, conservé pour reprendre les sauvegardes existantes, demande la destruction du camp et 30 unités de naquadah réellement produites par un extracteur alimenté. La production cumulée est distincte du stock : les ruines ne comptent pas, et dépenser du naquadah ne fait pas régresser l'objectif. Le HUD affiche ce compteur. Le premier raid se prépare 130/100/80 secondes après la mise en service du commandement selon la difficulté ; reconnaissance et installation n'écoulent pas ce délai.

Les tirs de campagne et d'expédition utilisent la même traversée de grille. Les bâtiments et massifs de l'expédition bloquent les tirs. En campagne, les bâtiments et décors hauts sont opaques ; les objets bas donnent un couvert sans bloquer entièrement. Les deux camps respectent cette règle, y compris aux coins. Les grenades conservent leur trajectoire en cloche et leurs dégâts de zone.

## Finition de la porte et du décor

Chevrons en V évidés avec coque et ailettes ; lèvres et cannelures de l'anneau ; rampe ajourée, accès blindés et conduits. La surface de la porte utilise une turbulence advectée et des reflets fins. L'accueil suit les sept glyphes d'Abydos, avec leurs noms et leur état de verrouillage. Composition, sons discrets, ouverture, attente et fermeture sont pilotés par un Timer enfant annulable ; aucun délai de l'accueil ne poursuit la séquence dans la campagne.

Validation supplémentaire : `res://dev/title_gate_tests.tscn` (liaison, chevrons, son et retour campagne) et `res://dev/audio_tests.tscn`.

## Modèle de porte fourni

La porte utilise maintenant le GLB « Milky Way Stargate | Stargate SG-1 » d'Anquietas System, fourni par l'utilisateur. Les fichiers d'origine et leur attribution sont conservés ; voir assets/stargate/SOURCES.md. Le modèle préparé mobile.scn réduit les albedos à 2K et les cartes de données à 1K, puis partage maillages et textures entre instances. L'anneau et les neuf lumières sont commandés par le jeu ; le chevron supérieur utilise le morph fourni. L'horizon, l'iris et le kawoosh restent ceux du jeu. Les supports de salle sont reculés pour dégager les lumières latérales.

Test complémentaire : `res://dev/imported_gate_tests.tscn`.

## Correction campagne complète

Toutes les missions utilisent le moteur autonome `combat_realtime.gd`. Les contacts ordinaires et les gardiens démarrent directement le combat. Déplacements et tirs avancent simultanément ; recharges et étourdissements sont exprimés en secondes. La pause tactique permet de donner des ordres, et l'abandon suspend le combat avant la transition. Le recrutement de Bra'tac ne modifie pas rétroactivement les membres déjà déployés.

`res://dev/campaign_realtime_tests.tscn` vérifie les 24 rencontres et gardiens des six mondes : moteur réellement instancié par le déclencheur, tirs simultanés, déplacements longs, ordres en pause, sélection immédiate, résultats et progression, sans écrire la sauvegarde utilisateur.

## Trois modèles communautaires supplémentaires

- Anneaux d'Anquietas System sur Netu : couvercle, déploiement des cinq anneaux, transfert à la phase haute puis rangement, avec son synchronisé. Arrivée et départ utilisent l'animation source.
- Réplicateur de TaurWing sur Hala, gardes et essaims compris : quatre articulations procédurales, cinq maillages au lieu de 38, pieds compensés vers le sol, arrêt à la mort, étiquettes et effets de mêlée à hauteur adaptée.
- Console de merlincodes dans les ruines de campagne et les ruines de l'expédition RTS : touches animées à l'étude/activation, objet conservé après utilisation. Approche à une case pour éviter de marcher dans le meuble.

Les sources, transformations et licences sont décrites dans assets/community/SOURCES.md. Les sources d'origine restent dans imports/. scripts/imported_assets.gd partage la préparation et les caches entre la porte et ces modèles.

Validation : community_asset_tests.tscn (transports réels sur Netu, animation et états), campaign_realtime_tests.tscn (les six planètes), menu_ui_tests.tscn (dont liaison console/étude scientifique). Captures des modèles : community_visual.tscn.

## Iris et verrouillage individuel

Les neuf boîtiers du modèle sont séparés par secteur en conservant leurs matériaux et morphs. Chaque symbole actionne son propre mécanisme dans LOCK_ORDER : course radiale, maintien, retour au repos ; le chevron reste allumé. Seul le morph supérieur du GLB contient des déplacements réels ; sa déformation est transférée aux sommets correspondants des huit autres chevrons après rotation dans leur repère. Les pièces fixes restent fixes ; le boîtier et la lumière reproduisent la course du central. Le menu et la campagne utilisent la même séquence. Les maillages préparés sont partagés entre instances, leurs états restent indépendants.

L’iris utilise vingt feuilles courbes chevauchantes, pivotant derrière la couronne. Son matériau découpe les parties rangées hors de l’ouverture. Une commande inverse reprend la position courante au lieu de faire sauter l’animation.

Validation : `res://dev/gate_mechanics_tests.tscn`, `res://dev/imported_gate_tests.tscn`, `res://dev/title_gate_tests.tscn`. Contrôle visuel : `./start.sh res://dev/iris_visual.tscn` (captures `/tmp/sg1-iris-*.png`).

## Nettoyage du moteur de campagne

Le moteur temps réel hérite directement de Node3D. Les unités ne contiennent aucune réserve d’actions ou de déplacement ; il n’existe aucun cycle de tours ni verrou d’animation bloquant les ordres. `combat_stats.gd` partage les mêmes caractéristiques entre briefing et simulation, ajustées à la difficulté. Les anciens scores de puissance indépendants des règles ont été supprimés. Les seules issues de combat sont victoire, défaite et repli. Les tests contrôlent les échanges simultanés, les ordres pendant la pause, les délais en secondes et l’émission unique du résultat.


## Dernière Veille — nouvelles expéditions

Les nouvelles parties lancées depuis la préparation jouent désormais l’opération **Dernière Veille**, une histoire originale située pendant la saison 3 après l’échange avec Orban. Sept étapes : franchissement, tête de pont, archives, relais, camp, transmission et rapatriement. Un détour facultatif permet de secourir SG-11 et de récupérer ses renseignements radio.

Les modules nécessitent un ingénieur sur place ; les renforts arrivent du SGC. La destruction du camp ne donne pas la victoire : les données et les survivants doivent rentrer par une liaison sortante, incompatible avec les transports entrants. Le naquadah conditionné sert aux générateurs de terrain, au secours électrique et à la régulation, sans bonus de dégâts.

Voir [LAST-WATCH.md](LAST-WATCH.md) pour les règles, la compatibilité des sauvegardes et les vérifications.
