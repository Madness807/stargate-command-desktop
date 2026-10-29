# Abydos : comparaison de stratégies — 29 octobre 2026

60 simulations déterministes : 3 difficultés × 4 politiques × 5 graines (742 à 746). Équipe initiale, niveaux initiaux, soins limités au stock réel. Aucun dégât ni objectif forcé. Les commandes et les deux travaux de spécialistes utilisent les mécanismes réels.

| Difficulté | Politique | Extractions | Soins moyens |
|---|---|---:|---:|
| easy | automatic | 5/5 | 2.0 |
| easy | focus | 5/5 | 2.0 |
| easy | abilities | 5/5 | 1.0 |
| easy | cover | 5/5 | 0.8 |
| normal | automatic | 5/5 | 2.0 |
| normal | focus | 5/5 | 2.0 |
| normal | abilities | 5/5 | 2.0 |
| normal | cover | 5/5 | 1.8 |
| hard | automatic | 1/5 | 2.0 |
| hard | focus | 2/5 | 2.0 |
| hard | abilities | 5/5 | 2.0 |
| hard | cover | 5/5 | 2.0 |

`automatic` garde les tirs automatiques ; `focus` concentre les tirs sur les gardes puis le boss ; `abilities` ajoute les capacités disponibles ; `cover` ajoute un placement initial à couvert avec ligne de tir. Toutes les politiques tentent de soigner le membre le plus blessé sous 55 % de PV et lancent les travaux nécessaires.

Décision : conserver les valeurs de combat. Les capacités distinguent déjà nettement les stratégies en difficile. Cinq graines par cas ne permettent pas d'estimer un taux de victoire humain. Le placement à couvert combine aussi les capacités : ses résultats ne mesurent donc pas l'effet isolé du couvert. Le banc ne teste pas une stratégie autonome de repli : il compte les replis forcés et arrête après deux.

Les durées JSON sont du temps simulé avec décisions instantanées ; elles ne mesurent ni la lecture, ni l'exploration humaine, ni la durée d'une session. Le banc vérifie le retour physique au DHD après récupération ; la validation finale d'extraction relève des tests de mission existants.

Améliorations appliquées : bouton Aide contextuel dans le panneau d'objectif, consultation en pause, rappel de la protection des spécialistes et de l'extraction. Rapatriement forcé : perte uniquement sur les gains depuis le départ, à 0/25/50 % selon la difficulté, arrondie au-dessous. Les anciens checkpoints sans réserve initiale prennent la réserve à la reprise comme référence. Retour volontaire sans pénalité de ressources, mission à refaire ; sauvegarde et sortie permettent de reprendre.

Reproduction :

```sh
/root/.local/opt/godot47 --headless --path . res://dev/abydos_balance.tscn -- --samples=5 --output=/tmp/sg1-abydos-balance.json
```

À vérifier sur téléphone : compréhension des conseils sans intervention, confort du ciblage tactile, envie d'utiliser les capacités, rythme de l'exploration et lisibilité pendant le combat.
