# 📱 True Home - Google Play Store Upload Guide

## 🔐 Critical Information - KEEP SAFE!

### Keystore Details
- **Location**: `/home/kainamura/truehome-release-key.jks`
- **Store Password**: `truehome2025`
- **Key Password**: `truehome2025`
- **Key Alias**: `truehome`

⚠️ **IMPORTANT**: Backup this keystore file! If you lose it, you cannot update your app on Play Store.

### App Package Details
- **Package Name**: `com.example.true_home`
- **App Name**: True Home
- **Version**: 1.0.0+1

---

## 📦 Build Files Location

After successful build, you'll find:
- **App Bundle (.aab)**: `build/app/outputs/bundle/release/app-release.aab`
- This is what you upload to Play Store

---

## 🚀 Google Play Console Steps

### 1. Create Developer Account
1. Go to [Google Play Console](https://play.google.com/console)
2. Pay the $25 one-time registration fee
3. Complete your developer profile

### 2. Create New App
1. Click "Create app"
2. Fill in details:
   - **App name**: True Home
   - **Default language**: English (United States)
   - **App or Game**: App
   - **Free or Paid**: Free

### 3. Store Listing (Required before publishing)

#### App Details
- **App name**: True Home
- **Short description** (80 chars max):
  ```
  Find your perfect rental, condo, or hostel in Uganda. Browse verified listings.
  ```
- **Full description** (4000 chars max):
  ```
  True Home is Uganda's premier property rental platform, making it easy to find your perfect home. 
  
  🏠 KEY FEATURES:
  • Browse verified rental properties, condos, and hostels
  • Advanced search with filters (price, location, type)
  • Interactive maps to explore neighborhoods
  • Save favorites for quick access
  • Direct contact with property owners
  • Detailed property photos and information
  • Multi-language support (English, Swahili, Luganda)
  • Dark mode for comfortable browsing
  
  👥 FOR EVERYONE:
  • Students looking for hostels near campus
  • Professionals seeking rental apartments
  • Families searching for spacious homes
  • Property owners wanting to list their properties
  
  📱 EASY TO USE:
  Simply browse through our curated listings, filter by your preferences, and connect directly with property owners. No middleman, no hidden fees.
  
  🔒 SECURE & VERIFIED:
  All property listings are verified for your peace of mind.
  
  📧 CONTACT US:
  Email: truehome376@gmail.com, ramzyhaden@gmail.com
  Phone: 0777274183
  WhatsApp: 0702021112
  ```

#### App Category
- **Category**: House & Home
- **Tags**: rental, property, real estate, housing, Uganda

#### Contact Details
- **Email**: truehome376@gmail.com
- **Phone**: +256777274183 (optional)
- **Website**: (if you have one)

#### Privacy Policy
You'll need a privacy policy URL. Create one at: https://app-privacy-policy-generator.firebaseapp.com/

### 4. Graphics Requirements

#### App Icon
- **Size**: 512 x 512 pixels
- **Format**: 32-bit PNG
- **No transparency**
- Should match your launcher icon

#### Feature Graphic
- **Size**: 1024 x 500 pixels
- **Format**: JPG or 24-bit PNG
- Showcases your app at the top of your store listing

#### Screenshots (REQUIRED)
- **Phone**: Minimum 2 screenshots
  - Minimum dimension: 320px
  - Maximum dimension: 3840px
  - Recommended: 1080 x 1920 or 1080 x 2340
- Capture:
  1. Home screen with property listings
  2. Property detail page
  3. Search/filter screen
  4. Profile/favorites screen

**How to take screenshots:**
```bash
adb shell screencap -p /sdcard/screenshot.png
adb pull /sdcard/screenshot.png ~/screenshots/
```

### 5. Content Rating
1. Go to "Content rating" in left menu
2. Complete the questionnaire
3. Categories likely: Communication, Social
4. No ads, no paid features, no in-app purchases

### 6. Target Audience & Content
- **Target age group**: 18+
- **Contains ads**: No
- **In-app purchases**: No

### 7. Store Settings
- **App availability**: All countries (or select Uganda specifically)
- **Primary category**: House & Home
- **Content guidelines**: None (unless you have specific restrictions)

---

## 📤 Uploading to Closed Testing

### Step 1: Create Testing Track
1. Go to "Testing" → "Closed testing"
2. Click "Create new release"
3. Click "Create new track" (e.g., "Internal Testing")

### Step 2: Upload App Bundle
1. Click "Upload" and select your `app-release.aab` file
2. Release name: Auto-generated or custom (e.g., "v1.0.0 - Initial Release")
3. Release notes:
   ```
   Initial release of True Home
   
   Features:
   - Browse property listings (rentals, condos, hostels)
   - Advanced search and filters
   - Interactive maps
   - Save favorites
   - Contact property owners
   - Multi-language support
   - Profile management
   ```

### Step 3: Add Testers
1. Create an email list:
   - Go to "Testers" tab
   - Create a list (e.g., "Beta Testers")
   - Add email addresses (one per line)
2. Share the opt-in URL with testers

### Step 4: Review and Rollout
1. Review all details
2. Click "Save" then "Review release"
3. Click "Start rollout to Closed testing"

---

## 🧪 Testing Phase

### For Testers:
1. They'll receive an email invitation
2. Click the opt-in URL
3. Accept the invitation
4. Download from Play Store

### Testing Duration:
- Recommended: 1-2 weeks minimum
- Gather feedback on bugs and UX
- Make fixes if needed

---

## 🌍 Going to Production

Once testing is complete:

1. **Go to Production**
   - Navigate to "Production" in left menu
   - Click "Create new release"
   - Select the same AAB file from closed testing
   - Or upload a new version with fixes

2. **Countries & Regions**
   - Select countries where your app will be available
   - Start with Uganda, then expand

3. **Submit for Review**
   - Click "Save"
   - Click "Review release"
   - Click "Start rollout to Production"

4. **Review Process**
   - Google typically reviews within 3-7 days
   - You'll receive email notifications
   - May request changes (rare for first submission)

---

## 🔄 Updating Your App

### Incrementing Version
Edit `pubspec.yaml`:
```yaml
version: 1.0.1+2  # Format: versionName+versionCode
```

### Building New Release
```bash
flutter clean
flutter pub get
flutter build appbundle --release
```

### Upload New Version
1. Go to Production or Testing track
2. Create new release
3. Upload new AAB
4. Version code must be higher than previous

---

## 📊 Post-Launch Checklist

- [ ] Monitor crash reports in Play Console
- [ ] Respond to user reviews
- [ ] Track installation metrics
- [ ] Update app regularly
- [ ] Backup keystore file in multiple locations
- [ ] Keep key.properties secure (add to .gitignore)

---

## 🆘 Common Issues & Solutions

### "Your app bundle is not signed"
- Check that `key.properties` file exists in `android/` folder
- Verify keystore path is correct

### "Version code already used"
- Increment version in `pubspec.yaml`
- Version code (number after +) must always increase

### "App not compatible with any devices"
- Check `minSdkVersion` in build.gradle
- Currently set to Flutter's default (usually API 21)

### "Missing required permissions"
- Already configured in AndroidManifest.xml
- Includes: Internet, Location, Camera, Storage

---

## 📞 Support Contacts

**True Home Support:**
- Email: truehome376@gmail.com, ramzyhaden@gmail.com
- Phone: 0777274183
- WhatsApp: 0702021112

**For Build Issues:**
- Check Flutter version: `flutter --version`
- Clean and rebuild: `flutter clean && flutter build appbundle --release`
- Check Gradle: `cd android && ./gradlew bundleRelease`

---

## ✅ Pre-Upload Checklist

Before uploading to Play Store, verify:

- [ ] App tested on physical device
- [ ] All features working correctly
- [ ] No crashes or critical bugs
- [ ] Contact information is correct
- [ ] App icon and branding finalized
- [ ] Privacy policy created and hosted
- [ ] Screenshots captured (minimum 2)
- [ ] Feature graphic created (1024x500)
- [ ] Store listing text prepared
- [ ] Keystore backed up securely
- [ ] App bundle (.aab) built successfully
- [ ] Package name is unique (com.example.true_home)

---

**Good luck with your app launch! 🚀**
