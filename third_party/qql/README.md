# QQL — vendored

Copied from `~/Projects/QQ Lang` (<https://github.com/mazhar266/QQ-Lang>), version **0.1.0**, commit **4c953a5**.

QQL parses compact references to Islamic texts — `Q:2:1-5,255`, `HM:27:1-3`, `B:1:1` — and resolves them against local JSON data. Upstream is a Rust crate with a C ABI; what lives here is the C header, one prebuilt native library, and the Dart FFI binding.

## Shorthand

The source code is optional, and a stated one carries forward:

```text
2:255            no source — a bare reference means the Quran
1                the whole of Al-Fatihah
1,2:255          commas group primaries: all of Surah 1, then Surah 2 ayah 255
q:1:2,3,2:3,4-6  two groups under one source
b:1:1;3          the source carries forward — Bukhari twice
b:1:1;q:3        …until another code replaces it
```

The rule for groups is that **an integer followed by `:` starts a new primary**.
A range is never a primary, so `Q:1:1-5:3` is a syntax error rather than a
second reading — both things it could mean are writable and they differ:
`Q:1:1-5;3` is Surah 1 ayat 1–5 then all of Surah 3, `Q:1:1-5,3` is ayat 1–5
plus ayah 3.

## Numbering: two forms

Every source addresses items two ways, and the difference matters when formatting a citation:

| Form | Meaning | Example |
| --- | --- | --- |
| `SOURCE:primary:n` | position **within** the chapter or surah | `B:1:1` — first hadith of chapter 1 |
| `SOURCE::n` | position **across the whole book** | `B::6018` — Bukhari hadith 6018 |

The flat form is what ordinary citations mean. Records resolved that way carry
`"numbering": "book"`, surfaced as `QqlRecord.isBookNumbering`, and `QqlRecord.reference`
uses it to avoid printing `6018` as if it were an item within a chapter. Quran records keep
`surah:ayah` either way, since that is the citation people expect. Bounds are the whole
collection: 1–6236 for the Quran, 1–7277 for Bukhari, 1–267 for Hisnul Muslim.

## What is vendored

| Path | From upstream | Notes |
| --- | --- | --- |
| `include/qql.h` | `include/qql.h` | C ABI, for reference and for rebuilding |
| `native/linux-x64/libqql.so` | `target/release/libqql.so` | **Linux x86-64 only** |
| `LICENSE.md` | `LICENSE.md` | GPL-3.0-or-later |
| `../../lib/qql/vendor/qql.dart` | `bindings/dart/qql.dart` | Verbatim; must stay under `lib/` to be importable |
| `../../sources/` | `sources/` (submodules) | Data subset — see below |

The Dart binding sits in `lib/qql/vendor/` rather than here because Dart cannot import files outside `lib/` from within it. It is unmodified, so it can be diffed against upstream when resyncing.

## Data

`sources/` at the repository root holds the subset of the upstream data submodules that QQL actually reads — 150 MB across 6,791 files:

| Directory | Size | Files | Enables |
| --- | --- | --- | --- |
| `quran-json-arabic/dist/chapters/en/` | 3.3 MB | 115 | `Q:2:255` — per-surah |
| `quran-json-arabic/dist/verses/` | 27 MB | 6236 | `Q::100` — flat, one file per ayah |
| `Hisn-Muslim-Json/husn_en.json` | 288 KB | 1 | `HM:` / `HISN:`, both forms |
| `hadith-json/db/by_chapter/the_9_books/` | 61 MB | 429 | `B:1:1` — per-chapter |
| `hadith-json/db/by_book/the_9_books/` | 60 MB | 9 | `B::6018` — flat, whole-book |

Each numbering form reads from its own directory, so dropping one silently disables that
form while the other keeps working. Not vendored: the ten other Quran translation
languages. Upstream is 256 MB in full.

The paths are hard-coded in the resolvers (`src/sources/quran.rs`, `hadith.rs`, `hisnul.rs`), so the directory layout under `sources/` must be preserved exactly.

## Rebuilding the native library

```bash
cd ~/Projects/QQ\ Lang
cargo build --release
cp target/release/libqql.so <this repo>/third_party/qql/native/linux-x64/
```

## Android

**The native libraries are built and bundled.** `android/app/src/main/jniLibs/` holds
`libqql.so` for `arm64-v8a`, `armeabi-v7a` and `x86_64`, and a release APK carries all
three — so `DynamicLibrary.open('libqql.so')`, the helper's default, resolves on device
with no code change.

Rebuild them after any change to the Rust source:

```bash
export ANDROID_HOME=$HOME/Android/Sdk
export ANDROID_NDK_HOME=$ANDROID_HOME/ndk/28.2.13676358
cd ~/Projects/QQ\ Lang
cargo ndk -t arm64-v8a -t armeabi-v7a -t x86_64 -P 24 \
  -o "<this repo>/android/app/src/main/jniLibs" build --release
```

`-P 24` matches the project's `minSdk`. Note the capital `-P` — cargo-ndk 4.x uses
lowercase `-p` for something else. The NDK version is not a free choice: `android/app/build.gradle.kts`
sets `ndkVersion = flutter.ndkVersion`, which Flutter 3.44.9 pins to `28.2.13676358`.

Toolchain needed: rustup with `aarch64-linux-android armv7-linux-androideabi x86_64-linux-android`,
`cargo install cargo-ndk`, the NDK above, and JDK 17 (AGP rejects JDK 25).

## Data on device

The native library reads JSON with `std::fs` and cannot see Flutter's asset bundle, so
`sources/` is declared as an asset in `pubspec.yaml` and unpacked to app storage on first
launch by `lib/qql/qql_data.dart`. That unpacked path is what gets passed to
`QqlHelper.open`.

Two things to know when changing the data:

- **Asset directories are not recursive.** Every leaf directory needs its own entry under
  `flutter.assets` — all nine hadith book directories are listed individually. A missing
  entry does not fail the build, it just makes that collection silently unresolvable.
  `test/qql_data_test.dart` asserts the expected asset counts to catch this.
- **Bump `QqlData.dataVersion`** after changing the bundled files, or existing installs
  keep their old unpacked copy.

Cost: the release APK is **90.0 MB**, of which ~64 MB is this data (150 MB on disk, JSON
compresses well). First launch unpacks 6,791 files, dominated by the 6,236 single-ayah
files — the Query tab shows a progress count while it runs, but it is not instant on a
slow device.

### The web build carries this data pointlessly

Flutter has no per-platform asset declaration, so `flutter build web` also bundles all
150 MB into `build/web/assets/sources/` even though the web build can never read it. The
files are served individually and are never actually requested by a browser, so users
download nothing extra — but the deploy artifact grows by that much. Strip it after
building:

```bash
flutter build web && rm -rf build/web/assets/sources
```

iOS would use `libqql.a` instead; there is no iOS runner in this repo.

## Licence

QQL is **GPL-3.0-or-later** (see `LICENSE.md`). Distributing Raqi Companion linked against it means the combined work is GPL-3 as well. Both projects are authored by the same person, so this is a choice rather than an obstacle — but Raqi Companion has no `LICENSE` file yet, and needs one before release.

The bundled data carries its own upstream licences: `sources/quran-json-arabic/LICENSE.txt`, and the terms of the `hadith-json` and `Hisn-Muslim-Json` repositories.
