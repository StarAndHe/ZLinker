import json, os, sys, requests, google.auth.transport.requests
from google.oauth2 import service_account

PKG = 'org.songsong.zlinker'
DIR = 'docs/store/googleplay'
sa = json.loads(os.environ['PLAY_SA'])
creds = service_account.Credentials.from_service_account_info(
    sa, scopes=['https://www.googleapis.com/auth/androidpublisher'])
creds.refresh(google.auth.transport.requests.Request())
TK = creds.token
H = {'Authorization': 'Bearer ' + TK}
API = 'https://androidpublisher.googleapis.com'

r = requests.post(f'{API}/androidpublisher/v3/applications/{PKG}/edits', headers=H).json()
edit = r['id']
print('edit:', edit)

def up(lang, kind, path):
    url = f'{API}/upload/androidpublisher/v3/applications/{PKG}/edits/{edit}/listings/{lang}/{kind}'
    with open(path, 'rb') as f:
        out = requests.post(url, headers={'Authorization': 'Bearer ' + TK,
                                          'Content-Type': 'image/png'}, data=f).json()
    ok = 'image' in out
    print(kind, lang, os.path.basename(path), '->', 'OK' if ok else out)

for lang in ['zh-CN', 'en-US']:
    up(lang, 'icon', f'{DIR}/icon/play-icon-512.png')
for f in sorted(os.listdir(f'{DIR}/screenshots/phone')):
    lang = 'zh-CN' if '-zh.' in f else 'en-US'
    up(lang, 'phoneScreenshots', f'{DIR}/screenshots/phone/{f}')
for f, lang in [('feature-graphic-zh.png','zh-CN'), ('feature-graphic-en.png','en-US')]:
    up(lang, 'featureGraphic', f'{DIR}/feature-graphic/{f}')

out = requests.post(f'{API}/androidpublisher/v3/applications/{PKG}/edits/{edit}:commit', headers=H)
print('commit:', out.status_code, out.text[:120])
