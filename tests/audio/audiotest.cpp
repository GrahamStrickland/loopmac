#include <filesystem>
#include <fstream>
#include <string>

#include <catch2/catch_test_macros.hpp>

#include "audioengine.h"

namespace fs = std::filesystem;

class mock_audio_data {
public:
  mock_audio_data() {
    float fake_data[4] = {0.1, 0.2, 0.3, 0.4};
    _audio_data = new float[4];

    for (std::size_t i = 0; i < 4; i++) {
      _audio_data[i] = fake_data[i];
    }
  }

  ~mock_audio_data() { delete[] _audio_data; }

  float *get_audio_data() { return _audio_data; }

private:
  float *_audio_data;
};

struct temp_file_guard {
  fs::path path;

  temp_file_guard(const std::string &filename) {
    path = fs::temp_directory_path() / filename;
  }

  ~temp_file_guard() {
    if (fs::exists(path)) {
      fs::remove(path);
    }
  }
};

TEST_CASE("AudioEngine captures audio data correctly", "[audio]") {
  auto audio_engine = audio::audio_engine(1.0);

  mock_audio_data data_mock{};
  auto audio_data = data_mock.get_audio_data();

  audio_engine.write_audio_data(audio_data, 4);
  REQUIRE(audio_engine.size_written() == 4);
};

TEST_CASE("AudioEngine writes audio data to file correctly", "[audio]") {
  temp_file_guard temp("test_file.wav");
  auto audio_engine = audio::audio_engine(1.0);
  std::string error_msg;

  mock_audio_data data_mock{};
  auto audio_data = data_mock.get_audio_data();
  audio_engine.write_audio_data(audio_data, 4);
  auto success =
      audio_engine.export_audio_data_to_wav(temp.path.string(), error_msg);

  REQUIRE(success);
  REQUIRE(fs::exists(temp.path));

  std::ifstream in(temp.path);
  std::string content;
  std::getline(in, content);
  REQUIRE(content.length() > 0);
}

TEST_CASE("AudioEngine fails to write audio data to existing file", "[audio]") {
  temp_file_guard temp("test_file.wav");
  auto audio_engine = audio::audio_engine(1.0);
  std::string error_msg;

  std::ofstream out(temp.path.string());
  out << "Test Data";

  REQUIRE(fs::exists(temp.path));

  fs::permissions(temp.path, fs::perms::owner_read | fs::perms::group_read |
                                 fs::perms::others_read);

  mock_audio_data data_mock{};
  auto audio_data = data_mock.get_audio_data();
  audio_engine.write_audio_data(audio_data, 4);
  auto success =
      audio_engine.export_audio_data_to_wav(temp.path.string(), error_msg);

  REQUIRE(!success);
}
