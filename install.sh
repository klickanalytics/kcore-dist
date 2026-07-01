#!/bin/sh
# KCore installer. Detects OS/arch, downloads the matching prebuilt binary from
# the public klickanalytics/kcore-dist release, verifies its checksum, and puts
# `kcore` on your PATH. No Rust toolchain required.
#
#   curl -sSL https://raw.githubusercontent.com/klickanalytics/kcore-dist/main/install.sh | sh
#
set -eu

REPO="klickanalytics/kcore-dist"

os="$(uname -s)"
arch="$(uname -m)"
case "$os" in
  Darwin)
    case "$arch" in
      arm64|aarch64) target="aarch64-apple-darwin" ;;
      x86_64)        target="x86_64-apple-darwin" ;;
      *) echo "kcore: unsupported macOS arch: $arch" >&2; exit 1 ;;
    esac ;;
  Linux)
    case "$arch" in
      x86_64|amd64) target="x86_64-unknown-linux-gnu" ;;
      *) echo "kcore: unsupported Linux arch: $arch" >&2; exit 1 ;;
    esac ;;
  *) echo "kcore: unsupported OS: $os" >&2; exit 1 ;;
esac

asset="kcore-${target}.tar.gz"

# Resolve the tag: KCORE_VERSION pins a version; otherwise use latest.
if [ -n "${KCORE_VERSION:-}" ]; then
  tag="$KCORE_VERSION"
else
  tag="$(curl -fsSL "https://api.github.com/repos/${REPO}/releases/latest" \
    | sed -n 's/.*"tag_name": *"\([^"]*\)".*/\1/p' | head -1)"
fi
[ -n "$tag" ] || { echo "kcore: could not resolve a release tag" >&2; exit 1; }

base="https://github.com/${REPO}/releases/download/${tag}"
tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT

echo "kcore: downloading ${tag} for ${target}…"
curl -fsSL "${base}/${asset}" -o "${tmp}/${asset}"
curl -fsSL "${base}/${asset}.sha256" -o "${tmp}/${asset}.sha256" || true

if [ -s "${tmp}/${asset}.sha256" ]; then
  echo "kcore: verifying checksum…"
  ( cd "$tmp" && { shasum -a 256 -c "${asset}.sha256" >/dev/null 2>&1 \
      || sha256sum -c "${asset}.sha256" >/dev/null 2>&1; } ) \
    || { echo "kcore: checksum verification FAILED" >&2; exit 1; }
else
  echo "kcore: warning — no checksum file found, skipping verification" >&2
fi

tar -xzf "${tmp}/${asset}" -C "$tmp"

bindir="${KCORE_BIN_DIR:-$HOME/.local/bin}"
mkdir -p "$bindir"
chmod 0755 "${tmp}/kcore"
mv -f "${tmp}/kcore" "${bindir}/kcore"

echo "kcore: installed to ${bindir}/kcore"
case ":$PATH:" in
  *":$bindir:"*) : ;;
  *) echo "kcore: add it to your PATH ->  export PATH=\"$bindir:\$PATH\"" >&2 ;;
esac
echo 'kcore: try  ->  KLICKANALYTICS_CLI_API_KEY=<your key> kcore -p "what'"'"'s the setup on NVDA?"'
