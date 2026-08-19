# AGENTS.md

Guidance for AI coding agents working on this repository. Assumes no prior knowledge of the project.

## Project overview

**raqi_companion** ("Raqi Companion") is an offline Flutter app providing Quranic ayats and adhkar for ruqyah shari'ah. It is a read-only content browser with:

- Three bottom-navigation tabs: **Browse** (the ruqyah content), **Lists** (user-built sequences) and **Query** (a QQL console).
- A category list of ruqyah content groups.
- Per-category item lists showing Arabic text with a bookmark toggle.
- A detail screen per item with Arabic, transliteration, translation, an optional note, and a tap counter for repetitions (`repeat` field).
- A "Session" screen: a guided checklist across all categories with a progress bar (in-memory only, not persisted).
- Bookmarks persisted locally via `shared_preferences`.
- An appearance setting (Light / Dark / System, default System) persisted the same way.

All content ships in a single bundled JSON asset (`assets/data/ruqyah.json`); there is no backend, network access, or account system.

## Technology stack

- **Flutter 3.44.9 (stable channel)** / **Dart SDK `>=3.0.0 <4.0.0`** (see `pubspec.yaml`).
- **Platforms enabled:** Android and Web only (see `.metadata` migration list and the `android/` and `web/` directories). There are no `ios/`, `linux/`, `macos/`, or `windows/` runners.
- **Runtime dependencies:** `shared_preferences` (^2.2.3), `ffi` (^2.1.0, required by the vendored QQL binding), `path_provider` (^2.1.0, locates the directory QQL data is unpacked into) and `file_picker` (list export/restore), plus the Flutter SDK.
- **`file_picker` is pinned to a prerelease on purpose.** The current stable, 11.0.3, applies its own Kotlin Gradle Plugin; Flutter 3.44 uses built-in Kotlin and rejects it, so the plugin's Kotlin never compiles and `assembleRelease` fails with `cannot find symbol: FilePickerPlugin`. 12.0.0-beta has migrated and builds. Move to 12.x stable once it ships, and do not "tidy" the constraint back to `^11`.
- **Dev dependencies:** `flutter_test` (SDK), `flutter_lints` (^3.0.0).
- **Android:** Gradle Kotlin DSL (`android/build.gradle.kts`, `android/app/build.gradle.kts`), Java/Kotlin 17, `applicationId = raqi.mazhar.fi`, namespace `raqi.mazhar.fi` (the Kotlin source lives at `android/app/src/main/kotlin/raqi/mazhar/fi/`). Release builds currently sign with the debug key (marked TODO in `android/app/build.gradle.kts`).

## Repository layout

```
lib/
  main.dart                        App entry point, theme (Material 3, seeded color scheme,
                                   light/dark), shared arabicStyle() text helper
  models.dart                      RuqyahItem and Category data classes with fromJson factories
  data_service.dart                DataService: loads/caches assets/data/ruqyah.json, findItem lookup
  bookmarks.dart                   BookmarkStore (ChangeNotifier) backed by shared_preferences
  user_lists.dart                  UserListStore (ChangeNotifier): the user's own lists
  surahs.dart                      Surah metadata and buildQuery() for the visual picker
  arabic_fonts.dart                arabicFontFamily, ArabicFontStore (size), ArabicFontScope
  version.dart                     appVersion / appBuildNumber, mirrored from pubspec.yaml
  list_backup.dart                 Export/restore format for user lists (pure, no I/O)
  theme_store.dart                 ThemeStore (ChangeNotifier) for the Light/Dark/System
                                   setting, plus the appearance picker sheet
  tajweed.dart                     Tajweed rule parser (parseTajweed), rule colours,
                                   arabicText() widget helper, and the legend sheet
  qql/
    qql_helper.dart                Public entry point: conditional export + types
    qql_helper_io.dart             dart:ffi implementation
    qql_helper_web.dart            Web stub (isSupported == false, everything throws)
    qql_record.dart                QqlRecord / QqlQueryException — pure Dart
    qql_data.dart                  Unpacks the bundled data from assets to app storage
    vendor/qql.dart                Vendored QQL binding, verbatim from upstream
  screens/
    home_shell.dart                Root screen: bottom NavigationBar over the two tabs
    category_list_screen.dart      Browse tab; also maps category icon names to IconData
    category_group_screen.dart     The sections nested under one group (e.g. Dawah)
    app_menu.dart                  Overflow menu (Settings, About) on every tab
    settings_screen.dart           Appearance, Arabic size, tajweed legend, list backup
    list_backup_actions.dart       The file dialogs and merge/replace prompt
    about_screen.dart              Contributor, bundled components, and the version
    lists_screen.dart              Lists tab: create, rename, delete
    list_detail_screen.dart        One list, entries resolved through QQL, reorderable
    add_entry_sheet.dart           Query builder: dropdowns, or a typed reference
    qql_query_screen.dart          Query tab: a QQL input, submit, and the results
    item_list_screen.dart          Items of one category with bookmark toggles
    ayat_detail_screen.dart        Full item view with prev/next navigation and repeat counter
    session_screen.dart            Guided checklist across all categories (state not persisted)
    bookmarks_screen.dart          List of bookmarked items
assets/data/ruqyah.json            All content: {"categories": [...]}, 13 categories, 137 items
                                   (Modules 1-4 + Sword top level; Modules 5-7 grouped as
                                   Intensive, 8-9 as Daily Practice, and 3 under Dawah)
test/tajweed_test.dart             Unit tests for the tajweed parser
test/theme_store_test.dart         Unit and widget tests for the appearance setting
test/qql_helper_test.dart          Integration tests against the real native library
test/qql_data_test.dart            Asset declaration, unpacking, and an end-to-end query
test/home_shell_test.dart          Bottom-navigation and category-grouping widget tests
test/content_test.dart             Module/group structure, tajweed opt-outs, and Arabic
                                   checked byte-for-byte against sources/
third_party/qql/                   Vendored QQL: C header, prebuilt Linux .so, licence,
                                   and README.md with provenance and rebuild steps
android/app/src/main/jniLibs/      QQL native libs, 3 ABIs — built by cargo-ndk, see above
android/app/src/main/res/xml/      Auto Backup rules; keep both files in step
sources/                           QQL data (150 MB, 6791 files) — Quran, Hisnul Muslim,
                                   nine hadith books, each in per-chapter and flat form.
                                   Read from the filesystem, NOT the Flutter asset bundle
icon/icon.png                      Source app icon (1254px). The single source of truth
tool/generate_icons.py             Regenerates every launcher/web icon from it
assets/fonts/                      The single Arabic typeface (Hafs)
tool/check_font_coverage.py        Verifies a font can draw every mark the app renders
tool/font_coverage.json            Its report; test/fonts_test.dart asserts against it
tool/resync_quran_text.py          Refetches every Quranic ayah in ruqyah.json from sources/
web/                               Web runner (index.html, manifest, icons)
android/                           Android runner (Gradle Kotlin DSL)
```

Data model (`assets/data/ruqyah.json`, mirrored by `lib/models.dart`): each category has `id`, `title`, `subtitle`, `icon` (a string key mapped to `IconData` in `category_list_screen.dart`), an optional `group`, and `items`. Each item has `id`, `reference`, `arabic`, `transliteration`, `translation`, `repeat` (default 1), `note`, and an optional `script`. Optional string fields default to `''`.

Two optional fields carry behaviour:

- **`group`** on a category nests it under a menu. Categories sharing a group value are replaced on the home screen by a single card (titled with the group, subtitled with its section titles) that opens `CategoryGroupScreen`, and they are **excluded from the Session checklist**. The three groups in use are `Intensive` (Modules 5-7, deployed only against active resistance), `Daily Practice` (Modules 8-9, standalone routines) and `Dawah` (reference material). What is left at top level — Modules 1-4 and Sword — is exactly what a baseline ruqyah session should walk through.
- **`script`** on an item marks it as Quranic text taken from `sources/`: `"uthmani"` on all 128 such items, omitted on the nine sunnah duas. It is what `tool/resync_quran_text.py` and `test/content_test.dart` use to decide which items to re-check against the Quran data.

## Architecture and conventions

- **No state-management package.** State is plain `StatefulWidget` + `setState`, with two app-wide `ChangeNotifier` stores — `BookmarkStore` and `ThemeStore` — created in `_RuqyahAppState` and passed down constructors; screens that show bookmark state wrap themselves in `AnimatedBuilder(animation: bookmarks)`. The root wraps `MaterialApp` in `AnimatedBuilder(animation: Listenable.merge([bookmarks, themeStore]))`, so a theme change rebuilds the whole tree and no screen needs to listen for it. Both stores expose a `loaded` flag, and the root shows a spinner until both have loaded so the app never flashes the wrong theme on launch.
- **No routing package and no named routes.** Navigation uses `Navigator.push(MaterialPageRoute(...))` directly.
- **Data loading:** `DataService.loadCategories()` reads the JSON asset once via `rootBundle` and caches it in a static field; `main.dart` drives it with a `FutureBuilder`.
- **Styling:** single theme factory `_theme(Brightness)` in `lib/main.dart` (Material 3, seed color `0xFF6B5D4F`) builds both the light and dark themes; Arabic text is rendered through `arabicText(context, arabic)` in `lib/tajweed.dart`, which applies the shared `arabicStyle(context)` helper, RTL direction, and tajweed colouring. Any new colour must be defined for both brightnesses — read it off the `ColorScheme` where possible, or follow the `TajweedRule` pattern of an explicit light/dark pair.
- **Theme mode:** `ThemeStore` in `lib/theme_store.dart` holds a `ThemeMode` persisted under the `'themeMode'` key as `ThemeMode.name`; an unrecognised or missing value falls back to `ThemeMode.system`, so the app follows the device until the user picks Light or Dark, and remembers that choice until they change it. The picker lives in `SettingsScreen` and uses a `RadioGroup` ancestor because `RadioListTile.groupValue`/`onChanged` are deprecated in this Flutter version.
- **Settings and About** are reached from `AppMenuButton`, an overflow menu each tab puts in its own app bar — the tabs keep separate `Scaffold`s, so there is no shared bar to hang it on. Adding a tab means adding the menu to it.
- **Version:** `lib/version.dart` mirrors `pubspec.yaml` by hand rather than pulling in `package_info_plus`, and `test/version_test.dart` reads the pubspec and fails if the two drift. Bump both together.
- **Tajweed colouring:** `parseTajweed(String)` in `lib/tajweed.dart` is a pure function splitting vocalised Arabic into `TajweedSegment`s tagged with a `TajweedRule`. It reads the diacritics that are actually written, so it only works on fully vocalised text. It covers the noon sakin/tanwin rules (izhar, idgham with and without ghunnah, iqlab, ikhfa), the meem sakin rules, ghunnah, qalqalah sughra, and madd of 4-6 counts; natural 2-count madd is deliberately left uncoloured. Colours live on the `TajweedRule` enum, one per brightness. Any change to the rules must keep `test/tajweed_test.dart` green — including the round-trip tests over both `assets/data/ruqyah.json` and all 6236 ayat of `sources/`.
- **Two orthographies.** The parser handles the imlaei text in `ruqyah.json` and the Uthmani text in `sources/`, which spell things differently. The Uthmani conventions were verified against the data and must not be "simplified" away:
  - Sukun is **U+06E1**, not U+0652.
  - Tanwin has an *open* form — **U+0657 fathatan, U+065E dammatan, U+0656 kasratan** — despite Unicode names that describe the glyph rather than the role. These outnumber the standard codepoints roughly 3:1, so missing them blinds the parser to most tanwin.
  - Iqlab is spelled out by a **small meem (U+06E2/U+06ED)** over the noon, and is read directly rather than inferred.
  - A bare noon means ikhfa or idgham; a noon carrying the sukun sign means izhar.
- **Arabic typeface and size:** one face ships in `assets/fonts/` — `arabicFontFamily`, currently Hafs — with no picker; only the size is configurable, a multiplier persisted under `'arabicFontScale'` (0.8–2.0, default 1.0). It applies to Arabic only: `arabicStyle()` reads the size from `ArabicFontScope`, an inherited widget above `MaterialApp`, rather than taking it as a parameter through a dozen call sites. The interface font and size are untouched.
- **The size is a multiplier, not a point size.** Call sites already pass their own base (26 in the detail view, 22 for QQL results, 20 in lists, 16 in the session), so scaling preserves that hierarchy instead of flattening it. `arabicStyle(context, scaled: false)` opts out; the font previews in Settings use it so the list stays scannable at any size. The stored value is clamped on read as well as write, so a hand-edited preference cannot make the app unreadable.
- **Swapping the font means running `tool/check_font_coverage.py` first.** Most Arabic faces lack the Quranic marks this app renders: of eight candidates tried, seven could not draw the open dammatan (U+065E, 1,887 occurrences) and two also missed the open fathatan (U+0657, 3,017). Hafs is bundled because it was the only one covering every *combining* mark. Missing standalone glyphs (the ﴿ ﴾ markers, ﷺ) are fine — they come from a fallback face and still look right; a missing combining mark is positioned by the fallback's metrics and lands wrong. `test/fonts_test.dart` enforces that the bundled face has no combining-mark gaps, and that it is the only file in `assets/fonts/`.
- **QCF / King Fahd Complex page fonts cannot be used here.** They map ~2,000 Private Use Area codepoints, each a pre-shaped word from one mushaf line, and carry nothing in the Arabic block. They need per-ayah PUA strings (`code_v1`/`code_v2`), which `quran-json-arabic` does not provide — its `text` is ordinary Unicode. `tool/check_font_coverage.py` reports such a font as missing all 88 codepoints.
- **Where colouring is applied:** everywhere for the app's own content, and for QQL results **only when `QqlRecord.isQuran`**. Hadith and supplications are Arabic but are not recited under these rules, so colouring them would misrepresent them.
- **QQL (`lib/qql/`):** a vendored Rust library reached over `dart:ffi`, resolving references like `Q:2:1-5,255` against the JSON in `sources/`. It is **not wired into any screen yet** — the app's own content still comes entirely from `assets/data/ruqyah.json`. Three things constrain how it can be used:
  - **No web.** `dart:ffi` does not exist there. `lib/qql/qql_helper.dart` conditionally exports the FFI implementation or a stub, so the app still compiles for web; guard call sites with `QqlHelper.isSupported` rather than catching. Never import `qql_helper_io.dart` or `qql_helper_web.dart` directly, and never import `vendor/qql.dart` outside `qql_helper_io.dart` — any of those breaks the web build.
  - **Data must be unpacked before use.** The library reads with `std::fs` and cannot see the asset bundle, so `QqlData.ensureUnpacked()` copies `sources/` to app storage on first launch and returns the path for `QqlHelper.open`. Bump `QqlData.dataVersion` when the bundled data changes. Asset directories are not recursive — every leaf directory is listed in `pubspec.yaml`, and `test/qql_data_test.dart` guards the counts.
  - **The source code is optional and carries forward.** A bare reference is the Quran (`2:255`, `1`), commas group primaries (`1,2:255`), and a stated source applies to everything after it until another replaces it (`b:1:1;3`). See `third_party/qql/README.md`.
  - **Two numbering forms.** `B:1:1` counts within a chapter; `B::6018` counts across the whole book, which is what ordinary citations mean. Each form reads from its own data directory, so both are vendored. `QqlRecord.isBookNumbering` distinguishes them, and `reference` formats accordingly — never print a flat number as `chapter:number`.
  - **The web build bundles the 150 MB of data pointlessly** (no per-platform assets in Flutter); strip `build/web/assets/sources/` after building. See `third_party/qql/README.md`.
  - **`dispose()` is mandatory.** The context is native memory with no finalizer.
- **Language:** all code, comments, and UI strings are in English; content data includes Arabic and transliteration.
- **Linting:** `analysis_options.yaml` includes `package:flutter_lints/flutter.yaml` with no overrides. Code currently passes `flutter analyze` with zero issues — keep it that way.
- **Dependency policy:** the app is intentionally dependency-light. Confirm a package is truly needed before adding one, and pin it in `pubspec.yaml`.

## App icon

`icon/icon.png` is the only file to edit. Everything else is generated — never hand-edit
the mipmaps or `web/icons/`:

```bash
python3 tool/generate_icons.py     # needs Pillow; no Flutter/Gradle involvement
```

It writes three shapes, because one image cannot serve all of them:

- **Legacy Android mipmaps** (`mipmap-{m,h,xh,xxh,xxxh}dpi/ic_launcher.png`) and the plain
  web icons — the artwork full-bleed, keeping its own rounded corners. Used below API 26.
- **Adaptive foreground** (`ic_launcher_foreground.png` + `mipmap-anydpi-v26/ic_launcher.xml`)
  — used from API 26. Launcher masks only guarantee the central 66%, and this artwork's
  wordmark runs close to its edge, so the foreground insets the artwork to 74% over
  `@color/ic_launcher_background`. That colour is sampled from the artwork's own border
  ring, and the artwork's edge is feathered, so the two greens join invisibly.
  Deliberately **no `<monochrome>` layer**: Android tints it by alpha alone and this
  foreground is a near-solid square, so a themed icon would render as a blob.
- **Web maskable icons** — the same treatment against the more generous 80% maskable
  safe zone.

`flutter_launcher_icons` is deliberately not used; the script is a few lines of Pillow and
keeps the dependency list where it is.

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

Prefer editing this file with a script (Python's `json` module round-trips it cleanly with `ensure_ascii=False, indent=2`) over hand-editing Arabic strings, and reuse existing `arabic`/`transliteration`/`translation` values verbatim when a passage already appears elsewhere in the file rather than retyping them.

**Never retype Quranic Arabic, and never hand-edit it.** Every Quranic ayah in this file is generated from `sources/quran-json-arabic/dist/chapters/en/{surah}.json` by `tool/resync_quran_text.py`, so the whole file is one orthography — Uthmani, with the madd signs and open tanwin forms the imlaei text lacked. All 128 Quranic items carry `"script": "uthmani"`.

To change a passage, edit its `reference` and re-run the tool:

```bash
python3 tool/resync_quran_text.py            # report what would change
python3 tool/resync_quran_text.py --write    # apply
```

It parses the range out of `reference`, refetches, and **verifies** before replacing: the existing and fetched text are compared with diacritics and alefs stripped, and anything below a similarity floor is reported and skipped rather than silently overwritten. It rewrites `arabic` and `script` only — the hand-written `transliteration`, `translation`, `note` and `repeat` survive, since orthography does not affect them.

`test/content_test.dart` then re-checks **every** Quranic item against the source byte for byte, so a hand-edit or a reference that stops naming the passage it holds fails the suite.

The only nine items that are not Quranic — the four masnun duas in Module 8 and the five Module 9 routines — have no counterpart in the Quran data and are left alone; the test pins that list exactly. Multi-ayah passages join verses with an `﴿٢٨٥﴾`-style marker (Arabic-Indic digits) after each verse; single-ayah passages carry no marker. `test/dawah_content_test.dart` re-checks a sample of passages against the source files, so hand-edits to that Arabic will fail the suite. After any edit, confirm the file still parses, that item ids are still unique, and that `flutter test` passes — `test/tajweed_test.dart` parses every ayat in the asset and asserts the tajweed segmentation reassembles each one exactly.

## Security and content considerations

- The app is fully offline: no network calls, no permissions beyond defaults, no user data leaves the device. Do not add network permissions or telemetry without an explicit request.
- The only persisted state is in local `shared_preferences`: bookmarks under `'bookmarks'`, the appearance setting under `'themeMode'`, the user's lists under `'userLists'` (a JSON array of `{id, name, queries}`), and and the Arabic text size under `'arabicFontScale'`.
- **Android Auto Backup copies app storage to the user's Google Drive**, and is on by default. That is wanted for `shared_prefs`, but the quota is **25 MB per app** and `QqlData` unpacks ~150 MB into `files/qql/` — over quota the *entire* backup fails, so without an exclusion the lists would not be backed up either. `android/app/src/main/res/xml/backup_rules.xml` (API ≤30) and `data_extraction_rules.xml` (API 31+) exclude that directory; it is regenerable from assets, so nothing is lost. The path in those XML files is a plain string, so `test/backup_rules_test.dart` ties it to `QqlData.directoryName` and fails if either side is renamed. Keep the two rule files in step.
- **User lists store QQL queries, not resolved text**, so one entry can stand for a whole passage and the text survives a data update. They therefore only resolve where QQL runs, and the Lists tab degrades on web the same way the Query tab does.
- **List backups carry references only** — names and QQL queries, no Arabic or translations — which is why an export is a couple of kilobytes and stays valid across a data update. `lib/list_backup.dart` is pure and does the encoding, validation and error messages; `list_backup_actions.dart` owns the file dialogs. A malformed file is rejected whole rather than imported in part, and importing reassigns ids so a file restored onto a device that already has lists cannot collide. Bump `backupFormatVersion` only for a breaking shape change — the decoder refuses anything newer than it understands.
- Android release builds are signed with the debug key — fix the signing config in `android/app/build.gradle.kts` before any real distribution.
- The vendored QQL library is **GPL-3.0-or-later**. Shipping the app linked against it makes the combined work GPL-3, and this repository still has no `LICENSE` file. The About screen names QQL and its licence, which is the minimum GPL requires of a shipped binary; a `LICENSE` file is still owed. See `third_party/qql/README.md`.
- `assets/data/ruqyah.json` contains religious content (Quranic verses with translations). Treat its text with care: do not alter Arabic strings, references, or translations unless explicitly asked, and validate the JSON after any edit (it must remain valid UTF-8 and parse cleanly).
