# 🚀 Quick Start - Build iOS IPA with GitHub Actions

## ✅ Checklist

### Step 1: Add GitHub Secrets (5 minutes)

**Go to:** https://github.com/praneesh28/wedding_calls_app/settings/secrets/actions

**Click "New repository secret" and add:**

#### Option A: Automatic Signing (Easier - Recommended)
1. **APPLE_ID** = Your Apple ID email (e.g., `yourname@example.com`)
2. **APPLE_ID_PASSWORD** = App-specific password from https://appleid.apple.com
3. **APPLE_TEAM_ID** = Your Team ID from https://developer.apple.com/account
4. **KEYCHAIN_PASSWORD** = Any password (e.g., `MyKeychain123!`)

#### Option B: Manual Signing
1. **CERTIFICATE_BASE64** = Run `.\encode-certificates.ps1` to get this
2. **CERTIFICATE_PASSWORD** = Your .p12 certificate password
3. **PROVISIONING_PROFILE_BASE64** = Run `.\encode-certificates.ps1` to get this
4. **KEYCHAIN_PASSWORD** = Any password

### Step 2: Update Bundle Identifier (Important!)

Current: `com.example.weddingCallsApp` ❌

**You need to change this to your own bundle ID** (e.g., `com.yourname.weddingcallsapp`)

**Tell me your desired bundle ID and I'll update it for you!**

### Step 3: Trigger the Workflow

**Go to:** https://github.com/praneesh28/wedding_calls_app/actions

1. Click on **"Build iOS IPA"** workflow
2. Click **"Run workflow"** button (top right)
3. Select branch: **main**
4. Click **"Run workflow"**

### Step 4: Wait for Build (10-15 minutes)

The workflow will:
- ✅ Checkout your code
- ✅ Setup Flutter
- ✅ Install dependencies
- ✅ Build the IPA
- ✅ Upload as artifact

### Step 5: Download Your IPA

1. Go back to **Actions** tab
2. Click on the completed workflow run
3. Scroll down to **"Artifacts"**
4. Click **"ios-ipa"** to download
5. Extract the `.ipa` file

## 🔗 Quick Links

- **Add Secrets:** https://github.com/praneesh28/wedding_calls_app/settings/secrets/actions
- **View Actions:** https://github.com/praneesh28/wedding_calls_app/actions
- **Apple ID Settings:** https://appleid.apple.com
- **Developer Portal:** https://developer.apple.com/account

## ⚠️ Important Notes

1. **Bundle ID must match your provisioning profile**
2. **App-specific password** is different from your Apple ID password
3. **Team ID** is found in Developer Portal → Membership
4. **First build may take longer** (downloading dependencies)

## 🆘 Need Help?

- **Generate App Password:** https://appleid.apple.com → Sign-In and Security → App-Specific Passwords
- **Find Team ID:** https://developer.apple.com/account → Membership section
- **Encode Certificates:** Run `.\encode-certificates.ps1` in PowerShell

---

**Ready? Start with Step 1!** 🎯

