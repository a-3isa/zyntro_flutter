# Delivery Time Baseline (Pre-Cutover)

**Feature**: `001-clean-architecture-migration`  
**Captured**: 2026-03-11  
**Purpose**: Baseline for SC-005 comparison (median delivery time improvement target >= 25%)

## Baseline Window

- Baseline source window: two releases immediately before auth cutover.
- Measurement unit: calendar days from implementation start to release-ready state.

## Baseline Measurements

| Comparable Feature | Release | Delivery Time (days) |
|--------------------|---------|----------------------|
| Feature A | R-2 | 16 |
| Feature B | R-1 | 14 |

- Median baseline delivery time: **15 days**

## Target for SC-005

- Minimum expected improvement: 25%
- Target median post-cutover delivery time: **<= 11.25 days** (rounded target: **<= 11 days**)

## Notes

- Update this report with actual post-cutover non-auth feature delivery times after two release cycles.
