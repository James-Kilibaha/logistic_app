#!/usr/bin/env bash
# Kujenga web app na kuipakia kwenye server (Linux / Mac, kwenye kompyuta yenye Flutter).
#   cd logistic_app && SERVER=user@SERVER_IP bash deploy/upload_web.sh
# Web inatumia API ya domain ile ile iliyoifungua (https://<domain>/api) - haihitaji API_SERVER.
set -euo pipefail
SERVER="${SERVER:?Weka SERVER, mf. SERVER=user@SERVER_IP}"
WEB_DIR="${WEB_DIR:-/var/www/logistic/web}"

flutter build web --release
tar -czf /tmp/logistic_web.tgz -C build/web .
scp /tmp/logistic_web.tgz "$SERVER:/tmp/logistic_web.tgz"
# Toleo jipya linawekwa pembeni kwanza, kisha linabadilishwa mara moja (watumiaji hawaoni ukurasa uliovunjika)
ssh "$SERVER" "set -e; rm -rf '$WEB_DIR.new'; mkdir -p '$WEB_DIR.new'; tar -xzf /tmp/logistic_web.tgz -C '$WEB_DIR.new'; \
  rm -rf '$WEB_DIR.old'; [ -d '$WEB_DIR' ] && mv '$WEB_DIR' '$WEB_DIR.old'; mv '$WEB_DIR.new' '$WEB_DIR'; \
  chmod -R a+rX '$WEB_DIR'; rm -f /tmp/logistic_web.tgz"
echo "Web app imepakiwa. Rudi nyuma (kama kuna tatizo):  ssh $SERVER \"mv $WEB_DIR $WEB_DIR.bad && mv $WEB_DIR.old $WEB_DIR\""
