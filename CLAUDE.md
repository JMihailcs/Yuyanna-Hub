# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project

Yuyanna Hub is a Flutter app for UNSAAC (Universidad Nacional de San Antonio Abad del Cusco) students to browse *convocatorias* (calls: incubation, exchange, research funding) and form/join *grupos* (teams) to apply to them. Domain language, UI text, and identifiers are in Spanish — keep new code consistent with that. Build targets are Android and web only (no ios/desktop directories).

## Commands

```sh
flutter pub get                    # install dependencies
flutter run                        # run the app (add -d chrome for web)
flutter analyze                    # lint (default flutter_lints ruleset)
flutter test                       # run all tests
flutter test test/widget_test.dart # run a single test file
flutter test --plain-name "Splash screen shows app name smoke test"  # run one test by name
```

## Architecture

Layered but intentionally simple — no state-management package, no routing package, no codegen:

- **`lib/services/`** — the backend is **Firebase (Auth + Cloud Firestore)**, on the free Spark plan (no Cloud Functions, no FCM yet). Services are instantiated directly by screens and are injectable (`{FirebaseFirestore? firestore, FirebaseAuth? auth}`) for tests with `fake_cloud_firestore`/`firebase_auth_mocks`.
  - `auth_service.dart` — `AuthService`: email/password register/login/logout/reset; writes the profile to `usuarios/{uid}`; caches the `Usuario` in `LocalSessionManager` so screens keep reading from there. No email-domain restriction, but `Usuario.esUnsaac` tags `@unsaac.edu.pe` users.
  - `convocatoria_service.dart` — `ConvocatoriaService`: reads/creates events in the `convocatorias` collection (with optional `imagen_url`/`video_url`). Creating is admin-only (enforced by rules).
  - `grupo_service.dart` — `GrupoService` owns the **team-formation domain logic** over Firestore collections `grupos`/`invitaciones`/`solicitudes`: groups start as `borrador`; on `publicarGrupo` it scores the real `usuarios` directory against `habilidadesBuscadas` (10 pts/skill + semestre tie-break) and invites the top `maxInvitaciones`; invitees join via `aceptarInvitacion`; others `solicitarIngreso` → leader `responderSolicitud` (or `agregarMiembro`). Full groups auto-close and expire pending invitations/solicitudes. Queries use a single field + in-memory filter to avoid composite indexes; invitations/solicitudes carry scalar `usuario_id`/`lider_id` for rules. Covered by `test/grupo_service_test.dart`. **The team-logic writes touch other users' docs (cascade), so `firestore.rules` allows any authenticated write on these three collections — a pilot trade-off to harden with Cloud Functions on Blaze.**
  - `admin_service.dart` — `AdminService`: admin role via the `admins/{uid}` collection. The first admin bootstraps from `correosFundadores` (must match `esFundador()` in `firestore.rules`): a founder auto-provisions their admin doc on Home load.
- **`lib/database/sqlite_helper.dart`** — misleadingly named: `LocalSessionManager`, a static `shared_preferences` wrapper (not SQLite) caching the login flag + serialized `Usuario`.
- **`lib/models/`** — plain immutable classes (`Usuario`, `Convocatoria`, `Grupo`, `InvitacionGrupo`, `SolicitudIngreso`, `MiembroResumen`) with manual `fromJson`/`toJson`/`copyWith`; JSON keys are snake_case (e.g. `escuela_profesional`). `Grupo.miembros` holds **denormalized `MiembroResumen` summaries** (id/nombre/escuela/semestre), not full `Usuario` objects, so a group loads its members in a single read (no N+1 in Firestore); the authoritative profile lives in `usuarios/{uid}`.
- **`lib/screens/`** — StatefulWidgets managing their own state via `setState`. Navigation flow: `SplashScreen` (2.5s delay, checks `LocalSessionManager.getLoginState()`) → `LoginScreen`/`RegisterScreen` or `HomeScreen`. `HomeScreen` hosts a 3-tab `IndexedStack` (feed / `CrearGrupoScreen` / `ProfileScreen`) switched by `MenuWidget` (bottom nav) and pushes detail screens (`GruposScreen`, `NotificacionesScreen`) with plain `Navigator.push`/`MaterialPageRoute` — no named routes. The feed tab is a **TikTok-style vertical `PageView`** of full-screen convocatoria pages; its top bar shows an unread-invitation badge count fetched via `getInvitacionesParaUsuario`.
- **`lib/theme/`** — all styling goes through here: `AppColors`/`AppGradients` (institutional red/blue/gold palette), `AppTypography` (google_fonts), and `AppTheme.light()` (Material 3, light theme only). Don't hardcode colors or text styles in screens.
- **`lib/widgets/`** — shared UI (gradient button, convocatoria card, bottom nav, logo glyph, `selector_usuario` directory picker). Screen-private widgets live as private classes inside their screen file.

Other conventions in the codebase: auth requires an `@unsaac.edu.pe` email (validated in `LoginScreen`), and entrance animations use `flutter_animate`.

Note on tests: `SplashScreen` starts a 2.5s timer, so widget tests that pump the app must advance time past it (see `test/widget_test.dart`) or the test framework reports a pending timer.
