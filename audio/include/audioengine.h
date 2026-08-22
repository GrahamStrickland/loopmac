#ifndef AUDIO_ENGINE_H
#define AUDIO_ENGINE_H

#include <vector>

namespace audio {
class audio_engine {
public:
  audio_engine(double total_seconds = 0.0);

  void write_audio_data(const void *raw_bytes, std::size_t byte_length);
  bool export_audio_data_to_wav(const std::string &filename,
                                std::string &error_msg);
  std::size_t size_written() const;

private:
  std::vector<float> pcm_buffer;
};
} // end namespace audio

#endif // AUDIO_ENGINE_H
