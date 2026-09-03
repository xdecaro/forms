#!/usr/bin/env bash
set -euo pipefail

bash tools/release-1.2.6/build.sh

# The build script cleans temporary workflow files, but GitHub Actions' token
# cannot push workflow changes. Restore them to the checked-out HEAD before
# the commit step; they will be cleaned directly through the repository API.
git checkout HEAD -- .github/workflows/rebuild-release.yml .github/workflows/inspect-1.2.5-live.yml

echo 'Workflow files restored for push-safe release commit.'
