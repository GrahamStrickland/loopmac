# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

## [0.0.4] - 2026-06-28

### Changed

- Replaced the Qt6/QML user interface with a native macOS AppKit UI written in
  Objective-C++ (`main.mm`, `AppDelegate`, `MainWindowController`,
  `PlaybackControlView`)
- Replaced Qt Multimedia `MediaPlayer` with an AVFoundation-backed
  `PlaybackEngine` (`AVAudioPlayer`) for audio file playback
- Replaced bundled SVG icons with native SF Symbols
- Rewrote `AudioManager` as a plain Objective-C++ wrapper (no `QObject`),
  marshalling the permission callback to the main queue via Grand Central Dispatch
- Dropped all Qt6 dependencies from the build; `LoopMac` now links AppKit,
  AVFoundation, and UniformTypeIdentifiers directly

### Removed

- Qt6/QML UI files, bundled SVG assets, and Qt-based tests

### Added

- `format_to_minutes` time-formatting utility with Catch2 coverage (extracted
  from `PlaybackSeekControl.qml`)

## [0.0.3] - 2026-05-24

### Added

- Permission request when record button pressed in QML UI
- utils library to tests for permission status validation 

## [0.0.2] - 2026-05-23

### Added

- Project description, homepage URL and `SPDX_LICENSE` to CMakeLists.txt
- capture module setup with permissions checking
- Basic QML interface for audio playback

### Fixed

- QML include errors caused by `MACOS_BUNDLE_POST_BUILD` in app/CMakeLists.txt

### Changed

- Application/project name from "apploopmac" to "LoopMac"
- QML module to `LoopMacUI` in loopmac_lib for QML testing
- Millisecond formatting to M:SS:mmm in `PlaybackSeekControl`

## [0.0.1] - 2026-05-17

### Added

- Initial project setup
- app, audio, capture, playback, qml, and tests modules
- LGPL v3 license
