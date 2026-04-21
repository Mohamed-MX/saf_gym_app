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
  double ballY = kWaveGaps[0];
  final List<Pipe> pipes = [];
  int pipeIndex = 0;
  int reps = 0;

  double rawVal = 0.0;
  double fVal = 0.0;

  double? startAx;
  double? startAy;
  double? startAz;
  double pointB = 0.0;
  bool isHigh = false;

  // Add a simple debounce to completely prevent any double-counting
  int lastRepTime = 0;

  void reset() {
    reps = 0;
    ballY = kWaveGaps[0];
    pipes.clear();
    pipeIndex = 0;
    
    rawVal = 0.0;
    fVal = 0.0;
    startAx = null;
    startAy = null;
    startAz = null;
    pointB = 0.0;
    isHigh = false;
    lastRepTime = 0;
  }

  void updateSensor(double ax, double ay, double az) {
    if (startAx == null || startAy == null || startAz == null) {
      startAx = ax;
      startAy = ay;
      startAz = az;
      pointB = 0.0;
    }

    double dist = sqrt(pow(ax - startAx!, 2) + pow(ay - startAy!, 2) + pow(az - startAz!, 2));

    rawVal = dist;
    fVal = kSensorAlpha * dist + (1 - kSensorAlpha) * fVal;

    // Point B is the highest point (max distance) of the current rep
    if (fVal > pointB) {
      pointB = fVal;
    } else {
      // Decay pointB slowly so it adjusts if the user does smaller reps over time
      pointB -= (pointB - fVal) * 0.005;
    }

    // Minimum distance required to consider the movement a valid rep (noise filter)
    double minRepDistance = 30.0;

    if (pointB > minRepDistance) { 
      // Lowered thresholdDown to 0.30 so it waits until the weight is fully down
      double thresholdUp = pointB * 0.70;
      double thresholdDown = pointB * 0.30;

      if (fVal > thresholdUp) {
        isHigh = true;
      } else if (fVal < thresholdDown && isHigh) {
        isHigh = false;
        
        int now = DateTime.now().millisecondsSinceEpoch;
        // 2 second delay (1000ms) to strictly prevent any double counting
        if (now - lastRepTime > 1000) {
          reps++;
          lastRepTime = now;
        }
      }
    }

    if (pointB > 0) {
      double normalizedDist = fVal / pointB; 
      double targetY = 0.8 - (normalizedDist * 0.6);
      targetY = targetY.clamp(0.0, 1.0);
      
      ballY += (targetY - ballY) * 0.2;
    } else {
      ballY += (0.8 - ballY) * 0.2;
    }
  }

  void tick(double screenW, double screenH) {
    if (screenW == 0 || screenH == 0) return;

    // Disabled pipe logic to focus entirely on sensor counting as requested.
    pipes.clear();
  }
}