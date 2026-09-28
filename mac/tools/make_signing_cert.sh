#!/bin/bash
# Once per Mac that builds releases: a self-signed code-signing certificate in the login keychain, named
# "GoblinCamp Code Signing". build.sh signs with it when it is there.
#
# Why: a build signed ad hoc ("codesign --sign -") is known to macOS only by the hash of that very build, so after every
# update the Keychain asks again for the password before the app can read its sign-in ("永遠允許" held for one build
# only). Signed with the same certificate every time, the app stays the same app to macOS and "永遠允許" keeps.
#
# Keep the certificate: a release signed with a different one is again a stranger to everyone's Keychain.
# Back it up with:  security export -k login.keychain-db -t identities -f pkcs12 -o GoblinCampSigning.p12
set -euo pipefail

NAME="GoblinCamp Code Signing"
if security find-certificate -c "$NAME" >/dev/null 2>&1; then
    echo "「${NAME}」已經在鑰匙圈裡了，不用再建。"
    exit 0
fi

TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT
cat > "$TMP/cert.cnf" <<EOF
[req]
distinguished_name = dn
x509_extensions = ext
prompt = no
[dn]
CN = $NAME
[ext]
basicConstraints = critical, CA:false
keyUsage = critical, digitalSignature
extendedKeyUsage = critical, codeSigning
EOF
openssl req -x509 -newkey rsa:2048 -nodes -days 7300 -config "$TMP/cert.cnf" -keyout "$TMP/key.pem" -out "$TMP/cert.pem" 2>/dev/null
PASS="$(openssl rand -hex 16)"
openssl pkcs12 -export -inkey "$TMP/key.pem" -in "$TMP/cert.pem" -name "$NAME" -out "$TMP/id.p12" -passout "pass:$PASS" $(openssl version | grep -q "^OpenSSL 3" && echo -legacy) 2>/dev/null
# -T: codesign may use the key without asking each time
security import "$TMP/id.p12" -k "$HOME/Library/Keychains/login.keychain-db" -P "$PASS" -T /usr/bin/codesign >/dev/null
echo "建好了：「${NAME}」（20 年有效）。之後 ./build.sh 都會用它簽名。"
echo "記得備份（換電腦時要用同一張）：security export -k login.keychain-db -t identities -f pkcs12 -o GoblinCampSigning.p12"
