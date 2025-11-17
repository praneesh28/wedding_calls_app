# GitHub Actions Setup for iOS IPA Build

This guide will help you set up GitHub Actions to automatically build your iOS .ipa file.

## Prerequisites

1. **GitHub Repository** - Your code should be pushed to GitHub
2. **Apple Developer Account** - You need an Apple Developer account ($99/year)
3. **Certificates and Provisioning Profiles** - Required for code signing

## Step 1: Prepare Your Certificates

You have two options for code signing:

### Option A: Automatic Signing (Easier - Recommended for beginners)

This uses your Apple ID credentials and automatically manages certificates.

**What you need:**
- Apple ID email
- App-specific password (see Step 2)
- Apple Team ID

### Option B: Manual Signing (More control)

This uses pre-generated certificates and provisioning profiles.

**What you need:**
- `.p12` certificate file
- Certificate password
- `.mobileprovision` provisioning profile file

## Step 2: Generate App-Specific Password (For Automatic Signing)

1. Go to [appleid.apple.com](https://appleid.apple.com)
2. Sign in with your Apple ID
3. Go to **Sign-In and Security** → **App-Specific Passwords**
4. Click **Generate an app-specific password**
5. Label it "GitHub Actions" or similar
6. Copy the password (you'll only see it once!)

## Step 3: Find Your Apple Team ID

1. Go to [developer.apple.com](https://developer.apple.com)
2. Sign in with your Apple ID
3. Go to **Membership** section
4. Your **Team ID** is displayed there (looks like: `ABC123DEF4`)

## Step 4: Get Your Certificates (For Manual Signing Only)

If you're using manual signing, you need to:

1. **Export your certificate as .p12:**
   - On a Mac, open **Keychain Access**
   - Find your iOS Distribution certificate
   - Right-click → **Export**
   - Save as `.p12` format
   - Set a password (remember this!)

2. **Download your provisioning profile:**
   - Go to [developer.apple.com/account/resources/profiles/list](https://developer.apple.com/account/resources/profiles/list)
   - Download your App Store or Ad Hoc provisioning profile
   - Save the `.mobileprovision` file

3. **Encode files to Base64:**
   - On Windows PowerShell:
     ```powershell
     # For certificate
     [Convert]::ToBase64String([IO.File]::ReadAllBytes("path\to\certificate.p12"))
     
     # For provisioning profile
     [Convert]::ToBase64String([IO.File]::ReadAllBytes("path\to\profile.mobileprovision"))
     ```
   - Copy the output (it's a long string)

## Step 5: Add Secrets to GitHub

1. Go to your GitHub repository
2. Click **Settings** → **Secrets and variables** → **Actions**
3. Click **New repository secret**
4. Add the following secrets:

### For Automatic Signing (Option A):

| Secret Name | Value | Description |
|------------|-------|-------------|
| `APPLE_ID` | your-email@example.com | Your Apple ID email |
| `APPLE_ID_PASSWORD` | xxxx-xxxx-xxxx-xxxx | App-specific password from Step 2 |
| `APPLE_TEAM_ID` | ABC123DEF4 | Your Team ID from Step 3 |
| `KEYCHAIN_PASSWORD` | any-random-password | Any password (used for temporary keychain) |

### For Manual Signing (Option B):

| Secret Name | Value | Description |
|------------|-------|-------------|
| `CERTIFICATE_BASE64` | (long base64 string) | Base64 encoded .p12 certificate |
| `CERTIFICATE_PASSWORD` | your-cert-password | Password for the .p12 file |
| `PROVISIONING_PROFILE_BASE64` | (long base64 string) | Base64 encoded .mobileprovision file |
| `KEYCHAIN_PASSWORD` | any-random-password | Any password (used for temporary keychain) |

## Step 6: Update Your Workflow (If Needed)

The workflow file (`.github/workflows/build-ios.yml`) is already set up. 

**If you want to use automatic signing instead**, you can use the simpler workflow in `build-ios-auto.yml`.

## Step 7: Update Bundle Identifier (Important!)

Before building, make sure your bundle identifier is correct:

1. Open `ios/Runner.xcodeproj/project.pbxproj` (or use Xcode)
2. Find `PRODUCT_BUNDLE_IDENTIFIER` (currently: `com.example.weddingCallsApp`)
3. Change it to your own bundle identifier (e.g., `com.yourcompany.weddingcallsapp`)
4. Make sure it matches your provisioning profile

Or update it in Xcode:
- Open `ios/Runner.xcworkspace` in Xcode
- Select Runner project → Target → General
- Update **Bundle Identifier**

## Step 8: Commit and Push

```bash
git add .github/workflows/build-ios.yml
git add BUILD_iOS_IPA.md
git add GITHUB_ACTIONS_SETUP.md
git commit -m "Add GitHub Actions workflow for iOS IPA build"
git push origin main
```

## Step 9: Trigger the Workflow

The workflow will automatically run when you push to `main` or `master` branch.

**To manually trigger:**
1. Go to **Actions** tab in GitHub
2. Select **Build iOS IPA** workflow
3. Click **Run workflow**
4. Select branch and click **Run workflow**

## Step 10: Download Your IPA

1. Go to **Actions** tab
2. Click on the completed workflow run
3. Scroll down to **Artifacts**
4. Click **ios-ipa** to download
5. Extract the `.ipa` file

## Troubleshooting

### Workflow fails with "No signing certificate found"
- Make sure you've added all required secrets
- For automatic signing, verify your Apple ID credentials
- For manual signing, verify your certificate is valid and not expired

### "Bundle identifier mismatch"
- Update the bundle identifier in your Xcode project
- Make sure it matches your provisioning profile

### "Provisioning profile not found"
- Download the correct provisioning profile
- Make sure it's encoded correctly in the secret

### Workflow runs but no IPA artifact
- Check the build logs for errors
- Make sure Flutter build completed successfully
- Verify the path in the upload-artifact step

## Next Steps

Once you have the .ipa file:
- **TestFlight**: Upload to App Store Connect for beta testing
- **App Store**: Submit for review
- **Ad-Hoc**: Install on registered devices

## Need Help?

- Check the build logs in the Actions tab
- Review `BUILD_iOS_IPA.md` for more details
- Ensure all secrets are correctly set

