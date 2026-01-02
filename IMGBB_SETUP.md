# ImgBB Setup Instructions

## Getting Your Free ImgBB API Key

ImgBB provides **FREE unlimited image hosting** with their API!

### Step 1: Create ImgBB Account
1. Go to https://imgbb.com/
2. Click "Sign up" (top right)
3. Create a free account using email or social login

### Step 2: Get API Key
1. Once logged in, go to https://api.imgbb.com/
2. Click "Get API Key" or go directly to: https://api.imgbb.com/
3. Your API key will be displayed on the page
4. Copy your API key (it looks like: `a1b2c3d4e5f6g7h8i9j0k1l2m3n4o5p6`)

### Step 3: Add API Key to App
1. Open `lib/services/imgbb_service.dart`
2. Find line with: `static const String _apiKey = 'YOUR_IMGBB_API_KEY';`
3. Replace `YOUR_IMGBB_API_KEY` with your actual API key
4. Save the file

Example:
```dart
static const String _apiKey = 'a1b2c3d4e5f6g7h8i9j0k1l2m3n4o5p6';
```

### Step 4: Test Upload
1. Run your app
2. Try adding a property with images
3. Images will now be stored on ImgBB cloud servers (FREE forever!)

## ImgBB Benefits
- ✅ **FREE unlimited uploads**
- ✅ **No storage limits**
- ✅ **Fast CDN delivery**
- ✅ **Permanent image hosting**
- ✅ **Direct image URLs**
- ✅ **No credit card required**

## Important Notes
- Keep your API key private (don't share it publicly)
- Images uploaded are permanent and publicly accessible
- Free tier has rate limits (but very generous for most apps)
- No deletion via API in free tier (images stay forever)

## Alternative Free Services (if needed)
1. **Cloudinary** - 25 GB free storage
2. **Uploadcare** - 3 GB free storage
3. **Filestack** - 100 MB free storage

But ImgBB is recommended for truly unlimited free storage!
