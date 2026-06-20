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
  double ballY = invertSensorMovement ? 0.158 : 0.842; // Start at the correct resting position
  final List<StarItem> items = [];
  int pipeIndex = 0;
  int reps = 0;
  int totalStarsCollected = 0;
  
  bool useYZOnly = false;

  bool initialized = false;
  double sAx = 0, sAy = 0, sAz = 0;
  double startAx = 0, startAy = 0, startAz = 0;
  
  double maxDist = 0.0;
  double peakAx = 0, peakAy = 0, peakAz = 0;
  double calibrationRom = 12000.0; // Fixed denominator for first rep to prevent wild teleporting
  
  bool _axisLocked = false;
  double _axisX = 0, _axisY = 1, _axisZ = 0; // Default to Y axis
  double maxReach = 10.0;
  
  bool isHigh = false;
  double lastActiveVal = 0.0;
  double currentPipeSpeed = 0.0;
  int lastRepTime = 0;

  void reset() {
    reps = 0;
    totalStarsCollected = 0;
    ballY = invertSensorMovement ? 0.158 : 0.842;
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
    
    _axisLocked = false;
    _axisX = 0; _axisY = 1; _axisZ = 0;
    maxReach = 10.0;
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
    
    double currentDist;
    if (useYZOnly) {
      currentDist = sqrt(dy * dy + dz * dz);
    } else {
      currentDist = sqrt(dx * dx + dy * dy + dz * dz);
    }
    
    // The ball's up/down movement only responds to the y-axis
    // Negated to flip the movement (up is down, down is up)
    double signedDist = -dy;
    if (signedDist.abs() > maxReach) {
      maxReach = signedDist.abs();
    }
    
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


    // Anchored mapping using signed distance to naturally follow up/down movement
    // Map -maxReach to bottom (0.842), 0 to center (0.5), +maxReach to top (0.158)
    // Multiplied by 1.45 to make the ball significantly more sensitive to movement.
    double positionFrac = (signedDist * 1.45) / maxReach; // -1.45 to 1.45
    double targetY = 0.5 - (positionFrac * (0.5 - 0.158));
        
    targetY = targetY.clamp(0.0, 1.0);
    ballY += (targetY - ballY) * 0.18;

    // Dynamic pipe speed based strictly on 3D displacement
    double speedMagnitude = (currentDist - lastActiveVal).abs();
    lastActiveVal = currentDist;
    
    // Scale speed by ROM so it's consistent regardless of the physical sensor values.
    // Multiplier heavily increased so user movement actually drives the game clearly.
    double normalizedSpeed = calibrationRom > 10.0 ? (speedMagnitude / calibrationRom) : 0;
    double targetSpeed = (normalizedSpeed * 1200.0).clamp(0.0, 3.2);
    
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
    
    // Keep the ball within the screen limits (borders of the game screen)
    if (bY < kBirdRadius) bY = kBirdRadius;
    if (bY > screenH - kBirdRadius) bY = screenH - kBirdRadius;
    ballY = bY / screenH;

    // ── Magnetic pull: stars attract the ball ────────────────────────────────
    const double kMagnetRange    = 220.0; // horizontal px range where pull activates
    const double kMagnetStrength = 0.018; // max fraction of gap closed per frame
    for (final star in items) {
      if (star.collected) continue;
      double starCenterX = star.x + kPipeWidth / 2;
      double horizDist   = (bX - starCenterX).abs();
      if (horizDist < kMagnetRange) {
        double strength = kMagnetStrength * (1.0 - horizDist / kMagnetRange);
        double starY    = star.yPos * screenH;
        bY             += (starY - bY) * strength;
      }
    }
    ballY = bY / screenH; // sync after pull before collision clamping below

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
          totalStarsCollected++;
        }
      }
    }

    // Remove off-screen stars
    items.removeWhere((p) => p.x < -kPipeWidth);

    // Only spawn stars at the extremes (Start and Peak)
    double startPos = invertSensorMovement ? 0.158 : 0.842;
    double peakPos = invertSensorMovement ? 0.842 : 0.158;
    List<double> currentPattern = [peakPos, startPos];

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