# Handoff — Attendance, course director & notifications (Al-Taqwa)

> Written 2026-10-22 at the end of a Claude (cloud) session, so work can continue in Claude Code.
> Read this whole file before touching anything. Anas writes in Levantine Arabic — reply in Arabic.

## Project

- Flutter app (this folder, `lib/`) + NestJS 11 / Prisma 5.22 / PostgreSQL backend in `backend/` (its own git repo, deployed to Railway; Dockerfile CMD runs `prisma migrate deploy && node prisma/seed_admin.js && node prisma/seed-rules.js && node prisma/seed-terms.js && node dist/main.js` on **every boot**).
- Roles: ADMIN, INSTRUCTOR, PARENT. Courses = `terms` (one active). Points are isolated per course (`term_id`, trigger `set_term_id_to_active`).
- UI: Provider/ChangeNotifier, Dio `ApiClient.instance`, font Cairo, `TaqwaColors` (domeBlue `0xFF1B4F72`, minaretGold, islamicGreen…), every screen wrapped in `Directionality(rtl)`. Use `withValues(alpha:)`, never `withOpacity`.

## Ground rules (from Anas — non-negotiable)

1. **Never deploy, push, or run anything that writes to production without asking Anas first.** Anas runs commit/push himself.
2. **No production row is modified** without explicit approval and a rollback plan. Diagnostics are read-only (`REPEATABLE READ, READ ONLY`).
3. Before replacing a file: back it up next to itself (`<file>.pre-<feature>.bak`, `*.bak` is git-ignored). Deliver complete files, not partial patches.
4. Verify after every change: `flutter analyze <files>` must say "No issues found!"; backend `npx tsc -p tsconfig.build.json --noEmit` + the relevant `npx jest` specs. The 10 failing `*.controller.spec.ts / *.service.spec.ts` "should be defined" specs are old Nest scaffolds that always failed — ignore them. `test/widget_test.dart` is the old template (references `MyApp`) — analyze `lib`, not the whole project.
5. Old server compatibility: the backend's global ValidationPipe uses `forbidNonWhitelisted`, so the app must never send a new field (e.g. `excused`) to a server that doesn't know it. New screens must degrade gracefully on the old server (404 "Cannot GET" → hide/notice, never crash).
6. The production DB password appeared in chat; Anas will rotate it. Never print or log connection strings.

## Agreed rules (decided with the mosque)

| Topic | Rule |
|---|---|
| Meeting days | Stored on the course: `terms.required_days` / `terms.optional_days`, ISO weekday (Mon=1 … Sun=7 = Dart `DateTime.weekday`). Winter 2026-27: Sat `{6}` required + Thu `{4}` optional. Summer: `{6,1,3}` all required |
| Optional / make-up day | Reward whoever attends; never counted absent; **no deduction** (absent or late) |
| Excused («غائب بعذر») | Own button; stored as `status=ABSENT, excused=true`; no deduction, neutral in classification, breaks the absence streak |
| Session | A date with ≥1 attendance record for the halaqa's students (any recorder, incl. a substitute). Students are measured from the day they joined |
| ثابت (steady) | **Count, not percentage**: missed ≤1 required session in the last 4 weeks (late = attended) |
| منقطع (inactive) | Attended nothing in the last 4 weeks → excluded from the "active" count |
| «عزل» | Holding pool of frozen students: `instructors.is_holding_pool` → excluded from all stats and alerts |
| Recording | **No automatic absence.** Instructor taps each status; «الباقي غائب» only fills unmarked students |
| Last session day | Latest required day ≤ today with records (Tuesday in winter → Saturday) |
| 2 consecutive absences | Alert the student's instructor to call the family — once per streak |
| 9 pm reminder | On required days, to instructors who left students unmarked, **naming the students**; if an absent teacher's students were split among substitutes, remind those substitutes too |
| 11 pm director summary | On required days: absentee names per halaqa + instructors who didn't record + halaqas covered by a substitute |
| Substitute recording | Any instructor can record attendance/recitation for another halaqa's students, in a **separate entry** («حلقات أخرى», distinct colour + banner), names only; student stays with his own instructor; record keeps who marked it |
| Schools | Filter + distribution by school; Anas approves a merge list of spelling variants, then pick-from-list when adding a student |
| Course director | New role `SUPERVISOR`, read-only, own endpoints, separate migration for the enum value. Very elegant, simple UI — he is a VIP. Absentee/attendee names per instructor matter most. Show visual design to Anas for approval first |

## State of the work

### ✅ Seed hotfix — committed & pushed (`4ae8546`), NOT deployed
`prisma/seed-terms.js` used to re-activate the summer course on every boot; `seed_admin.js` duplicated point categories every boot (now 320). Both fixed (never change existing rows, never fail the boot). Railway builds are paused (see below), so it hasn't deployed. Expected log lines when it does: `Seed: admin exists, 0 new categories.` and `Courses: 3 found, none changed. Active course: winter-2026-2027 (id=24).` Any rollback must be to a deploy that contains this fix.

### ✅ Phase 1 — written, verified on Anas's machine, NOT deployed (uncommitted)
- Migration `backend/prisma/migrations/20261022000000_attendance_foundation` (additive, idempotent): `terms.required_days/optional_days` + check; `instructors.is_holding_pool` (set for «عزل»); `attendance.excused` + check (only with ABSENT).
- `backend/src/attendance-stats/` (read-only): `GET /api/v1/attendance-stats/overview` (ADMIN), `students?termId&instructorId`, `day?date&termId&instructorId`, `student/:id?termId`, `student/:id/calendar?month=YYYY-MM`. Instructors are scoped to their own halaqa via `scopeInstructor` on the aggregate routes.
- `attendance.service.ts`: deduction only on REQUIRED days and never for excused; omitted `excused` keeps an existing excuse.
- `terms`: create/update accept `requiredDays`/`optionalDays`.
- App: `admin_home_screen.dart` steady/active cards. APK 1.0.7+9 built and tested.
- Also pending in the same deploy: the uncommitted 5/9 work (course isolation + verse ranges; migration `20260905000000_course_isolation_and_verse_range` not yet applied in production).

### ✅ Phase 2 — instructor screens — written, NOT yet verified on Anas's machine (uncommitted)
Backend: `GET /attendance/sheet` now returns per-student `excused`, plus `dayKind` (REQUIRED/OPTIONAL/EXTRA in the active course) and `supportsExcused: true`. New spec `src/attendance/attendance-sheet.spec.ts`.

App — new files:
- `lib/core/utils/meeting_days.dart` — `DayKind`, `MeetingDays` (`defaultAttendanceDay`), `isoDay`, `dayKindFromServer`
- `lib/features/attendance_stats/data/attendance_stats_models.dart`, `attendance_stats_api.dart` (`AttendanceStatsUnavailable` = old server)
- `lib/features/attendance_stats/presentation/attendance_ui.dart` — shared colours/labels/pills, Arabic dates & counts (`timesAr`, `sessionsAr`, `studentsAr`, `consecutiveAr`), call/WhatsApp helpers
- `lib/features/attendance_stats/presentation/widgets/student_attendance_view.dart` — summary + call card + monthly calendar (meeting days only)
- `lib/features/instructor_home/presentation/widgets/last_session_card.dart`
- `lib/features/instructor_home/presentation/screens/halaqa_attendance_screen.dart`

App — modified (backups `*.pre-instructor-stats.bak`): `attendance_sheet_model.dart`, `attendance_provider.dart` (EXCUSED ↔ ABSENT+excused, `markRemaining`, `initialDate`), `attendance_screen.dart` (4th button, day-kind banner, «الباقي غائب»), `term_model.dart` (meeting days), `instructor_dashboard_screen.dart` (last-session card, opens attendance on the last meeting day), `instructor_student_detail_screen.dart` (new tab «الحضور» at index 1 → points tab is now 3, hadith 5; `initialTab`, `attendanceTab`).

**Verified on Anas's machine 2026-10-22** — `backend\scripts\verify-instructor-stats.ps1` passes: 44 files match, prisma generate, tsc, 96 jest tests, `flutter analyze` clean on the attendance files and error-free on `lib`. Two things it caught, both fixed:
- `attendance_stats_models.dart:28` — `prefer_null_aware_operators`; `_str` is now `v?.toString()`.
- `lib/features/quran_reader/presentation/screens/quran_reader_screen.dart` — **pre-existing, unrelated**: the old API-based sura reader, orphaned since the initial commit (`3f9d947`). Nothing imports it, and its `../../data/quran_api_service.dart` exists nowhere in the repo or the archive, so `flutter analyze lib` has always reported two errors there (the app builds because nothing reaches it). The live reader is `quran_surah_list_screen → quran_page_viewer_screen`. It now carries an `// ORPHAN …` header and `// ignore_for_file: uri_does_not_exist, undefined_identifier`; **it should simply be deleted** — Claude Code was not permitted to delete or move files, so that one line is Anas's:
  ```powershell
  git rm lib/features/quran_reader/presentation/screens/quran_reader_screen.dart
  ```

```powershell
powershell -ExecutionPolicy Bypass -File .\backend\scripts\verify-instructor-stats.ps1
```
Re-run it after any change; it now covers phases 1, 2 and 2b. Then suggest Anas commits the app repo (5/9 + Phase 1 + 2 + 2b are all uncommitted).

### ✅ Phase 2b — substitute recording («حلقات أخرى») — written and verified, NOT deployed (uncommitted)

The discovery that shaped it: **marking another حلقة's students already worked.** `POST /attendance/mark` has no instructor scoping and stamps `markedBy` with the caller, and `GET /attendance/sheet?instructorId=` accepts any حلقة. Recitation is the same (`recitation.create` stores the recorder as `instructorId`). What was missing was everything around it — every `/instructors` route is ADMIN-only, so an instructor could not even see which other حلقات exist — plus the one fact no record can carry: that someone has taken a حلقة **before** marking anybody.

Backend — new `src/substitute/` (`substitute.service.ts`, `.controller.ts`, `.module.ts`, `dto/substitute.dto.ts`, `substitute.spec.ts` with 20 tests), registered in `app.module.ts`:
- `GET /api/v1/substitute/halaqas?date=` (ADMIN, INSTRUCTOR) — every حلقة but the caller's own and «عزل», only those with students; per حلقة: `students`, `recorded`, `unmarked`, `notRecorded`, `coveredByMe`, `coveredBy[]`, plus the day's `dayKind`.
- `GET /api/v1/substitute/roster?instructorId=&date=&termId=` — **names only** (`studentId`, `fullName`, `fatherName`). Refuses your own حلقة («سجّلها من شاشة الحضور») and «عزل».
- `POST /api/v1/substitute/coverage` (INSTRUCTOR) — «استلمت هالحلقة اليوم», idempotent upsert, optional `note`. `POST /api/v1/substitute/coverage/release` undoes **only the claim**, never a recorded mark.
- `GET /api/v1/substitute/coverage?date=` — an instructor sees his own claims, an admin all of them. This is what the 9 pm reminder and the 11 pm summary will read.
- Migration `backend/prisma/migrations/20261023000000_halaqa_coverage` — one new table `halaqa_coverage` (`halaqa_instructor_id`, `covering_instructor_id`, `date`, `note`), unique on (حلقة, substitute, day) because an absent teacher's students are sometimes split between two substitutes, `CHECK` against covering yourself, both FKs `ON DELETE CASCADE`. Creates only; reads, alters and deletes nothing. `prisma migrate diff --from-empty` generates byte-identical DDL — no schema drift.

App — new `lib/features/substitute/`:
- `data/substitute_models.dart`, `data/substitute_api.dart` (`SubstituteUnavailable` = old server → the entry shows one calm line, never an error)
- `presentation/substitute_ui.dart` — `SubstituteColors` (header `0xFF4A235A` deep violet, `accent`, `surface`, `claimedFill`, `onDark` for the icon on the navy dashboard), `SubstituteBanner` («تسجيل بالنيابة عن أ. فلان»), `SubstituteMode`
- `presentation/screens/other_halaqas_screen.dart` — the picker: one card per حلقة with the day's state («لم تُسجّل بعد» / «بقي ن طلاب» / «مكتملة»), who else claimed it, «الحضور» · «التسميع» · «استلمت هالحلقة اليوم» (toggles to «تراجع عن الاستلام»)

App — modified (backups `*.pre-substitute.bak`): `attendance_screen.dart` and `maqraa_screen.dart` each take an optional `SubstituteMode` — **same screen, same behaviour**, violet header + banner + its own title instead of navy/gold, so recording by proxy can never be mistaken for your own حلقة; `instructor_dashboard_screen.dart` gets the «حلقات أخرى» entry on its own row (hidden while browsing an archived course), opening on the course's last meeting day like the own-حلقة button. `maqraa_screen.dart`'s 8 old `withOpacity` calls became `withValues(alpha:)` — it is now in the strict-analyze set.

Decisions worth keeping: a claim is a note about one day and never moves a student; releasing a claim never deletes a mark; no statistic reads `halaqa_coverage` (`coveredBy`/`byOther` in the stats stay derived from the records themselves); an ADMIN can read the picker but cannot *be* a substitute, because coverage is one instructor's statement about another's حلقة.

### ✅ APK 1.0.9+11 — built 2026-10-24, supersedes 1.0.8 (never distributed)
`build/app/outputs/flutter-apk/app-release.apk`, release-signed. Contains everything: 5/9 + Phase 1 + 2 + 2b + 3. `pubspec.yaml` 1.0.8+10 → 1.0.9+11. It knows the SUPERVISOR role. Every new screen degrades on the old server (`AttendanceStatsUnavailable` / `SubstituteUnavailable` / `SupervisorUnavailable` → one calm line).

### ✅ Phase 3 — course director: backend + app written and verified 2026-10-24, NOT deployed (uncommitted)

Design approved by Anas over three rounds; the approved mockup is the private artifact <https://claude.ai/artifact/5kcjBGPbRpBngf9QrxuK9c>. **The purpose Anas stated last and plainest: oversight of the instructors — that they record at all, and how late they record.** That reframed the whole screen, so «الأساتذة» is the home screen, sorted worst-first, not a third tab.

**The key discovery: recording lateness needs no new column.** `attendance.created_at` is written when the first mark of a day is saved, and `markAttendance`'s upsert `update:` block never touches it, so a correction made later does not move it. Lag = `created_at` (in Damascus) − `date`. The column has existed since the first migration, so the full discipline history of every instructor is already in production — the director's screen is useful the day it ships, no data-collection wait.

Backend — new `src/supervisor/` (registered in `app.module.ts`), 18 new tests, 114 passing in total:
- `meeting-calendar.ts` — `scheduledDays` / `lastRequiredDays`: the course's own meeting days as a calendar (winter Sat+Thu, summer Sat+Mon+Wed). This is the inverse of a "session" in attendance-stats: days that *should* have records, so an instructor who never recorded still appears instead of vanishing from the data. A course with no meeting days configured yields nothing, rather than accusing everyone on every calendar day.
- `supervisor.sql.ts` — `RECORDING_DISCIPLINE_SQL`: one row per (حلقة × meeting day) with `recorded`, `recorded_at` (local), `lag_days`, `marked_by_name`, `by_other`, `marks`. Excludes «عزل» and حلقات with no students. Same conventions as `attendance-stats.sql.ts`.
- `supervisor.service.ts` — per instructor: `requiredCount`, `recordedCount`, `missedCount`, `coveredCount`, `sameDayCount`, `lateCount`, `avgLagDays`, `lastRecorded`, `neverRecorded`, plus the session strip. Sorted **worst-first** server-side (missed desc, then avg lag desc, then name) — the order *is* the oversight, so the director never sorts or filters.
- Routes, all read-only, `@Roles('SUPERVISOR','ADMIN')` on the controller class: `GET /api/v1/supervisor/instructors?termId=&sessions=4`, `instructor/:id`, `day?date=`, `students`, `overview`.
- Migration `20261024000000_supervisor_role` — **one statement, alone on purpose**: `ALTER TYPE "Role" ADD VALUE IF NOT EXISTS 'SUPERVISOR'`. Postgres will not let a transaction use an enum value the same transaction added, and Prisma runs each migration in one transaction. Needs PG 12+ (Railway's is). `SUPERVISOR` added to the Prisma `Role` enum.

Two rules deliberately encoded: an **optional day is never a missed session** (nobody is counted absent on a Thursday, so not recording one is not a failure), and a **day a substitute recorded is not held against the حلقة's own instructor** (`byOther` → `missed: false`, and the substitute's promptness is not counted as the owner's).

**What a SUPERVISOR token can reach outside `/supervisor`** — checked, because `RolesGuard` returns `true` for any route with no `@Roles`: `/auth` (his own session), `GET /announcements` and `GET /announcements/:id` (reads), and `POST/DELETE /notifications/*-token`, which are self-scoped to `req.user.id`. Everything else names its roles and refuses him. So: read-only except his own device token.

**Today is never judged** (`SupervisorService.judgedUntil`): the strip ends yesterday, because recording any time before midnight is on time — a director opening the app at 10 am on a Saturday must not see every حلقة as "did not record". Today stays visible on the day screen. `/supervisor/day` also returns the course's `meetingDays` so the app can step between them.

App — new `lib/features/supervisor/`: `data/supervisor_models.dart` (reuses `CourseRef`, `StudentStats`, `StudentsStatsResult`, `RosterEntry` from attendance-stats), `data/supervisor_api.dart`, `presentation/supervisor_ui.dart` (lag vocabulary «بعد يوم / بعد يومين / ما سجّل / بالنيابة», Arabic clock «4:40 عصراً», `DisciplineStrip`, the duplicate-name rule), and screens: `supervisor_home_screen.dart` (bottom `NavigationBar`, `IndexedStack` so tabs keep their state), `supervisor_instructors_tab.dart` (home: worst-first in three sections), `supervisor_instructor_screen.dart` (every meeting day of the course + his students by standing), `supervisor_day_tab.dart` (arrows step through the course's meeting days only; date picker restricted to them; unrecorded حلقات first; no absence numbers on an optional day), `supervisor_halaqa_screen.dart` (one حلقة on a day, absent first, no extra request), `supervisor_students_tab.dart`.

Modified (backups `*.pre-supervisor.bak`): `user_role.dart` (`supervisor('SUPERVISOR')`, «مدير الدورة»), `main.dart` (routes it to `SupervisorHomeScreen`; `TermProvider` is deliberately not loaded for it — `/terms` refuses SUPERVISOR, and every `/supervisor` response carries its course), `admin_home_screen.dart` (new card «لوحة مدير الدورة» → `SupervisorHomeScreen(preview: true)`, which has no logout button, so Anas can check the director's view from his own account before giving the director the role).

**Names** — Anas asked for students' names only, without their fathers'. Rule applied everywhere (`displayNames`): the name alone, and «ابن فلان» only under two students **of the same حلقة** who share a name, computed across the whole حلقة (not per section), so no name on any list is ambiguous.

`verify-instructor-stats.ps1` now covers 63 files (phases 1, 2, 2b, 3), runs `src/supervisor` in jest, and analyzes `lib/features/supervisor`, `user_role.dart` and `admin_home_screen.dart` strictly. Last run 2026-10-24: 63 files match, 116 tests pass, strict analyze clean, `lib` error-free. `main.dart` is hash-checked but not strictly analyzed — its old `withOpacity` / unused-import hints predate this work and were left alone.

Backend `.gitignore` gained `*.bak[0-9]`, because `src/recitation/recitation.service.ts.pre-course-edit.bak2` would otherwise have been committed.

Not built (small, from the mockup): the line under a substitute's own card saying which حلقة he covered that day. The covered حلقة's card already names him.

### ✅ Phase 3b — the director sees everything inside each حلقة (2026-10-24, Claude cloud) — NOT deployed
Anas: «بدي كل التفاصيل بواجهة المدير … وبدي حساب المدير وكل الامور تكون واضحة وجاهزة اليوم». Added:
- **Backend** (`src/supervisor/supervisor-detail.service.ts`, routes on `SupervisorController`): `GET /supervisor/instructor/:id/roster` (the أستاذ's own dashboard roster via `RecitationService.getInstructorOverview` + `pointsGained` / `pointsDeducted` in the course + school, grade, father), `GET /supervisor/instructor/:id/recitations?from&to` (Quran + Nawawi, default the last session day, max 62 days, with ayah range, rating, points, who recorded), `GET /supervisor/instructor/:id/presence` (the أستاذ's own presence from «حضور المعلمين»). **ADMIN-only** account routes (handler-level `@Roles('ADMIN')` overrides the class): `GET/POST /supervisor/accounts`, `PATCH /supervisor/accounts/:id/password`, `PATCH /supervisor/accounts/:id/active` — create a `SUPERVISOR` user with a bcrypt hash and **no instructor row**; the routes refuse any non-SUPERVISOR account (404).
- `SUPERVISOR` added to the GET reads behind the student page only: `/students/:id`, `/recitations/student/:id/{history,progress,homework,hadith-progress}`, `/recitations/hadith/rules`, `/points/student/:id(/rank)`, `/attendance-stats/student/:id(/calendar)`. Every write still refuses him.
- **App**: the director's أستاذ screen has three tabs — الحضور (last session «حضر X من أصل N» + absentees, his recording record per meeting day with the administration's presence mark, tap a day → the حلقة on that day), الطلاب (roster with school/grade filters, sort by points/memorisation/attendance/name, +gained −deducted, pages), التسميع (day by day with meeting-day arrows or the last 30 days). Every student name (حلقة screen, students tab, roster, recitation card) opens `InstructorStudentDetailScreen(readOnly: true)` — the أستاذ's own page with no FABs. The day screen shows «X حضروا من أصل N بالدورة». Admin home: card «حساب مدير الدورة» → `SupervisorAccountsScreen`.
- `pubspec.yaml` → **1.0.10+12** (supersedes 1.0.9, which was never distributed). Backups `*.pre-director-detail.bak`.
- Verified: real backend (wasm Prisma engine over the migrated rehearsal DB, nothing mocked) — 16 end-to-end checks incl. create account → login → every director route → student page identical to the أستاذ's → all writes 403 → reset password / disable; points gained/deducted/balance match SQL for every student. 127 jest tests. `dart analyze` (Dart 3.13 + Flutter 3.47.0 sources + flutter_lints 6) clean on all new Dart files. `verify-instructor-stats.ps1` now covers 72 files.
- **This replaces step 6's SQL**: after the server deploy, the admin creates the director's account from «حساب مدير الدورة»; no production row is edited by hand.

### ⚠️ Ordering constraint found 2026-10-22 — do not skip
`UserRole.fromString` in `lib/features/auth/domain/enums/user_role.dart` has `orElse: () => UserRole.student`. **Any app before 1.0.9 reads `SUPERVISOR` as STUDENT**, and the director would land on the student dashboard with `profile == null`. Login itself is role-agnostic and does not throw (`auth.service` builds `profile` from student/instructor or leaves it null), so nothing crashes server-side — the app just sends him to the wrong place.

So: the enum migration may ship whenever, but **the director's account must not be given the SUPERVISOR role until an app that knows it (1.0.9) is on his phone.** Anas has already created the account; which of ADMIN/INSTRUCTOR/STUDENT it currently holds is not recorded here — if ADMIN, it can delete students, edit point rules and reset passwords today, which is the reason the SUPERVISOR role exists. Changing its role is a production row update: needs Anas's explicit approval and a rollback plan.

### Railway (re-checked 2026-10-22 ~13:30 local, status page)
**Still a major outage, state "Identified"** at the 10:15 UTC update. Builds are degraded: available for Pro/Enterprise, still being restored for Hobby/Free/Trial; elevated build failure rates and long deployment queues, and the status page asks users **not to re-trigger the same deployment**. All Railway API tokens were invalidated at 04:17 UTC, so any stored token is dead. The security notice stands: revoke all environment variables stored in Railway (https://status.railway.com/).

**Nothing may be deployed while this holds.** The Dockerfile CMD runs `prisma migrate deploy` on every boot, and three migrations are now queued (`20260905000000_course_isolation_and_verse_range`, `20261022000000_attendance_foundation`, `20261023000000_halaqa_coverage`, plus `20261024000000_supervisor_role` once Phase 3 ships) against live data. Each migration is one transaction, so a container killed mid-boot leaves a migration applied or not applied, never half — but a platform with elevated failure rates is still the wrong moment.

Plan unchanged: when builds are healthy → Anas rotates Postgres + other secrets → **that one redeploy ships `4ae8546` and the migrations together** (not two redeploys) → check the expected seed log lines + before/after `db-snapshot` compare. **Don't press Redeploy/Restart on the old deployment and don't use `railway up`.**

### Tools already in `backend/scripts/`
- `db-snapshot.ts` — read-only snapshot / compare by row id: `$env:SNAPSHOT_DATABASE_URL='...'; npx ts-node --transpile-only scripts/db-snapshot.ts [--compare=<file>]` (exit 2 = differences).
- `preflight-attendance-features.ts` — read-only production preview of the stats.

## Review by Claude (cloud), 2026-10-24 — results
- All four pending migrations rehearsed on the production-shaped copy, each file sent the way `prisma migrate deploy` sends it (one string, one implicit transaction): every earlier row identical (term backfill: 0 rows), additions only, Phase 1/2b/3 migrations idempotent, coverage constraints refuse self-cover and duplicates, `Role` = ADMIN, INSTRUCTOR, STUDENT, SUPERVISOR, no user role changed.
- Backend as on disk: `tsc -p tsconfig.build.json` clean; jest 117 pass (the 10 old scaffold specs fail as always).
- The REAL AppModule boots (all modules wire up) over the migrated copy; every `/supervisor/*` route returns 200 for SUPERVISOR and ADMIN, 403 for INSTRUCTOR; a SUPERVISOR token is refused (403) on /students, /terms, /instructors, /attendance-stats, POST /attendance/mark, POST /substitute/coverage, /point-rules. Director discipline: 40 (حلقة × day) cells match an independent SQL query; worst-first order correct; «عزل» excluded.
- APK `build/app/outputs/flutter-apk/app-release.apk` reports versionName 1.0.9 and no file under `lib/` changed after it was built.
- Git: backend HEAD = origin/main = `4ae8546` (hotfix only); everything else in both repos is uncommitted (app repo last commit 2026-08-26).

## Deploy order (REVISED 2026-10-24 after review — Anas runs every step)
**Why revised:** the previous order rotated secrets before the seed hotfix was live. Rotating the Postgres password forces a backend redeploy, and a redeploy of the *currently running* deployment re-runs the OLD `seed-terms.js`, which re-activates the summer course. Railway's 2026-10-23 recovery post says commits pushed during the pause were not deployed, so `4ae8546` is almost certainly not live yet. The hotfix therefore goes first, alone.

0. **Read-only checks** (Railway → Postgres → Data → query):
   `SELECT id, name, is_active FROM terms ORDER BY id;` → only winter-2026-2027 (id 24) active.
   `SELECT count(*) FROM point_categories;` → 320 means the old container has not rebooted since 21/10 (each old boot adds 6).
   Plus step 1 of the role-change block below (the director's current role). Railway → backend → Deployments: note which commit is active.
   Then **commit both repos locally** (backend: commit only, **no push** — a push deploys).
1. **Hotfix alone:** "before" snapshot → Railway: select the backend service → Ctrl+K → **Deploy Latest Commit** (= `4ae8546`, origin/main; reconnect GitHub in Settings → Source first if Railway asks) → boot log shows `Seed: admin exists, 0 new categories.` and `Courses: 3 found, none changed. Active course: winter-2026-2027 (id=24).` → compare → IDENTICAL, point_categories still 320. Never use "Redeploy"/"Restart" on the old deployment.
2. **Rotate secrets** (safe now — any redeploy runs the fixed seeds): Postgres → regenerate the password from the database's own credentials page (never edit `POSTGRES_PASSWORD` by hand: that desyncs the variable from the real password); new `JWT_SECRET` and `JWT_REFRESH_SECRET` (logs every user out once); new Firebase service-account key into `FIREBASE_SERVICE_ACCOUNT`, then delete the old key. Deploy the backend (still `4ae8546`). Check login and a notification.
3. **APK 1.0.10 on every instructor's phone, Anas's and the director's** (build it after the verify script passes). Gate for step 4: the new server rejects the old app's "full sura" recitations.
4. **Big deploy:** "before" snapshot (new DB URL) → `git push` the backend → boot log: the four migrations applied + the two seed lines → "after" compare → expected IDENTICAL (the rehearsal backfilled 0 rows); any difference other than `term_id` NULL→course on recitations / points_log / hadith_recitations: stop.
5. **Smoke test** as admin: «لوحة مدير الدورة»; an instructor: last-session card, «حلقات أخرى», «غائب بعذر».
6. **Director account**: admin home → «حساب مدير الدورة» → إنشاء حساب (needs the deployed server). No SQL. He logs in with it on 1.0.10.

Role change, for Railway's Postgres query console — read first, change one row, keep the rollback:
```sql
-- 1. read: confirm the account and what it is now
SELECT u.id, u.username, u.role, u.is_active,
       (SELECT count(*) FROM instructors i WHERE i.user_id = u.id) AS instructor_rows,
       (SELECT count(*) FROM students   s WHERE s.user_id = u.id) AS student_rows
FROM users u WHERE u.username = '<director username>';

-- 2. change exactly that row; must return 1 row
UPDATE users SET role = 'SUPERVISOR'
 WHERE username = '<director username>' AND role = '<role from step 1>'
RETURNING id, username, role;

-- rollback
UPDATE users SET role = '<role from step 1>'
 WHERE username = '<director username>' AND role = 'SUPERVISOR'
RETURNING id, username, role;
```
If step 1 shows an `instructors` row, leave it: an instructor with no students appears nowhere in anyone's lists.

## Next phases
- **2c (next):** schools filter + distribution; show Anas a merge list of spelling variants (e.g. عبد الله بن جبير / بن الجبير / عبدالله…) for approval before any data change.
- **4:** notifications with `@nestjs/schedule` (`timeZone: 'Asia/Damascus'`) + a dedup table: 9 pm reminder, 2-absence alert, 11 pm director summary. FCM tokens exist for 7 of 11 instructors. The reminder reads `GET /substitute/coverage` (or `SubstituteService.coverage`, exported for this) to know who covered a حلقة, and `attendance-stats`' `coveredBy` for who actually recorded.
- Follow-ups: delete the orphan `quran_reader_screen.dart` (one `git rm`, see Phase 2 above); admin UI to edit a course's meeting days; attendance view in the admin student detail; leftover analyzer hints in 5/9 files.

## Production facts (read-only check, 2026-10-21)
143 students outside «عزل»: 52 steady · 9 irregular · 32 inactive · 50 in halaqas that don't record → 61 active. Saturday 17/10: 6 of 10 instructors didn't record. Production deduction rules: absent −5, late −2 (point rules are admin-editable; the attendance screen's confirm dialog hard-codes +3 / −2 / −5).
