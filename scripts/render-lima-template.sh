#!/usr/bin/env bash
set -euo pipefail

if [ "$#" -ne 1 ]; then
  echo "Usage: $0 <base-lima-template>" >&2
  exit 1
fi

base_template=$1
repo=${DEVBOX_RELEASE_REPO:-juspay/devbox}

release_json=$(gh release view --repo "$repo" --json tagName,assets)
tag=$(jq -r '.tagName // empty' <<<"$release_json")

if [ -z "$tag" ]; then
  echo "Could not find latest release tag for ${repo}" >&2
  exit 1
fi

images_json=$(
  jq -c '
    . as $release
    |
    ["aarch64", "x86_64"]
    | map(. as $arch
      | ([ $release.assets[]
          | select(.name | test("^devbox(-.*)?-" + $arch + "\\.qcow2$"))
        ][0] // error("missing " + $arch + " qcow2 asset"))
      | {
          location: .url,
          arch: $arch,
          digest: .digest
        })
  ' <<<"$release_json"
)

echo "Using ${repo} ${tag}" >&2
COMMENT="Generated from latest ${repo} release: ${tag}" \
  IMAGES="$images_json" \
  yq -P '.images = env(IMAGES) | . headComment = strenv(COMMENT)' "$base_template"
