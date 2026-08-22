#ifndef WAV_HEADER_H
#define WAV_HEADER_H

#include <cstdint>

#pragma pack(push, 1)
struct wav_header {
  // RIFF descriptor chunk, see
  // https://learn.microsoft.com/en-us/windows/win32/xaudio2/resource-interchange-file-format--riff-
  char chunk_id[4] = {'R', 'I', 'F', 'F'};
  uint32_t chunk_size = 0; // Total file size minus 8 bytes
  char format[4] = {'W', 'A', 'V', 'E'};

  // Format sub-chunk (fmt )
  char sub_chunk1_id[4] = {'f', 'm', 't', ' '};
  uint32_t sub_chunk1_size = 16;
  uint16_t audio_format = 3; // Value 3 specifies IEEE Floating Point PCM
  uint16_t num_channels = 1; // Mono
  uint32_t sample_rate = 22050.0;
  uint32_t byte_rate = 0; // sample_rate * num_channels * (bits_per_sample / 8)
  uint16_t block_align = 0;      // num_channels * (bits_per_sample / 8)
  uint16_t bits_per_sample = 32; // 32 bits for float layout

  // Data sub-chunk (data)
  char sub_chunk2_id[4] = {'d', 'a', 't', 'a'};
  uint32_t sub_chunk2_size = 0; // Total byte size of the raw PCM payload
};
#pragma pack(pop)
#endif // WAV_HEADER_H
