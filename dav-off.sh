#!/bin/bash
# dav-off.sh
# Usage: ./dav-off.sh <project-name>

set -e

PROJECT="$1"
if [ -z "$PROJECT" ]; then
    echo "Usage: $0 <project-name> (only lowercase characters, dashes, numbers)"
    exit 1
fi

read -p "WebDAV username: " USERNAME
read -s -p "WebDAV password: " PASSWORD
echo

mkdir -p "$PROJECT"
cd "$PROJECT"

# ------------------------
# Dockerfile
# ------------------------
cat > Dockerfile <<EOF
FROM apachewebdav/apachewebdav:latest

COPY init.sh /init.sh
COPY fix.conf /usr/local/apache2/conf/conf-enabled/fix.conf

RUN chmod +x /init.sh

ENV FLY_PROJECT=$PROJECT

ENTRYPOINT ["/init.sh"]
EXPOSE 80
EOF

# ------------------------
# fly.toml
# ------------------------
cat > fly.toml <<EOF
app = "$PROJECT"

[build]
  dockerfile = "Dockerfile"

[http_service]
  internal_port = 80
  force_https = false

[[mounts]]
  source = "data_volume"
  destination = "/data"
EOF

# ------------------------
# fix.conf
# ------------------------
cat > fix.conf <<'EOF'
DocumentRoot "/data/projects"

<Directory "/data/projects">
    Options Indexes
    Require all granted
</Directory>

<Location />
    DAV On
    AuthType Basic
    AuthName "WebDAV"
    AuthUserFile /user.passwd
    Require valid-user
</Location>
EOF

# ------------------------
# init.sh
# ------------------------
cat > init.sh <<'EOF'
#!/bin/sh
set -e

echo "Initializing WebDAV…"

# Ensure mounted data dir exists
mkdir -p /data/projects
chmod -R 777 /data/projects

# Create Apache DavLock in real location
mkdir -p /var/lib/dav
touch /var/lib/dav/DavLock
chmod 666 /var/lib/dav/DavLock

# Create auth file
if [ ! -f /user.passwd ]; then
    if [ -n "$WEBDAV_USER" ] && [ -n "$WEBDAV_PASSWORD" ]; then
        htpasswd -cb /user.passwd "$WEBDAV_USER" "$WEBDAV_PASSWORD"
        echo "Created /user.passwd"
    else
        echo "Missing WEBDAV_USER / WEBDAV_PASSWORD"
        exit 1
    fi
fi
chmod 644 /user.passwd

# Create the welcome file in data dir
WELCOME_FILE="/data/projects/welcome.txt"

if [ ! -f "$WELCOME_FILE" ]; then
    NOW="$(date)"

    cat > "$WELCOME_FILE" <<WELCOME_EOF
Welcome to your WebDAV folder!

Project: ${FLY_PROJECT:-unknown}
User: ${WEBDAV_USER:-unknown}
Created on: $(date -u +"%Y-%m-%d %H:%M:%S UTC")
Ready to use!
WELCOME_EOF

    chmod 644 "$WELCOME_FILE"
fi

# Symlink data dir into Apache's expected path
rm -rf /var/lib/dav/data
ln -s /data/projects /var/lib/dav/data

# Start Apache
exec httpd-foreground
EOF

chmod +x init.sh

# ------------------------
# verify.sh
# ------------------------
cat > verify.sh <<'EOF'
#!/bin/bash
# verify.sh — proper WebDAV verification
# Usage: ./verify.sh <url> <username>

set -e

URL="$1"
USER="$2"

if [ -z "$URL" ] || [ -z "$USER" ]; then
    echo "Usage: $0 <url> <username>"
    exit 1
fi

echo "Verifying WebDAV at $URL"
echo

# Ask password ONCE
read -s -p "Password for $USER: " PASS
echo

AUTH="$USER:$PASS"

# ------------------------
# 1. Basic GET check
# ------------------------
STATUS=$(curl -s -o /dev/null -w "%{http_code}" -u "$AUTH" "$URL/")

if [[ "$STATUS" =~ ^2 ]]; then
    echo "✅ GET works (HTTP $STATUS)"
else
    echo "❌ GET failed (HTTP $STATUS)"
    exit 1
fi

# ------------------------
# 2. PROPFIND (WebDAV check)
# ------------------------
DAV_STATUS=$(curl -s -o response.xml -w "%{http_code}" \
    -u "$AUTH" \
    -X PROPFIND \
    -H "Depth: 1" \
    "$URL/")

if [ "$DAV_STATUS" != "207" ]; then
    echo "❌ PROPFIND failed (HTTP $DAV_STATUS)"
    echo "Response:"
    cat response.xml
    exit 1
fi

echo "✅ PROPFIND works (HTTP 207)"

# ------------------------
# 3. Validate XML safely
# ------------------------
if command -v xmllint >/dev/null 2>&1; then
    if xmllint --noout response.xml 2>/dev/null; then
        echo "✅ XML response is valid"
    else
        echo "⚠️ XML response is not well-formed"
    fi
else
    echo "ℹ️ xmllint not installed, skipping XML validation"
fi

# ------------------------
# 4. Check welcome file exists
# ------------------------
WELCOME_STATUS=$(curl -s -o /dev/null -w "%{http_code}" \
    -u "$AUTH" \
    "$URL/welcome.txt")

if [[ "$WELCOME_STATUS" =~ ^2 ]]; then
    echo "✅ welcome.txt accessible"
else
    echo "⚠️ welcome.txt missing (HTTP $WELCOME_STATUS)"
fi

# ------------------------
# Done
# ------------------------
echo
echo "------------------------------------------------"
echo " ✅ WebDAV verification complete. Positive Rate."
echo " 🧑‍✈️ Checklist complete. You have the controls."
echo "------------------------------------------------"
EOF

chmod +x verify.sh

# ------------------------
# DEPLOY.md
# ------------------------
cat > DEPLOY.md <<EOF
# Deploy WebDAV project $PROJECT

## 1. Create app
\`\`\`bash
fly apps create $PROJECT
\`\`\`

## 2. Create volume
\`\`\`bash
fly volumes create data_volume --region fra
\`\`\`

## 3. Set credentials (password masked)
\`\`\`bash
fly secrets set WEBDAV_USER=$USERNAME WEBDAV_PASSWORD=********
\`\`\`

## 4. Deploy
\`\`\`bash
fly deploy
\`\`\`

## 5. Verify server
\`\`\`bash
./verify.sh https://$PROJECT.fly.dev $USERNAME
\`\`\`

## Expected behavior
- First request → 401 (login prompt)
- After login → WebDAV works
- Welcome file \`/welcome.txt\` should exist
- PROPFIND → HTTP 2xx

## Useful commands
- \`fly logs -a <projectname>\`
- \`fly ssh console -a <projectname>\`
- \`fly deploy --local-only\` | \`--remote-only\` | \`--depot=false\`
- \`fly certs add example.com\` (add domain to cert and view DNS config)
- \`fly certs setup -a <projectname> <hostname>\` (view setup options)
- \`fly certs check -a <projectname> <hostname>\`
- \`grep fly DEPLOY.md\` (list of fly commands contained in DEPLOY.md)
EOF

echo ""
echo "✅ Project $PROJECT generated"
echo "👉 cd $PROJECT && follow DEPLOY.md"
