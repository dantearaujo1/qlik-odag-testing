#!/usr/bin/env bash

# ================================
# QLIK CLOUD ODAG ENDPOINT TESTER
# ================================
# Usage:
#   chmod +x test-odag-endpoints.sh
#   ./test-odag-endpoints.sh <YOUR_JWT>
#
# Example:
#   ./test-odag-endpoints.sh eyJhbGciOiJ...

TENANT_URL="https://danteprod.us.qlikcloud.com"
JWT_TOKEN="$1"

if [ -z "$JWT_TOKEN" ]; then
  echo "❌ Please provide your JWT token as an argument."
  echo "Usage: ./test-odag-endpoints.sh <JWT_TOKEN>"
  exit 1
fi

echo "🔍 Testing ODAG endpoints in tenant: $TENANT_URL"
echo "----------------------------------------------"

ENDPOINTS=(
  "/api/v1/odag"
  "/api/v1/odag/links"
  "/api/v1/odag/requests"
  "/api/v1/odag/links/{linkId}"
  "/api/v1/odag/requests/{requestId}"
  "/api/v1/odagservice"
  "/api/v1/odagservice/links"
  "/api/v1/odagservice/requests"
  "/qrs/odag/v1/links"
  "/qrs/odag/v1/requests"
  "/api/v1/apps"
)

for path in "${ENDPOINTS[@]}"; do
  echo -n "➡️  Checking $path ... "
  STATUS=$(curl -s -o /dev/null -w "%{http_code}" \
    -H "Authorization: Bearer $JWT_TOKEN" \
    -H "Content-Type: application/json" \
    "$TENANT_URL$path")

  if [ "$STATUS" == "200" ] || [ "$STATUS" == "201" ]; then
    echo "✅ Available ($STATUS)"
  elif [ "$STATUS" == "401" ]; then
    echo "🚫 Unauthorized (check JWT permissions)"
    break
  elif [ "$STATUS" == "404" ]; then
    echo "❌ Not found ($STATUS)"
  else
    echo "⚠️  Status: $STATUS"
  fi
done

echo "----------------------------------------------"
echo "🧩 Test complete. Any endpoint with ✅ can be used."
echo "If all returned ❌, ODAG API is not exposed in Qlik Cloud."
