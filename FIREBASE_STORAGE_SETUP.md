# Firebase Storage Setup Instructions

## Quick Fix - Deploy Storage Rules

1. **Install Firebase CLI** (if not already installed):
```bash
curl -sL https://firebase.tools | bash
```

2. **Login to Firebase**:
```bash
firebase login
```

3. **Initialize Firebase Storage** (run from project root):
```bash
firebase init storage
```
- Select your Firebase project
- Accept the default storage rules file location

4. **Deploy the Storage Rules**:
```bash
firebase deploy --only storage
```

## Alternative - Manual Setup via Firebase Console

1. Go to [Firebase Console](https://console.firebase.google.com)
2. Select your project: **true-home-68701**
3. Click on **Storage** in the left menu
4. Click **Get Started** if Storage is not enabled
5. Click on the **Rules** tab
6. Replace the rules with:

```
rules_version = '2';
service firebase.storage {
  match /b/{bucket}/o {
    // Allow authenticated users to read all files
    match /{allPaths=**} {
      allow read: if request.auth != null;
    }
    
    // Allow authenticated users to upload their own property images
    match /properties/{userId}/{fileName} {
      allow write: if request.auth != null && request.auth.uid == userId;
    }
  }
}
```

7. Click **Publish**

## Verify Setup

After deploying the rules:
1. Run the app
2. Login as a manager or owner
3. Try to add a property with images
4. Images should upload successfully

## Current App Behavior

The app now has a fallback:
- If image upload fails, it will show a dialog
- You can choose to submit the property without images
- This allows the app to work even if Storage isn't configured yet
- Once Storage is configured, images will upload properly

## Storage Bucket Location

Your Firebase Storage bucket is located at:
`true-home-68701.appspot.com`

Images are stored in the path:
`properties/{userId}/{fileName}`

Where:
- `userId` = Firebase Auth user ID
- `fileName` = property_timestamp_index.jpg
