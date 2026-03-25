import 'dart:async';
import 'dart:math';
import 'dart:typed_data';
import 'package:flutter/services.dart';

class SoundService {
  static bool _enabled = true;
  static const MethodChannel _channel = MethodChannel('abalone/audio');
  static bool _useNative = false;

  static late Uint8List _selectWav;
  static late Uint8List _moveWav;
  static late Uint8List _pushWav;
  static late Uint8List _winWav;
  static late Uint8List _errorWav;
  static late Uint8List _tapWav;

  static bool _initialized = false;

  static void setEnabled(bool enabled) {
    _enabled = enabled;
  }

  static Future<void> initialize() async {
    if (_initialized) return;
    _initialized = true;

    // ═══════════════════════════════════════
    // 1. SELECT: Soft glass marble tap
    // Like picking up a marble from a wooden bowl
    // ═══════════════════════════════════════
    _selectWav = _genMarbleSelect();

    // ═══════════════════════════════════════
    // 2. MOVE: Smooth marble slide on wood
    // Rolling/sliding feel
    // ═══════════════════════════════════════
    _moveWav = _genMarbleSlide();

    // ═══════════════════════════════════════
    // 3. PUSH: Two marbles colliding
    // Solid satisfying "clack"
    // ═══════════════════════════════════════
    _pushWav = _genMarbleCollision();

    // ═══════════════════════════════════════
    // 4. WIN: Beautiful ascending chime
    // Celebratory, pleasant melody
    // ═══════════════════════════════════════
    _winWav = _genWinChime();

    // ═══════════════════════════════════════
    // 5. ERROR: Gentle low "bonk"
    // Not harsh, just informative
    // ═══════════════════════════════════════
    _errorWav = _genErrorSound();

    // ═══════════════════════════════════════
    // 6. TAP: Light UI click
    // Subtle, barely there
    // ═══════════════════════════════════════
    _tapWav = _genTapSound();

    try {
      final result = await _channel.invokeMethod('init');
      _useNative = result == true;
    } catch (_) {
      _useNative = false;
    }
  }

  // ─── Public API ─────────────────────────────

  static void playTap() => _play(_tapWav);
  static void playSelect() => _play(_selectWav);
  static void playMove() => _play(_moveWav);
  static void playPush() => _play(_pushWav);
  static void playWin() => _play(_winWav);
  static void playError() => _play(_errorWav);

  static Future<void> _play(Uint8List wav) async {
    if (!_enabled) return;

    if (_useNative) {
      try {
        await _channel.invokeMethod('play', {'wav': wav});
        return;
      } catch (e) {
        _useNative = false;
      }
    }
    SystemSound.play(SystemSoundType.click);
  }

  // ═══════════════════════════════════════════════
  // SOUND GENERATORS
  // ═══════════════════════════════════════════════

  /// SELECT: Soft glass marble "clink"
  /// Two quick harmonics with fast decay = glass-like
  static Uint8List _genMarbleSelect() {
    const sr = 44100;
    const durationMs = 120;
    final n = (sr * durationMs / 1000).round();
    final samples = Int16List(n);

    for (int i = 0; i < n; i++) {
      final t = i / sr;

      // Fast exponential decay — marble tap is very short
      final env = exp(-25.0 * t);

      // Soft attack envelope to prevent click
      final attack = (i < 40) ? i / 40.0 : 1.0;

      // Primary tone — warm mid-high frequency
      final tone1 = sin(2 * pi * 1200 * t) * 0.5;

      // Harmonic — gives glass character
      final tone2 = sin(2 * pi * 2400 * t) * 0.2;

      // Very subtle high shimmer
      final tone3 = sin(2 * pi * 3600 * t) * 0.08;

      final val = (tone1 + tone2 + tone3) * env * attack * 0.3 * 32767;
      samples[i] = val.round().clamp(-32768, 32767);
    }
    return _wav(samples, sr);
  }

  /// MOVE: Marble sliding on wooden board
  /// Low rumble + gentle high end = sliding feel
  static Uint8List _genMarbleSlide() {
    const sr = 44100;
    const durationMs = 150;
    final n = (sr * durationMs / 1000).round();
    final samples = Int16List(n);

    for (int i = 0; i < n; i++) {
      final t = i / sr;

      // Envelope: quick attack, medium decay
      final env = exp(-12.0 * t);
      final attack = (i < 60) ? i / 60.0 : 1.0;

      // Low woody thud
      final low = sin(2 * pi * 280 * t) * 0.4;

      // Mid body — gives warmth
      final mid = sin(2 * pi * 560 * t) * 0.25;

      // Slight pitch bend down (marble settling)
      final freq = 800 - 200 * t * 6;
      final high = sin(2 * pi * freq * t) * 0.1;

      // Tiny noise burst at start (friction)
      final rng = Random(i);
      final noise = (i < 100)
          ? (rng.nextDouble() - 0.5) * 0.08 * (1.0 - i / 100.0)
          : 0.0;

      final val =
          (low + mid + high + noise) * env * attack * 0.35 * 32767;
      samples[i] = val.round().clamp(-32768, 32767);
    }
    return _wav(samples, sr);
  }

  /// PUSH: Two glass marbles colliding
  /// Sharp attack + dual frequencies + short ring
  static Uint8List _genMarbleCollision() {
    const sr = 44100;
    const durationMs = 200;
    final n = (sr * durationMs / 1000).round();
    final samples = Int16List(n);
    final rng = Random(42);

    for (int i = 0; i < n; i++) {
      final t = i / sr;

      // Two-stage envelope: sharp impact + gentle ring
      final impact = exp(-40.0 * t); // Very fast initial hit
      final ring = exp(-8.0 * t) * 0.4; // Longer gentle ring
      final env = impact + ring;

      // Soft attack to prevent speaker pop
      final attack = (i < 20) ? i / 20.0 : 1.0;

      // Impact body — two marbles have two resonances
      final marble1 = sin(2 * pi * 800 * t) * 0.3;
      final marble2 = sin(2 * pi * 1100 * t) * 0.25;

      // High frequency "clink" overtone
      final clink = sin(2 * pi * 2200 * t) * 0.15 * exp(-30.0 * t);

      // Very short noise burst (impact texture)
      final noise = (i < 30)
          ? (rng.nextDouble() - 0.5) * 0.12 * (1.0 - i / 30.0)
          : 0.0;

      final val =
          (marble1 + marble2 + clink + noise) * env * attack * 0.3 * 32767;
      samples[i] = val.round().clamp(-32768, 32767);
    }
    return _wav(samples, sr);
  }

  /// WIN: Pleasant ascending chime melody
  /// Musical notes with glass-bell character
  static Uint8List _genWinChime() {
    const sr = 44100;
    const durationMs = 1200;
    final n = (sr * durationMs / 1000).round();
    final samples = Int16List(n);

    // C major arpeggio — universally pleasant
    // C5, E5, G5, C6 (ascending)
    final notes = [523.25, 659.25, 783.99, 1046.50];
    final noteDelay = [0.0, 0.12, 0.24, 0.40]; // Staggered timing
    final noteVol = [0.30, 0.28, 0.26, 0.35]; // Last note slightly louder

    for (int i = 0; i < n; i++) {
      final t = i / sr;
      double sum = 0;

      for (int k = 0; k < notes.length; k++) {
        final noteT = t - noteDelay[k];
        if (noteT < 0) continue;

        // Each note rings like a bell
        final env = exp(-3.5 * noteT);
        final attack = (noteT < 0.005) ? noteT / 0.005 : 1.0;

        // Pure tone + soft harmonic = bell/chime
        final fundamental = sin(2 * pi * notes[k] * noteT) * 0.6;
        final harmonic2 = sin(2 * pi * notes[k] * 2 * noteT) * 0.2;
        final harmonic3 = sin(2 * pi * notes[k] * 3 * noteT) * 0.08;

        // Subtle shimmer
        final shimmer =
            sin(2 * pi * notes[k] * 4.1 * noteT) * 0.04 * exp(-6.0 * noteT);

        sum += (fundamental + harmonic2 + harmonic3 + shimmer) *
            env *
            attack *
            noteVol[k];
      }

      // Gentle master volume
      final val = sum * 0.35 * 32767;
      samples[i] = val.round().clamp(-32768, 32767);
    }
    return _wav(samples, sr);
  }

  /// ERROR: Gentle low "bonk" — not harsh
  /// Two quick low tones = "nope" feeling
  static Uint8List _genErrorSound() {
    const sr = 44100;
    const durationMs = 180;
    final n = (sr * durationMs / 1000).round();
    final samples = Int16List(n);

    for (int i = 0; i < n; i++) {
      final t = i / sr;

      // Envelope
      final env = exp(-15.0 * t);
      final attack = (i < 30) ? i / 30.0 : 1.0;

      // Low dull tone — descending slightly
      final freq = 250 - 80 * t * 5;
      final tone1 = sin(2 * pi * freq * t) * 0.5;

      // Second lower tone — gives "wrong" feel
      final tone2 = sin(2 * pi * 180 * t) * 0.3;

      final val = (tone1 + tone2) * env * attack * 0.2 * 32767;
      samples[i] = val.round().clamp(-32768, 32767);
    }
    return _wav(samples, sr);
  }

  /// TAP: Minimal UI click
  /// Very short, very subtle
  static Uint8List _genTapSound() {
    const sr = 44100;
    const durationMs = 50;
    final n = (sr * durationMs / 1000).round();
    final samples = Int16List(n);

    for (int i = 0; i < n; i++) {
      final t = i / sr;

      final env = exp(-50.0 * t);
      final attack = (i < 15) ? i / 15.0 : 1.0;

      // Just a quick soft tick
      final tone = sin(2 * pi * 900 * t) * 0.5;
      final body = sin(2 * pi * 450 * t) * 0.3;

      final val = (tone + body) * env * attack * 0.15 * 32767;
      samples[i] = val.round().clamp(-32768, 32767);
    }
    return _wav(samples, sr);
  }

  // ═══════════════════════════════════════════════
  // WAV FILE BUILDER
  // ═══════════════════════════════════════════════

  static Uint8List _wav(Int16List samples, int sr) {
    final dataLen = samples.length * 2;
    final fileLen = 44 + dataLen;
    final b = ByteData(fileLen);

    // RIFF
    b.setUint8(0, 0x52);
    b.setUint8(1, 0x49);
    b.setUint8(2, 0x46);
    b.setUint8(3, 0x46);
    b.setUint32(4, fileLen - 8, Endian.little);
    b.setUint8(8, 0x57);
    b.setUint8(9, 0x41);
    b.setUint8(10, 0x56);
    b.setUint8(11, 0x45);

    // fmt
    b.setUint8(12, 0x66);
    b.setUint8(13, 0x6D);
    b.setUint8(14, 0x74);
    b.setUint8(15, 0x20);
    b.setUint32(16, 16, Endian.little);
    b.setUint16(20, 1, Endian.little); // PCM
    b.setUint16(22, 1, Endian.little); // Mono
    b.setUint32(24, sr, Endian.little);
    b.setUint32(28, sr * 2, Endian.little);
    b.setUint16(32, 2, Endian.little);
    b.setUint16(34, 16, Endian.little);

    // data
    b.setUint8(36, 0x64);
    b.setUint8(37, 0x61);
    b.setUint8(38, 0x74);
    b.setUint8(39, 0x61);
    b.setUint32(40, dataLen, Endian.little);

    int offset = 44;
    for (int i = 0; i < samples.length; i++) {
      b.setInt16(offset, samples[i], Endian.little);
      offset += 2;
    }

    return b.buffer.asUint8List();
  }

  static Future<void> dispose() async {}
}