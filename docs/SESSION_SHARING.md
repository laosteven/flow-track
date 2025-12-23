# Session Sharing Feature

## Overview

The Flow Track app now includes a powerful session sharing feature that allows paddlers to share their recorded sessions with coaches or teammates via deep links. This makes it easy to get feedback and analyze performance together.

## How It Works

### For Paddlers (Sharing Sessions)

1. **Record a Session**: Complete a training session as usual
2. **Open Session Review**: Navigate to the session you want to share
3. **Share the Session**: 
   - Tap the three-dot menu (⋮) in the top right
   - Select "Share Session"
   - The app will prepare the session data
   - Choose your preferred sharing method (WhatsApp, Email, SMS, etc.)

### For Coaches (Receiving Sessions)

1. **Receive the Link**: Get the session link via social media, email, or messaging app
2. **Open the Link**: 
   - Click the deep link (starts with `flowtrack://`)
   - Or open the attached JSON file
3. **Automatic Import**: 
   - The app will open automatically (if installed)
   - Session data is imported instantly
   - A success dialog appears with "View Session" option
4. **View & Analyze**: Review the complete session with all metrics and graphs

## Technical Details

### Deep Link Format

Sessions are shared using a custom URL scheme:
```
flowtrack://session?data=<base64_compressed_json>
```

The session data is:
- Serialized to JSON
- Compressed using gzip
- Encoded with base64url
- Embedded in the deep link

### What Gets Shared

A shared session includes:
- Session name and paddler name
- All sensor data (accelerometer readings)
- Detected strokes with timestamps
- Time-series metrics (SPM, consistency, power, distance, speed, split/500m)
- Session metadata (start time, duration)

### Data Size Optimization

- Raw JSON is compressed using gzip (typically 80-90% reduction)
- Base64 encoding adds ~33% overhead
- Final deep link size: depends on session length
  - Short session (5 min): ~50-100 KB
  - Medium session (15 min): ~150-300 KB
  - Long session (30+ min): ~400KB-1MB+

**Note**: Very long sessions may exceed platform limits for deep links. In such cases, use the JSON file attachment instead.

## Supported Platforms

### Android
- Deep link scheme: `flowtrack://`
- App Links domain: `flowtrack.app` (for future web integration)
- Requires Android 6.0+ for App Links verification

### iOS
- URL scheme: `flowtrack://`
- Universal Links support ready
- Works on iOS 9.0+

## Platform-Specific Configuration

### Android Configuration
Located in [`android/app/src/main/AndroidManifest.xml`](../dragon_paddle_app/android/app/src/main/AndroidManifest.xml):

```xml
<intent-filter android:autoVerify="true">
    <action android:name="android.intent.action.VIEW"/>
    <category android:name="android.intent.category.DEFAULT"/>
    <category android:name="android.intent.category.BROWSABLE"/>
    <data android:scheme="flowtrack" android:host="session"/>
</intent-filter>
```

### iOS Configuration
Located in [`ios/Runner/Info.plist`](../dragon_paddle_app/ios/Runner/Info.plist):

```xml
<key>CFBundleURLTypes</key>
<array>
    <dict>
        <key>CFBundleTypeRole</key>
        <string>Editor</string>
        <key>CFBundleURLName</key>
        <string>com.flowtrack.app</string>
        <key>CFBundleURLSchemes</key>
        <array>
            <string>flowtrack</string>
        </array>
    </dict>
</array>
```

## Code Architecture

### Key Components

1. **SessionShareService** ([`lib/services/session_share_service.dart`](../dragon_paddle_app/lib/services/session_share_service.dart))
   - Exports session data to deep links
   - Imports session data from deep links
   - Handles compression/decompression
   - Manages file sharing

2. **Main App** ([`lib/main.dart`](../dragon_paddle_app/lib/main.dart))
   - Listens for incoming deep links
   - Handles deep link routing
   - Shows import success/error dialogs
   - Navigates to imported session

3. **Session Review Screen** ([`lib/screens/session_review_screen.dart`](../dragon_paddle_app/lib/screens/session_review_screen.dart))
   - Adds "Share Session" menu item
   - Triggers session export and sharing

### Data Flow

```
┌─────────────┐
│   Paddler   │
│   Records   │
└──────┬──────┘
       │
       ▼
┌─────────────────────────┐
│  Session Review Screen  │
│  "Share Session" button │
└──────────┬──────────────┘
           │
           ▼
┌──────────────────────────┐
│  SessionShareService     │
│  • Compress JSON         │
│  • Create deep link      │
│  • Save JSON file        │
└──────────┬───────────────┘
           │
           ▼
┌──────────────────────────┐
│   Platform Share Sheet   │
│  (WhatsApp, Email, etc.) │
└──────────┬───────────────┘
           │
           ▼
       ┌────────┐
       │ Coach  │
       │ Clicks │
       │  Link  │
       └───┬────┘
           │
           ▼
┌──────────────────────────┐
│     App Opens (OS)       │
│  Deep link intercepted   │
└──────────┬───────────────┘
           │
           ▼
┌──────────────────────────┐
│    main.dart Handler     │
│  • Parse deep link       │
│  • Import session        │
│  • Show dialog           │
└──────────┬───────────────┘
           │
           ▼
┌──────────────────────────┐
│  Session Review Screen   │
│  Display imported data   │
└──────────────────────────┘
```

## Testing

### Manual Testing Steps

1. **Test Export**
   ```
   1. Record a test session (can be short)
   2. Go to Session List
   3. Open the session
   4. Tap menu → "Share Session"
   5. Verify loading dialog appears
   6. Verify share sheet opens
   ```

2. **Test Deep Link Import**
   ```
   1. Share session to yourself (e.g., via email)
   2. Close the app completely
   3. Click the deep link in the shared message
   4. Verify app opens automatically
   5. Verify success dialog appears
   6. Tap "View Session"
   7. Verify all data displays correctly
   ```

3. **Test File Import**
   ```
   1. Save the JSON attachment from shared message
   2. Open the JSON file
   3. Verify app can open it (platform-dependent)
   ```

### Test on Different Platforms

- [ ] Android (custom scheme)
- [ ] iOS (URL scheme)
- [ ] Test with different messaging apps (WhatsApp, Telegram, Email, SMS)
- [ ] Test with long sessions (>10 minutes)
- [ ] Test with special characters in session names

### Edge Cases to Test

- ✓ App not installed (should prompt to install)
- ✓ App already running (should navigate to import)
- ✓ Invalid deep link format (should show error)
- ✓ Corrupted data (should show error)
- ✓ Very long sessions (may need file fallback)

## Troubleshooting

### Deep Link Not Opening App

**Android:**
- Check if app is set as default handler for `flowtrack://` links
- Go to Settings → Apps → Flow Track → Set as default → Supported web addresses
- Verify intent filters in AndroidManifest.xml

**iOS:**
- Check if URL scheme is registered in Info.plist
- Try restarting the device
- Reinstall the app to register URL scheme

### Import Fails

- Verify the session data is not corrupted
- Check app logs for error messages
- Try using the JSON file attachment instead
- Ensure both devices have compatible app versions

### Session Data Too Large

For very long sessions:
- Use the JSON file attachment method
- Consider splitting long sessions
- Future enhancement: cloud storage with reference links

## Future Enhancements

- [ ] Cloud storage integration (Firebase, AWS S3)
- [ ] Web-based session viewer (no app required)
- [ ] QR code generation for easy sharing
- [ ] Session comments/annotations from coach
- [ ] Video synchronization with session data
- [ ] Privacy controls (password-protected sessions)
- [ ] Session comparison tools
- [ ] Team/group session management

## Privacy & Security

- **Local First**: All data stays on device until explicitly shared
- **No Cloud Dependency**: Works offline, direct peer-to-peer sharing
- **User Control**: Paddler chooses what to share and with whom
- **Data Compression**: Reduces network usage and storage
- **No Analytics**: No tracking of shared sessions

## Support

For issues or questions about session sharing:
1. Check this documentation
2. Review app logs for error messages
3. Verify platform configurations
4. Test with a fresh session recording
5. Contact the development team with:
   - Platform (Android/iOS)
   - App version
   - Steps to reproduce issue
   - Error messages or screenshots

---

**Version**: 1.4.0+7  
**Feature Added**: December 2025  
**Dependencies**: app_links ^6.3.2, share_plus ^10.1.3
