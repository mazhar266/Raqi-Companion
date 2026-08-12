# QQL — vendored

Copied from `~/Projects/QQ Lang` (<https://github.com/mazhar266/QQ-Lang>), version **0.1.0**, commit **e1846b4**.

QQL parses compact references to Islamic texts — `Q:2:1-5,255`, `HM:27:1-3`, `B:1:1` — and resolves them against local JSON data. Upstream is a Rust crate with a C ABI; what lives here is the C header, one prebuilt native library, and the Dart FFI binding.

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

`sources/` at the repository root holds the subset of the upstream data submodules that QQL actually reads, 64 MB in total:

| Directory | Size | Enables |
| --- | --- | --- |
| `quran-json-arabic/dist/chapters/en/` | 3.3 MB | `Q:` — 114 surahs, Arabic + English |
| `Hisn-Muslim-Json/husn_en.json` | 288 KB | `HM:` / `HISN:` — Hisnul Muslim |
| `hadith-json/db/by_chapter/the_9_books/` | 61 MB | `B: M: AD: T: N: IM:` and the rest of the nine books |

Not vendored: the ten other Quran translation languages, and the `by_book` hadith files (a second copy of the same hadith under book-global numbering). Upstream is 256 MB in full.

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

## Still to do — getting the data onto the device

The native library reads JSON with `std::fs`, so it cannot see Flutter's asset bundle,
and `sources/` is deliberately **not** declared as an asset — a release APK today
contains `libqql.so` but none of the data. Making QQL return results on device needs
`sources/` declared as an asset, unpacked to app storage on first launch, and that path
passed to `QqlHelper.open`. At 64 MB that roughly doubles install footprint, so trimming
to just the sources this app needs is worth doing first.

iOS would use `libqql.a` instead; there is no iOS runner in this repo.

## Licence

QQL is **GPL-3.0-or-later** (see `LICENSE.md`). Distributing Raqi Companion linked against it means the combined work is GPL-3 as well. Both projects are authored by the same person, so this is a choice rather than an obstacle — but Raqi Companion has no `LICENSE` file yet, and needs one before release.

The bundled data carries its own upstream licences: `sources/quran-json-arabic/LICENSE.txt`, and the terms of the `hadith-json` and `Hisn-Muslim-Json` repositories.
