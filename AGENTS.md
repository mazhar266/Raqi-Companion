# AGENTS.md

Guidance for AI coding agents working on this repository. Assumes no prior knowledge of the project.

## Project overview

**raqi_companion** ("Raqi Companion") is an offline Flutter app providing Quranic ayats and adhkar for ruqyah shari'ah. It is a read-only content browser with:

- A category list (home screen) of ruqyah content groups.
- Per-category item lists showing Arabic text with a bookmark toggle.
- A detail screen per item with Arabic, transliteration, translation, an optional note, and a tap counter for repetitions (`repeat` field).
- A "Session" screen: a guided checklist across all categories with a progress bar (in-memory only, not persisted).
- Bookmarks persisted locally via `shared_preferences`.
- An appearance setting (Light / Dark / System, default System) persisted the same way.

All content ships in a single bundled JSON asset (`assets/data/ruqyah.json`); there is no backend, network access, or account system.

## Technology stack

- **Flutter 3.44.9 (stable channel)** / **Dart SDK `>=3.0.0 <4.0.0`** (see `pubspec.yaml`).
- **Platforms enabled:** Android and Web only (see `.metadata` migration list and the `android/` and `web/` directories). There are no `ios/`, `linux/`, `macos/`, or `windows/` runners.
- **Runtime dependencies:** `shared_preferences` (^2.2.3) and `ffi` (^2.1.0, required by the vendored QQL binding), plus the Flutter SDK.
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
  theme_store.dart                 ThemeStore (ChangeNotifier) for the Light/Dark/System
                                   setting, plus the appearance picker sheet
  tajweed.dart                     Tajweed rule parser (parseTajweed), rule colours,
                                   arabicText() widget helper, and the legend sheet
  qql/
    qql_helper.dart                Public entry point: conditional export + types
    qql_helper_io.dart             dart:ffi implementation
    qql_helper_web.dart            Web stub (isSupported == false, everything throws)
    qql_record.dart                QqlRecord / QqlQueryException — pure Dart
    vendor/qql.dart                Vendored QQL binding, verbatim from upstream
  screens/
    category_list_screen.dart      Home screen; also maps category icon names to IconData
    item_list_screen.dart          Items of one category with bookmark toggles
    ayat_detail_screen.dart        Full item view with prev/next navigation and repeat counter
    session_screen.dart            Guided checklist across all categories (state not persisted)
    bookmarks_screen.dart          List of bookmarked items
assets/data/ruqyah.json            All content: {"categories": [...]}, 6 categories, 42 items total
test/tajweed_test.dart             Unit tests for the tajweed parser
test/theme_store_test.dart         Unit and widget tests for the appearance setting
test/qql_helper_test.dart          Integration tests against the real native library
third_party/qql/                   Vendored QQL: C header, prebuilt Linux .so, licence,
                                   and README.md with provenance and rebuild steps
android/app/src/main/jniLibs/      QQL native libs, 3 ABIs — built by cargo-ndk, see above
sources/                           QQL data (64 MB) — Quran, Hisnul Muslim, nine hadith
                                   books. Read from the filesystem, NOT a Flutter asset
web/                               Web runner (index.html, manifest, icons)
android/                           Android runner (Gradle Kotlin DSL)
```

Data model (`assets/data/ruqyah.json`, mirrored by `lib/models.dart`): each category has `id`, `title`, `subtitle`, `icon` (a string key mapped to `IconData` in `category_list_screen.dart`), and `items`. Each item has `id`, `reference`, `arabic`, `transliteration`, `translation`, `repeat` (default 1), `note`. Optional string fields default to `''`.

## Architecture and conventions

- **No state-management package.** State is plain `StatefulWidget` + `setState`, with two app-wide `ChangeNotifier` stores — `BookmarkStore` and `ThemeStore` — created in `_RuqyahAppState` and passed down constructors; screens that show bookmark state wrap themselves in `AnimatedBuilder(animation: bookmarks)`. The root wraps `MaterialApp` in `AnimatedBuilder(animation: Listenable.merge([bookmarks, themeStore]))`, so a theme change rebuilds the whole tree and no screen needs to listen for it. Both stores expose a `loaded` flag, and the root shows a spinner until both have loaded so the app never flashes the wrong theme on launch.
- **No routing package and no named routes.** Navigation uses `Navigator.push(MaterialPageRoute(...))` directly.
- **Data loading:** `DataService.loadCategories()` reads the JSON asset once via `rootBundle` and caches it in a static field; `main.dart` drives it with a `FutureBuilder`.
- **Styling:** single theme factory `_theme(Brightness)` in `lib/main.dart` (Material 3, seed color `0xFF6B5D4F`) builds both the light and dark themes; Arabic text is rendered through `arabicText(context, arabic)` in `lib/tajweed.dart`, which applies the shared `arabicStyle(context)` helper, RTL direction, and tajweed colouring. Any new colour must be defined for both brightnesses — read it off the `ColorScheme` where possible, or follow the `TajweedRule` pattern of an explicit light/dark pair.
- **Theme mode:** `ThemeStore` in `lib/theme_store.dart` holds a `ThemeMode` persisted under the `'themeMode'` key as `ThemeMode.name`; an unrecognised or missing value falls back to `ThemeMode.system`, so the app follows the device until the user picks Light or Dark, and remembers that choice until they change it. The picker (`showThemePicker`) is a bottom sheet reached from the home screen app bar; it uses a `RadioGroup` ancestor because `RadioListTile.groupValue`/`onChanged` are deprecated in this Flutter version.
- **Tajweed colouring:** `parseTajweed(String)` in `lib/tajweed.dart` is a pure function splitting vocalised Arabic into `TajweedSegment`s tagged with a `TajweedRule`. It reads the diacritics that are actually written, so it only works on fully vocalised text. It covers the noon sakin/tanwin rules (izhar, idgham with and without ghunnah, iqlab, ikhfa), the meem sakin rules, ghunnah, qalqalah sughra, and madd of 4-6 counts; natural 2-count madd is deliberately left uncoloured. Colours live on the `TajweedRule` enum, one per brightness. Any change to the rules must keep `test/tajweed_test.dart` green — including the round-trip test asserting that segments reassemble the input exactly.
- **QQL (`lib/qql/`):** a vendored Rust library reached over `dart:ffi`, resolving references like `Q:2:1-5,255` against the JSON in `sources/`. It is **not wired into any screen yet** — the app's own content still comes entirely from `assets/data/ruqyah.json`. Three things constrain how it can be used:
  - **No web.** `dart:ffi` does not exist there. `lib/qql/qql_helper.dart` conditionally exports the FFI implementation or a stub, so the app still compiles for web; guard call sites with `QqlHelper.isSupported` rather than catching. Never import `qql_helper_io.dart` or `qql_helper_web.dart` directly, and never import `vendor/qql.dart` outside `qql_helper_io.dart` — any of those breaks the web build.
  - **No data on device yet.** The Android `.so`s are built and bundled (`android/app/src/main/jniLibs/`, three ABIs), but `sources/` is not a Flutter asset, so a release APK ships the library without its data. Rebuild instructions and the remaining work are in `third_party/qql/README.md`.
  - **`dispose()` is mandatory.** The context is native memory with no finalizer.
- **Language:** all code, comments, and UI strings are in English; content data includes Arabic and transliteration.
- **Linting:** `analysis_options.yaml` includes `package:flutter_lints/flutter.yaml` with no overrides. Code currently passes `flutter analyze` with zero issues — keep it that way.
- **Dependency policy:** the app is intentionally dependency-light. Confirm a package is truly needed before adding one, and pin it in `pubspec.yaml`.

## Build and run commands

Flutter SDK is installed on this machine (`flutter` on PATH). Usual workflow:

```bash
flutter pub get          # install dependencies
flutter analyze          # static analysis (must stay clean)
flutter test             # run all tests
flutter run              # run on a connected device/emulator (Android) or web
flutter run -d chrome    # run on web
flutter build apk        # Android release APK
flutter build web        # web release build (output in build/web)
```

Running one test file or one test case:

```bash
flutter test test/tajweed_test.dart
flutter test test/tajweed_test.dart --plain-name 'iqlab before'   # substring of the test name
```

## Testing instructions

- `test/tajweed_test.dart` covers the tajweed parser; `test/theme_store_test.dart` covers the appearance setting, including a widget test driving the picker sheet; `test/qql_helper_test.dart` drives the real native library against `sources/` and **skips itself** on anything other than Linux x86-64, so a green run there does not mean QQL was exercised. Add tests under `test/` when making behavioral changes.
- `flutter analyze` and `flutter test` must both be clean before considering any change done.
- Both stores use the `shared_preferences` plugin, which needs a mock: call `TestWidgetsFlutterBinding.ensureInitialized()` once in `main()`, then `SharedPreferences.setMockInitialValues({...})` at the start of each test (it is per-test state, so set it every time rather than in `setUpAll`).

## Editing content (`assets/data/ruqyah.json`)

The JSON asset is the app's whole database, and three couplings in it are not visible from the file itself:

- **Item `id`s are a single flat namespace, not per-category.** `BookmarkStore` persists bare item ids, and `DataService.findItem` returns the first match across all categories, so two items sharing an id in different categories would bookmark and resolve as one. Prefix ids when a passage is repeated across sections (the `sword` category reuses passages as `sword-fatihah`, `sword-ikhlas`, …).
- **A category's `icon` is a string key, not an icon name.** It is resolved by the `switch` in `categoryIcon()` in `category_list_screen.dart`; an unrecognised key silently falls back to a bookmark outline. Adding a category with a new icon means editing that function too.
- **`repeat` drives UI, not just display.** `ayat_detail_screen.dart` shows a progress bar and a tap counter only when `repeat > 1`; `item_list_screen.dart` shows an `×N` chip on the same condition.

Prefer editing this file with a script (Python's `json` module round-trips it cleanly with `ensure_ascii=False, indent=2`) over hand-editing Arabic strings, and reuse existing `arabic`/`transliteration`/`translation` values verbatim when a passage already appears elsewhere in the file rather than retyping them. After any edit, confirm the file still parses, that item ids are still unique, and that `flutter test` passes — `test/tajweed_test.dart` parses every ayat in the asset and asserts the tajweed segmentation reassembles each one exactly.

## Security and content considerations

- The app is fully offline: no network calls, no permissions beyond defaults, no user data leaves the device. Do not add network permissions or telemetry without an explicit request.
- The only persisted state is in local `shared_preferences`: bookmarks under `'bookmarks'` and the appearance setting under `'themeMode'`.
- Android release builds are signed with the debug key — fix the signing config in `android/app/build.gradle.kts` before any real distribution.
- The vendored QQL library is **GPL-3.0-or-later**. Shipping the app linked against it makes the combined work GPL-3, and this repository still has no `LICENSE` file. See `third_party/qql/README.md`.
- `assets/data/ruqyah.json` contains religious content (Quranic verses with translations). Treat its text with care: do not alter Arabic strings, references, or translations unless explicitly asked, and validate the JSON after any edit (it must remain valid UTF-8 and parse cleanly).
