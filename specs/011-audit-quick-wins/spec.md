# Feature Specification: Audit quick wins

**Branch**: `011-audit-quick-wins`  
**Created**: 2026-09-17  
**Input**: Close XS/S audit items Z-SOC-002, Z-AND-001, Z-NOTIF-002, Z-DOC-001, Z-CI-004.

## Requirements

- **FR-001** (Z-SOC-002): GoRouter redirects non-moderators away from `/moderation/queue`.
- **FR-002** (Z-AND-001): Android FCM `default_notification_icon` meta-data + monochrome drawable.
- **FR-003** (Z-NOTIF-002): `shouldSendNotification` fails closed when preference read fails.
- **FR-004** (Z-DOC-001): CLAUDE.md / AGENTS.md Speckit markers point at current feature plan.
- **FR-005** (Z-CI-004): `deploy-firebase-rules` needs `analyze` job; Node 22 for rules tests.
