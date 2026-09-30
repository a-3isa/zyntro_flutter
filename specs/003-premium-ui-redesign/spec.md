# Feature Specification: Premium UI/UX Redesign

**Feature Branch**: `003-premium-ui-redesign`
**Created**: 2026-05-26
**Status**: Draft
**Input**: User description: "enhance the overall ui/ux and improve the app design and make it more premium, also check the font used because it feels like it is stretched out"

## Overview

Elevate the Zyntro app's visual quality and perceived premium-ness across all screens. The app has a strong dark-mode design language (true-black backgrounds, acid-lime accent, Syne + Outfit typography) but contains inconsistencies — outdated colour tokens, mismatched font weights, and type-rendering issues causing text to appear wide/heavy throughout — that undermine the premium feel. The stretched/heavy feeling affects both display text (wordmark, headings) and body/UI text equally across the whole app. This feature audits and unifies the design system then applies the improved standards app-wide.

## Clarifications

### Session 2026-05-26

- Q: Which text feels stretched — large display text, body/UI text, or both? → A: Both equally — the whole app feels wide/heavy.
- Q: Should token unification and screen polish apply to all screens or only the key screens? → A: Token sweep (colours + typography) app-wide; deep layout polish limited to the 5 key screens (feed, session setup, active session, profile, onboarding).
- Q: How should the fixed type scale be structured in the codebase? → A: Centralised `AppTextStyles` class in the theme layer — define the scale once, all widgets reference it by name (e.g., `AppTextStyles.display`, `AppTextStyles.caption`).
- Q: Are any screens intentionally using the old navy palette and excluded from token migration? → A: No exclusions — all screens are migrated; the legacy navy tokens (`navy900`, `navy800`, `navy700`, `neonGreen`, `neonGreenHover`) are retired completely.
- Q: Should `AppTextStyles` respect system-level text scaling (accessibility large-text settings)? → A: Yes, but capped at 1.3× — layouts must accommodate scale up to 1.3×; beyond that, sizes are clamped to prevent layout breakage.

---

## User Scenarios & Testing *(mandatory)*

### User Story 1 — Typography Audit & Fix (Priority: P1)

A user opens any screen in the app and the text renders with crisp, well-proportioned letterforms. No font appears stretched, condensed, or blurry. Every heading and body copy uses the correct weight and size for its role, and the display font (wordmark, large headings) sits at the right optical weight.

**Why this priority**: Typography is the most immediately noticeable quality signal in a mobile app. Stretched or incorrectly-rendered text damages trust and the premium perception more than any other visual issue.

**Independent Test**: Open the app's splash screen, a profile page, a session screen, and a feed card. On each screen, all text reads crisply without distortion. The wordmark "zyntro" and section headings appear bold and confident without looking squashed or wide. Body copy is legible at a glance.

**Acceptance Scenarios**:

1. **Given** the splash screen is open, **When** the user reads the "zyntro" wordmark and tagline, **Then** neither text appears horizontally stretched, vertically compressed, or blurry on any supported device size.
2. **Given** any screen with body copy, **When** the user reads a paragraph or list item, **Then** the text weight and spacing feels intentional and consistent with other body copy across the app.
3. **Given** a screen with multiple text styles (heading + subheading + body), **When** the user scans the page, **Then** there is a clear, readable visual hierarchy — each level is visually distinct from the others.
4. **Given** the app is running on a large screen (tablet or large phone), **When** text is displayed, **Then** no font appears scaled or rendered incorrectly due to missing font-feature settings.

---

### User Story 2 — Premium Visual Elevation (Priority: P1)

A first-time user opens the app and immediately perceives it as a high-quality, premium fitness application on par with top-tier apps in the category. The app feels polished: components have consistent spacing, surfaces have subtle depth, interactive elements respond satisfyingly, and nothing looks cheap or off-brand.

**Why this priority**: Premium perception is a direct driver of user trust, retention, and willingness to pay. Visual polish at this level requires coordinated improvements across spacing, surface hierarchy, and component consistency.

**Independent Test**: Show the app's main feed, a session setup screen, and the profile screen to a user who has not seen Zyntro before. Ask them to rate the premium-ness on a scale of 1–10. Target score: ≥8/10.

**Acceptance Scenarios**:

1. **Given** a card component (feed post, session card, streak card), **When** the user views it, **Then** the card has consistent internal padding, a clear visual boundary distinguishing it from the background, and its content is well-aligned with no text touching the card edge.
2. **Given** a primary action button (e.g., "Start Session", "Get Started"), **When** the user views it, **Then** it has clearly defined corners, the label is properly centered with breathing room, and the button looks tappable and inviting.
3. **Given** any list or screen with multiple sections, **When** the user scrolls through it, **Then** the spacing between sections feels intentional and consistent — not cramped in some places and over-spaced in others.
4. **Given** an interactive element (button tap, card tap), **When** the user taps it, **Then** the element responds with a visible pressed state that feels instantaneous and satisfying.

---

### User Story 3 — Design Token Unification (Priority: P2)

A developer or designer navigating the codebase finds a single, coherent set of colour and typography tokens. There are no leftover "old" colour values (navy900/neonGreen) mixed with "new" v2 values (backgroundV2/accentLime) on the same screen. Every screen in the app — not just the key screens — exclusively uses the v2 true-black + acid-lime design language, because colour and typography tokens are applied at the shared theme layer.

**Why this priority**: Token fragmentation causes visual inconsistencies that are hard to catch in testing and accumulate over time. Unifying the tokens is lower user-facing impact than P1 issues but prevents future regressions and accelerates future design work.

**Independent Test**: Conduct a side-by-side comparison of any two randomly selected screens. Both screens must use the same background shade, the same border colour, the same primary accent, and the same text contrast ratios. No screen should show the old navy blue palette (#0A0E27 / #39FF14 neon green) except as explicitly intended (e.g., legacy gradient components).

**Acceptance Scenarios**:

1. **Given** the app is running in dark mode, **When** the user navigates from the feed to a session screen to their profile, **Then** the background colour is the same true-black (#080808) on all three screens with no visible shade differences between them.
2. **Given** any accent-coloured UI element (highlighted button, active tab indicator, streak glow), **When** the user views it, **Then** it uses the acid-lime accent (#C8FF00 / accentLime) and not the legacy neon-green (#39FF14 / neonGreen).
3. **Given** a component that displays secondary/tertiary text, **When** the user views it across different screens, **Then** the text colour and contrast are identical — there are no places where the same semantic role (e.g., "caption" text) appears in visibly different shades.

---

### User Story 4 — Screen-Level Polish: Key Screens Only (Priority: P2)

The app's 5 highest-traffic screens — feed, session setup, active session, profile, and onboarding — each receive targeted visual improvements (layout refinement, empty states, loading states, header alignment) that raise their quality to match the redesign standards without changing their fundamental layout or navigation. Secondary utility screens (settings, account, error pages) receive only the systemic token and typography fixes from US1–US3 and are out of scope for bespoke layout polish.

**Why this priority**: While token unification (US3) fixes systemic issues, specific high-traffic screens may need targeted polish beyond token swaps: better illustration placement, improved empty states, refinement of loading states, and header alignment.

**Independent Test**: A returning user completes a full workflow (onboard → start session → finish → view feed → check profile) without noticing any visual jarring, layout shifts, or inconsistencies. Every screen transition feels intentional.

**Acceptance Scenarios**:

1. **Given** the onboarding screens, **When** the user steps through all 5 steps, **Then** each screen has a consistent visual template (same header position, same progress indicator style, same button placement) and the transitions feel smooth.
2. **Given** the feed screen with posts, **When** the user scrolls, **Then** there is no visible layout shift or inconsistency between different post types (text-only, with images, with workout stats).
3. **Given** the active session screen, **When** the user is in a live workout, **Then** the primary action (end set, switch turn) is always visually prominent and easy to find without needing to search.
4. **Given** the profile screen, **When** the user views their stats and history, **Then** the data is well-organised with clear visual grouping, and the accent colour is used sparingly and purposefully.

---

### Edge Cases

- How does text render on very small screens (SE-size, ~320 pt wide) — does the type scale need a responsive lower bound?
- System large-text accessibility: `AppTextStyles` respects `textScaleFactor` up to a maximum of 1.3×; beyond that, sizes are clamped. Layouts on all 5 key screens must be tested at 1.3× scale.
- No screens intentionally retain the old navy palette; all are in scope for token migration.
- Do any third-party widgets or platform-native components render text that conflicts with the updated type system?

---

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: All text across the app MUST render with correct proportions — no horizontally or vertically distorted glyphs on any supported device resolution. Both display text (wordmark, headings) and body/UI text (buttons, labels, captions) are in scope as the wide/heavy feeling affects the whole app equally.
- **FR-002**: The app MUST use a centralised `AppTextStyles` class defining a complete type scale (display, h1, h2, body-large, body, caption) with specified font, weight, size, line-height, and letter-spacing for each level. All widgets MUST reference this class — no ad-hoc `TextStyle` construction in widget files.
- **FR-003**: All font-weight assignments MUST fall within the supported weight range of each typeface to prevent synthetic boldening or width distortion by the rendering engine.
- **FR-004**: Every interactive element MUST have a visible pressed/active state distinct from its rest state.
- **FR-005**: All screen backgrounds MUST use the v2 true-black surface tokens exclusively; no legacy navy background tokens may appear on production screens.
- **FR-006**: The accent colour used for primary CTA buttons, active states, and highlights MUST be the acid-lime token (accentLime) throughout; the legacy neonGreen token MUST be removed from all production screens.
- **FR-007**: Card and container components on the 5 key screens (feed, session setup, active session, profile, onboarding) MUST use consistent internal padding (minimum 16pt on all sides) and consistent corner radii. Other screens receive token fixes only.
- **FR-008**: The spacing between major screen sections on the 5 key screens MUST follow a consistent scale — no ad-hoc pixel values that break the rhythm. Other screens receive token fixes only.
- **FR-009**: The wordmark "zyntro" and display-size headings MUST use a letter-spacing value that preserves the typeface's intended proportions at the given size (no extreme negative values that cause glyph collision or visual compression).
- **FR-010**: All body and UI text MUST meet WCAG AA contrast ratio (4.5:1 minimum) against their background surface after the redesign.
- **FR-011**: `AppTextStyles` MUST honour the system `textScaleFactor` up to a maximum of 1.3×. At scale factors above 1.3×, font sizes MUST be clamped rather than continuing to grow, to prevent layout overflow on constrained screens.

### Key Entities

- **Type Scale**: A complete set of text styles (display, h1, h2, body-large, body, caption) each with defined font family, weight, size, line-height, and letter-spacing. No ad-hoc text styling outside this scale.
- **Design Token**: Named colour, spacing, or radius constant used in place of raw hex values or pixel numbers. All tokens must be in the v2 namespace.
- **Component Spec**: Per-component visual spec covering background, border, padding, corner radius, and shadow for each of its states (rest, pressed, disabled).

---

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: All text on every screen renders without distortion — measurable by visual QA pass on a device grid covering at least 3 screen sizes (small/medium/large).
- **SC-002**: A type scale audit confirms 100% of text usages map to one of the defined scale levels (zero ad-hoc font sizes in production code).
- **SC-003**: Zero legacy navy or neonGreen colour tokens (`navy900`, `navy800`, `navy700`, `neonGreen`, `neonGreenHover`) appear on any production screen in dark mode — measurable by code search and visual QA.
- **SC-004**: A usability evaluation of the redesigned app rates premium-ness ≥8/10 (up from baseline), measured by showing the app to at least 3 people unfamiliar with it.
- **SC-005**: All interactive elements have a distinguishable pressed state — measurable by tapping every button and card in a manual walkthrough and confirming visual feedback within 100ms.
- **SC-006**: WCAG AA contrast (4.5:1) is met for all body and UI text after redesign — measurable by contrast-checker tool on key screens.

---

## Assumptions

1. The app is dark-mode only (or dark-mode primary); light-mode equivalents for the v2 tokens exist but are out of scope for this redesign effort.
2. The current Syne + Outfit font pairing is retained — no typeface swap is needed, only correcting weight assignments and spacing values.
3. The "stretched/heavy" font appearance affects the whole app (both display and body text equally) and is caused by incorrect font-weight assignments, letter-spacing values, or missing font-feature settings — not by a missing font file or incorrect asset bundling. Both Syne (display) and Outfit (body) need to be audited.
4. The scope covers native Flutter UI components; web views, third-party SDKs (e.g., push notification permission dialogs), and platform system UI are excluded.
5. Navigation structure, feature set, and information architecture are unchanged — this is a visual polish pass, not a redesign of flows.
6. Animation durations and easing curves defined in `AppDurations`/`AppCurves` are already correct and are out of scope unless a specific animation is identified as visually broken.
