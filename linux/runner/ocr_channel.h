#ifndef RUNNER_OCR_CHANNEL_H_
#define RUNNER_OCR_CHANNEL_H_

#include <flutter_linux/flutter_linux.h>

// Answers `recognizeText` on the dev.lifevalue.healthwallet/ocr channel with
// Tesseract, as Vision does on macOS and Windows.Media.Ocr on Windows. The
// caller keeps the returned channel for as long as the engine runs.
FlMethodChannel* ocr_channel_new(FlBinaryMessenger* messenger);

#endif  // RUNNER_OCR_CHANNEL_H_
