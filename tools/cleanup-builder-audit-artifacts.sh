#!/usr/bin/env bash
set -euo pipefail

git rm -f --ignore-unmatch \
  .github/workflows/audit-1.3.49-builder.yml \
  .github/workflows/audit-1.3.49-row-model.yml \
  .github/workflows/audit-1.3.49-builder-server.yml \
  .github/workflows/extract-1.3.49-builder-controller.yml \
  .github/workflows/build-1.3.49-row-drag-state.yml \
  tools/audit-1.3.49-builder.sh \
  tools/audit-1.3.49-builder-report.txt \
  tools/audit-1.3.49-row-model.sh \
  tools/audit-1.3.49-row-model-report.txt \
  tools/audit-1.3.49-builder-server.sh \
  tools/audit-1.3.49-builder-server-report.txt \
  tools/extract-1.3.49-builder-controller.sh \
  tools/audit-1.3.49-builder-controller-save.txt \
  tools/build-1.3.49-row-drag-state.sh \
  .github/workflows/audit-1.3.54-field-drag-zones.yml \
  tools/audit-1.3.54-field-drag-zones.sh \
  tools/audit-1.3.54-field-drag-zones-report.txt \
  .github/workflows/build-1.3.55-field-drag-zones.yml \
  tools/build-1.3.55-field-drag-zones.sh \
  .github/workflows/verify-1.3.55-package.yml \
  tools/verify-1.3.55-package.sh \
  .github/workflows/inspect-1.3.55-package.yml \
  tools/inspect-1.3.55-package.sh \
  tools/inspect-1.3.55-package-report.txt \
  .github/workflows/build-1.3.56-field-drag-package-fix.yml \
  tools/build-1.3.56-field-drag-package-fix.sh \
  .github/workflows/cleanup-builder-audit-artifacts.yml \
  tools/cleanup-builder-audit-artifacts.sh

echo "Temporary Builder audit/build artifacts staged for removal."
