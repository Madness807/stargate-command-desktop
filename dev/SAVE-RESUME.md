# Sauvegarde et reprise

La campagne utilise toujours `user://sg1_3d.json`. Le format 2 conserve les champs de progression du format 1 et ajoute l'état de mission. Les anciennes sauvegardes reprennent au SGC. Les données de mission sont des valeurs sérialisées (sans objets), regroupées avec les gains de campagne dans le même fichier écrit temporairement puis renommé.

Une mission active est enregistrée toutes les cinq secondes, à l'ouverture du menu pause, à la mise en arrière-plan, au début et à la résolution d'un combat et à la fermeture normale. Les transitions d'arrivée conservent le point sûr de début de mission. Une fermeture forcée peut perdre au plus les dernières secondes depuis le dernier enregistrement ; aucune simulation hors ligne n'est rattrapée.

L'accueil propose **Reprendre la mission**. Le menu pause propose **Sauvegarder**, **Sauvegarder et menu principal** et **Sauvegarder et quitter**. **Abandonner la mission** reste un choix différent : il retourne au SGC et supprime la reprise en cours. La reprise de combat est en pause tactique ; la reprise d'exploration ouvre le menu pause.

L'état de campagne comprend la graine et les lieux résolus, le brouillard, les objectifs d'Abydos, l'équipe réellement déployée, les positions et chemins, la caméra, le journal, les PV, les cibles, les ordres préparés, les recharges, les étourdissements, la traduction déjà appliquée, les interventions et l'état du générateur aléatoire de combat. Les projectiles et animations transitoires ne sont pas rejoués : leurs dégâts sont déjà représentés dans l'état logique.

La résolution d'une rencontre utilise une transaction : récompense, objectif et lieux résolus sont publiés ensemble. Le retour accepté au DHD et le rapatriement d'urgence retirent le checkpoint avant leur animation. Une reprise ne redonne donc pas une récompense déjà acquise et ne relance pas une opération déjà extraite.

L'expédition utilise `user://sg1_expedition.json`, indépendant de la campagne. Son état conserve unités, bâtiments et chantiers, stocks et production cumulée, énergie, fog et renseignements mémorisés, recherche, escouades, ordres, vagues, convois et franchissements en cours. La préparation propose **Reprendre** lorsqu'une sauvegarde existe ; lancer une nouvelle opération demande confirmation avant de remplacer celle-ci. Une opération terminée retire sa sauvegarde active.

En cas d'échec d'écriture, quitter depuis les menus est refusé et la partie reste ouverte avec un message. Un fichier d'expédition illisible est conservé et signalé. Les versions de mission incompatibles sont refusées sans écraser la progression de campagne.

## Vérification

`res://dev/session_save_tests.tscn` effectue des écritures et lectures réelles sur des chemins de test, puis reconstruit les scènes. Il couvre reprise partielle de Daniel et Carter, ordres préparés, délais, hasard, brouillard, récompenses, extraction, construction, convois, économie, retour en pause, ancien format, fichier illisible et échec d'écriture. Les sauvegardes utilisateur sont comparées avant et après.

`res://dev/session_process_tests.tscn -- --write-fixture` puis `--read-fixture` vérifient la reprise dans deux processus Godot distincts. Les tests et outils visuels existants désactivent les écritures d'expédition ou utilisent des chemins isolés.

La sauvegarde de mission conserve également la réserve de naquadah au départ. Le rapatriement forcé ne prélève que 0/25/50 % des gains de la sortie (facile/normal/difficile, arrondi au-dessous). Un ancien checkpoint sans cette valeur protège la réserve présente au moment de la reprise.


Dernière Veille ajoute un état d’opération optionnel au snapshot RTS : phases, travaux partiels, dépenses déjà engagées, alertes et cibles des raids, secours électrique, survivants SG-11, journal et passages sortants. Les anciens snapshots sans ce champ restent dans leur scénario d’origine. Les nouvelles parties utilisent Dernière Veille ; reprendre une ancienne partie ne la convertit pas.
