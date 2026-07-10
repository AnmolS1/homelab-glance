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
echo "▸ Generating HomelabGlance.xcodeproj from project.yml in $(pwd)…"
xcodegen generate

echo "✓ Xcode project generated."
