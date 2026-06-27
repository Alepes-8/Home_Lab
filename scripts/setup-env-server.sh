#!/bin/bash
set -e

echo "=== Homelab Environment Setup ==="
echo ""

echo "Enter staging credentials:"
read -p "APP_ADMIN_USERNAME (staging): " STAGING_USERNAME
read -s -p "APP_ADMIN_PASSWORD (staging): " STAGING_PASSWORD
echo ""
read -s -p "JWT_SECRET (staging): " STAGING_JWT
echo ""

echo ""
echo "Enter prod credentials:"
read -p "APP_ADMIN_USERNAME (prod): " PROD_USERNAME
read -s -p "APP_ADMIN_PASSWORD (prod): " PROD_PASSWORD
echo ""
read -s -p "JWT_SECRET (prod): " PROD_JWT
echo ""

cat > .env.staging << EOF
PORT=5002
MONGO_URI=mongodb://mongo-staging-database:27017/drink
JWT_SECRET=${STAGING_JWT}
APP_ADMIN_USERNAME=${STAGING_USERNAME}
APP_ADMIN_PASSWORD=${STAGING_PASSWORD}
NODE_ENV=staging
LOG_FILE_PATH=/var/log/homelab/drink_api/app.log
EOF

cat > .env.prod << EOF
PORT=5001
MONGO_URI=mongodb://mongo-prod-database:27017/drink
JWT_SECRET=${PROD_JWT}
APP_ADMIN_USERNAME=${PROD_USERNAME}
APP_ADMIN_PASSWORD=${PROD_PASSWORD}
NODE_ENV=production
LOG_FILE_PATH=/var/log/homelab/drink_api/app.log
EOF

echo "✓ .env.staging created"
echo "✓ .env.prod created"
echo ""
echo "Done. Review with: cat .env.staging"