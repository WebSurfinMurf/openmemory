#!/bin/bash
# OpenMemory OAuth2 Setup Script
# Generates secrets for OAuth2 proxy

set -e

SECRETS_FILE="/home/administrator/projects/secrets/openmemory-oauth2.env"

echo "Generating OAuth2 secrets..."

# Generate cookie secret
COOKIE_SECRET=$(openssl rand -base64 32 | tr -d '\n')
sed -i "s/OAUTH2_PROXY_COOKIE_SECRET=PLACEHOLDER_WILL_BE_GENERATED/OAUTH2_PROXY_COOKIE_SECRET=$COOKIE_SECRET/" "$SECRETS_FILE"
echo "✓ Cookie secret generated"

echo ""
echo "=========================================="
echo "Next Steps:"
echo "=========================================="
echo ""
echo "1. Create Keycloak client for openmemory-ui:"
echo "   - Go to https://keycloak.ai-servicers.com/admin"
echo "   - Click Clients → Create client"
echo "   - Client ID: openmemory-ui"
echo "   - Client type: OpenID Connect"
echo "   - Client authentication: ON"
echo "   - Valid redirect URIs: https://openmemory.ai-servicers.com/*"
echo ""
echo "2. Get the client secret from Keycloak:"
echo "   - Go to Clients → openmemory-ui → Credentials"
echo "   - Copy the Client secret"
echo ""
echo "3. Update the secrets file:"
echo "   vi $SECRETS_FILE"
echo "   Replace PLACEHOLDER_WILL_BE_GENERATED for CLIENT_SECRET"
echo ""
echo "4. Start the services:"
echo "   cd /home/administrator/projects/openmemory"
echo "   docker compose up -d"
echo ""
