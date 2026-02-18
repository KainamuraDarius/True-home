# Complete Guide: Build & Deploy True Home iOS App Using Codemagic

## Overview
This guide will help you build and publish your True Home app to the Apple App Store using Codemagic (no Mac required).

---

## Prerequisites

✅ Apple Developer Account ($99/year - active)
✅ GitHub repository with your code (https://github.com/KainamuraDarius/True-home.git)
✅ App Store Connect access (https://appstoreconnect.apple.com)

---

## Part 1: Prepare Apple App Store Connect

### Step 1.1: Create App in App Store Connect

1. Go to: https://appstoreconnect.apple.com
2. Click **"My Apps"** → **"+"** → **"New App"**
3. Fill in the details:
   - **Platform:** iOS
   - **Name:** True Home
   - **Primary Language:** English
   - **Bundle ID:** Create new → `com.truehome.app` (or your preferred ID)
   - **SKU:** `truehome-001` (any unique identifier)
   - **User Access:** Full Access
4. Click **"Create"**

### Step 1.2: Generate App Store Connect API Key

1. Go to: https://appstoreconnect.apple.com/access/api
2. Click **"+"** under "Keys" (or "Generate API Key")
3. Fill in:
   - **Name:** Codemagic CI/CD
   - **Access:** App Manager (or Admin)
4. Click **"Generate"**
5. **IMPORTANT - Download the .p8 file immediately** (you can only download it once!)
6. **Note down these values:**
   - **Key ID:** (e.g., `ABC123XYZ`)
   - **Issuer ID:** (at the top of the page, e.g., `12345678-1234-1234-1234-123456789012`)
   - **Key file:** (the .p8 file you downloaded)

---

## Part 2: Set Up Codemagic

### Step 2.1: Create Codemagic Account

1. Go to: https://codemagic.io/signup
2. Click **"Sign up with GitHub"**
3. Authorize Codemagic to access your GitHub account
4. Grant access to the **True-home** repository

### Step 2.2: Add Your Project

1. In Codemagic dashboard, click **"Add application"**
2. Select **"Flutter app"**
3. Choose **"GitHub"** as the repository source
4. Find and select: **KainamuraDarius/True-home**
5. Click **"Finish: Add application"**

### Step 2.3: Configure iOS Code Signing

1. In your app's settings, go to **"Code signing identities"**
2. Click **"iOS code signing"** → **"Add code signing certificate"**

**Option A - Automatic (Recommended):**
3. Choose **"Automatic code signing"**
4. Enter your **Apple ID** (the one for your developer account)
5. Enter **App-specific password**:
   - Generate one at: https://appleid.apple.com/account/manage
   - Click **"App-Specific Passwords"** → **"Generate Password"**
   - Name it "Codemagic" and copy the password
6. Bundle identifier: `com.truehome.app` (must match App Store Connect)
7. Click **"Fetch signing files"** - Codemagic will automatically create certificates

**Option B - Manual (If automatic fails):**
3. Choose **"Manual code signing"**
4. You'll need to provide:
   - Distribution certificate (.p12 file)
   - Provisioning profile
   - Certificate password
   (This requires a Mac to generate - skip if you don't have one)

### Step 2.4: Add App Store Connect API Key

1. Go to **"Publishing"** section in Codemagic
2. Click **"App Store Connect"**
3. Upload the **.p8 file** you downloaded earlier
4. Enter:
   - **Key ID:** (from Step 1.2)
   - **Issuer ID:** (from Step 1.2)
5. Click **"Save"**

---

## Part 3: Configure Build Settings

### Step 3.1: Build Configuration

1. In your app settings, go to **"Build"** section
2. **Flutter version:** Select `stable` (latest)
3. **Mode:** `Release`
4. **Build platforms:** Check ✅ **iOS** only (uncheck Android for now)

### Step 3.2: iOS Build Settings

1. Scroll to **"iOS build settings"**
2. **Xcode version:** Select latest (e.g., `15.2`)
3. **CocoaPods version:** Latest
4. **Build for platforms:**
   - ✅ iOS (iPhone)
   - ✅ iOS (iPad) - optional
5. **Bundle name:** `True Home`
6. **Bundle identifier:** `com.truehome.app` (must match what you set in App Store Connect)

### Step 3.3: Distribution Settings

1. Go to **"Distribution"** section
2. Enable: ✅ **"Publish to App Store Connect"**
3. **Submit to App Store:** You can enable this or manually submit later
4. **Track:** `TestFlight` (for beta testing first) or `Production`

---

## Part 4: Update iOS Configuration Files

Before building, we need to ensure your iOS configuration is correct:

### Step 4.1: Update Bundle Identifier

Your bundle ID needs to be set in the Xcode project. Since you're on Linux, I'll help you update the necessary files:

1. The bundle identifier should match what you created in App Store Connect
2. Common format: `com.truehome.app` or `com.yourcompany.truehome`

### Step 4.2: Add Required Permissions (Already Done)

Your Info.plist already has location permissions which is good. Make sure you have:
- Location permissions (for property maps) ✅
- Photo library access (for property images) ✅
- Camera access (for taking photos) ✅

---

## Part 5: Build and Deploy

### Step 5.1: Start Build

1. Go to your app in Codemagic dashboard
2. Click **"Start new build"**
3. Select:
   - **Branch:** `main` (or your default branch)
   - **Build configuration:** The one you just created
4. Click **"Start new build"**

### Step 5.2: Monitor Build Progress

1. Watch the build logs in real-time
2. Build typically takes **10-20 minutes**
3. Common stages:
   - ✅ Clone repository
   - ✅ Install dependencies (`flutter pub get`)
   - ✅ Build iOS app
   - ✅ Code signing
   - ✅ Upload to App Store Connect

### Step 5.3: If Build Fails

Check the logs for errors. Common issues:

**"Provisioning profile doesn't match"**
- Go back to code signing settings
- Make sure bundle ID matches exactly
- Regenerate certificates

**"Invalid API Key"**
- Re-check the .p8 file, Key ID, and Issuer ID
- Make sure the API key has "App Manager" access

**"Flutter build failed"**
- Check if there are any iOS-specific code errors
- Make sure all dependencies support iOS

---

## Part 6: TestFlight & App Store Submission

### Step 6.1: TestFlight (Beta Testing)

1. Once build succeeds and uploads to App Store Connect
2. Go to: https://appstoreconnect.apple.com
3. Navigate to **"My Apps"** → **"True Home"** → **"TestFlight"**
4. Your build will appear under **"Builds"** (may take 5-10 minutes to process)
5. Add beta testers and test your app

### Step 6.2: Submit to App Store

1. Go to **"App Store"** tab in App Store Connect
2. Create a new version (e.g., `1.0.0`)
3. Fill in required information:
   - **Screenshots** (iPhone and iPad)
   - **App description**
   - **Keywords**
   - **Support URL:** Your website
   - **Privacy Policy URL:** Your privacy policy page
   - **Category:** Lifestyle or Real Estate
4. Select your build from TestFlight
5. Complete **App Review Information**
6. Submit for review

---

## Part 7: Screenshots & App Store Assets

You'll need to provide:

### Required Screenshots:
- **iPhone 6.7" display** (iPhone 14 Pro Max): 1290 x 2796 pixels
- **iPhone 6.5" display** (iPhone 11 Pro Max): 1242 x 2688 pixels
- **iPad Pro 12.9" display**: 2048 x 2732 pixels

### How to Generate:
1. Use Codemagic's iOS simulator screenshots feature
2. Or use online tools like:
   - https://www.applaunchpad.com/screenshot-builder/
   - https://appure.io/
3. Take screenshots of:
   - Welcome screen
   - Property listings
   - Property details
   - Search/filter
   - Agent dashboard

### App Icon:
- **1024 x 1024 pixels** PNG (no transparency)
- Location: `ios/Runner/Assets.xcassets/AppIcon.appiconset/`

---

## Part 8: Troubleshooting

### Build Taking Too Long?
- Check Codemagic build logs for where it's stuck
- Free tier has limited build time (500 minutes/month)

### "Invalid Bundle Identifier"?
- Must match exactly in:
  - App Store Connect
  - Codemagic settings
  - Xcode project file

### "Certificate Expired"?
- Regenerate certificates in Codemagic
- Or manually create new ones in Apple Developer portal

### Need Help?
- Codemagic Docs: https://docs.codemagic.io/flutter/flutter-projects/
- Codemagic Support: support@codemagic.io
- Flutter iOS Deployment: https://docs.flutter.dev/deployment/ios

---

## Quick Reference

### URLs You'll Need:
- **App Store Connect:** https://appstoreconnect.apple.com
- **Apple Developer Portal:** https://developer.apple.com
- **Codemagic Dashboard:** https://codemagic.io/apps
- **GitHub Repository:** https://github.com/KainamuraDarius/True-home
- **Apple ID Management:** https://appleid.apple.com

### Important Files:
- **Bundle ID:** `com.truehome.app` (or your chosen ID)
- **App Store Connect API Key:** .p8 file (keep secure!)
- **Version:** Currently `1.0.0+17` in pubspec.yaml

---

## Timeline Estimate

- ⏱️ **Codemagic Setup:** 30-45 minutes
- ⏱️ **First Build:** 15-25 minutes
- ⏱️ **App Store Connect Setup:** 20-30 minutes
- ⏱️ **TestFlight Processing:** 5-15 minutes
- ⏱️ **App Review:** 1-3 days (after submission)

**Total:** ~2 hours of your time + Apple's review time

---

## Next Steps

1. ✅ Push your latest code to GitHub (already done)
2. ⬜ Create app in App Store Connect
3. ⬜ Generate App Store Connect API Key
4. ⬜ Sign up for Codemagic
5. ⬜ Configure code signing in Codemagic
6. ⬜ Start your first build
7. ⬜ Test via TestFlight
8. ⬜ Submit to App Store

---

## Need Help?

If you encounter any issues during this process, I'm here to help! Just let me know which step you're stuck on.

Good luck with your App Store launch! 🚀
