# Building iOS .ipa File

## Prerequisites

Building an `.ipa` file requires:
- **macOS** (cannot be built on Windows)
- **Xcode** installed (latest version recommended)
- **Apple Developer Account** (for distribution builds)
- **Flutter SDK** installed on macOS

## Option 1: Build on macOS (Local)

### Steps:

1. **Open Terminal on your Mac**

2. **Navigate to your project directory:**
   ```bash
   cd /path/to/wedding_calls_app
   ```

3. **Get Flutter dependencies:**
   ```bash
   flutter pub get
   ```

4. **Install iOS CocoaPods dependencies:**
   ```bash
   cd ios
   pod install
   cd ..
   ```

5. **Configure code signing:**
   - Open `ios/Runner.xcworkspace` in Xcode
   - Select the Runner project in the navigator
   - Go to "Signing & Capabilities" tab
   - Select your development team
   - Ensure the bundle identifier matches: `com.example.weddingCallsApp` (or update it to your own)

6. **Update ExportOptions.plist** (if needed):
   - Edit `ios/ExportOptions.plist`
   - Replace `YOUR_TEAM_ID` with your Apple Developer Team ID
   - Update the bundle identifier if you changed it
   - Choose the appropriate method:
     - `development` - for development/testing
     - `ad-hoc` - for ad-hoc distribution
     - `app-store` - for App Store submission
     - `enterprise` - for enterprise distribution

7. **Build the .ipa file:**
   ```bash
   flutter build ipa
   ```

   Or with specific export options:
   ```bash
   flutter build ipa --export-options-plist=ios/ExportOptions.plist
   ```

8. **Find your .ipa file:**
   The .ipa file will be located at:
   ```
   build/ios/ipa/wedding_calls_app.ipa
   ```

## Option 2: Build using GitHub Actions (CI/CD)

If you don't have access to a Mac, you can use GitHub Actions to build your .ipa file automatically.

### Setup:

1. **Push your code to GitHub**

2. **Add the GitHub Actions workflow** (see `.github/workflows/build-ios.yml`)

3. **Add secrets to your GitHub repository:**
   - Go to Settings → Secrets and variables → Actions
   - Add the following secrets:
     - `APPLE_ID`: Your Apple ID email
     - `APPLE_ID_PASSWORD`: App-specific password (generate at appleid.apple.com)
     - `APPLE_TEAM_ID`: Your Apple Developer Team ID
     - `CERTIFICATE_BASE64`: Base64 encoded .p12 certificate
     - `CERTIFICATE_PASSWORD`: Password for the certificate
     - `PROVISIONING_PROFILE_BASE64`: Base64 encoded provisioning profile

4. **Trigger the workflow:**
   - Push to main branch, or
   - Manually trigger from Actions tab

5. **Download the .ipa:**
   - Go to Actions tab
   - Find the completed workflow run
   - Download the .ipa artifact

## Option 3: Use Cloud Mac Services

You can also use cloud-based Mac services like:
- **MacStadium**
- **AWS EC2 Mac instances**
- **MacinCloud**
- **Codemagic** (Flutter-specific CI/CD)
- **AppCircle** (Mobile CI/CD)

## Important Notes

- **Bundle Identifier**: Currently set to `com.example.weddingCallsApp`. You should change this to your own unique identifier before publishing.
- **Code Signing**: You must have valid certificates and provisioning profiles for distribution.
- **Export Options**: The `ExportOptions.plist` file needs to be configured with your Team ID and provisioning profile information.

## Troubleshooting

### Common Issues:

1. **"No valid code signing certificates found"**
   - Solution: Install certificates in Keychain Access or configure in Xcode

2. **"Provisioning profile not found"**
   - Solution: Download and install provisioning profiles from Apple Developer Portal

3. **"Bundle identifier mismatch"**
   - Solution: Ensure bundle identifier in Xcode matches your provisioning profile

4. **"Flutter build ipa command not found"**
   - Solution: Make sure you're running Flutter 2.0+ and on macOS

## Distribution Methods

Once you have the .ipa file:

1. **TestFlight** (for beta testing)
   - Upload via Xcode or App Store Connect
   - Distribute to testers

2. **App Store** (for public release)
   - Upload via App Store Connect
   - Submit for review

3. **Ad-Hoc Distribution**
   - Install directly on registered devices
   - Limited to 100 devices per year

4. **Enterprise Distribution**
   - For internal company distribution
   - Requires Enterprise Developer account

