#!/usr/bin/env python3
"""Receive a user-selected Android download through a loopback-only upload page."""
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path
from urllib.parse import unquote, urlsplit
import json
import os
import secrets

DEST = Path('/root/games/sg1-3d/imports')
TOKEN = secrets.token_urlsafe(18)
PAGE = '''<!doctype html><html lang="fr"><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1"><title>Importer la porte Stargate</title><style>body{font:18px system-ui;background:#101820;color:#e5edf4;margin:0;padding:28px;max-width:600px}h1{font-size:28px}p{line-height:1.5;color:#bdcad5}input,button{font:inherit;max-width:100%;margin:16px 0}button{display:block;background:#edaf4c;border:0;padding:14px 20px;color:#111}progress{width:100%}#status{white-space:pre-wrap}</style><h1>Importer la porte Stargate</h1><p>Choisis le fichier téléchargé sur Android. Pour glTF, envoie le ZIP complet contenant le modèle et ses textures.</p><input id="file" type="file" accept=".zip,.glb,.gltf,.7z,.fbx"><button id="send">Envoyer le fichier</button><progress id="progress" value="0" max="100"></progress><p id="status">Le fichier sera copié dans le dossier du jeu.</p><script>const file=document.querySelector('#file'),button=document.querySelector('#send'),status=document.querySelector('#status'),progress=document.querySelector('#progress');button.onclick=()=>{if(!file.files.length){status.textContent='Choisis un fichier dans Téléchargements.';return;}const f=file.files[0];button.disabled=true;const req=new XMLHttpRequest();req.open('POST',location.pathname+'/upload');req.setRequestHeader('X-File-Name',encodeURIComponent(f.name));req.upload.onprogress=e=>{if(e.lengthComputable)progress.value=e.loaded/e.total*100;};req.onload=()=>{button.disabled=false;try{const data=JSON.parse(req.responseText);status.textContent=data.message;if(req.status===201)progress.value=100;}catch{status.textContent='Le transfert a échoué. Réessaie.';}};req.onerror=()=>{button.disabled=false;status.textContent='Connexion interrompue. Réessaie.';};status.textContent='Transfert en cours…';req.send(f);};</script></html>'''

class Handler(BaseHTTPRequestHandler):
    def reply(self, code, body, content_type='application/json; charset=utf-8'):
        if not isinstance(body, bytes):
            body = json.dumps({'message': body}, ensure_ascii=False).encode()
        self.send_response(code)
        self.send_header('Content-Type', content_type)
        self.send_header('Content-Length', str(len(body)))
        self.send_header('Cache-Control', 'no-store')
        self.end_headers()
        self.wfile.write(body)

    def do_GET(self):
        if urlsplit(self.path).path != '/' + TOKEN:
            self.reply(404, 'Adresse incorrecte.')
            return
        self.reply(200, PAGE.encode(), 'text/html; charset=utf-8')

    def do_POST(self):
        if self.path != '/' + TOKEN + '/upload':
            self.reply(404, 'Adresse incorrecte.')
            return
        try:
            length = int(self.headers.get('Content-Length', '0'))
        except ValueError:
            length = 0
        if not 0 < length <= 512 * 1024 * 1024:
            self.reply(413, 'Le fichier doit faire entre 1 octet et 512 Mo.')
            return
        name = Path(unquote(self.headers.get('X-File-Name', ''))).name
        if not name or name.startswith('.') or Path(name).suffix.lower() not in {'.zip', '.glb', '.gltf', '.7z', '.fbx'}:
            self.reply(400, 'Choisis le ZIP, GLB ou glTF téléchargé.')
            return
        target = DEST / name
        if target.exists():
            target = DEST / (Path(name).stem + '-' + secrets.token_hex(3) + Path(name).suffix)
        temp = DEST / ('.receiving-' + secrets.token_hex(10))
        self.connection.settimeout(180)
        try:
            with temp.open('xb') as out:
                remaining = length
                while remaining:
                    chunk = self.rfile.read(min(1024 * 1024, remaining))
                    if not chunk:
                        raise ConnectionError('Transfert incomplet')
                    out.write(chunk)
                    remaining -= len(chunk)
            os.replace(temp, target)
            print('RECEIVED ' + str(target) + ' ' + str(length), flush=True)
            self.reply(201, 'Fichier reçu : ' + target.name + '\nTu peux revenir dans la conversation : le modèle est maintenant accessible pour son intégration.')
        except (OSError, ConnectionError):
            temp.unlink(missing_ok=True)
            self.reply(400, 'Transfert interrompu. Réessaie.')

if __name__ == '__main__':
    DEST.mkdir(parents=True, exist_ok=True)
    server = ThreadingHTTPServer(('127.0.0.1', 8765), Handler)
    address = 'http://127.0.0.1:8765/' + TOKEN
    Path('/tmp/sg1-transfer-url.txt').write_text(address)
    print(address, flush=True)
    server.serve_forever()
