# Device Authorization Grant (IoT) – cURL Walkthrough

> Prereqs: realm imported, client `device-bootstrap` exists with Device Flow enabled.

## 1) Obtain Device Code
```bash
KC_BASE=http://localhost:8080
REALM=event-platform-organizations
CLIENT_ID=device-bootstrap

curl -sS -X POST "$KC_BASE/realms/$REALM/protocol/openid-connect/device/auth" \
  -d "client_id=$CLIENT_ID" \
  -d "scope=openid organization" | tee .device_resp.json
jq . .device_resp.json
```

Output contains `device_code`, `user_code`, and `verification_uri_complete`.

## 2) User Verification (separate browser)

Open the `verification_uri_complete` and sign in as an operator/admin. Approve the device.

## 3) Poll for Token

```bash
DEVICE_CODE=$(jq -r '.device_code' .device_resp.json)
curl -sS -X POST "$KC_BASE/realms/$REALM/protocol/openid-connect/token" \
  -d "grant_type=urn:ietf:params:oauth:grant-type:device_code" \
  -d "device_code=$DEVICE_CODE" \
  -d "client_id=$CLIENT_ID" | tee .device_token.json
jq . .device_token.json
```

## 4) Call Protected API with Access Token

```bash
ACCESS_TOKEN=$(jq -r '.access_token' .device_token.json)
curl -sS http://localhost:4000/protected -H "Authorization: Bearer $ACCESS_TOKEN"
```