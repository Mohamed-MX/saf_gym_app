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
const double _kGapHalf    = 85.0;
const double _kPipeSpeed  = 2.4;
const double _kPipeInterval = 175.0;
const List<double> _kWaveGaps = [0.75, 0.48, 0.22, 0.52];

// ─── SENSOR TUNING ───────────────────────────────────────────────────────────
// CHANGE THIS TO TRUE IF THE BALL MOVES DOWN WHEN YOU PUSH UP
const bool invertSensorMovement = false;

// HEAVY FILTER: Ignores the sharp "braking" spikes.
const double _kSensorAlpha  = 0.04;

// HEAVY SMOOTHING: Forces the ball to glide slowly to its target
const double _kSmoothFactor = 0.08;

class _Pipe {
  double x;
  double gapCenter;
  bool   scored = false;

  _Pipe({required this.x, required this.gapCenter});
}

enum AppState { setup, calibWait, calibRecord, game }

class RepGameScreen extends StatefulWidget {
  const RepGameScreen({super.key});

  @override
  State<RepGameScreen> createState() => _RepGameScreenState();
}

class _RepGameScreenState extends State<RepGameScreen> {
  Timer? _gameTimer;
  final BleManager _bleManager = BleManager();
  bool _bleConnected = false;

  AppState _appState = AppState.setup;
  bool _isCalibrated = false;

  double _ballY       = _kWaveGaps[0];
  double _targetBallY = _kWaveGaps[0];
  final List<_Pipe> _pipes = [];
  int _pipeIndex = 0;
  double _screenW = 0;
  double _screenH = 0;
  int _reps = 0;

  final int _calibWaitMs = 2000;
  final int _calibRecordMs = 7000;
  int? _calibStartTime;

  double _faz = 0.0;
  double _calMin = double.maxFinite;
  double _calMax = -double.maxFinite;
  double _calRom = 0.0;

  double _lowThreshold = 0;
  double _highThreshold = 0;
  double _resetLow = 0;
  double _resetHigh = 0;
  double _minRom = 0;

  int _repState = 0;
  int _lowCount = 0;
  int _highCount = 0;
  int _resetCount = 0;
  final int _confirmSamples = 2;
  double _valleyValue = double.maxFinite;
  double _peakValue = -double.maxFinite;
  int _repStartTime = 0;

  @override
  void initState() {
    super.initState();
    _gameTimer = Timer.periodic(
      const Duration(milliseconds: 16),
          (_) => _onTick(),
    );
    _initBle();
  }

  void _initBle() {
    _bleManager.onDataCallback = (ax, ay, az) {
      if (!mounted) return;

      // Z-Axis Filtering
      _faz = _kSensorAlpha * az + (1.0 - _kSensorAlpha) * _faz;
      double value = _faz;

      int now = DateTime.now().millisecondsSinceEpoch;

      if (_appState == AppState.calibWait) {
        if (_calibStartTime != null && now - _calibStartTime! >= _calibWaitMs) {
          setState(() {
            _appState = AppState.calibRecord;
            _calibStartTime = now;
            _calMin = double.maxFinite;
            _calMax = -double.maxFinite;
          });
        }
      }
      else if (_appState == AppState.calibRecord) {
        if (value < _calMin) _calMin = value;
        if (value > _calMax) _calMax = value;

        if (_calibStartTime != null && now - _calibStartTime! >= _calibRecordMs) {
          _processCalibration();
        }
      }
      else if (_appState == AppState.game) {

        // --- SENSOR TO SCREEN MAPPING WITH FORGIVENESS ZONE ---
        double range = _calMax - _calMin;
        if (range < 100) range = 100;

        // Shrink the required range by 20% so the ball easily reaches the edges
        double forgivingRange = range * 0.8;

        // Calculate position based on the centered 80% of the movement
        double norm = (value - (_calMin + (range * 0.1))) / forgivingRange;

        if (invertSensorMovement) {
          _targetBallY = norm.clamp(0.05, 0.95);
        } else {
          _targetBallY = (1.0 - norm).clamp(0.05, 0.95);
        }

        // --- EXERCISE REP LOGIC ---
        switch (_repState) {
          case 0:
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

          case 1:
            if (value < _valleyValue) _valleyValue = value;
            if (value > _peakValue) _peakValue = value;

            if (now - _repStartTime > 4000) {
              _repState = 0;
              _lowCount = 0;
              break;
            }

            if (value >= _highThreshold) _highCount++; else _highCount = 0;
            if (_highCount >= _confirmSamples) {
              double rom = _peakValue - _valleyValue;
              int repTime = now - _repStartTime;
              if (rom >= _minRom && repTime >= 400) {
                // Rep verified physically. (Scoring happens visually in the game)
              }
              _repState = 2;
              _highCount = 0;
            }
            break;

          case 2:
            if (value >= _resetLow && value <= _resetHigh) _resetCount++; else _resetCount = 0;
            if (_resetCount >= _confirmSamples) {
              _repState = 0;
              _resetCount = 0;
            }
            break;
        }
      }

      if (!_bleConnected) {
        setState(() => _bleConnected = true);
      }
    };
    _bleManager.startScan();
  }

  void _processCalibration() {
    _calRom = _calMax - _calMin;

    if (_calRom < 4000) {
      setState(() {
        _isCalibrated = false;
        _appState = AppState.setup;
      });
      _showErrorSnackBar("Motion range too small. Do bigger reps!");
    } else {
      setState(() {
        _lowThreshold   = _calMin + (0.20 * _calRom);
        _highThreshold  = _calMax - (0.20 * _calRom);
        _resetLow       = _calMin + (0.40 * _calRom);
        _resetHigh      = _calMin + (0.65 * _calRom);
        _minRom         = 0.55 * _calRom;

        _isCalibrated = true;
        _appState = AppState.setup;
      });
    }
  }

  void _startCalibration() {
    if (!_bleConnected) {
      _showErrorSnackBar("Ensure sensor is connected first.");
      return;
    }
    setState(() {
      _appState = AppState.calibWait;
      _calibStartTime = DateTime.now().millisecondsSinceEpoch;
      _isCalibrated = false;
    });
  }

  void _startGame() {
    setState(() {
      _appState = AppState.game;
      _reps = 0;
      _ballY = _kWaveGaps[0];
      _targetBallY = _kWaveGaps[0];
      _pipes.clear();
      _pipeIndex = 0;

      _repState = 0;
      _lowCount = 0;
      _highCount = 0;
      _resetCount = 0;
      _valleyValue = double.maxFinite;
      _peakValue = -double.maxFinite;
      _repStartTime = 0;
    });
  }

  void _endGame() {
    setState(() {
      _appState = AppState.setup;
      _pipes.clear();
    });
  }

  void _showErrorSnackBar(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: Colors.redAccent),
    );
  }

  void _onTick() {
    if (_appState != AppState.game) return;
    if (_screenW == 0 || _screenH == 0) return;

    setState(() {
      if (_bleConnected) {
        _ballY += (_targetBallY - _ballY) * _kSmoothFactor;
        _ballY  = _ballY.clamp(0.02, 0.98);
      }

      if (_pipes.isEmpty) {
        _pipes.add(_Pipe(x: _screenW, gapCenter: _kWaveGaps[_pipeIndex % 4]));
        _pipeIndex++;
      } else if (_pipes.last.x <= _screenW - _kPipeInterval) {
        final newX = _pipes.last.x + _kPipeInterval;
        _pipes.add(_Pipe(x: newX, gapCenter: _kWaveGaps[_pipeIndex % 4]));
        _pipeIndex++;
      }

      for (final p in _pipes) {
        p.x -= _kPipeSpeed;
      }

      final ballPx = _screenW * _kBirdX;
      for (final p in _pipes) {
        if (!p.scored && p.x + _kPipeWidth < ballPx) {
          final gapCenterPx = p.gapCenter * _screenH;
          final ballAbsPx   = _ballY * _screenH;
          final inGap = (ballAbsPx - gapCenterPx).abs() < _kGapHalf - _kBirdRadius;
          if (inGap) {
            _reps++;
          }
          p.scored = true;
        }
      }

      _pipes.removeWhere((p) => p.x + _kPipeWidth < 0);
    });
  }

  @override
  void dispose() {
    _gameTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F1829),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: AppTheme.white),
          onPressed: () {
            if (_appState == AppState.game) {
              _endGame();
            } else {
              Navigator.pop(context);
            }
          },
        ),
        title: Text(
          _appState == AppState.game ? 'Rep Game' : 'Sensor Setup',
          style: GoogleFonts.outfit(fontSize: 20, fontWeight: FontWeight.w800, color: AppTheme.white),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: Icon(
              Icons.bluetooth_rounded,
              color: _bleConnected ? Colors.greenAccent : Colors.white38,
              size: 22,
            ),
          ),
        ],
      ),
      body: _appState == AppState.game ? _buildGameScreen() : _buildSetupScreen(),
    );
  }

  Widget _buildSetupScreen() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
                _appState == AppState.calibWait ? Icons.timer_rounded :
                _appState == AppState.calibRecord ? Icons.fitness_center_rounded :
                Icons.sensors_rounded,
                color: _bleConnected ? Colors.blueAccent : Colors.white38,
                size: 72
            ),
            const SizedBox(height: 24),
            Text(
              _appState == AppState.calibWait ? "Get Ready... (2s)" :
              _appState == AppState.calibRecord ? "DO 3 FULL REPS NOW!" :
              "Calibrate Your Motion",
              style: GoogleFonts.outfit(fontSize: 28, fontWeight: FontWeight.bold, color: Colors.white),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            Text(
              _appState == AppState.calibWait ? "Hold the bar steady." :
              _appState == AppState.calibRecord ? "Recording range of motion..." :
              "Lie on the bench and connect the sensor. Press Calibrate, wait 2 seconds, then do 3 full clean reps.",
              style: GoogleFonts.inter(fontSize: 15, color: Colors.white70, height: 1.5),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 40),
            if (_isCalibrated && _appState == AppState.setup)
              Container(
                padding: const EdgeInsets.all(16),
                margin: const EdgeInsets.only(bottom: 30),
                decoration: BoxDecoration(
                  color: Colors.greenAccent.withValues(alpha: 0.1),
                  border: Border.all(color: Colors.greenAccent.withValues(alpha: 0.4)),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  children: [
                    Text("Calibration Successful", style: GoogleFonts.outfit(color: Colors.greenAccent, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    Text("ROM: ${_calRom.toInt()} | Min: ${_calMin.toInt()} | Max: ${_calMax.toInt()}", style: const TextStyle(color: Colors.white70, fontSize: 12)),
                    Text("Low: ${_lowThreshold.toInt()} | High: ${_highThreshold.toInt()}", style: const TextStyle(color: Colors.white70, fontSize: 12)),
                  ],
                ),
              ),
            if (_appState == AppState.setup) ...[
              SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blueAccent.withValues(alpha: 0.2),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: const BorderSide(color: Colors.blueAccent)),
                  ),
                  onPressed: _bleConnected ? _startCalibration : null,
                  child: Text(_isCalibrated ? "RECALIBRATE" : "START CALIBRATION", style: GoogleFonts.outfit(fontSize: 18, color: Colors.white)),
                ),
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _isCalibrated ? Colors.greenAccent : Colors.grey[800],
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  onPressed: _isCalibrated ? _startGame : null,
                  child: Text("PLAY GAME", style: GoogleFonts.outfit(fontSize: 18, color: _isCalibrated ? Colors.black : Colors.white54, fontWeight: FontWeight.bold)),
                ),
              ),
            ]
          ],
        ),
      ),
    );
  }

  Widget _buildGameScreen() {
    return Column(
      children: [
        _RepBar(reps: _reps, bleConnected: _bleConnected, onReset: _startGame),
        Expanded(
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
                  nextGapY: _pipes.isNotEmpty
                      ? _pipes.firstWhere((p) => !p.scored && p.x + _kPipeWidth > _screenW * _kBirdX, orElse: () => _pipes.last).gapCenter
                      : _kWaveGaps[0],
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

// ─── Rep counter bar ─────────────────────────────────────────────────────────
class _RepBar extends StatelessWidget {
  final int reps;
  final bool bleConnected;
  final VoidCallback onReset;

  const _RepBar({super.key, required this.reps, required this.bleConnected, required this.onReset});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
      decoration: BoxDecoration(
        color: const Color(0xFF162035),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.3), blurRadius: 12, offset: const Offset(0, 4))],
      ),
      child: Row(
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('REPS', style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w600, color: AppTheme.white.withValues(alpha: 0.5), letterSpacing: 1.2)),
              Text('$reps', style: GoogleFonts.outfit(fontSize: 42, fontWeight: FontWeight.w900, color: AppTheme.white, height: 1.0)),
            ],
          ),
          const Spacer(),
          GestureDetector(
            onTap: onReset,
            child: Container(
              width: 42, height: 42,
              decoration: BoxDecoration(
                color: AppTheme.primaryBlue.withValues(alpha: 0.2), shape: BoxShape.circle,
                border: Border.all(color: AppTheme.primaryBlue.withValues(alpha: 0.4)),
              ),
              child: const Icon(Icons.refresh_rounded, color: AppTheme.primaryBlue, size: 22),
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
  final double nextGapY;

  _GamePainter({required this.birdY, required this.pipes, required this.screenW, required this.screenH, required this.nextGapY});

  @override
  void paint(Canvas canvas, Size size) {
    final bgRect = Rect.fromLTWH(0, 0, size.width, size.height);
    final bgPaint = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [Color(0xFF0F1829), Color(0xFF0D2144)],
      ).createShader(bgRect);
    canvas.drawRect(bgRect, bgPaint);

    final starPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.15)
      ..style = PaintingStyle.fill;
    final starPositions = const [
      Offset(0.1, 0.05), Offset(0.3, 0.12), Offset(0.6, 0.07),
      Offset(0.8, 0.18), Offset(0.5, 0.25), Offset(0.9, 0.04),
      Offset(0.15, 0.35), Offset(0.75, 0.40), Offset(0.45, 0.5),
    ];
    for (final frac in starPositions) {
      canvas.drawCircle(Offset(frac.dx * size.width, frac.dy * size.height), 1.5, starPaint);
    }

    final pipeBodyPaint = Paint()..color = const Color(0xFF1A6EE8)..style = PaintingStyle.fill;
    final pipeCapPaint = Paint()..color = const Color(0xFF2882FF)..style = PaintingStyle.fill;
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

      canvas.drawRect(pipeRect, pipeGlowPaint);

      final topBody = RRect.fromRectAndCorners(
        Rect.fromLTWH(pipe.x, 0, _kPipeWidth, topPipeBottom - capH),
        bottomLeft: const Radius.circular(4), bottomRight: const Radius.circular(4),
      );
      canvas.drawRRect(topBody, pipeBodyPaint);

      canvas.drawRRect(
        RRect.fromRectAndRadius(Rect.fromLTWH(pipe.x - capExtra, topPipeBottom - capH, _kPipeWidth + capExtra * 2, capH), const Radius.circular(6)),
        pipeCapPaint,
      );

      final botBody = RRect.fromRectAndCorners(
        Rect.fromLTWH(pipe.x, botPipeTop + capH, _kPipeWidth, size.height - botPipeTop - capH),
        topLeft: const Radius.circular(4), topRight: const Radius.circular(4),
      );
      canvas.drawRRect(botBody, pipeBodyPaint);

      canvas.drawRRect(
        RRect.fromRectAndRadius(Rect.fromLTWH(pipe.x - capExtra, botPipeTop, _kPipeWidth + capExtra * 2, capH), const Radius.circular(6)),
        pipeCapPaint,
      );
    }

    final groundPaint = Paint()..color = const Color(0xFF1A3060)..strokeWidth = 2;
    canvas.drawLine(Offset(0, size.height - 2), Offset(size.width, size.height - 2), groundPaint);

    final ballPx = Offset(size.width * _kBirdX, birdY * size.height);
    final birdPx = ballPx;

    canvas.drawCircle(
      birdPx, _kBirdRadius + 10,
      Paint()..color = const Color(0xFFFF3D3D).withValues(alpha: 0.18)..maskFilter = const MaskFilter.blur(BlurStyle.normal, 10),
    );

    canvas.drawCircle(
      birdPx, _kBirdRadius,
      Paint()..shader = RadialGradient(colors: [Colors.redAccent.shade100, Colors.redAccent.shade700]).createShader(Rect.fromCircle(center: birdPx, radius: _kBirdRadius)),
    );
  }

  @override
  bool shouldRepaint(_GamePainter old) => old.birdY != birdY || old.pipes != pipes || old.nextGapY != nextGapY;
}