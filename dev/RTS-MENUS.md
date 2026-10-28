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

La campagne conserve ses six planètes, toutes jouées avec des combats en temps réel. La construction d'avant-poste reste propre à l'expédition P3X-742. Les expéditions n'ont pas encore de sauvegarde ; cette limite est indiquée avant le déploiement et avant l'abandon.

## Finition de la porte et du décor

Chevrons en V évidés avec coque et ailettes ; lèvres et cannelures de l'anneau ; rampe ajourée, accès blindés et conduits. La surface de la porte utilise une turbulence advectée et des reflets fins. L'accueil suit les sept glyphes d'Abydos, avec leurs noms et leur état de verrouillage. Composition, sons discrets, ouverture, attente et fermeture sont pilotés par un Timer enfant annulable ; aucun délai de l'accueil ne poursuit la séquence dans la campagne.

Validation supplémentaire : `res://dev/title_gate_tests.tscn` (liaison, chevrons, son et retour campagne) et `res://dev/audio_tests.tscn`.

## Modèle de porte fourni

La porte utilise maintenant le GLB « Milky Way Stargate | Stargate SG-1 » d'Anquietas System, fourni par l'utilisateur. Les fichiers d'origine et leur attribution sont conservés ; voir assets/stargate/SOURCES.md. Le modèle préparé mobile.scn réduit les albedos à 2K et les cartes de données à 1K, puis partage maillages et textures entre instances. L'anneau et les neuf lumières sont commandés par le jeu ; le chevron supérieur utilise le morph fourni. L'horizon, l'iris et le kawoosh restent ceux du jeu. Les supports de salle sont reculés pour dégager les lumières latérales.

Test complémentaire : `res://dev/imported_gate_tests.tscn`.

## Correction campagne complète

Le choix du moteur dans main.gd ne dépend plus de l'indice de planète : toutes les missions utilisent RealtimeCombat. Les contacts ordinaires et les gardiens démarrent directement le combat. Le HUD et le briefing ne proposent plus d'alternance de tours ; sélection et déplacement n'exigent aucun point d'action. La pause tactique permet de donner des ordres, et l'abandon suspend le combat avant la transition. Le recrutement de Bra'tac ne modifie pas rétroactivement les membres déjà déployés.

`res://dev/campaign_realtime_tests.tscn` vérifie les 24 rencontres et gardiens des six mondes : moteur réellement instancié par le déclencheur, tirs simultanés, déplacement au-delà de quatre cases, ordres en pause, portraits sans PA, résultats et progression, sans écrire la sauvegarde utilisateur.

## Trois modèles communautaires supplémentaires

- Anneaux d'Anquietas System sur Netu : couvercle, déploiement des cinq anneaux, transfert à la phase haute puis rangement, avec son synchronisé. Arrivée et départ utilisent l'animation source.
- Réplicateur de TaurWing sur Hala, gardes et essaims compris : quatre articulations procédurales, cinq maillages au lieu de 38, pieds compensés vers le sol, arrêt à la mort, étiquettes et effets de mêlée à hauteur adaptée.
- Console de merlincodes dans les ruines de campagne et les ruines de l'expédition RTS : touches animées à l'étude/activation, objet conservé après utilisation. Approche à une case pour éviter de marcher dans le meuble.

Les sources, transformations et licences sont décrites dans assets/community/SOURCES.md. Les sources d'origine restent dans imports/. scripts/imported_assets.gd partage la préparation et les caches entre la porte et ces modèles.

Validation : community_asset_tests.tscn (transports réels sur Netu, animation et états), campaign_realtime_tests.tscn (les six planètes), menu_ui_tests.tscn (dont liaison console/étude scientifique). Captures des modèles : community_visual.tscn.
