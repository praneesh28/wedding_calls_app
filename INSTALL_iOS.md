# How to Install iOS App on iPhone

## Method 1: Using Xcode (Mac Required)

1. **Download the build artifact from GitHub Actions:**
   - Go to: https://github.com/praneesh28/wedding_calls_app/actions
   - Click on the latest successful "Build iOS App" workflow run
   - Scroll down to "Artifacts" section
   - Download `ios-build` zip file
   - Extract it to find `Runner.app`

2. **Connect iPhone to Mac:**
   - Use USB cable
   - Unlock iPhone and trust the computer

3. **Install via Xcode:**
   - Open Xcode
   - Go to: **Window** → **Devices and Simulators**
   - Select your iPhone from the left sidebar
   - Drag and drop `Runner.app` into the "Installed Apps" section
   - Wait for installation

4. **Trust the developer on iPhone:**
   - On iPhone: **Settings** → **General** → **VPN & Device Management**
   - Tap on your Apple ID/Developer
   - Tap **Trust**

## Method 2: Using AltStore (Windows/No Mac)

1. **Install AltStore:**
   - Download AltServer: https://altstore.io
   - Install on Windows PC
   - Install AltStore app on iPhone (via AltServer)

2. **Convert .app to .ipa:**
   - Create a folder named `Payload`
   - Put `Runner.app` inside `Payload` folder
   - Zip the `Payload` folder
   - Rename `.zip` to `.ipa`

3. **Install via AltStore:**
   - Open AltStore on iPhone
   - Tap the **+** button
   - Select the `.ipa` file
   - Wait for installation

**Note:** Free Apple ID apps expire after 7 days. Re-sign via AltStore.

## Method 3: Using Sideloadly (Windows/No Mac)

1. **Download Sideloadly:**
   - Go to: https://sideloadly.io
   - Download and install

2. **Connect iPhone:**
   - Connect iPhone to PC via USB
   - Trust the computer on iPhone

3. **Install:**
   - Open Sideloadly
   - Select your iPhone
   - Drag and drop `.ipa` file
   - Enter your Apple ID
   - Click **Start**

**Note:** Free Apple ID apps expire after 7 days.

## Method 4: Build Locally (If you have a Mac)

If you have a Mac, you can build and install directly:

```bash
# Connect iPhone via USB
# Then run:
flutter build ios --release
flutter install
```

## Troubleshooting

- **"Untrusted Developer" error:** Go to Settings → General → VPN & Device Management → Trust your Apple ID
- **App expires:** Re-sign using AltStore or Sideloadly
- **Build not found:** Make sure the GitHub Actions workflow completed successfully

## Current Status

Your iOS app is being built automatically via GitHub Actions. Check the Actions tab for the latest build.

