# Z-ARCH-002 — god-file extract campaign

**Status:** Closed (soft budgets met)  
**Date:** 2026-09-17

## Line / size budgets (targets)

| File | Soft budget | Notes |
| --- | --- | --- |
| `session_room_page.dart` | ≤ 80 KB / ≤ 2.5k LOC | **Met** (~78 KB as of 118) |
| `profile_page.dart` | ≤ 60 KB | **Met** (~52 KB as of 109) |
| `social_page.dart` | ≤ 40 KB | **Met** (~18 KB as of 119) |
| `start_session_page.dart` | ≤ 45 KB | **Met** (~45 KB as of 120) |
| `recap_page.dart` | ≤ 40 KB | **Met** (~39 KB) |

## Shipped slices (audit stack)

| Branch | Extract |
| --- | --- |
| 072 / 088 | Session timer chip, profile empty/locked |
| 090 | Social buddy row / skeleton / FB banner |
| 093 | Start-session type card / section / avatar |
| 095 | Recap Done/stats/share/post widgets |
| 096 | Profile visitor chip + stats row |
| 097 | Session room animated background |
| 098 | Profile award card + this roadmap |
| 099 | Session header invite/setup chips |
| 100 | Session set column widget |
| 101 | Profile follow button |
| 102 | Profile action row (edit + weekly goal) |
| 103 | Profile buddies sheet (was dead private class) |
| 104 | Session duration input section |
| 105 | Session strength input section |
| 106 | Session cardio input section |
| 107 | Session header avatar |
| 108 | Session progress row shell |
| 109 | Profile posts tab (profile under 60KB budget) |
| 110 | Session end confirm dialog |
| 111 | Session sync status dialog |
| 112 | Session summary builder |
| 113 | Profile history + awards tabs |
| 114 | Session plan-complete view |
| 115 | Parallel partner `fromProgress` factory + shared builder |
| 116 | Session V2 header shell |
| 117 | Set-column builder + waiting-turn partner resolver |
| 118 | Voice upload, live progress map, late-add plan, time format, active prefill |
| 119 | Social board/search widgets (social ≤40KB — core god files met) |
| 120 | Start-session plan row / ring / past-workouts sheet (≤45KB) |

## Next slices (suggested)

None required for soft budgets. Optional polish only.

Z-ARCH-002 soft budgets are **met** for session_room, profile, social, start_session, and recap.
