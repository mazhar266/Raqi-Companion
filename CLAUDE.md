# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Read AGENTS.md

All guidance for this repository lives in **[AGENTS.md](AGENTS.md)** — read it before starting work. It is the single source of truth and covers:

- **Project overview** — what the app is and what it does not do (offline, no backend, no accounts).
- **Technology stack** — Flutter/Dart versions, the two enabled platforms, the deliberately short dependency list.
- **Repository layout** — the role of each file under `lib/`, and the shape of `assets/data/ruqyah.json`.
- **Architecture and conventions** — no state-management or routing package, how data loading and theming work, and how the tajweed parser in `lib/tajweed.dart` is structured.
- **Build and run commands** — including how to run a single test file or a single test case.
- **Testing instructions** — what is covered today and the `shared_preferences` mock needed for widget tests.
- **Editing content** — the couplings in `assets/data/ruqyah.json` that are invisible from the file itself (flat item-id namespace, the icon-key indirection, what `repeat` drives).
- **Security and content considerations** — most importantly, the care required around the Quranic text.

Deliberately kept as a pointer rather than a copy: duplicating that content here would create two files to keep in sync. When repository guidance needs to change, edit `AGENTS.md`.
