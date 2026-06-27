#!/bin/bash
set -e

echo "=== Raspberry Pi Environment Setup ==="
echo ""

echo "Enter Grafana credentials:"
read -p "Admin username: " GF_USERNAME
read -s -p "Admin password: " GF_PASSWORD
echo ""

cat > .env.grafana << EOF
GF_SECURITY_ADMIN_USER=${GF_USERNAME}
GF_SECURITY_ADMIN_PASSWORD=${GF_PASSWORD}
GF_USERS_ALLOW_SIGN_UP=false
EOF

echo "✓ .env.grafana created"
echo ""
echo "Done. Review with: cat .env.grafana"