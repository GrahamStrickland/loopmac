#include "test_utils.h"

namespace test_utils {
bool is_valid_permission_status(capture::permission_status status) {
  switch (status) {
  case capture::permission_status::PermissionStatusNotDetermined:
  case capture::permission_status::PermissionStatusDenied:
  case capture::permission_status::PermissionStatusAuthorized:
  case capture::permission_status::PermissionStatusRestricted:
    return true;
  default:
    return false;
  }
}

bool is_request_result_status(capture::permission_status status) {
  return status == capture::permission_status::PermissionStatusDenied ||
         status == capture::permission_status::PermissionStatusAuthorized;
}
} // namespace
