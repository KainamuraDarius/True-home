# Firestore Database Indexes Required

## Browse New Projects Feature

The "Browse New Projects In Uganda" feature requires the following Firestore composite indexes to function properly.

### Required Indexes:

#### Index 1: For getting all locations
**Collection:** `advertised_projects`
**Fields:**
- `isApproved` (Ascending)
- `adExpiresAt` (Ascending)

**Create this index:**
https://console.firebase.google.com/v1/r/project/truehome-9a244/firestore/indexes?create_composite=Clpwcm9qZWN0cy90cnVlaG9tZS05YTI0NC9kYXRhYmFzZXMvKGRlZmF1bHQpL2NvbGxlY3Rpb25Hcm91cHMvYWR2ZXJ0aXNlZF9wcm9qZWN0cy9pbmRleGVzL18QARoOCgppc0FwcHJvdmVkEAEaDwoLYWRFeHBpcmVzQXQQARoMCghfX25hbWVfXxAB

#### Index 2: For getting projects by location
**Collection:** `advertised_projects`
**Fields:**
- `location` (Ascending)
- `isApproved` (Ascending)
- `adExpiresAt` (Ascending)

**Create this index:**
https://console.firebase.google.com/v1/r/project/truehome-9a244/firestore/indexes?create_composite=Clpwcm9qZWN0cy90cnVhaG9tZS05YTI0NC9kYXRhYmFzZXMvKGRlZmF1bHQpL2NvbGxlY3Rpb25Hcm91cHMvYWR2ZXJ0aXNlZF9wcm9qZWN0cy9pbmRleGVzL18QARoMCghsb2NhdGlvbhABGg4KCmlzQXBwcm92ZWQQARoPCgthZEV4cGlyZXNBdBABGgwKCF9fbmFtZV9fEAE

## Steps to Create Indexes:

1. Click on each link above while logged into Firebase Console
2. Click "Create Index" on the page that opens
3. Wait for the index to build (this may take a few minutes)
4. Once both indexes show as "Enabled", the feature will work properly

## Collection Structure

### advertised_projects Collection

Example document structure:
```json
{
  "name": "Luxury Apartments",
  "description": "Modern luxury apartments with excellent amenities",
  "imageUrls": ["url1", "url2", "url3"],
  "developerId": "userId",
  "developerName": "ABC Developers",
  "location"``````````````````````````````wwww: "Kololo",
  "adTier": "firstPlaceRotational",
  "isFirstPlaceSubscriber": true,
  "paymentAmount": 500000,
  "createdAt": "timestamp",
  "adExpiresAt": "timestamp",
  "isApproved": true,
  "contactPhone": "+256700000000",
  "contactEmail": "contact@abcdevelopers.com",
  "websiteUrl": "https://abcdevelopers.com",
  "viewCount": 0,
  "clickCount": 0
}
```

### Ad Tier Types:
- **basic**: Standard listing
- **premium**: Higher payment, better placement
- **firstPlaceRotational**: First place rotational (up to 10 can subscribe, randomly rotates)

### Pricing Model (Recommended):
- Basic: UGX 100,000/month
- Premium: UGX 250,000/month
- First Place Rotational: UGX 500,000/month

## How the Rotation Works:

For **firstPlaceRotational** tier:
1. Up to 10 developers can subscribe to the first-place package for any location
2. When a customer views properties in that location, one of the 10 is randomly selected to appear first
3. Each time the page is loaded, a different developer may appear first (random rotation)
4. This ensures fair exposure for all first-place subscribers
5. Other projects are sorted by payment amount (premium listings appear higher)

## Admin Management:

Admins can:
- View all advertised projects (pending, approved, all)
- Approve or reject project advertisements
- Delete projects
- See analytics (view count, click count)
- Monitor expiration dates

Access via: **Admin Dashboard → Manage Advertised Projects**

## Security Rules (Add to Firestore Rules):

```javascript
// Allow admins to manage all projects
match /advertised_projects/{projectId} {
  // Allow read for approved, non-expired projects
  allow read: if resource.data.isApproved == true && 
                 resource.data.adExpiresAt > request.time;
  
  // Allow admins full access
  allow read, write: if request.auth != null && 
                       get(/databases/$(database)/documents/users/$(request.auth.uid)).data.role == 'admin';
  
  // Allow developers to create their own projects
  allow create: if request.auth != null && 
                   request.resource.data.developerId == request.auth.uid;
  
  // Allow developers to update their own projects
  allow update: if request.auth != null && 
                   resource.data.developerId == request.auth.uid;
}
```

## Testing the Feature:

1. Create indexes using the links above
2. As an admin, add test projects via Firestore Console or create an admin UI for adding projects
3. Set `isApproved: true` and `adExpiresAt` to a future date
4. View the customer home screen to see the "Browse New Projects In Uganda" section
5. Test different locations by clicking the location tabs
6. Click on project cards to view details

## Next Steps for Full Implementation:

1. Create UI for developers to submit their projects (optional - can be done via admin for now)
2. Implement payment integration (Mobile Money, Stripe, etc.)
3. Add automatic expiration notifications
4. Create renewal system for expired ads
5. Add more analytics (conversion tracking, etc.)
