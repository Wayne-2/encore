# AGENTS.md

Flutter app ("Encore"). Entry: `lib/main.dart` → `SplashScreen` → welcome/auth → `HomeShell` (5-tab `PageView`: Updates, Messages, Finance, Profile, More).

## Commands
- `flutter analyze` — must report no issues before finishing.
- `flutter test` — runs `test/widget_test.dart` + `test/messages_test.dart` (~30 tests).
- Single file: `flutter test test/messages_test.dart`
- Single test: `flutter test test/widget_test.dart --plain-name "Updates shows Trending and opens Show more"`
- Icons: `dart run flutter_launcher_icons` (config in `pubspec.yaml`). No codegen, migrations, or CI.

## Styling (read before touching UI)
- Dark-only. `themeMode: ThemeMode.dark`; in `lib/theme/app_theme.dart` the light theme renders the same dark palette.
- Design tokens live in `lib/theme/`: `spotify_colors.dart` (palette; accent is the app green `#25A10C`, not Spotify green), `app_spacing.dart` (`AppSpacing`), `app_type.dart` (`AppType`, Spotify scale), `slack_type.dart` (`SlackType`), `app_theme.dart` (`AppTheme.fontFamily = 'Montserrat'`, bundled in `assets/fonts`).
- Two design languages intentionally coexist; do not merge them:
  - Spotify styling (`AppType` + `AppSpacing`) for most screens.
  - Slack-exact styling (`SlackType`) for the Announcement section (Updates page) and the Messages conversation tiles.
- Route all page-content text through `AppType`/`SlackType`. They apply the shared size→opacity hierarchy (`AppType.hierarchyOpacity`, 0.2 steps; `withHierarchy`). Don't hardcode content font sizes/colors/opacities.
- Auth screens under `lib/screens/auth/` (plus welcome/splash/getting_ready) set their own styles and are excluded from the shared hierarchy.
- Icons are SVGs in `assets/icons/`, referenced by bare name (e.g. `assets/icons/${tab.icon}.svg`).

## Navigation
- `lib/navigation/app_route.dart`: use `sharedAxisRoute` for navigational transitions, `fadeRoute` for splash/loading.

## Tests
- Tests pump screens directly, e.g. `MaterialApp(home: Scaffold(body: MessagesScreen()))`, and assert on `ValueKey`s. Keep these keys stable: `updates-scroll`, `announcement-show-more`, `announcement-$i`, `trending-show-more`, `trending-$i`, `activity-$i`, `all-announcement-$i`, `nav-<label>` (e.g. `nav-Messages`), `chat-three-dots-menu`, `paperclip-icon`, `send-button`, `direct-send-button`, `plus-button`.

## Conventions
- Match existing style: single quotes, trailing commas, `withValues(alpha:)` (not `withOpacity`).
- `analysis_options.yaml` excludes `build/**` and all platform dirs — don't edit generated platform code.
