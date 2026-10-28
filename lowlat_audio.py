#!/usr/bin/env python3
"""Garde au moins 32 Kio de marge pour la sortie audio Android.

Le tampon de 16 Kio était trop fragile lorsque le rendu sollicite le téléphone.
Ne réduit jamais un tampon existant et ne suspend jamais la sortie partagée.
"""
import fcntl
import os
import sys

F_SETPIPE_SZ, F_GETPIPE_SZ = 1031, 1032
SIZE = 32768


def configure_pipe():
    path = os.path.join(os.environ.get("XDG_RUNTIME_DIR", "/run/user/0"), "audio.fifo")
    try:
        fd = os.open(path, os.O_WRONLY | os.O_NONBLOCK)
    except OSError:
        return
    try:
        if fcntl.fcntl(fd, F_GETPIPE_SZ) < SIZE:
            fcntl.fcntl(fd, F_SETPIPE_SZ, SIZE)
    except OSError as error:
        print(f"Audio : tampon inchangé ({error}).", file=sys.stderr)
    finally:
        os.close(fd)


if __name__ == "__main__":
    configure_pipe()
