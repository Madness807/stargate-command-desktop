#!/usr/bin/env python3
"""Relais Wayland : fait croire au client que l'écran est à l'échelle 1.

Le compositeur du launcher annonce wl_output.scale = 2 mais affiche les buffers
sans tenir compte de wl_surface.set_buffer_scale : Godot rend alors une image
2x trop grande (zoomée) et les touches tombent à côté. Ici on réécrit chaque
événement wl_output.scale en 1 ; le reste passe tel quel (descripteurs compris).

Usage : wlscale1.py <socket-à-créer>   (se connecte à $WAYLAND_DISPLAY)
"""
import os
import signal
import socket
import struct
import sys
import threading

RUNTIME = os.environ["XDG_RUNTIME_DIR"]
UPSTREAM = os.path.join(RUNTIME, os.environ.get("WAYLAND_DISPLAY", "wayland-0"))
MAX_FDS = 28


def wl_string(buf, off):
    n = struct.unpack_from("<I", buf, off)[0]
    s = bytes(buf[off + 4:off + 4 + n - 1]).decode(errors="replace")
    return s, off + 4 + ((n + 3) & ~3)


class Conn:
    def __init__(self, client):
        self.client = client
        self.server = socket.socket(socket.AF_UNIX, socket.SOCK_STREAM)
        self.server.connect(UPSTREAM)
        self.registries = set()
        self.outputs = set()
        threading.Thread(target=self.pump, args=(client, self.server, self.on_request), daemon=True).start()
        threading.Thread(target=self.pump, args=(self.server, client, self.on_event), daemon=True).start()

    def on_request(self, buf, off, obj, op):
        if obj == 1 and op == 1:  # wl_display.get_registry(new_id)
            self.registries.add(struct.unpack_from("<I", buf, off + 8)[0])
        elif obj in self.registries and op == 0:  # wl_registry.bind(name, interface, version, id)
            iface, p = wl_string(buf, off + 12)
            if iface == "wl_output":
                self.outputs.add(struct.unpack_from("<I", buf, p + 4)[0])

    def on_event(self, buf, off, obj, op):
        if obj in self.outputs and op == 3:  # wl_output.scale(factor)
            struct.pack_into("<i", buf, off + 8, 1)
        elif obj == 1 and op == 1:  # wl_display.delete_id(id)
            i = struct.unpack_from("<I", buf, off + 8)[0]
            self.outputs.discard(i)
            self.registries.discard(i)

    def pump(self, src, dst, hook):
        pending = bytearray()
        held = []
        try:
            while True:
                data, fds, _, _ = socket.recv_fds(src, 65536, MAX_FDS)
                if not data:
                    break
                held += fds
                pending += data
                off = 0
                while len(pending) - off >= 8:
                    obj, word = struct.unpack_from("<II", pending, off)
                    size = word >> 16
                    if size < 8 or len(pending) - off < size:
                        break
                    hook(pending, off, obj, word & 0xFFFF)
                    off += size
                out, pending = bytes(pending[:off]), pending[off:]
                if out and held:
                    n = socket.send_fds(dst, [out], held)
                    for f in held:
                        os.close(f)
                    held = []
                    if n < len(out):
                        dst.sendall(out[n:])
                elif out:
                    dst.sendall(out)
        except OSError:
            pass
        finally:
            for s in (src, dst):
                try:
                    s.shutdown(socket.SHUT_RDWR)
                except OSError:
                    pass


def main():
    path = os.path.join(RUNTIME, sys.argv[1])
    # Tué par le lanceur à la fermeture du jeu : on retire quand même la socket
    signal.signal(signal.SIGTERM, lambda *_: sys.exit(0))
    try:
        os.unlink(path)
    except FileNotFoundError:
        pass
    ls = socket.socket(socket.AF_UNIX, socket.SOCK_STREAM)
    ls.bind(path)
    ls.listen(8)
    try:
        while True:
            c, _ = ls.accept()
            Conn(c)
    finally:
        os.unlink(path)


if __name__ == "__main__":
    main()
