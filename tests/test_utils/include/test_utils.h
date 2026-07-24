#ifndef TEST_UTILS_H
#define TEST_UTILS_H

#include "capture.h"

namespace test_utils {
bool is_valid_permission_status(capture::permission_status status);

bool is_request_result_status(capture::permission_status status);
} // namespace
#endif // TEST_UTILS_H
