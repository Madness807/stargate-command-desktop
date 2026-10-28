# Milky Way Stargate

Title: Milky Way Stargate | Stargate SG-1
Author: Anquietas System
Author profile: https://sketchfab.com/anquietas-sys
Source: https://sketchfab.com/3d-models/milky-way-stargate-stargate-sg-1-517b56e322a548ac81dd8454dbbd95bf
License: Creative Commons Attribution-NonCommercial 4.0
License URL: https://creativecommons.org/licenses/by-nc/4.0/

The user downloaded and supplied the GLB. Its embedded asset metadata identifies the author, source and license above. The original received file is retained in imports/; milky_way.glb is a byte-for-byte copy.

Modifications for this project:
- Materials/textures retained, with albedo dimensions capped at 2048 pixels and data maps at 1024 pixels and mipmaps regenerated for mobile memory usage.
- A compressed Godot scene, mobile.scn, stores this prepared version so resizing is not repeated at launch.
- Model normalized to a 6.70 m frame diameter.
- Rotating glyph ring connected to the game's dialing sequence.
- Separate chevron light meshes connected to per-gate off/on materials.
- Author's master-chevron morph connected to the locking sequence.
- Existing project event horizon, kawoosh and iris retained.

Rebuild mobile.scn with scripts/imported_gate.gd after moving an old prepared scene aside. The runtime retains a procedural fallback if the asset cannot be loaded.
