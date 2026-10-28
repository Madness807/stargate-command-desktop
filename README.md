# Stargate Command Desktop

Projet Stargate SG-1 3D réalisé avec Godot 4.

## Lancer le projet

Ouvrir `project.godot` avec Godot 4 puis lancer la scène principale (`main.tscn`).

Sur l'environnement Android/omalauncher d'origine, `./start.sh` utilise Godot installé dans `~/.local/opt/godot47` et configure le relais Wayland et l'audio.

## Organisation

- `scripts/`, `shaders/` : code du jeu et rendu.
- `assets/` : ressources utilisées par le jeu.
- `imports/` : modèles et archives sources.
- `dev/` : outils, scènes de test, notes et sauvegardes de travail.

Les caches Godot et Python sont exclus de Git. Les fichiers `.import` et `.uid` sont conservés pour préserver les références des ressources.

Les ressources tierces restent soumises à leurs licences et attributions respectives ; leur présence dans ce dépôt ne leur attribue pas une nouvelle licence.
