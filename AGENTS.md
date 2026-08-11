# AGENTS.md

Guidance for AI coding agents working on this repository. Assumes no prior knowledge of the project.

## Project overview

**raqi_companion** ("Raqi Companion") is an offline Flutter app providing Quranic ayats and adhkar for ruqyah shari'ah. It is a read-only content browser with:

- A category list (home screen) of ruqyah content groups.
- Per-category item lists showing Arabic text with a bookmark toggle.
- A detail screen per item with Arabic, transliteration, translation, an optional note, and a tap counter for repetitions (`repeat` field).
- A "Session" screen: a guided checklist across all categories with a progress bar (in-memory only, not persisted).
- Bookmarks persisted locally via `shared_preferences`.

All content ships in a single bundled JSON asset (`assets/data/ruqyah.json`); there is no backend, network access, or account system.

## Technology stack

- **Flutter 3.44.9 (stable channel)** / **Dart SDK `>=3.0.0 <4.0.0`** (see `pubspec.yaml`).
- **Platforms enabled:** Android and Web only (see `.metadata` migration list and the `android/` and `web/` directories). There are no `ios/`, `linux/`, `macos/`, or `windows/` runners.
- **Runtime dependencies:** `shared_preferences` (^2.2.3) only, plus the Flutter SDK.
- **Dev dependencies:** `flutter_test` (SDK), `flutter_lints` (^3.0.0).
- **Android:** Gradle Kotlin DSL (`android/build.gradle.kts`, `android/app/build.gradle.kts`), Java/Kotlin 17, `applicationId = com.example.raqi_companion`, namespace `com.example.raqi_companion`. Release builds currently sign with the debug key (marked TODO in `android/app/build.gradle.kts`).

## Repository layout

```
lib/
  main.dart                        App entry point, theme (Material 3, seeded color scheme,
                                   light/dark), shared arabicStyle() text helper
  models.dart                      RuqyahItem and Category data classes with fromJson factories
  data_service.dart                DataService: loads/caches assets/data/ruqyah.json, findItem lookup
  bookmarks.dart                   BookmarkStore (ChangeNotifier) backed by shared_preferences
  screens/
    category_list_screen.dart      Home screen; also maps category icon names to IconData
    item_list_screen.dart          Items of one category with bookmark toggles
    ayat_detail_screen.dart        Full item view with prev/next navigation and repeat counter
    session_screen.dart            Guided checklist across all categories (state not persisted)
    bookmarks_screen.dart          List of bookmarked items
assets/data/ruqyah.json            All content: {"categories": [...]}, 5 categories, 22 items total
web/                               Web runner (index.html, manifest, icons)
android/                           Android runner (Gradle Kotlin DSL)
```

Data model (`assets/data/ruqyah.json`, mirrored by `lib/models.dart`): each category has `id`, `title`, `subtitle`, `icon` (a string key mapped to `IconData` in `category_list_screen.dart`), and `items`. Each item has `id`, `reference`, `arabic`, `transliteration`, `translation`, `repeat` (default 1), `note`. Optional string fields default to `''`.

## Architecture and conventions

- **No state-management package.** State is plain `StatefulWidget` + `setState`, with one app-wide `BookmarkStore extends ChangeNotifier` created in `_RuqyahAppState` and passed down constructors; screens that show bookmark state wrap themselves in `AnimatedBuilder(animation: bookmarks)`.
- **No routing package and no named routes.** Navigation uses `Navigator.push(MaterialPageRoute(...))` directly.
- **Data loading:** `DataService.loadCategories()` reads the JSON asset once via `rootBundle` and caches it in a static field; `main.dart` drives it with a `FutureBuilder`.
- **Styling:** single theme factory `_theme(Brightness)` in `lib/main.dart` (Material 3, seed color `0xFF6B5D4F`); Arabic text always uses the shared `arabicStyle(context)` helper (RTL `Directionality` is applied per-widget at call sites). Theme mode follows the system.
- **Language:** all code, comments, and UI strings are in English; content data includes Arabic and transliteration.
- **Linting:** `analysis_options.yaml` includes `package:flutter_lints/flutter.yaml` with no overrides. Code currently passes `flutter analyze` with zero issues — keep it that way.
- **Dependency policy:** the app is intentionally dependency-light. Confirm a package is truly needed before adding one, and pin it in `pubspec.yaml`.

## Build and run commands

Flutter SDK is installed on this machine (`flutter` on PATH). Usual workflow:

```bash
flutter pub get          # install dependencies
flutter analyze          # static analysis (must stay clean)
flutter test             # runs tests (see note below — no tests exist yet)
flutter run              # run on a connected device/emulator (Android) or web
flutter run -d chrome    # run on web
flutter build apk        # Android release APK
flutter build web        # web release build (output in build/web)
```

## Testing instructions

- **There is currently no `test/` directory and no tests.** `flutter_test` is already in dev dependencies, so add widget/unit tests under `test/` (e.g. `test/bookmarks_test.dart`) when making behavioral changes.
- `flutter analyze` is the only enforced check today; run it before considering any change done.
- When testing bookmark behavior, note that `BookmarkStore` uses the `shared_preferences` plugin — in widget tests, call `SharedPreferences.setMockInitialValues({})` first.

## Security and content considerations

- The app is fully offline: no network calls, no permissions beyond defaults, no user data leaves the device. Do not add network permissions or telemetry without an explicit request.
- Bookmarks are stored only in local `shared_preferences` under the key `'bookmarks'`.
- Android release builds are signed with the debug key — fix the signing config in `android/app/build.gradle.kts` before any real distribution.
- `assets/data/ruqyah.json` contains religious content (Quranic verses with translations). Treat its text with care: do not alter Arabic strings, references, or translations unless explicitly asked, and validate the JSON after any edit (it must remain valid UTF-8 and parse cleanly).
