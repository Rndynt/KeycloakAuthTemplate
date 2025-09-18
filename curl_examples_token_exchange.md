# Standard Token Exchange – cURL Walkthrough (KC ≥ 26.2)

## Setup

* Two confidential clients: `api-a` (source) with service account; `api-b` (target audience).

## 1) Get token from api-a (client_credentials)

```bash
KC_BASE=http://localhost:8080
REALM=event-platform-organizations

curl -sS -X POST "$KC_BASE/realms/$REALM/protocol/openid-connect/token" \
  -d "grant_type=client_credentials" \
  -d "client_id=api-a" \
  -d "client_secret=YOUR_API_A_SECRET" | tee .token_a.json
jq . .token_a.json
```

## 2) Exchange token for api-b audience

```bash
SUBJECT_TOKEN=$(jq -r '.access_token' .token_a.json)

curl -sS -X POST "$KC_BASE/realms/$REALM/protocol/openid-connect/token" \
  -d "grant_type=urn:ietf:params:oauth:grant-type:token-exchange" \
  -d "client_id=api-a" \
  -d "client_secret=YOUR_API_A_SECRET" \
  -d "subject_token=$SUBJECT_TOKEN" \
  -d "subject_token_type=urn:ietf:params:oauth:token-type:access_token" \
  -d "audience=api-b" | tee .token_exchanged.json
jq . .token_exchanged.json
```

## 3) Compare token claims

```bash
echo "Original token (api-a):"
echo "$SUBJECT_TOKEN" | cut -d. -f2 | base64 -d | jq .

echo "Exchanged token (api-b audience):"
EXCHANGED_TOKEN=$(jq -r '.access_token' .token_exchanged.json)
echo "$EXCHANGED_TOKEN" | cut -d. -f2 | base64 -d | jq .
```

The exchanged token should have `"aud": "api-b"` and potentially different claims/scopes.