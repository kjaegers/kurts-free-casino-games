import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:kurts_free_casino_games/core/audio/kfg_tone_generator.dart';

void main() {
  group('generateToneWavBytes', () {
    test('produces a well-formed 16-bit mono PCM WAV header', () {
      final bytes = generateToneWavBytes(
        frequencyHz: 440,
        duration: const Duration(milliseconds: 100),
        sampleRate: 44100,
      );
      final data = ByteData.sublistView(bytes);

      String readAscii(int offset, int length) {
        return String.fromCharCodes(bytes.sublist(offset, offset + length));
      }

      expect(readAscii(0, 4), 'RIFF');
      expect(readAscii(8, 4), 'WAVE');
      expect(readAscii(12, 4), 'fmt ');
      expect(readAscii(36, 4), 'data');

      expect(data.getUint16(20, Endian.little), 1); // PCM
      expect(data.getUint16(22, Endian.little), 1); // mono
      expect(data.getUint32(24, Endian.little), 44100); // sample rate
      expect(data.getUint16(34, Endian.little), 16); // bits per sample

      final dataLength = data.getUint32(40, Endian.little);
      expect(bytes.length, 44 + dataLength);
    });

    test('sample count matches the requested duration and sample rate', () {
      final bytes = generateToneWavBytes(
        frequencyHz: 440,
        duration: const Duration(milliseconds: 200),
        sampleRate: 44100,
      );
      final data = ByteData.sublistView(bytes);
      final dataLength = data.getUint32(40, Endian.little);

      // 16-bit mono -> 2 bytes per sample.
      final sampleCount = dataLength ~/ 2;
      expect(sampleCount, closeTo(44100 * 0.2, 2));
    });

    test('starts and ends at (near) silence thanks to the fade envelope', () {
      final bytes = generateToneWavBytes(
        frequencyHz: 440,
        duration: const Duration(milliseconds: 180),
      );
      final data = ByteData.sublistView(bytes);
      final sampleCount = (bytes.length - 44) ~/ 2;

      final firstSample = data.getInt16(44, Endian.little);
      final lastSample = data.getInt16(
        44 + (sampleCount - 1) * 2,
        Endian.little,
      );

      expect(firstSample, 0);
      expect(lastSample.abs(), lessThan(500));
    });

    test('never exceeds the requested amplitude', () {
      final bytes = generateToneWavBytes(
        frequencyHz: 523.25,
        duration: const Duration(milliseconds: 180),
        amplitude: 0.5,
      );
      final data = ByteData.sublistView(bytes);
      final sampleCount = (bytes.length - 44) ~/ 2;
      final maxAllowed = (0.5 * 32767).ceil();

      for (var i = 0; i < sampleCount; i++) {
        final sample = data.getInt16(44 + i * 2, Endian.little);
        expect(sample.abs(), lessThanOrEqualTo(maxAllowed));
      }
    });

    test('different frequencies produce different audio data', () {
      final a = generateToneWavBytes(frequencyHz: 261.63);
      final b = generateToneWavBytes(frequencyHz: 659.25);

      expect(a, isNot(equals(b)));
    });

    test('the same frequency and duration always produce identical bytes', () {
      final a = generateToneWavBytes(frequencyHz: 392.0);
      final b = generateToneWavBytes(frequencyHz: 392.0);

      expect(a, equals(b));
    });
  });
}
