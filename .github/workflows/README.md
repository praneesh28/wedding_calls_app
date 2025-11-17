# GitHub Actions Workflows

This repository includes automated build workflows for iOS and Android apps.

## Quick Start

1. **Push your code to GitHub** (if not already done)
2. **Go to the Actions tab** in your GitHub repository
3. **Select a workflow** (Build iOS App or Build Android App)
4. **Click "Run workflow"** to manually trigger a build
5. **Download artifacts** after the build completes

## iOS Build Workflow

Builds your iOS app using GitHub Actions on macOS runners.

### Basic Build (No Code Signing) - Works Out of the Box ✅

The workflow will automatically:
- Build your iOS app without code signing
- Upload the `.app` bundle as a downloadable artifact
- Works immediately without any setup!

**To use:**
1. Push code to GitHub
2. Go to Actions → "Build iOS App"
3. Click "Run workflow"
4. Download the `ios-build` artifact when complete

### With Code Signing (For App Store Distribution)

To enable code signing and generate an IPA file:

1. **Export your Apple Developer Certificate:**
   ```bash
   # On a Mac, export from Keychain Access
   # Then convert to base64:
   base64 -i certificate.p12 -o certificate_base64.txt
   ```

2. **Get your Provisioning Profile:**
   - Download from [Apple Developer Portal](https://developer.apple.com)
   - Convert to base64:
   ```bash
   base64 -i profile.mobileprovision -o profile_base64.txt
   ```

3. **Add GitHub Secrets:**
   Go to: Repository → Settings → Secrets and variables → Actions
   
   Add these secrets:
   - `APPLE_CERTIFICATE_BASE64`: Content of certificate_base64.txt
   - `APPLE_CERTIFICATE_PASSWORD`: Your certificate password
   - `APPLE_PROVISIONING_PROFILE_BASE64`: Content of profile_base64.txt
   - `CODE_SIGN_IDENTITY`: e.g., "Apple Development: Your Name"
   - `TEAM_ID`: Your Apple Developer Team ID (found in Apple Developer Portal)

4. **Update `ios/ExportOptions.plist`:**
   - Replace `YOUR_TEAM_ID` with your Team ID
   - Replace `YOUR_PROVISIONING_PROFILE_NAME` with your profile name

## Android Build Workflow

Builds both APK and App Bundle files automatically.

**Features:**
- ✅ Builds APK (for direct installation)
- ✅ Builds App Bundle (for Google Play Store)
- ✅ No additional setup required
- ✅ Works on every push to main/master

**Artifacts:**
- `android-apk`: `app-release.apk` file
- `android-bundle`: `app-release.aab` file

## Manual Trigger

Both workflows can be manually triggered:
1. Go to **Actions** tab in your GitHub repository
2. Select the workflow (Build iOS App or Build Android App)
3. Click **"Run workflow"** button
4. Select branch and click **"Run workflow"**

## Build Artifacts

After a workflow completes:
1. Go to the **Actions** tab
2. Click on the completed workflow run
3. Scroll down to **"Artifacts"** section
4. Download the artifacts you need

**Retention:** Artifacts are kept for 30 days

## Workflow Triggers

Workflows automatically run on:
- ✅ Push to `main` or `master` branch
- ✅ Pull requests to `main` or `master` branch
- ✅ Manual trigger via "Run workflow" button

## Notes

- **iOS workflow** runs on `macos-latest` (includes Xcode)
- **Android workflow** runs on `ubuntu-latest`
- Flutter version: `3.35.6` (update in workflow files if needed)
- Builds are free on GitHub Actions (with usage limits)

