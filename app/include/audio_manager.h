// Copyright (C) 2026 Graham Strickland
//
// This file is part of LoopMac.
//
// LoopMac is free software: you can redistribute it and/or modify it under the
// terms of the GNU Lesser General Public License as published by the Free
// Software Foundation, either version 3 of the License, or (at your option) any
// later version.
//
// LoopMac is distributed in the hope that it will be useful, but WITHOUT ANY
// WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS FOR
// A PARTICULAR PURPOSE. See the GNU Lesser General Public License for more
// details.
//
// You should have received a copy of the GNU Lesser General Public License
// along with LoopMac. If not, see <https://www.gnu.org/licenses/>.

#ifndef AUDIO_MANAGER_H
#define AUDIO_MANAGER_H

#include <QObject>

#include "capture.h"

class AudioManager : public QObject {
  Q_OBJECT

public:
  explicit AudioManager(QObject *parent = nullptr);

  // Mirrors capture::permission_status, registered with the meta-object system
  // so QML can compare against AudioManager.Authorized etc.
  enum PermissionStatus {
    NotDetermined = capture::PermissionStatusNotDetermined,
    Denied = capture::PermissionStatusDenied,
    Authorized = capture::PermissionStatusAuthorized,
    Restricted = capture::PermissionStatusRestricted,
  };
  Q_ENUM(PermissionStatus)

  Q_INVOKABLE PermissionStatus getPermission();

  // Fire-and-forget: returns immediately and emits permissionResult() once the
  // user responds to the system prompt, so the UI thread is never blocked.
  Q_INVOKABLE void requestPermission();

  ~AudioManager();

signals:
  void permissionResult(PermissionStatus status);

private:
  capture::audio_capture_manager captureManager;
};
#endif // AUDIO_MANAGER_H
