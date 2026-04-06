#!/usr/bin/env python3
"""Send SILK voice message via WeChat ILINK API - using fresh token"""
import sys, json, hashlib, base64, struct, os, urllib.request, urllib.error
sys.stdout.reconfigure(encoding='utf-8', errors='replace')

# Use FRESH token from account file
TOKEN = '3bcffbca8264@im.bot:060000828e9c7c0640d5bfd87d825c45b266bf'
BASE_URL = 'https://ilinkai.weixin.qq.com'
TO_USER = 'liu13453934594'
SILK_PATH = '/tmp/hello_liushuping.silk'

def api_post(endpoint, body_obj):
    url = f"{BASE_URL}/{endpoint}"
    data = json.dumps(body_obj).encode('utf-8')
    req = urllib.request.Request(url, data=data)
    req.add_header('Content-Type', 'application/json')
    req.add_header('Authorization', f'Bearer {TOKEN}')
    try:
        with urllib.request.urlopen(req, timeout=10) as resp:
            return json.loads(resp.read().decode('utf-8'))
    except urllib.error.HTTPError as e:
        return {'errcode': e.code, 'errmsg': str(e)}

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

BS = 16
padlen = BS - rawsize % BS
ciphertext = AES.new(aeskey_bytes, AES.MODE_ECB).encrypt(silk_data + bytes([padlen] * padlen))
filesize = len(ciphertext)
filekey = os.urandom(16).hex()

print(f"[1] SILK: {rawsize} bytes -> ciphertext {filesize} bytes")

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
print(f"[2] Upload URL resp: {json.dumps(upload_resp, ensure_ascii=False)}")
