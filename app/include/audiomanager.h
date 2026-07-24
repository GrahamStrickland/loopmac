#ifndef AUDIO_MANAGER_H
#define AUDIO_MANAGER_H

#include <functional>

#include "capture.h"

/**
 * @class AudioManager
 * @brief Thin UI-facing wrapper around capture::audio_capture_manager.
 *
 * Mirrors capture::permission_status and marshals the asynchronous permission
 * result back onto the main (UI) thread so AppKit callers can update views
 * directly from the callback.
 */
class AudioManager {
public:
  enum PermissionStatus {
    NotDetermined = capture::PermissionStatusNotDetermined,
    Denied = capture::PermissionStatusDenied,
    Authorized = capture::PermissionStatusAuthorized,
    Restricted = capture::PermissionStatusRestricted,
  };

  AudioManager();
  ~AudioManager();

  PermissionStatus getPermission();

  // Fire-and-forget: returns immediately and invokes `callback` on the main
  // thread once the user responds to the system prompt, so the UI thread is
  // never blocked and callers may touch views directly from the callback.
  void requestPermission(std::function<void(PermissionStatus)> callback);

  bool startCapture();

  bool stopCapture();

private:
  capture::audio_capture_manager captureManager;
};

#endif // AUDIO_MANAGER_H
