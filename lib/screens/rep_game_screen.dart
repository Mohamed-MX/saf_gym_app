import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../ble/ble_manager.dart';
import '../theme/app_theme.dart';

// ─── Game constants ──────────────────────────────────────────────────────────

const double _kBirdX      = 0.22;
const double _kBirdRadius = 18.0;
const double _kPipeWidth  = 52.0;
const double _kGapHalf    = 85.0;  // half-height of the pipe gap
const double _kPipeSpeed  = 2.4;   // pixels per frame at ~60 fps
// Sensor mapping — z-axis of IMU
const double _kAzMin = -10.0;  // full tilt → ball at top
const double _kAzMax =  10.0;  // full tilt → ball at bottom
// Ball movement
// Alpha for the EMA low-pass filter applied to raw sensor values.
// 0.08 = 8% new data, 92% old → dampens noise aggressively.
const double _kSensorAlpha  = 0.08;
// Lerp speed: ball moves this fraction of remaining distance each frame.
// 0.07 = slow glide; raise toward 0.15 if more responsiveness is desired.
const double _kSmoothFactor = 0.07;
// Dead zone: target doesn't update if filtered change is below this threshold.
// Prevents sensor noise from causing micro-jitter.
const double _kDeadZone     = 0.006;
// ── Wave pattern ─────────────────────────────────────────────────────────────
// 4 unique gap positions (fractional Y: 0=top, 1=bottom) forming a wave:
//   pos[0] = 0.75  bottom           (step 2 down / wave start)
//   pos[1] = 0.48  medium-low       (step 1 up   — "gradually going up")
//   pos[2] = 0.22  top              (step 2 up   — fully up)
//   pos[3] = 0.52  medium-high      (step 1 down — "gradually going down")
// pos[1] ≠ pos[3] so the two intermediate levels are NOT on the same level.
const List<double> _kWaveGaps = [0.75, 0.48, 0.22, 0.52];
// Fixed pixel distance between pipe leading edges → guarantees uniform spacing.
const double _kPipeInterval = 175.0;

// ─── Data class ──────────────────────────────────────────────────────────────

class _Pipe {
  double x;          // left edge in logical pixels
  double gapCenter;  // fractional Y of gap center [0..1]
  bool   scored = false;

  _Pipe({required this.x, required this.gapCenter});
}

// ─── Modes ───────────────────────────────────────────────────────────────────

enum GameMode { idle, calibWait, calibRecord, workout }

// ─── Screen ──────────────────────────────────────────────────────────────────

class RepGameScreen extends StatefulWidget {
  const RepGameScreen({super.key});

  @override
  State<RepGameScreen> createState() => _RepGameScreenState();
}

class _RepGameScreenState extends State<RepGameScreen> {
  // Game loop
  Timer? _gameTimer;

  // BLE
  final BleManager _bleManager = BleManager();
  bool _bleConnected = false;

  // Ball state — fractional Y [0=top .. 1=bottom] driven purely by sensor
  double _ballY       = _kWaveGaps[0]; // starts at bottom (wave pos 0)
  double _targetBallY = _kWaveGaps[0];

  // Sensor rolling average
  double _sensorAz = 0.0;

  // Pipes — deterministic wave pattern
  final List<_Pipe> _pipes = [];
  int _pipeIndex = 0; // tracks which pipe in the wave cycle
  double _screenW = 0;
  double _screenH = 0;

  // Score
  int _reps = 0;

  // States
  GameMode _mode = GameMode.idle;

  // Calibration
  final int _calibWaitMs = 2000;
  final int _calibRecordMs = 7000;
  int? _calibStartTime;
  double _calMin = double.maxFinite;
  double _calMax = -double.maxFinite;

  // Filters
  double _fax = 0.0;
  double _fay = 0.0;
  double _faz = 0.0;
  double _filteredSignal = 0.0;
  final double _alpha = 0.15;

  // Rep State Machine
  int _repState = 0; // 0: LOW, 1: HIGH, 2: RESET
  double _lowThreshold = 10000;
  double _highThreshold = 22000;
  double _resetLow = 14000;
  double _resetHigh = 19000;
  double _minRom = 7000;

  int _lowCount = 0;
  int _highCount = 0;
  int _resetCount = 0;
  final int _confirmSamples = 2;

  double _valleyValue = double.maxFinite;
  double _peakValue = -double.maxFinite;
  int _repStartTime = 0;

  // ── Lifecycle ────────────────────────────────────────────────────────────

  @override
  void initState() {
    super.initState();
    // ~60 fps
    _gameTimer = Timer.periodic(
      const Duration(milliseconds: 16),
      (_) => _onTick(),
    );
    _initBle();
  }

  void _initBle() {
    _bleManager.onDataCallback = (ax, ay, az) {
      if (!mounted) return;

      // 1. Heavy low-pass filter logic
      _fax = _alpha * ax + (1.0 - _alpha) * _fax;
      _fay = _alpha * ay + (1.0 - _alpha) * _fay;
      _faz = _alpha * az + (1.0 - _alpha) * _faz;

      // 2. Signal magnitude
      double magYZ = math.sqrt(_fay * _fay + _faz * _faz);
      _filteredSignal = _alpha * magYZ + (1.0 - _alpha) * _filteredSignal;

      int now = DateTime.now().millisecondsSinceEpoch;

      if (_mode == GameMode.calibWait) {
        if (_calibStartTime != null && now - _calibStartTime! >= _calibWaitMs) {
          _mode = GameMode.calibRecord;
          _calibStartTime = now;
          _calMin = double.maxFinite;
          _calMax = -double.maxFinite;
        }
      } else if (_mode == GameMode.calibRecord) {
        if (_filteredSignal < _calMin) _calMin = _filteredSignal;
        if (_filteredSignal > _calMax) _calMax = _filteredSignal;

        if (_calibStartTime != null && now - _calibStartTime! >= _calibRecordMs) {
          double calROM = _calMax - _calMin;

          if (calROM < 4000) {
            // Calibration failed (motion range too small), fallback to defaults
            _calMin = 6000; 
            _calMax = 26000;
            _lowThreshold = 10000;
            _highThreshold = 22000;
            _resetLow = 14000;
            _resetHigh = 19000;
            _minRom = 7000;
          } else {
            // Apply dynamic thresholds as in C++
            _lowThreshold   = _calMin + (0.20 * calROM);
            _highThreshold  = _calMax - (0.20 * calROM);
            _resetLow       = _calMin + (0.40 * calROM);
            _resetHigh      = _calMin + (0.68 * calROM);
            _minRom         = 0.50 * calROM;
          }
          
          _repState = 0;
          _lowCount = 0;
          _highCount = 0;
          _resetCount = 0;
          _valleyValue = double.maxFinite;
          _peakValue = -double.maxFinite;
          _repStartTime = 0;

          _mode = GameMode.workout;
        }
      } else if (_mode == GameMode.workout) {
        // Map filtered signal to 0..1 (targetBallY)
        double range = _calMax - _calMin;
        if (range < 0.01) range = 0.01;
        
        // Map using calMin/calMax, where higher signal -> bottom
        double norm = (_filteredSignal - _calMin) / range;
        double candidate = (1.0 - norm).clamp(0.05, 0.95);
        if ((candidate - _targetBallY).abs() > _kDeadZone) {
          _targetBallY = candidate;
        }

        // Run Rep State Machine
        double value = _filteredSignal;
        switch (_repState) {
          case 0: // WAIT_FOR_LOW
            _highCount = 0;
            _resetCount = 0;
            if (value <= _lowThreshold) _lowCount++; else _lowCount = 0;
            if (_lowCount >= _confirmSamples) {
              _repState = 1;
              _repStartTime = now;
              _valleyValue = value;
              _peakValue = value;
              _lowCount = 0;
            }
            break;
            
          case 1: // WAIT_FOR_HIGH
            if (value < _valleyValue) _valleyValue = value;
            if (value > _peakValue) _peakValue = value;
            
            if (now - _repStartTime > 4500) {
              _repState = 0;
              _lowCount = 0;
              break;
            }
            
            if (value >= _highThreshold) _highCount++; else _highCount = 0;
            if (_highCount >= _confirmSamples) {
              double rom = _peakValue - _valleyValue;
              int repTime = now - _repStartTime;
              if (rom >= _minRom && repTime >= 400) {
                // Physical rep verified! (Scoring is now handled by the pipe gaps)
              }
              _repState = 2;
              _highCount = 0;
            }
            break;
            
          case 2: // WAIT_FOR_RESET
            if (value >= _resetLow && value <= _resetHigh) _resetCount++; else _resetCount = 0;
            if (_resetCount >= _confirmSamples) {
              _repState = 0;
              _resetCount = 0;
            }
            break;
        }
      }

      // 4. Mark as connected (safe to call from any isolate — no rebuild needed)
      if (!_bleConnected) {
        if (mounted) setState(() => _bleConnected = true);
      }
    };
    _bleManager.startScan();
  }

  @override
  void dispose() {
    _gameTimer?.cancel();
    super.dispose();
  }

  // ── Game loop ────────────────────────────────────────────────────────────

  void _onTick() {
    if (_mode != GameMode.workout) return;
    if (_screenW == 0 || _screenH == 0) return;

    setState(() {
      // ── Move ball smoothly toward sensor target ───────────────────────
      // Uses lerp each frame so the ball glides, not snaps.
      // _targetBallY is updated smoothly by the sensor callback filter.
      if (_bleConnected) {
        _ballY += (_targetBallY - _ballY) * _kSmoothFactor;
        _ballY  = _ballY.clamp(0.02, 0.98);
      }
      // (no sensor → ball frozen; pipes still scroll; reps not scored)

      // ── Spawn pipes (4-step wave, uniform spacing) ───────────────────────
      // Each new pipe is placed exactly _kPipeInterval px after the previous,
      // guaranteeing constant gap between columns regardless of frame timing.
      if (_pipes.isEmpty) {
        _pipes.add(_Pipe(x: _screenW, gapCenter: _kWaveGaps[_pipeIndex % 4]));
        _pipeIndex++;
      } else if (_pipes.last.x <= _screenW - _kPipeInterval) {
        // Spawn at a fixed offset from the PREVIOUS pipe, not from screenW:
        final newX = _pipes.last.x + _kPipeInterval;
        _pipes.add(_Pipe(x: newX, gapCenter: _kWaveGaps[_pipeIndex % 4]));
        _pipeIndex++;
      }

      // ── Move pipes ───────────────────────────────────────────────────
      for (final p in _pipes) {
        p.x -= _kPipeSpeed;
      }

      // ── Score: ball must be inside the gap when crossing the pipe ─────
      final ballPx = _screenW * _kBirdX;
      for (final p in _pipes) {
        // Crossed the trailing edge of the pipe this frame?
        if (!p.scored && p.x + _kPipeWidth < ballPx) {
          final gapCenterPx = p.gapCenter * _screenH;
          final ballAbsPx   = _ballY * _screenH;
          final inGap = (ballAbsPx - gapCenterPx).abs() < _kGapHalf - _kBirdRadius;
          if (inGap) {
            _reps++;
          }
          // Mark as processed regardless so we don't recheck
          p.scored = true;
        }
      }

      // ── Prune off-screen pipes ────────────────────────────────────────
      _pipes.removeWhere((p) => p.x + _kPipeWidth < 0);
    });
  }

  // ── Input ────────────────────────────────────────────────────────────────

  /// Tap only starts the game — no flap, no ball control via touch.
  void _onTap() {
    if (_mode == GameMode.idle) {
      if (!_bleConnected) return; // Prevent calibrating if no BLE
      setState(() {
        _mode = GameMode.calibWait;
        _calibStartTime = DateTime.now().millisecondsSinceEpoch;
      });
    }
    // After game starts taps do nothing — ball is sensor-only.
  }

  void _reset() {
    setState(() {
      _reps        = 0;
      _ballY       = _kWaveGaps[0];
      _targetBallY = _kWaveGaps[0];
      _fax = 0.0;
      _fay = 0.0;
      _faz = 0.0;
      _filteredSignal = 0.0;

      // Reset to idle -> must calibrate again
      _mode        = GameMode.idle;
      _pipes.clear();
      _pipeIndex   = 0;
    });
  }


  // ── Build ────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F1829),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded,
              color: AppTheme.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Rep Game',
          style: GoogleFonts.outfit(
            fontSize: 20,
            fontWeight: FontWeight.w800,
            color: AppTheme.white,
          ),
        ),
        actions: [
          // BLE indicator
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: Icon(
              Icons.bluetooth_rounded,
              color: _bleConnected
                  ? Colors.greenAccent
                  : Colors.white38,
              size: 22,
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          // ── Rep counter bar ─────────────────────────────────────────────
          _RepBar(reps: _reps, bleConnected: _bleConnected, onReset: _reset),

          // ── Game canvas ─────────────────────────────────────────────────
          Expanded(
            child: GestureDetector(
              onTap: _onTap,
              child: LayoutBuilder(
                builder: (context, constraints) {
                  _screenW = constraints.maxWidth;
                  _screenH = constraints.maxHeight;
                  return CustomPaint(
                    size: Size(_screenW, _screenH),
                    painter: _GamePainter(
                      birdY: _ballY,
                      pipes: _pipes,
                      screenW: _screenW,
                      screenH: _screenH,
                      // next pipe gap so painter can draw hint arrow
                      nextGapY: _pipes.isNotEmpty
                          ? _pipes
                              .firstWhere(
                                (p) => !p.scored && p.x + _kPipeWidth > _screenW * _kBirdX,
                                orElse: () => _pipes.last,
                              )
                              .gapCenter
                          : _kWaveGaps[0],
                    ),
                    child: _mode != GameMode.workout ? _buildOverlay() : null,
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
  Widget _buildOverlay() {
    if (_mode == GameMode.idle) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.gamepad_rounded, color: AppTheme.white.withValues(alpha: 0.6), size: 64),
            const SizedBox(height: 16),
            Text('Tap to Calibrate', style: GoogleFonts.outfit(fontSize: 26, fontWeight: FontWeight.w800, color: AppTheme.white)),
            const SizedBox(height: 8),
            Text(
              _bleConnected
                  ? 'Sensor Ready\nWe will calibrate your motion range next.'
                  : 'Tap to start  •  Waiting for sensor…',
              style: GoogleFonts.inter(fontSize: 14, color: AppTheme.white.withValues(alpha: 0.6)),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    } else if (_mode == GameMode.calibWait) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.timer_rounded, color: Colors.yellowAccent.withValues(alpha: 0.8), size: 64),
            const SizedBox(height: 16),
            Text('Do 3 reps for Calibration ...', style: GoogleFonts.outfit(fontSize: 26, fontWeight: FontWeight.w800, color: AppTheme.white)),
            const SizedBox(height: 8),
            Text(
              'Do 3 full reps to calibrate.',
              style: GoogleFonts.inter(fontSize: 14, color: AppTheme.white.withValues(alpha: 0.6)),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    } else if (_mode == GameMode.calibRecord) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.fitness_center_rounded, color: Colors.greenAccent.withValues(alpha: 0.8), size: 64),
            const SizedBox(height: 16),
            Text('CALIBRATING', style: GoogleFonts.outfit(fontSize: 26, fontWeight: FontWeight.w800, color: AppTheme.white)),
            const SizedBox(height: 8),
            Text(
              'Do 3 full clean reps now in 7s!',
              style: GoogleFonts.inter(fontSize: 14, color: AppTheme.white.withValues(alpha: 0.6)),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }
    return const SizedBox.shrink();
  }
}

// ─── Rep counter bar ─────────────────────────────────────────────────────────

class _RepBar extends StatelessWidget {
  final int reps;
  final bool bleConnected;
  final VoidCallback onReset;

  const _RepBar({
    required this.reps,
    required this.bleConnected,
    required this.onReset,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
      decoration: BoxDecoration(
        color: const Color(0xFF162035),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.3),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          // Reps
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'REPS',
                style: GoogleFonts.inter(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.white.withValues(alpha: 0.5),
                  letterSpacing: 1.2,
                ),
              ),
              Text(
                '$reps',
                style: GoogleFonts.outfit(
                  fontSize: 42,
                  fontWeight: FontWeight.w900,
                  color: AppTheme.white,
                  height: 1.0,
                ),
              ),
            ],
          ),
          const Spacer(),

          // Sensor status badge
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: bleConnected
                  ? Colors.greenAccent.withValues(alpha: 0.15)
                  : Colors.white.withValues(alpha: 0.06),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: bleConnected
                    ? Colors.greenAccent.withValues(alpha: 0.5)
                    : Colors.white24,
              ),
            ),
            child: Row(
              children: [
                Icon(
                  bleConnected
                      ? Icons.sensors_rounded
                      : Icons.sensors_off_rounded,
                  color: bleConnected ? Colors.greenAccent : Colors.white38,
                  size: 16,
                ),
                const SizedBox(width: 6),
                Text(
                  bleConnected ? 'Sensor ON' : 'No Sensor',
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: bleConnected
                        ? Colors.greenAccent
                        : Colors.white38,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),

          // Reset button
          GestureDetector(
            onTap: onReset,
            child: Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: AppTheme.primaryBlue.withValues(alpha: 0.2),
                shape: BoxShape.circle,
                border: Border.all(
                    color: AppTheme.primaryBlue.withValues(alpha: 0.4)),
              ),
              child: const Icon(Icons.refresh_rounded,
                  color: AppTheme.primaryBlue, size: 22),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Custom painter ──────────────────────────────────────────────────────────

class _GamePainter extends CustomPainter {
  final double birdY;
  final List<_Pipe> pipes;
  final double screenW;
  final double screenH;
  final double nextGapY; // fractional Y of the next pipe's gap center

  _GamePainter({
    required this.birdY,
    required this.pipes,
    required this.screenW,
    required this.screenH,
    required this.nextGapY,
  });

  @override
  void paint(Canvas canvas, Size size) {
    // ── Background gradient ────────────────────────────────────────────────
    final bgRect = Rect.fromLTWH(0, 0, size.width, size.height);
    final bgPaint = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [Color(0xFF0F1829), Color(0xFF0D2144)],
      ).createShader(bgRect);
    canvas.drawRect(bgRect, bgPaint);

    // ── Stars (static decorative dots) ────────────────────────────────────
    final starPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.15)
      ..style = PaintingStyle.fill;
    final starPositions = const [
      Offset(0.1, 0.05), Offset(0.3, 0.12), Offset(0.6, 0.07),
      Offset(0.8, 0.18), Offset(0.5, 0.25), Offset(0.9, 0.04),
      Offset(0.15, 0.35), Offset(0.75, 0.40), Offset(0.45, 0.5),
    ];
    for (final frac in starPositions) {
      canvas.drawCircle(
        Offset(frac.dx * size.width, frac.dy * size.height), 1.5, starPaint);
    }

    // ── Pipes ─────────────────────────────────────────────────────────────
    final pipeBodyPaint = Paint()
      ..color = const Color(0xFF1A6EE8)
      ..style = PaintingStyle.fill;
    final pipeCapPaint = Paint()
      ..color = const Color(0xFF2882FF)
      ..style = PaintingStyle.fill;
    final pipeGlowPaint = Paint()
      ..color = const Color(0xFF4A9FFF).withValues(alpha: 0.25)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8)
      ..style = PaintingStyle.fill;
    const capH = 20.0;
    const capExtra = 6.0;

    for (final pipe in pipes) {
      final gapCenterPx = pipe.gapCenter * size.height;
      final topPipeBottom = gapCenterPx - _kGapHalf;
      final botPipeTop = gapCenterPx + _kGapHalf;

      final pipeRect = Rect.fromLTWH(pipe.x, 0, _kPipeWidth, size.height);
      // Glow
      canvas.drawRect(pipeRect, pipeGlowPaint);

      // Top pipe
      final topBody = RRect.fromRectAndCorners(
        Rect.fromLTWH(pipe.x, 0, _kPipeWidth, topPipeBottom - capH),
        bottomLeft: const Radius.circular(4),
        bottomRight: const Radius.circular(4),
      );
      canvas.drawRRect(topBody, pipeBodyPaint);
      // Top cap
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(
              pipe.x - capExtra, topPipeBottom - capH,
              _kPipeWidth + capExtra * 2, capH),
          const Radius.circular(6),
        ),
        pipeCapPaint,
      );

      // Bottom pipe
      final botBody = RRect.fromRectAndCorners(
        Rect.fromLTWH(pipe.x, botPipeTop + capH, _kPipeWidth,
            size.height - botPipeTop - capH),
        topLeft: const Radius.circular(4),
        topRight: const Radius.circular(4),
      );
      canvas.drawRRect(botBody, pipeBodyPaint);
      // Bottom cap
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(pipe.x - capExtra, botPipeTop,
              _kPipeWidth + capExtra * 2, capH),
          const Radius.circular(6),
        ),
        pipeCapPaint,
      );
    }

    // ── Ground line ───────────────────────────────────────────────────────
    final groundPaint = Paint()
      ..color = const Color(0xFF1A3060)
      ..strokeWidth = 2;
    canvas.drawLine(
      Offset(0, size.height - 2),
      Offset(size.width, size.height - 2),
      groundPaint,
    );

    // ── Hint arrow: shows direction to next gap ───────────────────────────
    final ballPx = Offset(size.width * _kBirdX, birdY * size.height);
    final nextGapPx = nextGapY * size.height;
    final goingUp = nextGapPx < ballPx.dy;
    final arrowColor = goingUp
        ? const Color(0xFF00E5FF)  // cyan = tilt up
        : const Color(0xFFFFD600); // yellow = tilt down

    // Arrow tip and tail
    final arrowDy = goingUp ? -(_kBirdRadius + 22.0) : (_kBirdRadius + 22.0);
    final tipY    = ballPx.dy + arrowDy;
    const arrowW  = 10.0;
    const arrowH  = 14.0;
    final tipPt   = Offset(ballPx.dx, tipY);
    final arrowPath = Path();
    if (goingUp) {
      arrowPath
        ..moveTo(tipPt.dx, tipPt.dy)
        ..lineTo(tipPt.dx - arrowW, tipPt.dy + arrowH)
        ..lineTo(tipPt.dx + arrowW, tipPt.dy + arrowH)
        ..close();
    } else {
      arrowPath
        ..moveTo(tipPt.dx, tipPt.dy)
        ..lineTo(tipPt.dx - arrowW, tipPt.dy - arrowH)
        ..lineTo(tipPt.dx + arrowW, tipPt.dy - arrowH)
        ..close();
    }
    canvas.drawPath(
      arrowPath,
      Paint()
        ..color = arrowColor.withValues(alpha: 0.85)
        ..style = PaintingStyle.fill,
    );
    // Glow on arrow
    canvas.drawPath(
      arrowPath,
      Paint()
        ..color = arrowColor.withValues(alpha: 0.25)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6)
        ..style = PaintingStyle.fill,
    );

    // ── Ball ─────────────────────────────────────────────────────────────
    final birdPx = ballPx;

    // Glow
    canvas.drawCircle(
      birdPx,
      _kBirdRadius + 10,
      Paint()
        ..color = const Color(0xFFFF3D3D).withValues(alpha: 0.18)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 10),
    );

    // Body
    canvas.drawCircle(
      birdPx,
      _kBirdRadius,
      Paint()
        ..shader = RadialGradient(
          colors: [
            Colors.redAccent.shade100,
            Colors.redAccent.shade700,
          ],
        ).createShader(
          Rect.fromCircle(center: birdPx, radius: _kBirdRadius),
        ),
    );

    // Eye
    canvas.drawCircle(
      birdPx + const Offset(6, -5),
      4.5,
      Paint()..color = Colors.white,
    );
    canvas.drawCircle(
      birdPx + const Offset(7.5, -5),
      2.5,
      Paint()..color = Colors.black87,
    );

    // Beak
    final beakPath = Path()
      ..moveTo(birdPx.dx + _kBirdRadius - 4, birdPx.dy)
      ..lineTo(birdPx.dx + _kBirdRadius + 10, birdPx.dy - 3)
      ..lineTo(birdPx.dx + _kBirdRadius + 10, birdPx.dy + 2)
      ..close();
    canvas.drawPath(
      beakPath,
      Paint()..color = const Color(0xFFFFB300),
    );
  }

  @override
  bool shouldRepaint(_GamePainter old) =>
      old.birdY != birdY || old.pipes != pipes || old.nextGapY != nextGapY;
}
