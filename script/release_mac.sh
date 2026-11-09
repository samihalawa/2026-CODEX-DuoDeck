#!/usr/bin/env bash
# DuoDeck distribution. Resume pins an existing upload; it never builds or submits.
set -euo pipefail
cd "$(dirname "$0")/.."

fail() { echo "Error: $*" >&2; exit 1; }
usage() {
  cat <<'USAGE'
Usage: script/release_mac.sh [--publish]
       script/release_mac.sh [--publish] --resume-notary ID --expected-dmg-sha SHA256

Requires DUODECK_NOTARY_KEY, DUODECK_NOTARY_KEY_ID and DUODECK_NOTARY_ISSUER.
Resume uses dist/DuoDeck-Host-macOS.dmg without rebuilding or uploading it.
Apple's existing job is awaited for at most 3h. A timeout never publishes.
Publishing requires clean, committed main sources already pushed to DuoDeck.
Artifacts and frozen release notes are retained in .build/releases/ for inspection.
USAGE
}
publish=0
resume_notary=""
expected_sha=""
while [ "$#" -gt 0 ]; do
  case "$1" in
    --publish) [ "$publish" = 0 ] || fail "Duplicate --publish."; publish=1; shift ;;
    --resume-notary)
      [ "$#" -ge 2 ] && [ -z "$resume_notary" ] || fail "--resume-notary needs one submission ID."
      [ -n "$2" ] || fail "--resume-notary needs a nonempty submission ID."
      resume_notary="$2"; shift 2 ;;
    --expected-dmg-sha)
      [ "$#" -ge 2 ] && [ -z "$expected_sha" ] || fail "--expected-dmg-sha needs one SHA-256."
      [ -n "$2" ] || fail "--expected-dmg-sha needs a nonempty SHA-256."
      expected_sha="$2"; shift 2 ;;
    --help|-h) usage; exit 0 ;;
    *) echo "Unknown option: $1" >&2; usage >&2; exit 2 ;;
  esac
done
if [ -n "$resume_notary" ]; then
  [[ "$resume_notary" =~ ^[[:xdigit:]]{8}-[[:xdigit:]]{4}-[[:xdigit:]]{4}-[[:xdigit:]]{4}-[[:xdigit:]]{12}$ ]] || fail "Invalid notary submission ID."
  [[ "$expected_sha" =~ ^[[:xdigit:]]{64}$ ]] || fail "Resume requires --expected-dmg-sha with exactly 64 hexadecimal characters."
  resume_notary="$(printf '%s' "$resume_notary" | tr '[:upper:]' '[:lower:]')"
  expected_sha="$(printf '%s' "$expected_sha" | tr '[:upper:]' '[:lower:]')"
elif [ -n "$expected_sha" ]; then
  fail "--expected-dmg-sha is only valid with --resume-notary."
fi

: "${DUODECK_NOTARY_KEY:?Path to your App Store Connect notarization key}"
: "${DUODECK_NOTARY_KEY_ID:?Notarization key ID}"
: "${DUODECK_NOTARY_ISSUER:?Notarization issuer ID}"
[ -r "$DUODECK_NOTARY_KEY" ] || fail "The notarization key file is not readable."
auth=(--key "$DUODECK_NOTARY_KEY" --key-id "$DUODECK_NOTARY_KEY_ID" --issuer "$DUODECK_NOTARY_ISSUER")
repo="samihalawa/2026-CODEX-DuoDeck"
bundle_id="com.agentsai.duodeck.host"
signing_requirement='anchor apple generic and certificate leaf[subject.OU] = "U549N38BV6" and certificate leaf[field.1.2.840.113635.100.6.1.13] exists'
release_commit="$(git rev-parse --verify HEAD)"
require_clean() {
  [ -z "$(git status --porcelain)" ] || fail "Commit the verified release sources before publishing."
  [ "$(git symbolic-ref --quiet --short HEAD)" = main ] || fail "Publish from main."
  [ "$(git rev-parse HEAD)" = "$release_commit" ] || fail "HEAD changed after the release was frozen."
}
[ "$publish" = 0 ] || require_clean
sha256() { /usr/bin/shasum -a 256 "$1" | /usr/bin/awk '{print $1}'; }

# This is the only build/submission branch. Resume cannot enter it.
if [ -z "$resume_notary" ]; then
  ./script/build_and_run.sh --package
fi
source_dmg="$PWD/dist/DuoDeck-Host-macOS.dmg"
[ -f "$source_dmg" ] || fail "The packaged DMG is missing."
pristine_sha="$(sha256 "$source_dmg")"
if [ -n "$resume_notary" ]; then
  [ "$pristine_sha" = "$expected_sha" ] || fail "The DMG does not match --expected-dmg-sha. Nothing was submitted or stapled."
fi

umask 077
mkdir -p .build/releases
stage="$(mktemp -d "$PWD/.build/releases/mac-XXXXXX")"
dmg="$stage/DuoDeck-Host-macOS.dmg"
app="$stage/DuoDeck Host.app"
mountpoint=""
cleanup() {
  if [ -n "$mountpoint" ]; then hdiutil detach "$mountpoint" >/dev/null 2>&1 || true; fi
}
trap cleanup EXIT
trap 'exit 130' INT
trap 'exit 143' TERM
echo "RELEASE_STAGE=$stage"
printf '%s\n' "$release_commit" > "$stage/RELEASE_COMMIT.txt"
printf '%s\n' "$pristine_sha" > "$stage/PRISTINE_DMG_SHA256.txt"
cp "$source_dmg" "$dmg"
[ "$(sha256 "$dmg")" = "$pristine_sha" ] || fail "The staged DMG changed while copying."
codesign --verify --strict "-R=$signing_requirement" "$dmg"

# Derive the ZIP app from the pinned upload, never from a possibly newer dist app.
mountpoint="$stage/mounted"
mkdir "$mountpoint"
hdiutil attach -readonly -nobrowse -mountpoint "$mountpoint" "$dmg" > "$stage/mount.log"
[ -d "$mountpoint/DuoDeck Host.app" ] || fail "The pinned DMG has no DuoDeck Host.app."
ditto "$mountpoint/DuoDeck Host.app" "$app"
hdiutil detach "$mountpoint" > "$stage/detach.log"
mountpoint=""
[ ! -d "$stage/mounted" ] || rmdir "$stage/mounted"

validate_app() {
  [ "$(/usr/libexec/PlistBuddy -c 'Print CFBundleIdentifier' "$app/Contents/Info.plist")" = "$bundle_id" ] || fail "Wrong host bundle identifier."
  [ "$(/usr/libexec/PlistBuddy -c 'Print CFBundleExecutable' "$app/Contents/Info.plist")" = DuoDeckHost ] || fail "Wrong host executable."
  codesign --verify --strict --deep "-R=$signing_requirement and identifier \"$bundle_id\"" "$app"
  local architectures
  architectures="$(/usr/bin/lipo -archs "$app/Contents/MacOS/DuoDeckHost")"
  for arch in arm64 x86_64; do
    [[ " $architectures " == *" $arch "* ]] || fail "The host is missing $arch."
    codesign --display --verbose=4 --architecture "$arch" "$app" 2> "$stage/signature-$arch.txt"
    /usr/bin/grep -Eq 'flags=.*runtime' "$stage/signature-$arch.txt" || fail "$arch lacks hardened runtime."
    /usr/bin/grep -q '^Timestamp=' "$stage/signature-$arch.txt" || fail "$arch lacks a trusted timestamp."
  done
}
validate_app
version="$(/usr/libexec/PlistBuddy -c 'Print CFBundleShortVersionString' "$app/Contents/Info.plist")"
[[ "$version" =~ ^[0-9]+(\.[0-9]+){1,2}$ ]] || fail "The packaged release version is invalid."
tag="v$version"
git show "$release_commit:docs/releases/$version.md" > "$stage/RELEASE_NOTES.md"
[ -s "$stage/RELEASE_NOTES.md" ] || fail "The frozen commit has no release notes for $version."

# A failed lookup is not evidence of absence unless GitHub actually returned 404.
require_no_release() {
  if gh api --include "repos/$repo/releases/tags/$tag" > "$stage/release-lookup.txt" 2> "$stage/release-lookup.err"; then
    fail "$repo already has release $tag. Nothing will be overwritten."
  fi
  /usr/bin/grep -Eq '^HTTP/[0-9.]+ 404([[:space:]]|$)' "$stage/release-lookup.txt" ||
    fail "Could not establish that $tag is absent; inspect $stage/release-lookup.err."
}
check_tag() {
  GIT_TERMINAL_PROMPT=0 git ls-remote --tags "https://github.com/$repo.git" "refs/tags/$tag" "refs/tags/$tag^{}" > "$stage/tag-refs.txt"
  tag_commit="$(/usr/bin/awk -v ref="refs/tags/$tag" '$2 == ref {direct=$1} $2 == ref "^{}" {peeled=$1} END {print peeled != "" ? peeled : direct}' "$stage/tag-refs.txt")"
  [ -z "$tag_commit" ] || [ "$tag_commit" = "$release_commit" ] || fail "$tag already points to another commit."
}
publish_preflight() {
  require_clean
  gh api "repos/$repo" > "$stage/repository.json"
  python3 - "$stage/repository.json" "$repo" <<'PY'
import json, sys
d = json.load(open(sys.argv[1]))
if not (d["full_name"] == sys.argv[2] and d["private"] is False
        and d["default_branch"] == "main" and d.get("permissions", {}).get("push") is True):
    raise SystemExit("Expected the public DuoDeck repository with push access and main as its default branch.")
PY
  [ "$(gh api "repos/$repo/commits/main" --jq .sha)" = "$release_commit" ] || fail "Push the frozen main commit before publishing."
  require_no_release
  check_tag
}
[ "$publish" = 0 ] || publish_preflight

submission="$resume_notary"
if [ -z "$submission" ]; then
  # A failed/ambiguous submit is never retried automatically.
  xcrun notarytool submit "$dmg" "${auth[@]}" --no-s3-acceleration --output-format json > "$stage/notary-submit.json"
  submission="$(python3 -c 'import json,sys; print(json.load(open(sys.argv[1]))["id"])' "$stage/notary-submit.json")"
fi
printf '%s\n' "$submission" > "$stage/NOTARY_SUBMISSION.txt"
echo "NOTARY_SUBMISSION=$submission"
echo "PRISTINE_DMG_SHA256=$pristine_sha"
# Local notarytool help confirms --timeout accepts durations such as 3h.
wait_exit=0
xcrun notarytool wait "$submission" "${auth[@]}" --timeout 3h --output-format json > "$stage/notary-wait.json" || wait_exit=$?
# Native readback is authoritative even if wait timed out or returned an error.
xcrun notarytool info "$submission" "${auth[@]}" --output-format json > "$stage/notary-info.json"
python3 - "$stage/notary-info.json" "$submission" "$wait_exit" <<'PY'
import json, sys
d = json.load(open(sys.argv[1]))
if d.get("id", "").lower() != sys.argv[2].lower() or d.get("status") != "Accepted":
    raise SystemExit(f"Not published: Apple status={d.get('status', 'unknown')}; wait exit={sys.argv[3]}. Resume the same submission after reviewing its state.")
print("Notarization accepted:", d["id"])
PY
xcrun notarytool log "$submission" "$stage/notary-log.json" "${auth[@]}"
python3 - "$stage/notary-log.json" "$submission" "$pristine_sha" <<'PY'
import json, sys
d = json.load(open(sys.argv[1]))
if not (d.get("jobId", "").lower() == sys.argv[2].lower() and d.get("status") == "Accepted"
        and d.get("sha256", "").lower() == sys.argv[3]):
    raise SystemExit("Accepted job does not identify the checksum-pinned DMG. Nothing will be stapled or published.")
PY
[ "$(sha256 "$dmg")" = "$pristine_sha" ] || fail "The staged pristine DMG changed during the wait."

xcrun stapler staple "$app"
xcrun stapler staple "$dmg"
xcrun stapler validate "$app"
xcrun stapler validate "$dmg"
validate_app
codesign --verify --strict "-R=$signing_requirement" "$dmg"
spctl --assess --type execute --verbose=2 "$app"
spctl --assess --type open --context context:primary-signature --verbose=2 "$dmg"
ditto -c -k --keepParent "$app" "$stage/DuoDeck-Host-macOS.zip"
(cd "$stage" && shasum -a 256 DuoDeck-Host-macOS.dmg DuoDeck-Host-macOS.zip > SHA256SUMS.txt)
stapled_sha="$(sha256 "$dmg")"

if [ "$publish" = 1 ]; then
  publish_preflight
  # Pin the tag atomically, then make exactly one release-create attempt.
  if [ -z "$tag_commit" ]; then
    if ! gh api --method POST "repos/$repo/git/refs" -f "ref=refs/tags/$tag" -f "sha=$release_commit" > "$stage/tag-create.json"; then
      fail "Tag creation was not confirmed. Inspect GitHub; this command will not retry it."
    fi
  fi
  check_tag
  [ "$tag_commit" = "$release_commit" ] || fail "The remote tag was not confirmed at the frozen commit."
  if ! gh release create "$tag" "$dmg" "$stage/DuoDeck-Host-macOS.zip" "$stage/SHA256SUMS.txt" \
      --repo "$repo" --verify-tag --target "$release_commit" --title "DuoDeck $version" \
      --notes-file "$stage/RELEASE_NOTES.md" --latest > "$stage/release-create.txt"; then
    fail "Release creation was not confirmed and may have partially succeeded. Inspect GitHub; do not blindly retry."
  fi
  gh api "repos/$repo/releases/tags/$tag" > "$stage/published-release.json"
  python3 - "$stage/published-release.json" "$tag" <<'PY'
import json, sys
d = json.load(open(sys.argv[1]))
expected = {"DuoDeck-Host-macOS.dmg", "DuoDeck-Host-macOS.zip", "SHA256SUMS.txt"}
if d.get("tag_name") != sys.argv[2] or d.get("draft") is not False or d.get("prerelease") is not False:
    raise SystemExit("Publication exists but its public release state was not confirmed.")
if not expected.issubset({a["name"] for a in d.get("assets", []) if a.get("state") == "uploaded"}):
    raise SystemExit("Publication exists but all three uploaded assets were not confirmed.")
print("Published:", d["html_url"])
PY
  mkdir "$stage/public-download"
  for download in tagged latest; do
    if [ "$download" = tagged ]; then route="download/$tag"; else route="latest/download"; fi
    download_verified=0
    # Only public GETs are retried: allow brief asset/redirect propagation after create.
    for attempt in 1 2 3 4 5; do
      if curl --disable --fail --show-error --location --proto '=https' --tlsv1.2 --connect-timeout 10 --max-time 30 \
          --output "$stage/public-download/$download.dmg" \
          "https://github.com/$repo/releases/$route/DuoDeck-Host-macOS.dmg"; then
        if [ "$(sha256 "$stage/public-download/$download.dmg")" = "$stapled_sha" ]; then
          download_verified=1; break
        fi
      fi
      if [ "$attempt" != 5 ]; then sleep 5; fi
    done
    [ "$download_verified" = 1 ] ||
      fail "Publication exists, but the $download public DMG bytes were not verified after five bounded read-only attempts. Do not retry release creation."
  done
  echo "VERIFIED_PUBLIC_DMG_SHA256=$stapled_sha"
fi
echo "VERIFIED_RELEASE=$stage"
