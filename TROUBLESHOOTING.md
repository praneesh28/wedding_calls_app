# Troubleshooting iOS Build Issues

## Common Errors and Solutions

### Error: Exit Code 65

**Cause:** Xcode build failure, usually related to:
- Code signing issues
- Missing provisioning profiles
- Bundle identifier mismatch
- CocoaPods dependency issues

**Solutions:**

1. **Check your secrets are set correctly:**
   - Go to: https://github.com/praneesh28/wedding_calls_app/settings/secrets/actions
   - Verify all required secrets are present

2. **For Automatic Signing, ensure you have:**
   - `APPLE_ID` - Your Apple ID email
   - `APPLE_ID_PASSWORD` - App-specific password (NOT your regular password)
   - `APPLE_TEAM_ID` - Your Team ID from developer.apple.com
   - `KEYCHAIN_PASSWORD` - Any random password

3. **Check bundle identifier:**
   - Current: `com.example.weddingCallsApp`
   - This MUST match your provisioning profile
   - Update in Xcode or project.pbxproj file

### Warning: "Run script build phase will be run during every build"

**This is a warning, not an error.** It's related to CocoaPods and BoringSSL-GRPC.

**Solution:** The updated Podfile should suppress this. If it persists:
- The build should still succeed
- This warning doesn't prevent IPA creation

### "No signing certificate found"

**Cause:** Code signing is not configured properly.

**Solutions:**

1. **For Automatic Signing:**
   - Make sure `APPLE_ID`, `APPLE_ID_PASSWORD`, and `APPLE_TEAM_ID` are set
   - Verify your Apple ID has access to the Team ID
   - Check that app-specific password is correct

2. **For Manual Signing:**
   - Verify certificate is not expired
   - Check certificate matches provisioning profile
   - Ensure bundle identifier matches

### "Provisioning profile not found"

**Cause:** Provisioning profile doesn't match bundle identifier or is missing.

**Solutions:**
1. Download the correct provisioning profile from Apple Developer Portal
2. Ensure bundle identifier matches exactly
3. Re-encode and update the secret

### "Bundle identifier mismatch"

**Cause:** Bundle ID in Xcode doesn't match provisioning profile.

**Solution:**
1. Check your bundle identifier in `ios/Runner.xcodeproj/project.pbxproj`
2. Update to match your provisioning profile
3. Or create a new provisioning profile with matching bundle ID

## Workflow Improvements Made

The workflow has been updated with:

1. ✅ **Xcode Setup** - Ensures latest Xcode is available
2. ✅ **CocoaPods Clean Install** - Cleans cache and reinstalls pods
3. ✅ **Better Error Handling** - More detailed error messages
4. ✅ **Podfile Updates** - Suppresses script phase warnings

## Try These Steps

1. **Use the Simple Workflow:**
   - Try `build-ios-simple.yml` which uses automatic signing
   - Requires only: APPLE_ID, APPLE_ID_PASSWORD, APPLE_TEAM_ID

2. **Check Build Logs:**
   - Go to Actions tab → Click on failed workflow
   - Scroll through logs to find the exact error
   - Look for red error messages

3. **Verify Secrets:**
   - Double-check all secrets are set correctly
   - App-specific password is different from regular password
   - Team ID is correct (found in Developer Portal)

4. **Update Bundle Identifier:**
   - If you have a specific bundle ID, update it in the project
   - Make sure it matches your Apple Developer account

## Still Having Issues?

1. Check the full build logs in GitHub Actions
2. Verify your Apple Developer account is active
3. Ensure your Team ID has proper permissions
4. Try building with a fresh pod install locally (if you have a Mac)

## Quick Fixes

**If build fails immediately:**
- Check that all required secrets are present
- Verify Flutter version matches (3.35.6)

**If CocoaPods fails:**
- The workflow now cleans and reinstalls pods
- This should resolve most pod-related issues

**If code signing fails:**
- Use automatic signing (simpler)
- Or verify manual signing certificates are valid

