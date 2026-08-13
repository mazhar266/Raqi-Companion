/// The app's version, shown at the bottom of the About screen.
///
/// Deliberately a constant rather than a `package_info_plus` lookup: the
/// dependency list is kept short, and `test/version_test.dart` reads
/// `pubspec.yaml` and fails if these drift out of step with it.
library;

/// Semantic version, the part of `pubspec.yaml`'s `version:` before the `+`.
const appVersion = '1.0.0';

/// Build number, the part after the `+`.
const appBuildNumber = '1';

/// `1.0.0 (1)` — what the About screen displays.
const appVersionLabel = '$appVersion ($appBuildNumber)';
