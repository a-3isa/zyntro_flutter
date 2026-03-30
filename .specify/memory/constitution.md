# Zyntro Migration Constitution

## Core Principles

### I. Feature-Slice Scope Discipline

- Each migration slice MUST be scoped to one named feature domain.
- Out-of-scope work MUST be captured as explicit backlog items.
- A slice MUST NOT silently expand scope during implementation.

### II. Evidence-First Cutover

- A migration slice MUST produce regression evidence for primary and critical failure paths before cutover.
- Legacy removal MUST occur only after cutover evidence is complete and accepted.
- Requirements and tasks MUST remain traceable to measurable success criteria.

### III. Security and Access Integrity

- Authentication and authorization behavior MUST be regression-verified before cutover.
- Cutover MUST NOT proceed with unresolved critical-severity security defects.
- Security-critical failures MUST have explicit remediation or rollback criteria.

### IV. Operational Safety and Reversibility

- Auth-related cutovers MUST run with no planned downtime.
- A tested rollback path MUST exist before cutover.
- Telemetry for success rate, error rate, and rollback-trigger conditions MUST be active before cutover.

### V. Independent Deliverability

- Each user story MUST be independently implementable and testable.
- Foundational work MUST be completed before dependent stories begin.
- Story phases SHOULD minimize cross-story coupling.

## Required Quality Gates

- Plans MUST include constitution gate checks before design and after design.
- Tasks MUST include explicit work for security, observability, and post-cutover verification when required by the spec.
- Ambiguous success criteria MUST be converted into measurable acceptance conditions before implementation.

## Governance

- This constitution supersedes conflicting planning conventions within this repository.
- Any amendment MUST be explicit, documented, and approved before dependent artifacts are updated.
- Compliance checks are mandatory for `spec.md`, `plan.md`, and `tasks.md` before implementation starts.

**Version**: 1.0.0 | **Ratified**: 2026-03-10 | **Last Amended**: 2026-03-10
