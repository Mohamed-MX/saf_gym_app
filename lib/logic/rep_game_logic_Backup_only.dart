import 'dart:math';

// ─── Game constants ──────────────────────────────────────────────────────────
const double kBirdX      = 0.22;
const double kBirdRadius = 18.0;
const double kPipeWidth  = 52.0;
const double kGapHalf    = 85.0;
const double kPipeSpeed  = 2.4;
const double kPipeInterval = 175.0;
const List<double> kWaveGaps = [0.75, 0.48, 0.22, 0.52];

// ─── SENSOR TUNING ───────────────────────────────────────────────────────────
const bool invertSensorMovement = false;

// Fast filter: 40% of new data allowed through
const double kSensorAlpha  = 0.40;

// Fast smoothing: 25% of the distance covered per frame
const double kSmoothFactor = 0.25;

// Deadzone: Ignores micro-stutters smaller than 1% of the screen
const double kDeadZone = 0.01;

class Pipe {
  double x;
  double gapCenter;
  bool scored = false;

  Pipe({required this.x, required this.gapCenter});
}

class RepGameLogic {
  double ballY = 0.5;
  final List<Pipe> pipes = [];
  int pipeIndex = 0;
  int reps = 0;

  double rawAy = 0.0;
  double fAy = 0.0;

  double localMin = 0.0;
  double localMax = 100.0;
  bool isHigh = false;

  int gameTickCount = 0;

  void reset() {
    reps = 0;
    ballY = 0.5;
    pipes.clear();
    pipeIndex = 0;
    rawAy = 0.0;
    fAy = 0.0;
    localMin = 0.0;
    localMax = 100.0;
    isHigh = false;
    gameTickCount = 0;
  }

  void updateSensor(double ay) {
    rawAy = ay;
    fAy = kSensorAlpha * ay + (1 - kSensorAlpha) * fAy;

    if (fAy > localMax) localMax = fAy;
    if (fAy < localMin) localMin = fAy;

    // Decay to auto-adapt over time
    localMax -= (localMax - fAy) * 0.002;
    localMin += (fAy - localMin) * 0.002;

    double range = localMax - localMin;
    if (range > 500) {
      double thresholdUp = localMin + range * 0.7;
      double thresholdDown = localMin + range * 0.3;

      if (fAy > thresholdUp) {
        isHigh = true;
      } else if (fAy < thresholdDown && isHigh) {
        isHigh = false;
        reps++;
      }
    }
  }

  void tick(double screenW, double screenH) {
    if (screenW == 0 || screenH == 0) return;

    gameTickCount++;
    double timeSeconds = gameTickCount * 0.016; // approx 60fps

    // 1 full rep = 3.5 seconds
    double freq = (2 * pi) / 3.5;

    // The ball smoothly glides up and down in a pure sine wave rhythm
    ballY = 0.5 - 0.35 * cos(timeSeconds * freq);

    // Spawn pipes so they exactly match the sine wave's future path
    if (pipes.isEmpty) {
      double dist = screenW - (screenW * kBirdX);
      double futureTime = timeSeconds + (dist / kPipeSpeed) * 0.016;
      pipes.add(Pipe(x: screenW, gapCenter: 0.5 - 0.35 * cos(futureTime * freq)));
      pipeIndex++;
    } else if (pipes.last.x <= screenW - kPipeInterval) {
      final newX = pipes.last.x + kPipeInterval;
      double dist = newX - (screenW * kBirdX);
      double futureTime = timeSeconds + (dist / kPipeSpeed) * 0.016;
      pipes.add(Pipe(x: newX, gapCenter: 0.5 - 0.35 * cos(futureTime * freq)));
      pipeIndex++;
    }

    // Move pipes
    for (final p in pipes) {
      p.x -= kPipeSpeed;
      if (!p.scored && p.x + kPipeWidth < screenW * kBirdX) {
        p.scored = true;
      }
    }

    // Prune off-screen pipes
    pipes.removeWhere((p) => p.x + kPipeWidth < 0);
  }
}