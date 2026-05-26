# Zyntro v2 Full App Redesign

_Spec for implementing the Claude Design handoff (Zyntro App.html)_

---

## Overview

Full visual and interaction overhaul of the Zyntro Flutter app to match the v2 design system built in Claude Design. The design moves from a navy/glassmorphism aesthetic to a confident minimalist "true black + acid lime" aesthetic with editorial typography and no visual noise.

Implementation order: design tokens → core widgets → screens.

---

## 1. Design Tokens (`lib/core/theme/app_theme.dart`)

### Color Palette

**Dark mode (primary):**

| Token | Value | Usage |
|---|---|---|
| `bg` | `#080808` | Scaffold background |
| `s1` | `#111111` | Card surface |
| `s2` | `#1C1C1C` | Elevated surface |
| `s3` | `#242424` | Active/selected bg |
| `lime` | `#C8FF00` | Primary accent, CTAs, active states |
| `limeDim` | `#A6D400` | Lime pressed/dim state |
| `t1` | `#FFFFFF` | Primary text |
| `t2` | `#888888` | Secondary text |
| `t3` | `#444444` | Tertiary/disabled text |
| `error` | `#FF4D4D` | Error states |
| `ok` | `#00D68F` | Success |
| `warn` | `#FF8C00` | Warning |

**Light mode:**

| Token | Value | Usage |
|---|---|---|
| `bg` | `#F8F8F8` | Scaffold background |
| `s1` | `#FFFFFF` | Card surface |
| `s2` | `#F2F2F2` | Elevated surface |
| `s3` | `#E8E8E8` | Active/selected bg |
| `lime` | `#8AB000` | Lime darkened for light bg legibility |
| `limeDim` | `#6E8C00` | Lime pressed |
| `t1` | `#0A0A0A` | Primary text |
| `t2` | `#555555` | Secondary text |
| `t3` | `#BBBBBB` | Tertiary/disabled text |

Note: semantic error/ok/warn colors stay the same in both themes.

### Typography

Replace current fonts:
- **Display** (headings, numbers, CTAs): `Space Grotesk` → weight 700/800
- **Body** (labels, descriptions): `DM Sans` → weight 400/600

Add both to `pubspec.yaml` via `google_fonts`. Update `AppFonts.primary` → `'DM Sans'`, `AppFonts.display` → `'Space Grotesk'`.

### Workout-type accent colors

| Type | Color |
|---|---|
| gym | `#C8FF00` |
| cardio | `#38BDF8` |
| hiit | `#FF8C00` |
| cycling | `#A78BFA` |
| yoga | `#34D399` |
| swimming | `#22D3EE` |

Add `AppColors.typeColors` map.

---

## 2. Core Widget Updates

### `ZyntroButton`

- **Primary**: flat `#C8FF00` fill, `#080808` text, `borderRadius: 12`, `padding: 14×20`, no gradient
- **Ghost**: transparent, `t2` text, `1px solid s3` border
- **Danger**: `#FF4D4D` fill, white text
- Press: `scale(0.97)` on tap down, `transform` animated over 120ms
- Glow: `boxShadow: 0 0 20px lime30` on primary only
- Disabled: `opacity: 0.4`

### `ZyntroCard`

- Background: `s1` (no border, no glassmorphism)
- Border radius: 20
- Optional `accent` flag: adds `1px solid lime33` border
- Remove `backdropFilter` / `blur` effects

### `ZAvatar`

- Background: `s2`
- Border: `1.5px solid color44` (color is per-type or lime)
- Initials: Space Grotesk 700, size × 0.38

### `ZTabPill`

- Container: `s1` bg, `borderRadius: 12`, `padding: 3`
- Active tab: `s3` bg, `t1` text, weight 600
- Inactive: transparent, `t2` text, weight 400
- No gradient on active tab

### Floating Nav Pill

- Container: `#111111` pill, `borderRadius: 32`, shadow `0 8px 32px #00000060`
- 4 icon-only tabs: Feed, Train (⚡ FAB elevated), Social, Profile
- Active: lime dot (6px circle) beneath icon
- Session FAB: 56px lime circle, dumbbell icon, elevated above pill center with `0 0 24px lime40` glow
- Theme toggle icon: sun/moon, top-right of home screen header

---

## 3. Screen Designs

### 3.1 Feed

**Header**: `ZYNTRO` wordmark (Space Grotesk 800, 22px) left, bell icon right (→ Notifications overlay), theme toggle top-right.

**Tab pill**: Following / Discover

**Post cards** (full-bleed, no horizontal margins):
- Photo area: 280px tall radial gradient placeholder (type-color `22%` opacity)
- Type icon watermark (×5 scale, 5% opacity) right-center of photo
- Author overlay: gradient fade bottom 80px; author name (800 22px) + avatar row at bottom
- Action row below: ❤️ `likes` · 💬 `comments` · workout type badge

**Post → Post Detail**: tap card opens `PostDetailOverlay` as full-screen push.

### 3.2 Post Detail Overlay

**Photo header** (260px): radial gradient bg, back button top-left, type badge top-right. Author + title overlaid at bottom with gradient fade.

**Stats strip**: Exercises · Sets · Duration (3-column divider row)

**Tabs**: Workout | Reactions | Comments

- **Workout tab**: total volume strip (lime number + progress bar); per-exercise: dot + name + divider → each set row: numbered circle, `{weight}kg × {reps}`, per-set volume right
- **Reactions tab**: 4 emoji buttons (❤️ 🔥 💪 👊) with labels and counts, toggleable; "who reacted" user list below
- **Comments tab**: comment list (avatar + name + text + time + likes); sticky comment input at bottom

### 3.3 Train / Session Setup

**Home view** (`view: 'home'`):
- Weekly SVG ring: 120px, shows workouts-done / weekly-goal, lime fill, remaining at `s2`
- Hero CTA: "Start Workout" lime button full-width
- Quick-start grid: 2×3 of workout type tiles (icon + label + sub, `s1` bg, type-color accent dot)
- Tap quick-start → directly sets type and jumps to `start` view

**Start view** (`view: 'start'`):
- Back arrow header, type selector (6-type list with checkmark on selected)
- Buddy invite rows: avatar + name + mutual follows count; toggle checkmark per row
- "Next: Plan Exercises" lime button → `plan` view

**Plan view** (`view: 'plan'`):
- Back arrow header, "Plan Your Session" title
- Swipeable exercise rows: swipe left → reveal red trash bg → delete at −55px
- Per-row: index number, exercise name, up/down reorder arrows, sets picker (1–6 pill)
- Add exercise: autocomplete input with suggestion chips
- "Begin Session ⚡ ({N} sets)" lime button → launches Session Room

### 3.4 Session Room

**Progress bar** (always visible, top): `EXERCISE NAME · Set X/Y` label left, `done/total` right, 3px lime fill bar animating on completion.

States machine:

| State | Layout |
|---|---|
| `ready` | Exercise name (20px), set ordinal (12px t2), 140px lime circle START button |
| `running` | Pulsing lime ring (160px), `HH:MM:SS` monospaced timer 76px center, tap-anywhere-to-stop |
| `weight` | "How much?" label, quick-pick row (40/60/80/100/120 kg), ±2.5 / ±5 / ±10 increment buttons, 60px weight display; confirm → `reps` |
| `reps` | "How many reps?" label, tap-to-count: large number (80px lime) increments on each tap; long-press resets; confirm → complete set |
| `transition` | Exercise done screen: prev exercise ✓ label, "UP NEXT / {name} / {N} sets / I'm Ready →" |
| `waiting` | Split: left col = partner's completed sets grouped by exercise; right = partner live timer + "Active" pulse dot; bottom = PTT hold-to-talk button |

**Set history sidebar**: slide-in panel from right on list-icon tap; grouped by exercise; total volume at bottom.

**PR toast**: 3s "🏆 New PR! {Exercise} · {weight}kg" notification on new personal record.

**Rest timer** (between sets): configurable (30s/60s/90s/2m); progress strip + countdown; skip button.

**End session**: confirmation bottom sheet → navigates to Recap.

### 3.5 Recap

**Header**: "Done." 64px Space Grotesk 800 with count-up animation.

**2×2 stat grid**: Exercises · Sets · Duration · Volume — each animates from 0 on mount.

**Exercise breakdown bar chart**: per-exercise horizontal bars, width proportional to volume, grow from 0% (staggered 100ms per bar).

**Share card preview**: collapsed by default; tap "Share Card Preview" expands styled card (zyntro wordmark + "DONE." headline + stats + @handle + dot-grid background).

**Points badge**: animated count-up.

**Actions**: "Post to Feed" primary + "Done" ghost → back to Feed.

### 3.6 Social / Leaderboard

**Tab pill**: Friends | Global

**Live score ticker** (horizontal bar): "LIVE" label, top-4 athletes with animated score count-up, updates every 4s.

**Podium** (top 3): side-by-side columns; #2 silver left (90px tall column), #1 gold center (116px, elevated), #3 bronze right (74px). Each shows avatar + name + score.

**Leaderboard list** (rank 4+): avatar + name + streak + workouts + animated score + rank-change badge (↑/↓ green/red).

### 3.7 Profile

**Header**: stacked editorial name — given name + surname on two lines, 38px Space Grotesk 800, letter-spacing −1.5. Edit / settings icons top-right.

**Stats row**: Workouts · Streak · Following · Followers — large numbers, no boxes.

**Weekly volume chart**: 8-bar chart; current week highlighted lime, previous week semi-transparent lime, older bars `s2`. Trend % shown above.

**Activity heatmap**: 12-week × 7-day grid, lime intensity scale (opacity 0.3–1.0), day labels M/T/W/T/F/S/S left side.

**Tab pill**: Posts | History | Achievements

- **Posts**: 3-column photo grid (Instagram style), tap → Post Detail
- **History**: session cards with date, type, exercise count, total volume
- **Achievements**: badge grid

### 3.8 Notifications

Full-screen overlay (bell icon tap from Feed).

**Groups**: Today | Yesterday

Each notification row: avatar (32px) + body text + time + unread dot (6px lime).

Types: new follower, session invite, workout reaction, buddy milestone.

### 3.9 Settings

Restyle only (structure already exists). Apply new tokens:
- Sections: `s1` cards with 20px radius
- Toggle rows: lime `Switch` for active state
- Pickers: `s2` pill chips
- Danger zone: error-colored text, ghost button

Sections: Notifications (4 toggles), Session Defaults (rest timer, weight unit), Privacy (profile/post visibility), Account (sign out, delete).

### 3.10 Theme Toggle

- Persistent user preference stored in `SharedPreferences` key `theme_mode`
- `ThemeMode.system` as default, `ThemeMode.light` / `ThemeMode.dark` as options
- Toggle button: sun ☀️ / moon 🌙 SVG icon, top-right of Feed header
- Wired into `MaterialApp.themeMode` via Riverpod provider `themeModeProvider`

---

## 4. Navigation

App shell wraps all 4 main tabs. Floating pill nav overlays the tab body. Session FAB tap → pushes Start Session flow on top of current tab.

Overlay screens (slide-up): Post Detail, Notifications, Settings. Full-screen routes: Session Room, Recap.

---

## 5. Assets / Fonts

Add to `pubspec.yaml`:
```yaml
fonts: []  # Removed — loaded via google_fonts package
```

Ensure `google_fonts` package is in `pubspec.yaml` (already present). Space Grotesk and DM Sans are available via `GoogleFonts.spaceGrotesk()` and `GoogleFonts.dmSans()`.

---

## 6. Out of Scope

- Onboarding flow (existing splash/auth flow retained as-is)
- Backend/Firebase changes
- Real PTT voice functionality (UI only, no WebRTC)
- Real-time leaderboard (live score ticker is UI-only animation)
