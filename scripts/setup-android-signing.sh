#!/usr/bin/env bash
# One-time setup: creates the Android upload keystore, writes
# android/key.properties for local release builds, and stores the keystore
# and its password as GitHub Actions secrets for CI.
#
# The keystore lives outside the repo in ~/.config/home-expense/. Back it up:
# if it's lost, installed apps can't be updated in place (uninstall + reinstall
# fixes it; data is in Firestore so nothing is lost).
set -euo pipefail

repo_root="$(cd "$(dirname "$0")/.." && pwd)"
key_dir="$HOME/.config/home-expense"
keystore="$key_dir/upload-keystore.jks"
props="$repo_root/android/key.properties"

if [[ -e "$keystore" ]]; then
  echo "Keystore already exists at $keystore. Not overwriting." >&2
  exit 1
fi

mkdir -p "$key_dir"
chmod 700 "$key_dir"

KS_PW="$(openssl rand -hex 24)"
export KS_PW

keytool -genkeypair -keystore "$keystore" -storetype JKS -keyalg RSA -keysize 2048 \
  -validity 10000 -alias upload -storepass:env KS_PW -keypass:env KS_PW \
  -dname "CN=Home Expense, O=Personal"

umask 077
cat > "$props" <<PROPS
storeFile=$keystore
storePassword=$KS_PW
keyAlias=upload
keyPassword=$KS_PW
PROPS
cp "$props" "$key_dir/key.properties.backup"

cd "$repo_root"
base64 -i "$keystore" | gh secret set ANDROID_KEYSTORE_BASE64
printf %s "$KS_PW" | gh secret set ANDROID_KEYSTORE_PASSWORD

echo "Done. Keystore: $keystore (back this folder up)."
