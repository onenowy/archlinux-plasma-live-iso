#!/bin/bash
set -e

echo ">>> Managing Release..."

# Define Variables
REPO="$GITHUB_REPOSITORY"   # Automatically provided by Actions
SHA="$GITHUB_SHA"           # Automatically provided by Actions

# GitHub release files must be under 2 GiB. Bigger ISOs are uploaded in parts
# of the largest size still under that.
ASSET_LIMIT=$((2 * 1024 * 1024 * 1024))
PART_SIZE=$((ASSET_LIMIT - 1))   # bytes

# Check & Delete Previous Release
if gh release view "$RELEASE_TAG" --repo "$REPO" > /dev/null 2>&1; then
    echo "-> Deleting existing '$RELEASE_TAG' release..."
    gh release delete "$RELEASE_TAG" --yes --cleanup-tag --repo "$REPO" || \
    gh release delete "$RELEASE_TAG" --yes --repo "$REPO" || true
else
    echo "-> No existing release found. Creating a new one."
fi

# Find the ISO and log its size
if [ ! -d "$OUT_DIR" ]; then
    echo "::error::Output directory '$OUT_DIR' not found! Build might have failed."
    exit 1
fi
shopt -s nullglob
ISOS=("$OUT_DIR"/*.iso)
if [ "${#ISOS[@]}" -ne 1 ]; then
    echo "::error::Expected one ISO in '$OUT_DIR', found ${#ISOS[@]}. Build might have failed."
    exit 1
fi
ISO="${ISOS[0]}"
ISO_NAME=$(basename "$ISO")
ISO_SIZE=$(stat -c%s "$ISO")
echo "   Final ISO Size: $((ISO_SIZE / 1024 / 1024)) MiB"

# Set title and notes based on release tag
case "$RELEASE_TAG" in
    *plasma*)
        RELEASE_TITLE="Arch Linux Plasma ISO"
        RELEASE_NOTES="Minimal KDE Plasma desktop environment with Wayland"
        ;;
    *console*)
        RELEASE_TITLE="Arch Linux Console ISO"
        RELEASE_NOTES="Minimal console environment with zsh, starship, and kmscon"
        ;;
    *)
        RELEASE_TITLE="Arch Linux ISO"
        RELEASE_NOTES="Arch Linux Live ISO"
        ;;
esac

ASSETS=("$ISO")
if [ "$ISO_SIZE" -ge "$ASSET_LIMIT" ]; then
    echo "-> ISO is 2 GiB or larger; splitting it into parts under 2 GiB..."
    (
        cd "$OUT_DIR"
        sha256sum "$ISO_NAME" > "$ISO_NAME.sha256"
        split -b "$PART_SIZE" -d -a 2 "$ISO_NAME" "$ISO_NAME.part"
        rm "$ISO_NAME"   # frees the space the parts took
    )
    PARTS=("$ISO".part*)
    ASSETS=("${PARTS[@]}" "$ISO.sha256")
fi

# Create Release & Upload
echo "-> Creating release and uploading ${#ASSETS[@]} file(s)..."
gh release create "$RELEASE_TAG" "${ASSETS[@]}" \
    --repo "$REPO" \
    --title "$RELEASE_TITLE" \
    --notes "$RELEASE_NOTES" \
    --latest \
    --target "$SHA"

echo ">>> Release process completed successfully."
