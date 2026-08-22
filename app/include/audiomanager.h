#ifndef AUDIOMANAGER_H
#define AUDIOMANAGER_H

#include <functional>

namespace audio {
  class audio_engine;
} // namespace audio

/**
 * @file audiomanager.h
 * @brief UI-facing wrapper around the platform audio backend.
 */

/**
 * @class AudioManager
 * @brief Thin C++ wrapper around the Objective-C capture backend.
 *
 * Exposes a pure C++ interface so it can be consumed both from plain C++
 * translation units (e.g. the test suite) and from the Objective-C++ AppKit UI,
 * without leaking Objective-C or Core Audio types into its callers. Internally
 * it forwards to capture's `AudioCaptureManager`; it is the aggregation point
 * for the capture, audio, and playback modules as those are migrated in.
 */
class AudioManager {
public:
  /**
   * @enum PermissionStatus
   * @brief System audio-capture permission states.
   *
   * The enumerators mirror the ordering of the platform permission enum so a
   * status can be mapped across the wrapper boundary by value.
   */
  enum PermissionStatus { NotDetermined, Denied, Authorized, Restricted };

  /**
   * @brief Construct a new AudioManager, initializing the capture backend.
   */
  AudioManager();

  /**
   * @brief Destroy the AudioManager and release the capture backend.
   */
  ~AudioManager();

  // The wrapper owns a single backend instance; copying would double-own it.
  AudioManager(const AudioManager &) = delete;
  AudioManager &operator=(const AudioManager &) = delete;

  /**
   * @brief Retrieve the current audio-capture permission state.
   * @return The current `PermissionStatus`.
   */
  PermissionStatus getPermission();

  /**
   * @brief Request audio-capture permission asynchronously.
   * @param callback Invoked with the resulting `PermissionStatus` once the
   * request resolves.
   *
   * The callback is always delivered on the main thread, so callers may update
   * UI directly from it.
   */
  void requestPermission(std::function<void(PermissionStatus)> callback);

  /**
   * @brief Start capturing system audio.
   * @return `true` if capture started (or was already running), `false`
   * otherwise. Failures are logged.
   */
  bool startCapture();

  /**
   * @brief Stop the current capture session.
   * @return `true` if capture stopped (or was already stopped), `false`
   * otherwise. Failures are logged.
   */
  bool stopCapture();

  /**
   * @brief Write the captured audio to a file with name `filename`.
   * @param filename Name of file to be written to.
   * @param uiError Error string for display in application UI.
   * @return `true` if writing to file succeeded, `false`
   * otherwise. Failures are logged.
   */
  bool writeCapturedAudio(std::string filename, std::string &uiError);

private:
  struct impl;
  impl *pimpl;
  audio::audio_engine *_audioEngine;
};

#endif // AUDIOMANAGER_H
