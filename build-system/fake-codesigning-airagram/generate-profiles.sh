#!/bin/bash
# Regenerates the self-signed provisioning profiles this fork builds with.
#
# The profiles that ship in build-system/fake-codesigning are bound to
# C67CF9S4VU.ph.telegra.Telegraph. Building against that bundle id makes
# Telegram/BUILD emit entitlements Apple only grants to the official app
# (unrestricted voip, carplay, associated domains, notification filtering),
# which no ordinary certificate can re-sign - the app then dies at launch.
# These profiles carry our own identifiers instead, so the build stays
# re-signable.
#
# Each profile embeds the signing certificate under DeveloperCertificates:
# rules_apple's codesigningtool reads that key to work out which identity to
# sign with, and raises KeyError without it.
set -e

DIR="$(cd "$(dirname "$0")" && pwd)"
TEAM_ID="AIRAGRM001"
BUNDLE_ID="org.a74d5e43279953af.airagram"
APP_GROUP="group.${BUNDLE_ID}"

KEY="$(mktemp)"
CERT="$(mktemp)"
trap 'rm -f "$KEY" "$CERT"' EXIT

# -legacy: the p12 is encrypted with RC2-40-CBC, which OpenSSL 3 only offers
# through the legacy provider.
openssl pkcs12 -legacy -in "$DIR/certs/SelfSigned.p12" -nocerts -nodes -passin pass: -out "$KEY" 2>/dev/null
openssl pkcs12 -legacy -in "$DIR/certs/SelfSigned.p12" -clcerts -nokeys -passin pass: -out "$CERT" 2>/dev/null

CERT_B64="$(openssl x509 -in "$CERT" -outform DER | openssl base64 -A)"

gen() {
  local outname="$1" suffix="$2" has_aps="$3" uuidnum="$4"
  local aps_block=""
  if [ "$has_aps" = "yes" ]; then
    aps_block="		<key>aps-environment</key>
		<string>development</string>
"
  fi
  local src="$(mktemp)"
  cat > "$src" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
	<key>AppIDName</key>
	<string>Airagram${suffix}</string>
	<key>ApplicationIdentifierPrefix</key>
	<array>
		<string>${TEAM_ID}</string>
	</array>
	<key>CreationDate</key>
	<date>2026-09-22T00:00:00Z</date>
	<key>DeveloperCertificates</key>
	<array>
		<data>${CERT_B64}</data>
	</array>
	<key>Entitlements</key>
	<dict>
		<key>application-identifier</key>
		<string>${TEAM_ID}.${BUNDLE_ID}${suffix}</string>
${aps_block}		<key>beta-reports-active</key>
		<true/>
		<key>com.apple.developer.team-identifier</key>
		<string>${TEAM_ID}</string>
		<key>com.apple.security.application-groups</key>
		<array>
			<string>${APP_GROUP}</string>
		</array>
		<key>get-task-allow</key>
		<false/>
		<key>keychain-access-groups</key>
		<array>
			<string>${TEAM_ID}.*</string>
			<string>com.apple.token</string>
		</array>
	</dict>
	<key>ExpirationDate</key>
	<date>2030-09-22T00:00:00Z</date>
	<key>IsXcodeManaged</key>
	<false/>
	<key>Name</key>
	<string>airagram ${BUNDLE_ID}${suffix}</string>
	<key>Platform</key>
	<array>
		<string>iOS</string>
	</array>
	<key>TeamIdentifier</key>
	<array>
		<string>${TEAM_ID}</string>
	</array>
	<key>TeamName</key>
	<string>Airagram</string>
	<key>TimeToLive</key>
	<integer>1461</integer>
	<key>UUID</key>
	<string>0000AAAA-0000-0000-0000-${uuidnum}</string>
	<key>Version</key>
	<integer>1</integer>
</dict>
</plist>
EOF
  openssl smime -sign -signer "$CERT" -inkey "$KEY" -certfile "$CERT" -nodetach -outform der \
    -in "$src" -out "$DIR/profiles/$outname.mobileprovision"
  rm -f "$src"
  echo "  $outname.mobileprovision"
}

echo "generating profiles for ${TEAM_ID}.${BUNDLE_ID}"
gen "Telegram" "" "yes" "000000000001"
gen "Share" ".Share" "no" "000000000002"
gen "Widget" ".Widget" "no" "000000000003"
gen "NotificationService" ".NotificationService" "no" "000000000004"
gen "NotificationContent" ".NotificationContent" "no" "000000000005"
gen "Intents" ".SiriIntents" "no" "000000000006"
gen "BroadcastUpload" ".BroadcastUpload" "no" "000000000007"
gen "WatchApp" ".watchkitapp" "no" "000000000008"
gen "WatchExtension" ".watchkitapp.watchkitextension" "no" "000000000009"
