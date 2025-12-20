# Hardware Setup Guide

## Components List

### Required Components

1. **Arduino Nano 33 BLE Sense Rev2**
   - Built-in BMI270 accelerometer + BMM150 magnetometer
   - Bluetooth Low Energy 5.0
   - USB-C for programming and charging

2. **Battery (Optional for Portable Use)**
   - 3.7V LiPo battery (500-1000mAh recommended)
   - JST connector or direct solder to VIN pin
   - Consider adding a power switch

3. **Mounting Hardware**
   - Velcro straps (25mm wide, 20-30cm long)
   - Anti-slip rubber pad or heat-shrink tubing
   - Cable ties for securing wires
   - Waterproof case or heat-shrink for protection

### Optional Components

1. **OLED Display (128x64)**
   - For instant on-paddle feedback
   - I2C connection to Arduino
   - Not implemented in current firmware

2. **Power Management**
   - LiPo battery charger module (TP4056)
   - Voltage regulator if using battery >5V
   - Battery level indicator LED

## Mounting Instructions

### Basic Velcro Mount

1. **Position Arduino**
   - Mount on upper shaft, about 30cm below hand grip
   - Orient with USB port facing up for easy access
   - Ensure accelerometer Y-axis aligns with paddle direction

2. **Secure with Velcro**
   - Wrap self-adhesive velcro around paddle shaft
   - Use at least 2 velcro straps (one above, one below Arduino)
   - Ensure tight fit to prevent rotation during paddling

3. **Add Anti-Slip Layer**
   - Place rubber pad between Arduino and paddle
   - Helps dampen vibrations and prevent sliding
   - Can use bicycle inner tube or rubber sheet

4. **Protect Electronics**
   - Wrap in heat-shrink tubing for water resistance
   - Or use small waterproof project box
   - Ensure LED is visible for status indication

### With Battery

1. **Battery Placement**
   - Mount battery on opposite side of shaft for balance
   - Use velcro or cable ties to secure
   - Keep connections away from water entry points

2. **Wiring**
   - Connect battery + to VIN or 3.3V pin
   - Connect battery - to GND
   - Route wires along paddle shaft
   - Secure with cable ties every 10cm

3. **Power Switch** (Recommended)
   - Install inline switch between battery and Arduino
   - Mount switch near top of shaft for easy access
   - Use waterproof toggle switch if possible

### Waterproofing Tips

1. **For Indoor Use Only**
   - Basic velcro mount is sufficient
   - No special waterproofing needed
   - Keep away from water splashes

2. **For Outdoor Use**
   - Apply conformal coating to Arduino PCB
   - Use waterproof case or heavy heat-shrink
   - Seal all openings with silicone
   - Test in water before use
   - Add desiccant pack inside case

## Paddle Orientation

For optimal measurements, mount Arduino with:
- **X-axis:** Perpendicular to paddle blade (side-to-side)
- **Y-axis:** Along paddle shaft (forward-backward)
- **Z-axis:** Through paddle thickness (up-down)

Visual indicator:
```
         [Hand Grip]
              |
              |
         [Arduino]  <- 30cm below grip
         Y-axis →
              |
              |
        [Paddle Blade]
```

## 3D Printable Mounts

Custom 3D printed mounts are now available for secure Arduino attachment. All designs are created in **Fusion 360** and optimized for printing.

### Design Specifications
- **CAD Software:** Fusion 360
- **Units:** Millimeters (mm)
- **Printer Used:** Bambulab P1S
- **Material:** PLA
- **Layer Height:** 0.2mm recommended
- **Infill:** 20% minimum for structural parts

### Available Designs

#### 1. **Enclosure**
Located in `enclosure/` folder:
- **Source files:** Fusion 360 design files in `source/`
- **STL files:** Print-ready files in `stl/`
- Protective case for the Arduino Nano 33 BLE
- Designed to mount securely on paddle shaft
- Includes mounting points and cable routing

#### 2. **Holder**
Located in `holder/` folder:
- **Source files:** Fusion 360 design files in `source/`
- **STL files:** Print-ready files in `stl/`
- Mounting bracket for paddle attachment
- Adjustable design for different shaft diameters
- Quick-release mechanism for easy installation

### Printing Instructions

1. **Prepare Files**
   - Download STL files from respective folders
   - Import into your slicer software

2. **Recommended Settings**
   - Material: PLA
   - Nozzle Temperature: 210°C
   - Bed Temperature: 60°C
   - Print Speed: 50-60mm/s
   - Supports: May be needed depending on design

3. **Post-Processing**
   - Remove supports carefully
   - Clean up any stringing
   - Test fit on paddle shaft before final assembly
   - Sand contact surfaces if needed for better fit

### Customization

The Fusion 360 source files are provided in the `source/` folders if you need to:
- Adjust dimensions for your specific paddle
- Modify mounting mechanism
- Add custom features
- Adapt for different Arduino models

Feel free to modify and share your improvements!

## Assembly Tips

1. **Test Before Mounting**
   - Flash firmware and test BLE connection
   - Verify IMU readings in Serial Monitor
   - Ensure battery lasts for practice duration

2. **Calibration**
   - Let Arduino warm up for 30 seconds
   - Hold paddle still for initial calibration
   - Reset stats at start of each session

3. **Maintenance**
   - Check mount tightness before each use
   - Inspect waterproofing seals regularly
   - Charge battery after every session
   - Update firmware as new versions release

4. **Troubleshooting**
   - If LED blinks rapidly: IMU initialization failed
   - If LED blinks slowly: BLE initialization failed
   - If no LED: Check battery/power connection
   - If inconsistent readings: Tighten mount to reduce play

## Safety Considerations

- Ensure mount doesn't interfere with paddle grip
- Check that Arduino doesn't create sharp edges
- Verify battery is properly secured before water use
- Don't charge LiPo batteries unattended
- Remove electronics from paddle during storage

## Weight Considerations

- 3D printed holder: 24g
- Battery (1100mAh): 19g
- **Complete assembly** (enclosure + holder + Arduino + all components): 72g

The added weight is well-distributed along the paddle shaft and has minimal impact on paddling dynamics.

## Questions?

For mounting questions or hardware issues, please open an issue on GitHub.
