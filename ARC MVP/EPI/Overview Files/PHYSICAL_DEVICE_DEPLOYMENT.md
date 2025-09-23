# Physical Device Deployment Guide

## 📱 Deploying EPI to Physical iOS Device

This guide will help you deploy the EPI app to a physical iOS device for testing and distribution.

---

## Prerequisites

- **Apple Developer Account** (Free or Paid)
- **macOS with Xcode** installed
- **Physical iOS device** (iPhone/iPad)
- **USB cable** to connect device to Mac

---

## Step 1: Apple Developer Account Setup

### Option A: Free Apple Developer Account
1. Go to [developer.apple.com](https://developer.apple.com)
2. Sign in with your Apple ID
3. Accept the Apple Developer Agreement
4. **Note**: Free accounts have limitations (7-day app expiration, limited device testing)

### Option B: Paid Apple Developer Program ($99/year)
1. Go to [developer.apple.com/programs](https://developer.apple.com/programs)
2. Enroll in the Apple Developer Program
3. **Benefits**: No app expiration, unlimited device testing, App Store distribution

---

## Step 2: Create Unique Bundle Identifier

### Current Bundle ID
```
com.yourname.epi.arcmvp
```

### Replace "yourname" with your actual name/company
**Examples:**
- `com.johnsmith.epi.arcmvp`
- `com.acmecorp.epi.arcmvp`
- `com.yourcompany.epi.arcmvp`

### Update Bundle ID in Code
1. Open `ios/Runner.xcodeproj/project.pbxproj`
2. Find all instances of `com.yourname.epi.arcmvp`
3. Replace `yourname` with your actual identifier
4. Save the file

---

## Step 3: Register Bundle ID in Apple Developer Portal

1. **Go to Apple Developer Portal**
   - Visit [developer.apple.com/account](https://developer.apple.com/account)
   - Sign in with your Apple ID

2. **Navigate to Identifiers**
   - Click "Certificates, Identifiers & Profiles"
   - Select "Identifiers" from the sidebar
   - Click the "+" button to create new identifier

3. **Create App ID**
   - Select "App IDs" and click "Continue"
   - Choose "App" and click "Continue"
   - Fill in the details:
     - **Description**: EPI ARC MVP
     - **Bundle ID**: `com.yourname.epi.arcmvp` (use your actual identifier)
   - Click "Continue" and then "Register"

---

## Step 4: Create Development Certificate

### Automatic Certificate Creation (Recommended)
1. **Open Xcode**
2. **Connect your iOS device** via USB
3. **Open the project**: `ios/Runner.xcworkspace`
4. **Select your device** as the target
5. **Xcode will automatically**:
   - Create a development certificate
   - Register your device
   - Create a provisioning profile

### Manual Certificate Creation (Alternative)
1. **In Xcode**: Xcode → Preferences → Accounts
2. **Add your Apple ID** if not already added
3. **Select your team** and click "Manage Certificates"
4. **Click "+"** and select "iOS Development"
5. **Download and install** the certificate

---

## Step 5: Configure Xcode Project

1. **Open Xcode Project**
   ```bash
   open ios/Runner.xcworkspace
   ```

2. **Select the Runner target**
   - Click on "Runner" in the project navigator
   - Select the "Runner" target (not the project)

3. **Configure Signing & Capabilities**
   - Go to "Signing & Capabilities" tab
   - **Team**: Select your Apple Developer team
   - **Bundle Identifier**: Should match what you registered (`com.yourname.epi.arcmvp`)
   - **Provisioning Profile**: Should auto-populate

4. **Verify Settings**
   - Bundle Identifier: `com.yourname.epi.arcmvp`
   - Team: Your Apple Developer Team
   - Signing Certificate: iOS Development
   - Provisioning Profile: Should show "Xcode Managed Profile"

---

## Step 6: Build and Deploy

### Method 1: Using Xcode
1. **Select your device** as the target
2. **Click the Play button** (▶️) or press Cmd+R
3. **Wait for build** to complete
4. **App will install** on your device

### Method 2: Using Flutter CLI
```bash
# Build for device
flutter build ios --release --dart-define=GEMINI_API_KEY=your_api_key

# Install on connected device
flutter install
```

### Method 3: Using Flutter with Device Selection
```bash
# List connected devices
flutter devices

# Run on specific device
flutter run -d [device-id] --dart-define=GEMINI_API_KEY=your_api_key
```

---

## Step 7: Trust Developer Certificate (First Time)

**On your iOS device:**
1. **Go to Settings** → General → VPN & Device Management
2. **Find your Apple ID** under "Developer App"
3. **Tap on it** and select "Trust [Your Apple ID]"
4. **Confirm** by tapping "Trust"

---

## Troubleshooting

### Common Issues

#### "No profiles for 'com.yourname.epi.arcmvp' were found"
- **Solution**: Make sure bundle ID matches exactly in Xcode and Apple Developer Portal
- **Check**: Bundle identifier in Xcode project settings

#### "Failed to register bundle identifier"
- **Solution**: Bundle ID is already taken, use a different one
- **Try**: Add your initials or company name to make it unique

#### "Code signing error"
- **Solution**: Check that your Apple ID is added to Xcode
- **Go to**: Xcode → Preferences → Accounts

#### "Device not recognized"
- **Solution**: 
  - Unlock your device
  - Trust the computer when prompted
  - Check USB connection

### Debug Commands
```bash
# Check connected devices
flutter devices

# Check iOS build configuration
flutter build ios --verbose

# Clean and rebuild
flutter clean
flutter pub get
flutter build ios
```

---

## Production Deployment

### For App Store Distribution
1. **Create App Store Connect record**
2. **Generate Distribution Certificate**
3. **Create App Store Provisioning Profile**
4. **Archive and upload** through Xcode

### For Enterprise Distribution
1. **Enterprise Developer Account** required
2. **Create Enterprise Provisioning Profile**
3. **Distribute via** internal app distribution

---

## Security Notes

### API Keys
- **Never commit** API keys to version control
- **Use environment variables** or secure storage
- **Current setup**: Uses `--dart-define=GEMINI_API_KEY=your_key`

### Bundle Identifier
- **Keep it unique** to avoid conflicts
- **Use reverse domain notation**: `com.yourcompany.appname`
- **Register early** to secure your preferred identifier

---

## Next Steps

1. **Test thoroughly** on physical device
2. **Verify all features** work correctly
3. **Test MCP export/import** functionality
4. **Check performance** and memory usage
5. **Prepare for** App Store submission (if desired)

---

## Support

If you encounter issues:
1. **Check Xcode console** for detailed error messages
2. **Verify Apple Developer Portal** settings
3. **Ensure device** is properly connected and trusted
4. **Try clean build** (`flutter clean && flutter build ios`)

---

**Last Updated**: January 20, 2025
**Version**: 1.0.0
