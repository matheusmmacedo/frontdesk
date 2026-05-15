#!/usr/bin/env python3
"""
KLaOS — atualiza foto de perfil do WhatsApp Business (WABA) via Meta Graph API.

Fluxo (2 passos):
  1. Resumable upload — POST /{app_id}/uploads → upload_id
                       POST /upload:{id} com bytes → handle
  2. POST /{phone_number_id}/whatsapp_business_profile com profile_picture_handle

Sem aprovação Meta — atualiza imediatamente.

Uso:
  python waba_set_profile_photo.py <image_path> <phone_number_id> <app_id> <token>
"""

import sys
import os
import json
import urllib.request
import urllib.parse


GRAPH = 'https://graph.facebook.com/v20.0'


def http(method, url, headers=None, data=None):
    req = urllib.request.Request(url, method=method, data=data)
    for k, v in (headers or {}).items():
        req.add_header(k, v)
    try:
        with urllib.request.urlopen(req) as r:
            return r.status, json.loads(r.read().decode('utf-8'))
    except urllib.error.HTTPError as e:
        return e.code, json.loads(e.read().decode('utf-8'))


def main():
    if len(sys.argv) != 5:
        print(__doc__)
        sys.exit(1)

    image_path, phone_number_id, app_id, token = sys.argv[1:]
    size = os.path.getsize(image_path)
    mime = 'image/jpeg' if image_path.lower().endswith(('.jpg', '.jpeg')) else 'image/png'
    fname = os.path.basename(image_path)

    print(f'→ Upload session: {fname} ({size} bytes, {mime})')
    qs = urllib.parse.urlencode({
        'file_name': fname,
        'file_length': str(size),
        'file_type': mime,
        'access_token': token,
    })
    code, body = http('POST', f'{GRAPH}/{app_id}/uploads?{qs}')
    if code != 200:
        print(f'  ✗ {code} {body}')
        sys.exit(2)
    upload_id = body['id']
    print(f'  ✓ upload_id={upload_id}')

    print('→ Sending bytes')
    with open(image_path, 'rb') as f:
        payload = f.read()
    code, body = http(
        'POST',
        f'{GRAPH}/{upload_id}',
        headers={'Authorization': f'OAuth {token}', 'file_offset': '0'},
        data=payload,
    )
    if code != 200:
        print(f'  ✗ {code} {body}')
        sys.exit(3)
    handle = body['h']
    print(f'  ✓ handle={handle[:40]}…')

    print(f'→ Setting profile_picture for phone_number_id={phone_number_id}')
    code, body = http(
        'POST',
        f'{GRAPH}/{phone_number_id}/whatsapp_business_profile',
        headers={
            'Authorization': f'Bearer {token}',
            'Content-Type': 'application/json',
        },
        data=json.dumps({
            'messaging_product': 'whatsapp',
            'profile_picture_handle': handle,
        }).encode('utf-8'),
    )
    if code != 200:
        print(f'  ✗ {code} {body}')
        sys.exit(4)
    print(f'  ✓ {body}')
    print('Done.')


if __name__ == '__main__':
    main()
