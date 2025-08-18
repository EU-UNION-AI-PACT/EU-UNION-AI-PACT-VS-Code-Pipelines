import os, requests, time

VAULT_ADDR = os.getenv("VAULT_ADDR")
ROLE = os.getenv("VAULT_ROLE")
APPROLE_PATH = os.getenv("VAULT_APPROLE_PATH","approle")
ROLE_ID_PATH = "/vault/runtime/role_id"
SECRET_ID_PATH = "/vault/runtime/secret_id"
VAULT_TOKEN_CACHE = {"token": None, "exp": 0}

def _read_file(p):
    with open(p,"r",encoding="utf-8") as f:
        return f.read().strip()

def get_vault_token():
    now = time.time()
    if VAULT_TOKEN_CACHE["token"] and now < VAULT_TOKEN_CACHE["exp"]:
        return VAULT_TOKEN_CACHE["token"]
    role_id = _read_file(ROLE_ID_PATH)
    secret_id = _read_file(SECRET_ID_PATH)
    r = requests.post(f"{VAULT_ADDR}/v1/auth/{APPROLE_PATH}/login",
                      json={"role_id":role_id,"secret_id":secret_id}, timeout=5)
    r.raise_for_status()
    js = r.json()
    ttl = js["auth"]["lease_duration"]
    VAULT_TOKEN_CACHE["token"] = js["auth"]["client_token"]
    VAULT_TOKEN_CACHE["exp"] = now + ttl*0.9
    return VAULT_TOKEN_CACHE["token"]

def kv_get(path="kv/data/app"):
    t = get_vault_token()
    r = requests.get(f"{VAULT_ADDR}/v1/{path}", headers={"X-Vault-Token":t}, timeout=5)
    r.raise_for_status()
    return r.json()["data"]["data"]

def transit_sign(key, payload_bytes:bytes):
    t = get_vault_token()
    import base64
    b64 = base64.b64encode(payload_bytes).decode()
    r = requests.post(f"{VAULT_ADDR}/v1/transit/sign/{key}",
                      headers={"X-Vault-Token":t},
                      json={"input":b64}, timeout=5)
    r.raise_for_status()
    return r.json()["data"]["signature"]

def transit_encrypt(key, payload_bytes:bytes):
    t = get_vault_token()
    import base64
    b64 = base64.b64encode(payload_bytes).decode()
    r = requests.post(f"{VAULT_ADDR}/v1/transit/encrypt/{key}",
                      headers={"X-Vault-Token":t},
                      json={"plaintext":b64}, timeout=5)
    r.raise_for_status()
    return r.json()["data"]["ciphertext"]

def transit_decrypt(key, ciphertext):
    t = get_vault_token()
    r = requests.post(f"{VAULT_ADDR}/v1/transit/decrypt/{key}",
                      headers={"X-Vault-Token":t},
                      json={"ciphertext":ciphertext}, timeout=5)
    r.raise_for_status()
    import base64
    pt_b64 = r.json()["data"]["plaintext"]
    return base64.b64decode(pt_b64)

def db_dynamic_creds():
    t = get_vault_token()
    r = requests.get(f"{VAULT_ADDR}/v1/database/creds/docproc-db-role", headers={"X-Vault-Token":t}, timeout=5)
    r.raise_for_status()
    return r.json()["data"]["username"], r.json()["data"]["password"]
