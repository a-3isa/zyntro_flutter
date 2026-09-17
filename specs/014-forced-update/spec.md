# Feature Specification: Forced update gate

**Branch**: `014-forced-update`  
**Input**: Z-ENH-042 / Z-OBS-003

## Requirements

- **FR-001**: Read `config/featureFlags.minSupportedVersion` (string).
- **FR-002**: Compare to `PackageInfo.version`; if current < minimum, show blocking update screen.
- **FR-003**: Missing/unreadable config fails open (app continues).
- **FR-004**: Update CTA opens Play Store / App Store.
