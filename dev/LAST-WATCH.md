# Dernière Veille — mission RTS

Opération originale du SGC sur P3X-742, située pendant la saison 3 après l'échange avec Orban. Elle utilise les systèmes de l'expédition et reste indépendante de la campagne. Le scénario et ses dispositifs sont une création pour le jeu, pas l'adaptation d'un épisode canonique.

## Jouer

Accueil → Expédition RTS · P3X-742 → nouvelle expédition. Les nouvelles parties utilisent cette mission. Une ancienne expédition sauvegardée reprend son scénario d'origine ; elle n'est pas convertie ni effacée automatiquement.

## Déroulement

1. Franchissement : MALP, première équipe, reconnaissance sans compteur de raid actif.
2. Tête de pont : sécurisation de la clairière, appel des ingénieurs du SGC, protection du commandement en construction.
3. Archives : laboratoire alimenté, scientifique arrêté aux ruines, 60 secondes de travail en zone sécurisée. L'exploitation du gisement fournit le combustible conditionné pour la suite.
4. Relais : interventions d'ingénieurs sur deux sites, 40 N et 45 secondes par générateur de terrain. Le nord réduit chaque colonne suivante d'un Jaffa (minimum deux). L'est retarde la prochaine colonne de 45 secondes et réduit les dégâts du camp de 40 %. Choisir l'ordre ou mener les deux opérations simultanément.
5. Assaut : le bouclier du camp ne cède qu'une fois les deux relais coupés. Les gardes restent vulnérables avant cela. La destruction du camp ne termine pas la mission.
6. Transmission : retour aux ruines, laboratoire alimenté et copie protégée de 90 secondes. Deux colonnes de réserve au maximum peuvent encore entrer dans le secteur après la chute du camp.
7. Rapatriement : scientifique au commandement pour valider les données, rassemblement près de la porte, composition sortante explicite puis passage de tous les survivants. Aucun convoi entrant pendant la liaison sortante. Le QG doit tenir jusqu'au dernier passage ; au moins un scientifique et un militaire doivent rentrer.

Détour facultatif : une balise SG-11 émet au nord-ouest. Approcher avec des militaires et repousser les Jaffas libère un scientifique et un ingénieur. Ramener au moins un survivant au QG fournit les fréquences radio ennemies : préavis de raid porté de 30 à 50 secondes. Les survivants deviennent commandables et doivent ensuite être couverts jusqu'à leur passage vers la Terre. Leur perte ne bloque pas l'objectif principal.

## Décisions et informations

- Les modules sont assemblés par un ingénieur arrêté à moins de trois cases ; un chantier attend si le personnel part. La commande de construction envoie l'ingénieur le plus proche.
- Les renforts viennent du SGC par groupes de trois. Capacité logistique de la mission : douze militaires, hors spécialistes.
- Un extracteur alimenté conditionne 1 N/s. Les ruines ne créent pas de ressources.
- Dépenses concurrentes : relais 40 N chacun ; secours électrique 25 N pour +8 énergie pendant 45 s ; régulation 80 N pour +4 énergie et interventions sur relais 25 % plus rapides. La recherche n'augmente pas les dégâts dans cette mission.
- Raids : premier départ 130/100/80 secondes après la mise en service du QG selon la difficulté, puis intervalles 140/115/95 secondes. Les colonnes entrent par un axe annoncé au bord de la carte et visent générateur, extracteur, QG ou scientifique. L'alerte décrit l'entrée dans le secteur, pas une heure garantie de premier tir. La mini-carte relie l'axe à la cible.
- Travaux : une menace à moins de cinq cases ou une panne suspend l'étude, le sabotage ou la copie. La progression reste acquise. Plusieurs spécialistes ne multiplient pas la vitesse.
- Les relevés sont partagés entre terminaux : un scientifique remplaçant peut reprendre avant la liaison sortante. Le départ bloque les remplacements.
- Objectifs, progression, raisons de blocage, commandes de relais, secours et départ sont dans le panneau de mission défilable. Le menu pause contient le journal de l'opération.

## Continuité

Le snapshot RTS ajoute un dictionnaire d'opération optionnel : étape, travaux, paiements, secours, alertes, cibles, effectifs rapatriés et état du sauvetage. Une ancienne sauvegarde sans ce champ reste lisible. Les nouveaux travaux et les alertes reprennent sans duplication. La sauvegarde automatique existante reste active, avec reprise en pause.

## Vérifications

98 contrôles dédiés : bouclier, énergie et interruption, paiements, interventions, reprise en mémoire et sur disque, effets des relais, variantes de raid, cases d'apparition praticables, sauvetage et bonus radio, capacité logistique, transfert, porte à sens unique, échec et victoire, ancien snapshot et interface à 1600×900 / 853×480.

Autres suites exécutées : RTS 81/81, expédition 69/69, vue RTS 22/22, menus 205/205 et sauvegarde/reprise 41/41. Les scénarios d'erreur d'écriture de cette dernière suite produisent volontairement un message d'erreur.

Trois parcours automatiques complets, sans création forcée d'unités, modification de PV, de dégâts ou de ressources. Ils utilisent les constructions, recrutements, réparations et ordres du joueur. Chaque parcours recharge réellement la simulation au milieu du relais nord. Les états des phases sont également reconstruits pour contrôler leur sérialisation.

| Parcours | Résultat | Temps simulé | Personnel rentré | Dont SG-11 |
|---|---|---:|---:|---:|
| Officier · parcours direct | victory | 487.0 s | 14 | 0 |
| Officier · détour SG-11 | victory | 460.7 s | 15 | 1 |
| Vétéran · parcours direct | victory | 484.7 s | 15 | 0 |

Les décisions du pilote sont instantanées : ces durées ne mesurent pas une session humaine et ces trois parcours ne constituent pas une estimation de taux de victoire. La branche SG-11 peut accélérer la mission grâce au personnel récupéré ; elle présente aussi un risque de pertes. Les rapports JSON complets sont dans `last-watch-2026-10-29/`.

Le lancement graphique a été tenté mais Wayland n'a pas pu créer de fenêtre. Les dispositions et les scènes sont vérifiées sans rendu ; l'apparence réelle, le confort tactile et le rythme restent à valider sur téléphone.

```sh
/root/.local/opt/godot47 --headless --path . res://dev/outpost_operation_tests.tscn
/root/.local/opt/godot47 --headless --path . res://dev/outpost_operation_playthrough.tscn
/root/.local/opt/godot47 --headless --path . res://dev/outpost_operation_playthrough.tscn -- --rescue --output=/tmp/sg1-last-watch-rescue.json
/root/.local/opt/godot47 --headless --path . res://dev/outpost_operation_playthrough.tscn -- --difficulty=hard
```

## Lisibilité des tourelles

Le contrôle ciblé des tourelles reproduit le tir automatique réel (14 dégâts, recharge de 1,3 s), la portée de 5,5 cases, les obstacles et la coupure électrique. Aucun blocage général du tir n'a été reproduit. Le rendu initial partait du centre du bâtiment et n'avait pas d'éclair de bouche ; son trait de 90 ms était peu lisible. Il part maintenant des canons orientés vers la cible, avec un éclair et un trait de 180 ms. La sélection affiche un cercle de portée ; l'étiquette et la fiche distinguent construction, panne, veille, hors portée, obstacle, bouclier et cible acquise. Le ciblage et le diagnostic partagent la même fonction de sélection pour éviter des informations contradictoires.

`res://dev/turret_tests.tscn` : 19/19 contrôles, y compris géométrie de la bouche, orientation, éclair et reprise de snapshot. Régressions : RTS 81/81 et Dernière Veille 98/98. `--inspect` lit la sauvegarde RTS sans la modifier pour diagnostiquer alimentation et cibles visibles. La lisibilité visuelle effective reste à contrôler sur téléphone.
