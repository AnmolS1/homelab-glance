#!/bin/sh
# Xcode Cloud post-clone hook.
#
# The Xcode project is generated from project.yml via XcodeGen and is gitignored
# (see ../../.gitignore — "project is generated from ios/project.yml"), so it does
# not exist in a fresh clone. Regenerate it here, after clone and before Xcode Cloud
# resolves the scheme and builds — otherwise the build fails with:
#   "Project HomelabGlance.xcodeproj does not exist at ios/HomelabGlance.xcodeproj".
#
# Xcode Cloud only runs scripts named ci_post_clone.sh / ci_pre_xcodebuild.sh /
# ci_post_xcodebuild.sh, located in a ci_scripts/ folder next to the .xcodeproj.
set -e

export HOMEBREW_NO_INSTALL_CLEANUP=1
export HOMEBREW_NO_AUTO_UPDATE=1

echo "▸ Installing XcodeGen…"
brew install xcodegen

# This script's working directory is ci_scripts/; the project lives one level up (ios/).
cd "$(dirname "$0")/.."

# Auto build number: derive CURRENT_PROJECT_VERSION from the git commit count so
# every Xcode Cloud build gets a fresh, monotonically-increasing build number with
# no manual bump. Xcode Cloud may shallow-clone, so unshallow first; floor the value
# so a broken/shallow count can never regress below an already-uploaded build.
# The App/Widget Info.plists use $(CURRENT_PROJECT_VERSION), so this is picked up by
# xcodegen below. (MARKETING_VERSION stays the human-set release version.)
git fetch --unshallow 2>/dev/null || true
BUILD=$(git rev-list --count HEAD 2>/dev/null || echo 0)
FLOOR=26
[ "$BUILD" -lt "$FLOOR" ] && BUILD=$FLOOR
echo "▸ Setting build number (CURRENT_PROJECT_VERSION) to $BUILD"
/usr/bin/sed -i '' -E "s/(CURRENT_PROJECT_VERSION:[[:space:]]*)\"[0-9]+\"/\1\"$BUILD\"/" project.yml

echo "▸ Generating HomelabGlance.xcodeproj from project.yml in $(pwd)…"
xcodegen generate

echo "✓ Xcode project generated."
