import 'dart:math' as math;
import 'dart:typed_data';

/// Synthesizes a short, pure sine-wave tone as PCM16 mono WAV bytes.
///
/// No audio assets needed — this is the whole sound, generated on the fly.
/// A short linear fade in/out (capped at 15ms) avoids the audible click a
/// sine wave produces when it starts or stops mid-cycle.
Uint8List generateToneWavBytes({
  required double frequencyHz,
  Duration duration = const Duration(milliseconds: 180),
  int sampleRate = 44100,
  double amplitude = 0.5,
}) {
  final sampleCount = (sampleRate * duration.inMicroseconds / 1e6).round();
  final samples = Int16List(sampleCount);

  final fadeSamples = (sampleRate * 0.015).round().clamp(
    1,
    sampleCount ~/ 2 == 0 ? 1 : sampleCount ~/ 2,
  );

  for (var i = 0; i < sampleCount; i++) {
    final t = i / sampleRate;
    var envelope = 1.0;
    if (i < fadeSamples) {
      envelope = i / fadeSamples;
    } else if (i > sampleCount - fadeSamples) {
      envelope = (sampleCount - i) / fadeSamples;
    }

    final value =
        amplitude * envelope * math.sin(2 * math.pi * frequencyHz * t);
    samples[i] = (value * 32767).round().clamp(-32768, 32767);
  }

  return _wrapPcm16AsWav(samples, sampleRate: sampleRate);
}

/// Wraps raw 16-bit mono PCM [samples] in a standard 44-byte WAV header.
Uint8List _wrapPcm16AsWav(Int16List samples, {required int sampleRate}) {
  const bitsPerSample = 16;
  const channels = 1;
  final blockAlign = channels * bitsPerSample ~/ 8;
  final dataLength = samples.length * blockAlign;
  final buffer = ByteData(44 + dataLength);

  void writeAscii(int offset, String text) {
    for (var i = 0; i < text.length; i++) {
      buffer.setUint8(offset + i, text.codeUnitAt(i));
    }
  }

  writeAscii(0, 'RIFF');
  buffer.setUint32(4, 36 + dataLength, Endian.little);
  writeAscii(8, 'WAVE');
  writeAscii(12, 'fmt ');
  buffer.setUint32(16, 16, Endian.little); // fmt chunk size
  buffer.setUint16(20, 1, Endian.little); // audio format: PCM
  buffer.setUint16(22, channels, Endian.little);
  buffer.setUint32(24, sampleRate, Endian.little);
  buffer.setUint32(28, sampleRate * blockAlign, Endian.little); // byte rate
  buffer.setUint16(32, blockAlign, Endian.little);
  buffer.setUint16(34, bitsPerSample, Endian.little);
  writeAscii(36, 'data');
  buffer.setUint32(40, dataLength, Endian.little);

  for (var i = 0; i < samples.length; i++) {
    buffer.setInt16(44 + i * 2, samples[i], Endian.little);
  }

  return buffer.buffer.asUint8List();
}
