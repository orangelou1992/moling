#!/usr/bin/env python3
"""Send SILK voice message via WeChat ILINK API"""
import sys, json, hashlib, base64, struct, os, urllib.request, urllib.error
sys.stdout.reconfigure(encoding='utf-8', errors='replace')

TOKEN = '9a787efabef8@im.bot:0600002fcbf35d345ff1ccf1dddc5978a66e71'
BASE_URL = 'https://ilinkai.weixin.qq.com'
TO_USER = 'liu13453934594'

SILK_PATH = '/tmp/voice_for_liushuping.silk'

def api_post(endpoint, body):
    url = f"{BASE_URL}/{endpoint}"
    data = json.dumps(body).encode('utf-8')
    req = urllib.request.Request(url, data=data)
    req.add_header('Content-Type', 'application/json')
    req.add_header('Authorization', f'Bearer {TOKEN}')
    with urllib.request.urlopen(req, timeout=10) as resp:
        return json.loads(resp.read().decode('utf-8'))

def build_base_info():
    return {
        "os": "windows",
        "device_name": "PC-20240827KKFN",
        "device_version": "10.0.19045",
        "app_version": "3.8.2",
        "obot_type": 3
    }

# Read SILK
with open(SILK_PATH, 'rb') as f:
    silk_data = f.read()
rawsize = len(silk_data)
rawfilemd5 = hashlib.md5(silk_data).hexdigest()

# AES-128-ECB + PKCS7
from Crypto.Cipher import AES
aeskey_bytes = os.urandom(16)
aeskey_hex = aeskey_bytes.hex()
aeskey_b64 = base64.b64encode(aeskey_bytes).decode()

BS = 16
padlen = BS - rawsize % BS
plaintext_padded = silk_data + bytes([padlen] * padlen)
ciphertext = AES.new(aeskey_bytes, AES.MODE_ECB).encrypt(plaintext_padded)
filesize = len(ciphertext)

filekey = os.urandom(16).hex()

print(f"[1] SILK: {rawsize} bytes, ciphertext: {filesize} bytes")

# Step 1: Get upload URL
upload_resp = api_post('ilink/bot/getuploadurl', {
    "filekey": filekey,
    "media_type": 4,  # VOICE
    "to_user_id": TO_USER,
    "rawsize": rawsize,
    "rawfilemd5": rawfilemd5,
    "filesize": filesize,
    "no_need_thumb": True,
    "aeskey": aeskey_hex,
    "base_info": build_base_info()
})
print(f"[2] Upload URL resp: {json.dumps(upload_resp, ensure_ascii=False)[:200]}")

if upload_resp.get('upload_full_url'):
    upload_url = upload_resp['upload_full_url'].strip()
    print(f"[3] Uploading to: {upload_url}")
    req = urllib.request.Request(upload_url, data=ciphertext)
    req.add_header('Content-Type', 'application/octet-stream')
    with urllib.request.urlopen(req, timeout=15) as resp:
        upload_result = resp.read()
        print(f"[4] Upload result: {upload_result[:100]}")
elif upload_resp.get('upload_param'):
    print(f"[3] Using upload_param (CDN): {upload_resp['upload_param']}")
    # Would need CDN upload logic
    print("[!] CDN upload param path not implemented, trying direct anyway")
else:
    print(f"[!] No upload URL, resp: {upload_resp}")
