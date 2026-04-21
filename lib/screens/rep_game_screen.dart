import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../ble/ble_manager.dart';
import '../logic/rep_game_logic.dart';
import '../theme/app_theme.dart';

enum AppState { setup, game }

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
  final RepGameLogic _logic = RepGameLogic();

  double _screenW = 0;
  double _screenH = 0;

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

      // Feed sensor to logic engine
      _logic.updateSensor(ax, ay, az);

      if (!_bleConnected) {
        setState(() => _bleConnected = true);
      }
    };

    _bleManager.startScan();
  }

  void _startGame() {
    setState(() {
      _appState = AppState.game;
      _logic.reset();
    });
  }


  void _endGame() {
    setState(() {
      _appState = AppState.setup;
      _logic.pipes.clear();
    });
  }

  void _onTick() {
    if (_appState != AppState.game) return;
    if (_screenW == 0 || _screenH == 0) return;

    setState(() {
      if (_bleConnected) {
        _logic.tick(_screenW, _screenH);
      }
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
            }
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
      body: _appState == AppState.game 
          ? _buildGameScreen() 
          : _buildSetupScreen(),
    );
  }

  // ─── Setup Screen View ───────────────────────────────────────────────────
  Widget _buildSetupScreen() {
    return Column(
      children: [
        const SizedBox(height: 12),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text("Sensor Diagnostic", style: GoogleFonts.outfit(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.white)),
              Text(
                _bleConnected ? "Sensor connected — move to see values" : "Waiting for sensor...",
                style: GoogleFonts.inter(fontSize: 13, color: _bleConnected ? Colors.greenAccent : Colors.white38),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            children: [
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: Colors.black45,
                  border: Border.all(color: Colors.blueAccent.withValues(alpha: 0.4)),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _sectionLabel("LIVE SENSOR (DISTANCE FROM A)"),
                    _sensorRow("Raw Dist", _logic.rawVal.toStringAsFixed(0), Colors.greenAccent.shade100),
                    _sensorRow("Filt Dist", _logic.fVal.toStringAsFixed(0), Colors.green),
                    const SizedBox(height: 12),
                    _sectionLabel("AUTO MAPPING RANGE"),
                    _sensorRow("Point A", "Fixed at Start", Colors.white54),
                    _sensorRow("Point B (Max)", _logic.pointB.toStringAsFixed(0), Colors.white54),
                  ],
                ),
              ),
              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _bleConnected ? Colors.greenAccent : Colors.grey[800],
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  onPressed: _bleConnected ? _startGame : null,
                  child: Text(
                    _bleConnected ? "PLAY GAME" : "Waiting for sensor...",
                    style: GoogleFonts.outfit(fontSize: 18, color: _bleConnected ? Colors.black : Colors.white54, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ],
    );
  }

  Widget _sectionLabel(String text) {
    return Padding(
      padding: const EdgeInsets.only(top: 8, bottom: 4),
      child: Text(text, style: GoogleFonts.inter(fontSize: 9, letterSpacing: 1.4, color: Colors.blueAccent, fontWeight: FontWeight.w700)),
    );
  }

  Widget _sensorRow(String label, String value, Color valueColor) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: Colors.white54, fontSize: 13)),
          Text(value, style: GoogleFonts.outfit(fontSize: 15, color: valueColor, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  // ─── Game Screen View ────────────────────────────────────────────────────
  Widget _buildGameScreen() {
    return Column(
      children: [
        _RepBar(reps: _logic.reps, bleConnected: _bleConnected, onReset: _startGame),
        Expanded(
          child: Stack(
            children: [
              LayoutBuilder(
                builder: (context, constraints) {
                  _screenW = constraints.maxWidth;
                  _screenH = constraints.maxHeight;
                  return CustomPaint(
                    size: Size(_screenW, _screenH),
                    painter: _GamePainter(
                      birdY: _logic.ballY,
                      pipes: _logic.pipes,
                      screenW: _screenW,
                      screenH: _screenH,
                      nextGapY: _logic.pipes.isNotEmpty
                          ? _logic.pipes.firstWhere((p) => !p.scored && p.x + kPipeWidth > _screenW * kBirdX, orElse: () => _logic.pipes.last).gapCenter
                          : kWaveGaps[0],
                    ),
                  );
                },
              ),
              Positioned(
                right: 8,
                top: 8,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.65),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.white12),
                  ),
                  child: DefaultTextStyle(
                    style: const TextStyle(fontSize: 11, fontFamily: 'monospace'),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text("Raw Dist : ${_logic.rawVal.toStringAsFixed(0)}", style: const TextStyle(color: Colors.greenAccent)),
                        Text("Filt Dist: ${_logic.fVal.toStringAsFixed(0)}", style: const TextStyle(color: Colors.green)),
                        Text("State : ${_logic.isHigh ? "UP" : "DOWN"}", style: const TextStyle(color: Colors.orangeAccent)),
                      ],
                    ),
                  ),
                ),
              ),
            ],
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
  final List<Pipe> pipes;
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
      final topPipeBottom = gapCenterPx - kGapHalf;
      final botPipeTop = gapCenterPx + kGapHalf;
      final pipeRect = Rect.fromLTWH(pipe.x, 0, kPipeWidth, size.height);

      canvas.drawRect(pipeRect, pipeGlowPaint);

      final topBody = RRect.fromRectAndCorners(
        Rect.fromLTWH(pipe.x, 0, kPipeWidth, topPipeBottom - capH),
        bottomLeft: const Radius.circular(4), bottomRight: const Radius.circular(4),
      );
      canvas.drawRRect(topBody, pipeBodyPaint);

      canvas.drawRRect(
        RRect.fromRectAndRadius(Rect.fromLTWH(pipe.x - capExtra, topPipeBottom - capH, kPipeWidth + capExtra * 2, capH), const Radius.circular(6)),
        pipeCapPaint,
      );

      final botBody = RRect.fromRectAndCorners(
        Rect.fromLTWH(pipe.x, botPipeTop + capH, kPipeWidth, size.height - botPipeTop - capH),
        topLeft: const Radius.circular(4), topRight: const Radius.circular(4),
      );
      canvas.drawRRect(botBody, pipeBodyPaint);

      canvas.drawRRect(
        RRect.fromRectAndRadius(Rect.fromLTWH(pipe.x - capExtra, botPipeTop, kPipeWidth + capExtra * 2, capH), const Radius.circular(6)),
        pipeCapPaint,
      );
    }

    final groundPaint = Paint()..color = const Color(0xFF1A3060)..strokeWidth = 2;
    canvas.drawLine(Offset(0, size.height - 2), Offset(size.width, size.height - 2), groundPaint);

    final ballPx = Offset(size.width * kBirdX, birdY * size.height);
    final birdPx = ballPx;

    canvas.drawCircle(
      birdPx, kBirdRadius + 10,
      Paint()..color = const Color(0xFFFF3D3D).withValues(alpha: 0.18)..maskFilter = const MaskFilter.blur(BlurStyle.normal, 10),
    );

    canvas.drawCircle(
      birdPx, kBirdRadius,
      Paint()..shader = RadialGradient(colors: [Colors.redAccent.shade100, Colors.redAccent.shade700]).createShader(Rect.fromCircle(center: birdPx, radius: kBirdRadius)),
    );
  }

  @override
  bool shouldRepaint(_GamePainter old) => old.birdY != birdY || old.pipes != pipes || old.nextGapY != nextGapY;
}