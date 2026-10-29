# Abydos — opération Skaara

Première version jouable de la refonte : la carte d'Abydos possède un parcours spécifique, les cinq autres planètes gardent leur parcours actuel.

1. Rejoindre Kasuf. Il indique la console gardée et les deux approches de la pyramide.
2. Pendant le combat de la console, choisir **Daniel · traduire**. Il rejoint une case adjacente puis travaille six secondes sans tirer. Les autres membres peuvent concentrer leurs tirs, employer leurs capacités et couvrir l'intervention.
3. Rejoindre Klorel. Son bouclier absorbe les dégâts tant que **Carter · couper bouclier** n'a pas terminé son intervention de six secondes à la seconde console.
4. Neutraliser Klorel et ses gardes, puis rejoindre le DHD. **Extraire Skaara** valide la mission et débloque Chulak. Un départ avant sa récupération ne valide pas Abydos.

Le panneau Objectif indique l'étape et permet de rejoindre le prochain lieu hors combat, ou de le voir pendant un combat. **Espace** suspend le combat et permet de préparer les ordres. Un nouvel ordre de mouvement, une attaque ou Halte au spécialiste annule son intervention ; un étourdissement remet la progression à zéro. La pause ne fait pas progresser le travail. La mort du spécialiste indispensable provoque un repli avec explication, sans valider l'étape. Une trousse peut être employée pendant le travail.

Le bouclier de Klorel possède une enveloppe bleue visible qui disparaît à la coupure du relais. La progression de Daniel et Carter est affichée dans une barre dédiée, avec les états approche, travail, étourdissement et pause. Leurs PV restent visibles au-dessus du personnage pendant l'intervention. Les consoles indiquent leur état après utilisation, et l'objectif se met à jour dès la coupure du bouclier.

Pour le membre sélectionné, le HUD indique la cible, la probabilité de toucher et son couvert directionnel. Les cibles hors portée, masquées par un obstacle ou protégées par le bouclier sont signalées explicitement. Un tracé bleu indique le trajet ordonné ; des pointillés orange indiquent la cible à portée, gris hors portée et rouges lorsqu'un obstacle coupe la ligne de tir. Les bâtiments et les décors de campagne d'au moins 1,8 m bloquent les tirs ; les objets bas restent des couverts qui diminuent la précision. La règle est symétrique et interdit de tirer au travers d'un coin opaque. Un ordre d'attaque fait avancer l'unité jusqu'à retrouver une ligne dégagée. Le spécialiste suspend son tir pendant son intervention. Les textes et commandes se compactent sur les écrans bas pour préserver l'accès aux actions.

La récupération de Skaara est pour l'instant un état d'objectif annoncé à l'écran ; il n'y a pas encore de personnage escorté physiquement. La sauvegarde automatique permet de reprendre l'opération en cours depuis l'accueil, en pause. L'équilibrage et la durée restent à éprouver au doigt : le parcours simulé suit les objectifs directement, sans temps de découverte ou de lecture.

## Vérifications

```sh
/root/.local/opt/godot47 --headless --path . res://dev/abydos_mission_tests.tscn
/root/.local/opt/godot47 --headless --path . res://dev/abydos_playthrough.tscn
/root/.local/opt/godot47 --headless --path . res://dev/campaign_realtime_tests.tscn
/root/.local/opt/godot47 --headless --path . res://dev/realtime_tests.tscn
/root/.local/opt/godot47 --headless --path . res://dev/menu_ui_tests.tscn
./start.sh res://dev/abydos_mission_tests.tscn -- --visual
```

Les scénarios d'Abydos isolent les écritures de sauvegarde. Les tests de règles vérifient les prérequis, les interventions, les interruptions, le repli, le bouclier et l'extraction. Le parcours simulé joue au niveau 1 sans équipement amélioré, avec déplacements, tirs aléatoires, grenade, capacité de Daniel et soins ; il ne force pas les dégâts, les morts ou les objectifs. Sa réussite sur une graine ne constitue pas un playtest complet.

Les captures du scénario visuel sont écrites dans `/tmp/sg1-abydos-*.png`. Les suites existantes signalent quelques objets non libérés à la sortie ; elles ne sont pas des tests de mémoire à long terme.
