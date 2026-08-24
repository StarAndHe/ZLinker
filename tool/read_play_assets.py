import json, os, requests, google.auth.transport.requests
from google.oauth2 import service_account
PKG = 'org.songsong.zlinker'
sa = json.loads(os.environ['PLAY_SA'])
creds = service_account.Credentials.from_service_account_info(
    sa, scopes=['https://www.googleapis.com/auth/androidpublisher'])
creds.refresh(google.auth.transport.requests.Request())
TK = creds.token
API = 'https://androidpublisher.googleapis.com'
r = requests.post(f'{API}/androidpublisher/v3/applications/{PKG}/edits', headers={'Authorization': f'Bearer {TK}'}).json()
edit = r['id']
for lang in ['zh-CN', 'en-US']:
    out = requests.get(f'{API}/androidpublisher/v3/applications/{PKG}/edits/{edit}/listings/{lang}', headers={'Authorization': f'Bearer {TK}'}).json()
    print(f"{lang}: title={out.get('title','?')!r} short_len={len(out.get('shortDescription',''))} full_len={len(out.get('fullDescription',''))}")
    for kind in ['icon','featureGraphic','phoneScreenshots']:
        out = requests.get(f'{API}/androidpublisher/v3/applications/{PKG}/edits/{edit}/listings/{lang}/images/{kind}', headers={'Authorization': f'Bearer {TK}'}).json()
        print(f'  {kind}: {len(out.get("images",[]))}')
