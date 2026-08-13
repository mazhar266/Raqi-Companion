# Raqi Companion

An offline Flutter app collecting Quranic ayats and adhkar for ruqyah shari'ah, with tajweed-coloured Arabic.

Everything ships inside the app. There is no backend, no network access, no accounts, and no telemetry — nothing you do in the app leaves the device.

## Features

- **Nine ruqyah modules** — a baseline routine, targeted sets for sihr, evil eye and jinn, intensive arrays for active resistance, and the masnun daily dhikr. Each item shows Arabic, transliteration, translation, and a note on its source or use.
- **Query tab** — look up any ayah, hadith, or supplication with a compact reference such as `Q:2:1-5,255`, `HM:27:1-3`, or `B:1:1`, covering the whole Quran, Hisnul Muslim, and the nine hadith books. Doubling the colon numbers across the whole book instead, so `B::6018` is Bukhari hadith 6018 as it is normally cited. Android only; see below.
- **Your own lists** — build a sequence of ayat, hadith and supplications: pick them from dropdowns (surah, ayah range) or type a reference like `Q:2:1-5,255`. Reorder by dragging, and it is saved on the device. Android only, like the Query tab.
- **Tajweed colouring** — the Arabic is coloured by recitation rule (ghunnah, idgham, ikhfa, iqlab, qalqalah, madd), with a legend explaining each colour. Applied to Quranic text only.
- **Repetition counter** — items with a recommended repetition count get a tap counter and a progress bar.
- **Dawah reference** — a menu of three sections (Jewish friends, Christian friends, and Shaytan), each a list of relevant ayat with a note on how the verse is meant to be used. Reference material, so it stays out of the recitation session.
- **Guided session** — a checklist across the baseline modules and Sword with overall progress. The intensive, daily-practice and Dawah sections stay out of it deliberately.
- **Bookmarks** — saved locally and kept between launches.
- **Light, dark, or system appearance** — follows your device by default; pick Light or Dark explicitly and the app remembers it. Under **Settings**, in the overflow menu at the top right, alongside **About**.

## Content

**Core modules** — the baseline a session walks through:

| Section | Items | Contents |
| --- | --- | --- |
| Module 1 · General Ruqyah | 7 | Al-Fatihah, 2:1-5, Ayat al-Kursi, 2:284-286, the Mu'awwidhat |
| Module 2 · Sihr | 5 | Nullifying sorcery and breaking spells |
| Module 3 · Ayn & Hasad | 4 | Evil eye and envy |
| Module 4 · Jinn Presence | 5 | Surah Al-Jinn, Al-Ahqaf, Al-Mu'minun |
| Sword | 20 | Ayat as-Sayf — the sword verses, in order as one full program |

**Intensive** — used only when an entity shows active resistance, so kept out of the session:

| Section | Items | Contents |
| --- | --- | --- |
| Module 5 · Ayatul Harq & Tadmir | 8 | Burning and destruction verses |
| Module 6 · Ayatul Qital | 5 | Warfare verses, for outright aggression |
| Module 7 · Ayatul Sakinah | 6 | Tranquility — read straight after an intensive session |

**Daily Practice** and **Dawah**:

| Section | Items | Contents |
| --- | --- | --- |
| Module 8 · Morning & Evening Shield | 4 | Masnun dhikr with counters (×10, ×3, ×3, ×7) |
| Module 9 · Situational Routines | 5 | Before sleep, localized pain, securing the house |
| Dawah → Jewish Friends | 22 | Common ground, the Torah honoured, prophethood |
| Dawah → Christian Friends | 26 | Isa and Maryam, and where the difference lies |
| Dawah → Shaytan | 20 | His strategy, the limits of his power, the refuge |

All of it lives in a single bundled asset, `assets/data/ruqyah.json`.

## Running it

Requires the [Flutter SDK](https://docs.flutter.dev/get-started/install) (Dart `>=3.0.0 <4.0.0`). Android and web are the enabled platforms.

```bash
flutter pub get
flutter run              # connected device or emulator
flutter run -d chrome    # in the browser
```

Building a release:

```bash
flutter build apk                                  # Android
flutter build web && rm -rf build/web/assets/sources   # output in build/web
```

> The `rm` is not optional housekeeping. Flutter cannot declare assets per platform, so
> the web build bundles 150 MB of query data that a browser can never read. Browsers never
> request the files, so users download nothing extra — but the deploy artifact balloons.

> Android release builds are currently signed with the debug key. Set a real signing config in `android/app/build.gradle.kts` before distributing.

## App icon

`icon/icon.png` is the source. After changing it, regenerate the Android launcher icons
and the web icons (needs Pillow):

```bash
python3 tool/generate_icons.py
```

## Development

```bash
flutter analyze                      # static analysis — kept at zero issues
flutter test                         # all tests
flutter test test/tajweed_test.dart  # one file
```

The tajweed rules are implemented as a pure function, `parseTajweed()` in [`lib/tajweed.dart`](lib/tajweed.dart), which splits vocalised Arabic into segments tagged with the rule that applies. It is covered by [`test/tajweed_test.dart`](test/tajweed_test.dart), including a check that the segmentation reassembles every ayat in the asset exactly.

The Query tab is powered by [QQL](https://github.com/mazhar266/QQ-Lang), a Rust library vendored into `third_party/qql/` and reached over `dart:ffi`. It works on Android and desktop; on web the tab reports that it is unavailable, because `dart:ffi` and the filesystem it needs do not exist there. See [`third_party/qql/README.md`](third_party/qql/README.md) for provenance, how to rebuild the native libraries, and the licence implications.

[`AGENTS.md`](AGENTS.md) documents the architecture, conventions, and the non-obvious couplings in the content file. Read it before making changes.

## A note on the content

The Arabic, transliterations, and translations are religious text and are treated as such: they are not edited casually, and the app presents them for recitation rather than interpreting them.

The Dawah sections are reference material for conversation, not a script to argue from. Their notes carry the source guidance verbatim where it matters — including the cautions on verses that describe historical hostility (5:82, 9:30–31), which are marked to be used with context or not at all. The Quran's own standard applies: invite with wisdom, never generalise about a community, and never debate to humiliate.

The tajweed colouring is a **reading aid, not an authority**. It is generated by a rule parser that reads the written diacritics, and it simplifies in places — natural two-count madd is left uncoloured, madd lazim is not distinguished from wajib and jaiz, and qalqalah kubra at a pause is not detected. It is applied only to Quranic text; hadith and supplications are shown uncoloured, since they are not recited under these rules. Learn recitation from a qualified teacher.

If you find an error in any verse, reference, or translation, please open an issue.
