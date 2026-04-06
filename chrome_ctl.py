#!/usr/bin/env python3
import websocket
import json
import sys
import base64

PAGE_WS = "ws://172.29.32.1:19222/devtools/page/D6CD2CF5907C9ACD183DD4F5F7414E1A"

ws = websocket.create_connection(PAGE_WS, timeout=10)
print("Connected!")

if len(sys.argv) > 1:
    url = sys.argv[1]
    ws.send(json.dumps({"id": 1, "method": "Page.navigate", "params": {"url": url}}))
    import time; time.sleep(4)

ws.send(json.dumps({"id": 2, "method": "Page.captureScreenshot", "params": {"format": "png"}}))
# Receive responses
for _ in range(3):
    resp = ws.recv()
    data = json.loads(resp)
    if data.get("id") == 2 and "result" in data and "data" in data["result"]:
        img_data = base64.b64decode(data["result"]["data"])
        with open("/home/louyz/.openclaw/workspace/screenshot.png", "wb") as f:
            f.write(img_data)
        print("Screenshot saved!")
        break
    else:
        print("Received:", data)

ws.close()
