#!/usr/bin/env bash
# Downloads the StackAlert Lambda artifact from GitHub Releases.
# Always resolves the latest tag first so you know exactly which version you get.
#
# Usage: ./scripts/download-lambda.sh [output-dir] [version]
#   output-dir — where to save the zip (default: current directory)
#   version    — release tag to download (default: latest)

set -euo pipefail

OUTPUT_DIR="${1:-.}"
VERSION="${2:-}"
REPO="stackalertapp/stackalert-lambda"
ARTIFACT="lambda-arm64.zip"

# Resolve latest tag via GitHub API
if [ -z "$VERSION" ]; then
  echo "Fetching latest release tag..."
  VERSION=$(curl -fsSL "https://api.github.com/repos/${REPO}/releases/latest" | grep '"tag_name"' | cut -d '"' -f 4)
  if [ -z "$VERSION" ]; then
    echo "Error: could not resolve latest release tag" >&2
    exit 1
  fi
fi

DOWNLOAD_URL="https://github.com/${REPO}/releases/download/${VERSION}/${ARTIFACT}"
OUTPUT_PATH="${OUTPUT_DIR}/${ARTIFACT}"

echo "Downloading StackAlert Lambda ${VERSION}..."
echo "  URL: ${DOWNLOAD_URL}"
echo "  Output: ${OUTPUT_PATH}"

mkdir -p "${OUTPUT_DIR}"
curl -fSL --progress-bar -o "${OUTPUT_PATH}" "${DOWNLOAD_URL}"

echo "Done. ${VERSION} — $(ls -lh "${OUTPUT_PATH}" | awk '{print $5}') downloaded."
echo ""
echo "Use in Terraform:"
echo "  lambda_filename = \"${OUTPUT_PATH}\""
