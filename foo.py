#!/usr/bin/env python3
import os, requests

API_KEY  = os.environ["RUNPOD_API_KEY"]
ENDPOINT = os.environ["ENDPOINT_ID"]
BASE     = f"https://api.runpod.ai/v2/{ENDPOINT}"
hdrs     = {"Authorization": f"Bearer {API_KEY}", "Content-Type":"application/json"}

def handler(input):
    # ignore input, immediately return a hello
    return {"message": "hello world"}


# 1) Health
r = requests.get(f"{BASE}/health", headers=hdrs, timeout=10)
print("HEALTH:", r.status_code, r.text)

## 2) RunSync
r = requests.post(f"{BASE}/runsync", headers=hdrs, json={"input":{}}, timeout=60)
print("RUNSYNC:", r.status_code, r.text)
