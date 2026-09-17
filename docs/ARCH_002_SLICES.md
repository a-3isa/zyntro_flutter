# Z-ARCH-002 — god-file extract campaign

**Status:** In progress (deferred until budgets met)  
**Date:** 2026-09-17

## Line / size budgets (targets)

| File | Soft budget | Notes |
| --- | --- | --- |
| `session_room_page.dart` | ≤ 80 KB / ≤ 2.5k LOC | ~90KB after 115; keep extracting orchestration |
| `profile_page.dart` | ≤ 60 KB | **Met** (~55.5 KB as of 109) |
| `social_page.dart` | ≤ 40 KB | **Met** (~43.5 KB — accept or trim 3.5KB later) |
| `start_session_page.dart` | ≤ 45 KB | Type/section/avatar extracted |
| `recap_page.dart` | ≤ 40 KB | Presentation widgets extracted |

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

## Next slices (suggested)

1. Session room V2 header shell  
2. Waiting/active turn wiring helpers  
3. Finish-session orchestration extract  
4. Social leaderboard list / people-you-may-know (optional trim)

Do not mark Z-ARCH-002 closed until every row meets soft budget **or** product accepts a revised budget with remaining god files listed.
