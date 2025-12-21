# Advanced Features Guide

This document describes the advanced features added to Flow Track and how to use them effectively.

## 📊 Advanced IMU Metrics

### Stroke Length
**What it measures:** The approximate distance your paddle travels during each stroke, calculated by integrating acceleration over time.

**How to use it:**
- Longer strokes generally indicate better technique (full extension)
- Consistent stroke length shows good form
- Sudden changes may indicate fatigue or technique breakdown

**Optimal range:** 1.5-2.5 meters per stroke (varies by paddler height and technique)

### Paddle Angle Entry/Exit
**What it measures:** The angle of your paddle relative to vertical when it enters and exits the water.

**How to use it:**
- **Entry angle (Catch):** Should be 30-45° for optimal catch
- **Exit angle:** Should be 45-60° to maximize power phase
- Too steep = incomplete stroke, too shallow = inefficient

**Visual feedback:** Displayed as "Entry° → Exit°" in the Advanced Metrics card

### Smoothness Score
**What it measures:** How consistent your acceleration is throughout the stroke (0-100%).

**How to use it:**
- **>80%** = Excellent smooth technique
- **60-80%** = Good, minor variations
- **40-60%** = Fair, noticeable variations
- **<40%** = Poor, jerky or inconsistent

**Tips:**
- Focus on fluid motion from catch to exit
- Avoid sudden jerks or pauses
- Maintain constant power application

### Fatigue Detection
**What it measures:** Compares recent stroke power to earlier strokes to detect declining performance (0-100%).

**How to use it:**
- **<20%** = Fresh, no fatigue
- **20-40%** = Mild fatigue, monitor hydration
- **40-60%** = Moderate fatigue, consider rest
- **>60%** = High fatigue, take a break!

**Display:** Shows percentage and color-coded indicator (green/yellow/orange/red)

### Asymmetry (Left vs Right Balance)
**What it measures:** Percentage distribution of left vs right side strokes.

**How to use it:**
- **50/50** = Perfect balance
- **±10%** = Acceptable variation
- **>20% imbalance** = Technique issue or injury concern

**Visual feedback:** "L:45% R:55%" format with color coding

### Rotation Torque
**What it measures:** Total paddle rotation during the stroke from gyroscope data.

**How to use it:**
- Moderate rotation is normal for proper technique
- Excessive rotation indicates over-twisting
- Very low rotation may indicate incomplete stroke

### Stroke Phase Detection
**What it tracks:** Real-time identification of which phase your stroke is in:

1. **Idle** (Grey) - No active stroke
2. **Catch** (Blue) - Paddle entering water
3. **Pull** (Green) - Power phase, main acceleration
4. **Exit** (Orange) - Paddle leaving water
5. **Recovery** (Purple) - Return to catch position

**Timing metrics:**
- **Catch timing:** Time from idle to catch
- **Recovery phase:** Time from exit to next catch
- Monitor for consistency across strokes

## 🌡️ Temperature Monitoring

### Temperature & Humidity Sensing
The HTS221 sensor provides real-time environmental monitoring.

**Features:**
- Live temperature in Celsius
- Humidity percentage
- Color-coded display (blue=cool, green=comfortable, orange=warm, red=hot)

### Water vs Air Detection
The system automatically detects when your paddle is in water vs air based on:
- Temperature stability (water temperature is more stable)
- Humidity levels (>80% indicates water immersion)

**Visual indicators:**
- 💧 Water drop icon when in water
- 🌬️ Air icon when out of water

### Heat Safety Warnings
**Automatic alerts when temperature exceeds 35°C (95°F):**
- Red warning banner appears
- Reminder to stay hydrated
- Monitor for heat exhaustion symptoms

**Safety tips:**
- Take breaks in shade when warning appears
- Drink water every 15-20 minutes
- Watch for dizziness, nausea, or excessive fatigue

## 🤖 AI Stroke Quality Analysis

The ML Classification system provides real-time technique feedback using heuristic analysis (can be upgraded to TensorFlow Lite models).

### Overall Quality Score
Composite score (0-100%) combining all quality metrics:
- **>80%** = Excellent technique
- **60-80%** = Good technique
- **40-60%** = Fair, room for improvement
- **<40%** = Needs work

### Clean Stroke vs Messy Stroke
**What it detects:** Stroke smoothness and consistency

**Indicators:**
- Clean: High smoothness score, consistent acceleration pattern
- Messy: Jerky motion, irregular power application

**How to improve:** Focus on fluid motion, avoid sudden changes in speed

### Over-Rotation Detection
**What it detects:** Excessive paddle twisting during stroke

**Indicators:**
- High gyroscope Y-axis values
- Rotation torque exceeds optimal range

**How to improve:** 
- Keep paddle blade perpendicular to water
- Engage core, not just arms
- Focus on pulling straight back

### Paddle Angle Mistakes
**What it detects:** Entry/exit angles outside optimal range (30-60°)

**Common mistakes:**
- Too vertical = incomplete power phase
- Too horizontal = weak catch, slipping

**How to improve:**
- Practice proper catch position
- Ensure full blade immersion
- Exit cleanly before blade surfaces

### Early Exit Detection
**What it detects:** Pulling paddle out before completing full stroke

**Indicators:**
- Shorter than expected stroke length
- Exit angle too shallow
- Reduced power in latter half of stroke

**How to improve:**
- Pull through to hip level
- Maintain power through entire stroke
- Don't anticipate the exit

### Lawnmower Stroke Detection
**What it detects:** Wide arc instead of straight pull

**Indicators:**
- Excessive lateral gyroscope motion
- Curved trajectory instead of linear

**How to improve:**
- Focus on pulling straight back
- Keep elbows in
- Engage lats, not just shoulders

### Leg Drive Detection
**What it detects:** Initial power spike from leg engagement

**Indicators:**
- Strong initial acceleration at catch
- Proper power transfer from legs to paddle

**Note:** This requires proper sensor mounting and may vary based on position

## 📈 3D Trajectory Visualization

### What it Shows
Real-time 2D projections of your paddle's 3D motion path:
- **XY Plane (Top View):** Left-right and forward-backward motion
- **XZ Plane (Side View):** Forward-backward and up-down motion

### Color Coding
- **Blue → Red gradient:** Shows progression from start to end of trajectory
- **Grey reference lines:** Center point indicators

### How to Use
- Observe pattern consistency across strokes
- Straight lines in side view = efficient stroke
- Minimal lateral motion = good technique
- Repeated patterns = consistent form

### Trajectory Points
- System tracks last 100 trajectory points
- Updates in real-time at 50Hz
- Automatically clears when resetting statistics

## 🔄 Auto Session Detection

### How It Works
The system automatically:
1. **Starts session** when paddling is detected (acceleration > threshold)
2. **Tracks session time** from first stroke
3. **Ends session** after 5 minutes of inactivity
4. **Reports session stats** (duration, total strokes)

### Benefits
- No manual start/stop needed
- Accurate session duration tracking
- Automatic separation of practice sets

### Session Indicators
- Serial monitor shows ">>> SESSION STARTED <<<" 
- Session stroke count tracks separately from total
- End summary includes duration and stroke count

## 💡 Tips for Best Results

### Sensor Mounting
- Mount securely on paddle shaft near blade
- Ensure consistent orientation (same direction each session)
- Avoid loose mounting that causes vibration
- Protect from water ingress with waterproof case

### Calibration
- Paddle a few warm-up strokes before recording
- System auto-calibrates to your motion patterns
- Reset statistics when starting new training set

### Data Interpretation
- Look for trends over time, not absolute values
- Compare session to session for improvement tracking
- Focus on one metric at a time for technique work
- Use fatigue score to plan training intensity

### Optimal Use Cases
- **Solo training:** Focus on technique refinement
- **Team practice:** Monitor consistency across sessions
- **Race preparation:** Track peak performance metrics
- **Rehabilitation:** Monitor gradual return to form

## 🔧 Troubleshooting

### Temperature Shows Zero
- HTS221 sensor may not be initialized
- Check serial monitor for sensor initialization messages
- Firmware will continue with other features

### ML Scores Seem Off
- Ensure proper paddle mounting orientation
- Current scores are heuristic-based, not true ML
- Calibrate by comparing with video analysis

### Trajectory Looks Erratic
- Check sensor mounting (loose = noise)
- Verify no magnetic interference (phones, metal)
- Trajectory is approximate, not GPS-accurate

### Session Won't Auto-Start
- Ensure strokes exceed threshold (>15 m/s²)
- Check if previous session is still active
- Manual reset may be needed

## 📚 Future Enhancements

### Planned ML Features
- Train TensorFlow Lite models on labeled stroke data
- Deploy models to Arduino for true on-device ML
- Add more classification categories
- Improve accuracy with real training data

### Enhanced Visualization
- Full 3D trajectory with flutter_cube
- Stroke comparison overlays
- Historical trend charts
- Team synchronization display

### Advanced Analysis
- Power curve visualization
- Optimal stroke cadence detection
- Biomechanical efficiency scoring
- Injury prevention alerts

---

For questions or feedback, please open an issue on GitHub or consult the main README.md.
