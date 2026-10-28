#!/usr/bin/env bash
# Lance SG-1 3D (Godot 4, Vulkan sur l'Adreno, rendu mobile) dans une fenêtre Wayland plein écran.
# Le compositeur du launcher annonce une échelle 2 qu'il n'applique pas aux buffers :
# wlscale1.py relaie Wayland en annonçant une échelle 1 (sinon image zoomée, touches décalées).
export GODOT_SILENCE_ROOT_WARNING=1
export XDG_RUNTIME_DIR="${XDG_RUNTIME_DIR:-/run/user/$(id -u)}"
dir="$(dirname "$(readlink -f "$0")")"
python3 "$dir/lowlat_audio.py" || true
sock="wayland-sg1-$$"
python3 "$dir/wlscale1.py" "$sock" &
relay=$!
trap 'kill $relay 2>/dev/null' EXIT
for _ in $(seq 50); do [ -S "$XDG_RUNTIME_DIR/$sock" ] && break; sleep 0.05; done
WAYLAND_DISPLAY="$sock" "$HOME/.local/opt/godot47" --path "$dir" \
  --display-driver wayland --rendering-driver vulkan --rendering-method mobile "$@"
