import 'dart:math';

// ─── Game constants ──────────────────────────────────────────────────────────
const double kBirdX      = 0.22;
const double kBirdRadius = 18.0;
const double kPipeWidth  = 42.0;
const double kGapHalf    = 58.0;
const double kPipeSpeed  = 2.4;
const double kPipeInterval = 200.0;

// ─── SENSOR TUNING ───────────────────────────────────────────────────────────
const bool invertSensorMovement = false;

// Slower filter: heavily smooths raw data to prevent wiggling
const double kSensorAlpha  = 0.15;

// Fast smoothing: 25% of the distance covered per frame
const double kSmoothFactor = 0.25;

// Deadzone: Ignores micro-stutters smaller than 1% of the screen
const double kDeadZone = 0.01; 

class StarItem {
  double x;
  double yPos;
  bool collected = false;

  StarItem({required this.x, required this.yPos});
}

class RepGameLogic {
  double ballY = invertSensorMovement ? 0.12 : 0.88; // Start at the correct resting position
  final List<StarItem> items = [];
  int pipeIndex = 0;
  int reps = 0;

  bool initialized = false;
  double sAx = 0, sAy = 0, sAz = 0;
  double startAx = 0, startAy = 0, startAz = 0;
  
  double maxDist = 0.0;
  double peakAx = 0, peakAy = 0, peakAz = 0;
  double calibrationRom = 12000.0; // Fixed denominator for first rep to prevent wild teleporting
  
  bool isHigh = false;
  double lastActiveVal = 0.0;
  double currentPipeSpeed = 0.0;
  int lastRepTime = 0;

  void reset() {
    reps = 0;
    ballY = invertSensorMovement ? 0.12 : 0.88;
    items.clear();
    pipeIndex = 0;
    
    initialized = false;
    sAx = 0; sAy = 0; sAz = 0;
    startAx = 0; startAy = 0; startAz = 0;
    
    maxDist = 0.0;
    peakAx = 0; peakAy = 0; peakAz = 0;
    calibrationRom = 12000.0;
    
    isHigh = false;
    lastRepTime = 0;
    lastActiveVal = 0.0;
    currentPipeSpeed = 0.0;
  }

  void updateSensor(double ax, double ay, double az) {
    if (!initialized) {
      sAx = ax; sAy = ay; sAz = az;
      startAx = ax; startAy = ay; startAz = az;
      initialized = true;
    }

    sAx = kSensorAlpha * ax + (1 - kSensorAlpha) * sAx;
    sAy = kSensorAlpha * ay + (1 - kSensorAlpha) * sAy;
    sAz = kSensorAlpha * az + (1 - kSensorAlpha) * sAz;

    double dx = sAx - startAx;
    double dy = sAy - startAy;
    double dz = sAz - startAz;
    double currentDist = sqrt(dx * dx + dy * dy + dz * dz);
    
    if (currentDist > maxDist) {
      maxDist = currentDist;
      peakAx = sAx;
      peakAy = sAy;
      peakAz = sAz;
    }
    
    double rom = maxDist;

    // Project using calibrationRom to guarantee 100% smooth movement on every frame
    double normalizedDist = currentDist / calibrationRom;
    normalizedDist = normalizedDist.clamp(0.0, 1.0);

    // Rep logic
    if (rom > 2000.0) { // Require a real physical movement to count reps
      if (normalizedDist > 0.70) {
        isHigh = true;
      } else if (normalizedDist < 0.30 && isHigh) {
        isHigh = false;
        
        int now = DateTime.now().millisecondsSinceEpoch;
        if (now - lastRepTime > 1000) {
          reps++;
          lastRepTime = now;
          calibrationRom = maxDist > 2000.0 ? maxDist : calibrationRom; // Lock in true ROM
        }
      }
    }


    // Anchored mapping
    double defaultY = invertSensorMovement ? 0.12 : 0.88;
    double targetY = defaultY;
    if (rom > 10.0) {
      targetY = invertSensorMovement
          ? 0.12 + (normalizedDist * 0.76)  // Moves DOWN to 0.88
          : 0.88 - (normalizedDist * 0.76); // Moves UP to 0.12
    }
        
    targetY = targetY.clamp(0.0, 1.0);
    ballY += (targetY - ballY) * 0.18;

    // Dynamic pipe speed based strictly on 3D displacement
    double speedMagnitude = (currentDist - lastActiveVal).abs();
    lastActiveVal = currentDist;
    
    // Scale speed by ROM so it's consistent regardless of the physical sensor values.
    // Multiplier heavily increased so user movement actually drives the game clearly.
    double normalizedSpeed = calibrationRom > 10.0 ? (speedMagnitude / calibrationRom) : 0;
    double targetSpeed = (normalizedSpeed * 1500.0).clamp(0.0, 4.0);
    
    // Flywheel smoothing: Ramp up quickly, glide down smoothly to prevent stuttering
    if (targetSpeed > currentPipeSpeed) {
      currentPipeSpeed += (targetSpeed - currentPipeSpeed) * 0.20;
    } else {
      currentPipeSpeed += (targetSpeed - currentPipeSpeed) * 0.03;
    }
  }

  void tick(double screenW, double screenH) {
    if (screenW == 0 || screenH == 0) return;

    double bX = kBirdX * screenW;
    double bY = ballY * screenH;

    // Move existing stars using user-driven speed
    for (int i = 0; i < items.length; i++) {
      items[i].x -= currentPipeSpeed;
      
      // Star Collection logic
      double sLeft = items[i].x;
      double sRight = items[i].x + kPipeWidth;
      
      if (!items[i].collected && bX + kBirdRadius > sLeft && bX - kBirdRadius < sRight) {
        double starY = items[i].yPos * screenH;
        if ((bY - starY).abs() < 40.0) { // 40px collection radius
          items[i].collected = true;
        }
      }
    }

    // Remove off-screen stars
    items.removeWhere((p) => p.x < -kPipeWidth);

    // Only spawn stars at the extremes (Start and Peak)
    double startPos = invertSensorMovement ? 0.12 : 0.88;
    double peakPos = invertSensorMovement ? 0.88 : 0.12;
    List<double> currentPattern = [startPos, peakPos];

    // Spawn new stars
    if (items.isEmpty) {
      items.add(StarItem(x: screenW, yPos: currentPattern[pipeIndex % 2]));
      pipeIndex++;
    } else {
      StarItem lastItem = items.last;
      if (screenW - lastItem.x >= kPipeInterval) {
        items.add(StarItem(x: screenW, yPos: currentPattern[pipeIndex % 2]));
        pipeIndex++;
      }
    }
  }
}