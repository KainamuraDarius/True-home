# Project Advertisement Implementation Guide

## Overview
This document describes the complete workflow for the "Browse New Projects In Uganda" feature - a paid advertising system for property developers and agents.

## Workflow

### 1. Developer/Agent Side (Submit Projects)
**Path:** Manager Dashboard → "Advertise Project" OR Owner Dashboard → "Advertise Project"

**Features:**
- Fill project details (name, location, description)
- Add up to 5 project images
- Add contact information (phone, email, website)
- Choose advertising package:
  - **Basic Package** (UGX 50,000/month): Standard listing
  - **Premium Package** (UGX 100,000/month): Better positioning with premium badge
  - **First Place Rotational** (UGX 200,000/month): Rotational first place (up to 10 subscribers)
- Submit for admin approval
- Status: "Pending" - awaiting payment verification

**View Submissions:**
Path: Manager/Owner Dashboard → "My Project Ads"
- View all projects (Pending/Approved/All tabs)
- Track analytics (views, clicks, days remaining)
- See payment amounts and status

### 2. Admin Side (Review & Approve)
**Path:** Admin Dashboard → "Manage Projects"

**Features:**
- Three tabs: Pending, Approved, All Projects
- Review project details and images
- Verify payment (developer should pay via Mobile Money/Bank)
- Approve or reject projects
- Set/extend expiration dates (default 30 days)
- Delete projects if needed
- View analytics for each project

**Approval Process:**
1. Developer submits project and makes payment
2. Admin receives notification of new pending project
3. Admin verifies payment receipt
4. Admin approves project (or rejects if payment not received)
5. Project goes live for customers to see

### 3. Customer Side (Browse Projects)
**Path:** Customer Home → "Browse New Projects In Uganda" section

**Features:**
- Horizontal scrollable location tabs (Kololo, Naalya, Nakasero, etc.)
- Projects displayed by location
- Rotational first-place algorithm:
  - Up to 10 developers can subscribe for first place per location
  - One randomly selected on each app load
  - Fair rotation ensures all subscribers get exposure
- Premium projects highlighted with badge
- Click project to see full details
- Contact developer via phone, email, or website
- View tracking (increments view and click counts)

## Payment Information

### Pricing
- **Basic:** UGX 50,000 per 30 days
- **Premium:** UGX 100,000 per 30 days
- **First Place Rotational:** UGX 200,000 per 30 days

### Payment Methods
Developers should pay to:
- **Mobile Money:** +256-XXX-XXXXXX (Update with actual number)
- **Bank Account:** XXXXXXX (Update with actual account details)

**Note:** Update payment information in [submit_project_screen.dart](lib/screens/common/submit_project_screen.dart) lines 626-636.

## Technical Details

### Files Created/Modified

**New Files:**
1. `lib/screens/common/submit_project_screen.dart` - Developer project submission form
2. `lib/screens/common/my_projects_screen.dart` - View submitted projects with analytics
3. `lib/models/project_model.dart` - Project data model with AdTier enum
4. `lib/services/project_service.dart` - Firestore operations and rotation logic
5. `lib/screens/customer/project_details_screen.dart` - Customer project view
6. `lib/screens/admin/admin_projects_screen.dart` - Admin approval interface

**Modified Files:**
1. `lib/screens/manager/manager_dashboard_screen.dart` - Added navigation to project screens
2. `lib/screens/owner/owner_dashboard_screen.dart` - Added navigation to project screens
3. `lib/screens/customer/customer_home_screen.dart` - Displays projects by location

### Database Structure

**Collection:** `advertised_projects`

**Document Fields:**
```dart
{
  "name": "Luxury Apartments Kololo",
  "description": "Modern 2-bedroom apartments...",
  "imageUrls": ["url1", "url2", ...],
  "developerId": "uid",
  "developerName": "John Developer",
  "location": "Kololo",
  "adTier": "firstPlaceRotational", // basic, premium, firstPlaceRotational
  "isFirstPlaceSubscriber": true,
  "paymentAmount": 200000,
  "createdAt": Timestamp,
  "adExpiresAt": Timestamp,
  "isApproved": false,
  "contactPhone": "+256...",
  "contactEmail": "contact@company.com",
  "websiteUrl": "https://...",
  "viewCount": 0,
  "clickCount": 0
}
```

### Required Firestore Indexes

**Index 1:** For approved, non-expired projects by location
- Collection: `advertised_projects`
- Fields:
  - `location` (Ascending)
  - `isApproved` (Ascending)
  - `adExpiresAt` (Ascending)

**Index 2:** For admin filtering
- Collection: `advertised_projects`
- Fields:
  - `isApproved` (Ascending)
  - `adExpiresAt` (Ascending)

**Index 3:** For developer's own projects
- Collection: `advertised_projects`
- Fields:
  - `developerId` (Ascending)
  - `isApproved` (Ascending)
  - `createdAt` (Descending)

**Index 4:** For all developer projects
- Collection: `advertised_projects`
- Fields:
  - `developerId` (Ascending)
  - `createdAt` (Descending)

### Security Rules Recommendation

```javascript
match /advertised_projects/{projectId} {
  // Anyone can read approved projects
  allow read: if resource.data.isApproved == true;
  
  // Developers can create projects
  allow create: if request.auth != null 
    && request.resource.data.developerId == request.auth.uid
    && request.resource.data.isApproved == false;
  
  // Developers can read their own projects
  allow read: if request.auth != null 
    && resource.data.developerId == request.auth.uid;
  
  // Only admins can approve/update
  allow update: if request.auth != null 
    && get(/databases/$(database)/documents/users/$(request.auth.uid)).data.role == 'admin';
  
  // Only admins can delete
  allow delete: if request.auth != null 
    && get(/databases/$(database)/documents/users/$(request.auth.uid)).data.role == 'admin';
}
```

## Rotation Algorithm

The first-place rotational system works as follows:

1. Up to 10 developers per location can subscribe to "First Place Rotational"
2. When a customer opens the app and selects a location:
   - System fetches all first-place subscribers for that location
   - Randomly selects ONE to show in first position
   - Other first-place subscribers appear after the randomly selected one
   - Premium and basic projects follow
3. Each time the app is opened or location is changed, a new random selection occurs
4. This ensures fair exposure for all first-place subscribers

**Code:** See `getProjectsByLocation()` in [project_service.dart](lib/services/project_service.dart) lines 10-60

## Available Locations

60+ locations across Kampala and Wakiso districts including:
- **Kampala Central:** Kololo, Nakasero, Naguru, Bugolobi, Muyenga
- **Kampala North:** Ntinda, Kyanja, Kira, Naalya, Namugongo
- **Wakiso:** Kansanga, Kabalagala, Makindye, Munyonyo, Entebbe
- **And 50+ more locations...**

Full list available in `ProjectService.defaultLocations`

## Analytics Tracking

For each project, the system tracks:
- **View Count:** Incremented when project appears in customer's feed
- **Click Count:** Incremented when customer clicks to view details
- **Days Remaining:** Calculated from expiration date
- **Status:** Pending, Approved, Expired

Developers can view these analytics in "My Project Ads" screen.

## Next Steps

1. **Update Payment Information:** Edit [submit_project_screen.dart](lib/screens/common/submit_project_screen.dart) with actual Mobile Money number and bank account details

2. **Create Firestore Indexes:** Create the required composite indexes in Firebase Console (will see error messages prompting you with direct links)

3. **Test Workflow:**
   - As Developer: Submit a test project
   - As Admin: Approve the test project
   - As Customer: View the approved project by location

4. **Optional Enhancements:**
   - Integrate payment gateway (Flutterwave, Pesapal) for automatic payment
   - Add push notifications for approval status
   - Add project renewal feature for expired ads
   - Add project editing before approval

## Support

For any issues or questions about this feature, refer to:
- [API_REFERENCE.md](API_REFERENCE.md) - API documentation
- [PROJECT_SUMMARY.md](PROJECT_SUMMARY.md) - Overall project structure
- Firebase Console for database and index management
