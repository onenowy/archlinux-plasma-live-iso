#!/bin/bash
set -e

echo ">>> Managing Release..."

# Define Variables
REPO="$GITHUB_REPOSITORY"   # Automatically provided by Actions
SHA="$GITHUB_SHA"           # Automatically provided by Actions

# Check & Delete Previous Release
if gh release view "$RELEASE_TAG" --repo "$REPO" > /dev/null 2>&1; then
    echo "-> Deleting existing '$RELEASE_TAG' release..."
    gh release delete "$RELEASE_TAG" --yes --cleanup-tag --repo "$REPO"
else
    echo "-> No existing release found. Creating a new one."
fi

# Log ISO Size
if [ -d "$OUT_DIR" ]; then
    cd "$OUT_DIR"
    ISO_FILE=$(ls *.iso | head -n 1)
    if [ -f "$ISO_FILE" ]; then
        FILE_SIZE=$(stat -c%s "$ISO_FILE")
        echo "   Final ISO Size: $(($FILE_SIZE / 1024 / 1024)) MB"
    fi
    cd ..
else
    echo "::error::Output directory '$OUT_DIR' not found! Build might have failed."
    exit 1
fi

# Create Release & Upload
echo "-> Creating release and uploading artifacts..."

# Set title and notes based on release tag
case "$RELEASE_TAG" in
    *plasma*)
        RELEASE_TITLE="Arch Linux Plasma ISO"
        RELEASE_NOTES="Minimal KDE Plasma desktop environment with Wayland"
        ;;
    *custom*)
        RELEASE_TITLE="Arch Linux Custom ISO"
        RELEASE_NOTES="Custom KDE Plasma with zsh, starship, and additional tools"
        ;;
    *console-wayland*)
        RELEASE_TITLE="Arch Linux Console Wayland ISO"
        RELEASE_NOTES="Minimal Wayland console environment with zsh, starship, and sway"
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

gh release create "$RELEASE_TAG" "$OUT_DIR"/*.iso \
    --repo "$REPO" \
    --title "$RELEASE_TITLE" \
    --notes "$RELEASE_NOTES" \
    --latest \
    --target "$SHA"

echo ">>> Release process completed successfully."
