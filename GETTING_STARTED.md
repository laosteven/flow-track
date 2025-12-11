# Getting Started with Dragon Paddle Tracker

This guide will walk you through setting up your Dragon Paddle Tracker from scratch.

## What You'll Need

### Hardware
- [ ] Arduino Nano 33 BLE Sense Rev2
- [ ] USB-C cable for programming
- [ ] Velcro straps (2-3 pieces, 25mm wide)
- [ ] Optional: 3.7V LiPo battery (500-1000mAh)
- [ ] Optional: Waterproof case or heat-shrink tubing

### Software
- [ ] Computer with Arduino IDE installed
- [ ] Smartphone (iOS 12+ or Android 5.0+)
- [ ] Flutter SDK (if building app from source)

## Step 1: Flash Arduino Firmware (15 minutes)

### Install Arduino IDE

1. Download from https://www.arduino.cc/en/software
2. Install for your operating system
3. Launch Arduino IDE

### Install Required Libraries

1. Open Arduino IDE
2. Go to **Tools → Board → Boards Manager**
3. Search for "Arduino Mbed OS Nano Boards"
4. Install the package (may take a few minutes)
5. Go to **Tools → Manage Libraries**
6. Search and install:
   - "ArduinoBLE"
   - "Arduino_BMI270_BMM150"

### Upload Firmware

1. Connect Arduino to computer via USB-C
2. In Arduino IDE:
   - **Tools → Board** → Select "Arduino Nano 33 BLE"
   - **Tools → Port** → Select the port with your Arduino
3. Open `firmware/nano33ble_rev2/imu_tracker.ino`
4. Click **Upload** button (→)
5. Wait for "Done uploading" message
6. Open **Tools → Serial Monitor** (set to 115200 baud)
7. You should see:
   ```
   Dragon Paddle Tracker - Initializing...
   ✓ IMU initialized successfully
   ✓ BLE initialized successfully
   Ready! Waiting for connections...
   ```

### Troubleshooting Upload Issues

**If port doesn't appear:**
- Try a different USB cable (some are power-only)
- Press the reset button on Arduino twice quickly
- Check device manager (Windows) or `ls /dev/tty*` (Mac/Linux)

**If upload fails:**
- Make sure correct board is selected
- Try uploading a simple sketch first (File → Examples → Basics → Blink)
- Update board package to latest version

## Step 2: Mount Arduino to Paddle (10 minutes)

### Basic Mount (Indoor Use)

1. **Position Arduino:**
   - Place ~30cm below hand grip on paddle shaft
   - Orient with USB port facing up
   - Y-axis (length) should align with paddle direction

2. **Secure with Velcro:**
   - Wrap first strap around shaft below Arduino
   - Wrap second strap around shaft above Arduino
   - Ensure snug fit - Arduino shouldn't rotate or slide

3. **Test Fit:**
   - Grip paddle normally - Arduino shouldn't interfere
   - Shake paddle - Arduino should stay firmly in place
   - If loose, add more velcro or tighten existing straps

### With Battery (Outdoor Use)

1. **Connect Battery:**
   - Battery + to Arduino VIN (or 3.3V for 3.7V battery)
   - Battery - to Arduino GND
   - Optional: Add power switch inline

2. **Mount Battery:**
   - Place on opposite side of shaft for balance
   - Secure with velcro or cable ties
   - Keep connections away from water

3. **Waterproof (if needed):**
   - Apply conformal coating to Arduino PCB (available at electronics stores)
   - Wrap in heat-shrink tubing or place in waterproof box
   - Ensure LED is still visible

## Step 3: Install Mobile App (10 minutes)

### Option A: Build from Source (Developers)

1. **Install Flutter:**
   ```bash
   # Follow instructions at https://flutter.dev/docs/get-started/install
   ```

2. **Build App:**
   ```bash
   cd dragon_paddle_app
   flutter pub get
   flutter run
   # Or for release:
   flutter build apk     # Android
   flutter build ios     # iOS
   ```

### Option B: Pre-built App (Coming Soon)

Pre-built APK/IPA files will be available in GitHub Releases.

### Grant Permissions

**Android:**
- When prompted, allow Bluetooth and Location permissions
- Both are required for BLE scanning

**iOS:**
- When prompted, allow Bluetooth access
- Open Settings if you missed the prompt

## Step 4: Connect and Test (5 minutes)

### First Connection

1. **Power On Arduino:**
   - Via USB or battery
   - LED should blink 3 times → Ready state

2. **Open App:**
   - Launch Dragon Paddle Tracker
   - Tap Bluetooth icon (top-right)

3. **Scan for Device:**
   - Tap "Scan for Devices"
   - "DragonPaddleIMU" should appear within 5 seconds
   - If not, see troubleshooting below

4. **Connect:**
   - Tap "Connect" next to device name
   - Status changes to "Connected" with green indicator
   - Data should start streaming immediately

### Verify Data Stream

You should see:
- ✓ Green "Connected" banner
- ✓ Stroke rate at 0 (not moving yet)
- ✓ Consistency at 100%
- ✓ Motion graph showing flat lines

### Do a Test Stroke

1. Hold paddle and make a paddling motion
2. Watch for:
   - Stroke rate to update
   - Total strokes to increment
   - Motion graph to show movement
   - Consistency to adjust

**Success!** Your tracker is working.

## Step 5: First Practice Session

### Pre-Practice Checklist

- [ ] Arduino battery charged (if using battery)
- [ ] Mount is secure and tight
- [ ] Phone is charged
- [ ] App connects successfully
- [ ] Data is streaming

### During Practice

1. **Start Session:**
   - Connect to Arduino
   - Tap refresh icon to reset stats
   - Begin paddling

2. **Glance at Metrics:**
   - Big stroke rate number for pacing
   - Consistency bar for technique feedback
   - Don't stare at phone - focus on paddling!

3. **Between Sets:**
   - Check detailed metrics
   - Note what worked well
   - Reset stats for next set

4. **End Session:**
   - Note final stats in training log
   - Tap Bluetooth icon to disconnect
   - Power off Arduino to save battery

### Post-Practice

- Wipe down Arduino/case (if wet)
- Charge battery for next session
- Review metrics and plan next practice

## Common Issues & Solutions

### Arduino LED Patterns

| Pattern | Meaning | Solution |
|---------|---------|----------|
| 3 blinks → solid off | Ready, waiting | Normal - ready to connect |
| Fast blink | IMU error | Re-upload firmware, check hardware |
| Slow blink | BLE error | Re-upload firmware |
| No light | No power | Check battery/USB connection |
| Solid on | Connected | Normal - device is connected |

### Connection Problems

**Device not found:**
- Check Arduino is powered on
- Verify Bluetooth is enabled on phone
- Try airplane mode on/off
- Move phone closer to Arduino
- Restart app

**Connection fails:**
- Arduino might be paired to another phone
- Power cycle Arduino
- Restart phone Bluetooth
- Try from different location (less interference)

**Frequent disconnections:**
- Check battery level
- Reduce distance to phone
- Close other Bluetooth apps
- Ensure mount isn't loose (vibrations can disconnect)

### Data Issues

**No stroke detection:**
- Check mount is tight
- Verify orientation (Y-axis along shaft)
- Try larger paddling motions
- See troubleshooting in docs/README.md

**Erratic readings:**
- Tighten mount - play in mount causes false readings
- Check Arduino isn't damaged
- Verify IMU is working (check Serial Monitor)

**Low stroke rate shown:**
- You might actually be paddling slower than expected (normal!)
- System needs ~10 strokes to calculate accurate rate
- Check total strokes is incrementing

## Next Steps

### Learn More
- Read full documentation: `/docs/README.md`
- Hardware details: `/hardware/README.md`
- App customization: `/dragon_paddle_app/README.md`

### Improve Your Technique
- Track consistency trends over time
- Experiment with different stroke rates
- Compare metrics with teammates
- Set goals for each session

### Join the Community
- Share your experience on GitHub
- Report bugs or request features
- Contribute improvements
- Help other paddlers get started

## Tips for Success

1. **Start Simple:** Use indoor with USB power first
2. **Test Everything:** Verify before getting on water
3. **Track Progress:** Keep a training log with your metrics
4. **Stay Consistent:** Use the tracker every practice for best insights
5. **Focus on Feel:** Use data to confirm, not replace, body awareness

## Need Help?

- **Quick questions:** Check `/docs/README.md` troubleshooting section
- **Hardware issues:** See `/hardware/README.md`
- **App problems:** Check `/dragon_paddle_app/README.md`
- **Still stuck:** Open an issue on GitHub with details

---

**You're all set!** Get out there and track those strokes! 🐉🚣‍♂️
