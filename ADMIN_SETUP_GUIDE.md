# Admin System Setup Guide

## Overview
The admin system has been implemented with a hidden access point to keep it completely separate from regular users. Admins can view and manage all users, create other admin accounts, and access system-wide features.

## Hidden Admin Access
**How to access admin login:**
1. Open the app to the Welcome Screen
2. **Tap the True Home logo 7 times quickly** (within 2 seconds between taps)
3. Admin Login screen will appear
4. Login with admin credentials

## Creating the First Admin Account

Since this is the first admin, you need to create it manually through Firebase Console:

### Step 1: Create Admin User in Firebase Authentication
1. Go to [Firebase Console](https://console.firebase.google.com/)
2. Select your project: **truehome-9a244**
3. Navigate to **Authentication** → **Users**
4. Click **Add user**
5. Enter:
   - Email: `admin@truehome.com` (or your preferred email)
   - Password: Create a strong password
6. Click **Add user**
7. **Copy the User UID** (you'll need this in the next step)

### Step 2: Create Admin Document in Firestore
1. In Firebase Console, navigate to **Firestore Database**
2. Go to the `users` collection
3. Click **Add document**
4. Document ID: **Paste the User UID from Step 1**
5. Add the following fields:

```
Field Name          | Type      | Value
--------------------|-----------|---------------------------
email               | string    | admin@truehome.com
name                | string    | System Administrator
phoneNumber         | string    | +1234567890
role                | string    | admin
profileImageUrl     | string    | null (leave empty)
favoritePropertyIds | array     | [] (empty array)
createdAt           | string    | 2025-12-25T00:00:00.000Z
updatedAt           | string    | 2025-12-25T00:00:00.000Z
companyName         | string    | null (leave empty)
companyAddress      | string    | null (leave empty)
whatsappNumber      | string    | null (leave empty)
isVerified          | boolean   | true
```

6. Click **Save**

### Step 3: Login as Admin
1. Open the True Home app
2. Tap the logo 7 times quickly
3. Login with the credentials you created:
   - Email: `admin@truehome.com`
   - Password: (the password you set)
4. You'll be redirected to the Admin Dashboard

## Admin Features

### Admin Dashboard
- **System Overview**: View statistics of all user types
  - Total users
  - Customers
  - Property Owners
  - Property Managers
  - Admins

### User Management
- **View All Users**: Browse all registered users
- **Filter by Role**: 
  - All Users
  - Customers
  - Property Owners
  - Property Managers
  - Admins
- **User Details**: Expand user cards to see full information
- **Delete Users**: Remove non-admin users (admin accounts cannot be deleted from the app)

### Admin Account Creation
- **Create New Admins**: Current admins can create additional admin accounts
- **Important**: Creating a new admin will temporarily sign you out (you'll need to login again)

## Security Features

1. **Hidden Access**: No visible admin option for regular users
2. **Role Verification**: Admin login validates user role - non-admins cannot access
3. **Separate Login**: Admin uses a different login screen than regular users
4. **Admin Protection**: Admin accounts cannot be deleted through the app interface
5. **Access Logging**: Unauthorized access attempts can be tracked (future feature)

## User Flow Diagram

```
Welcome Screen
    │
    ├─► Sign up with Email ─► Role Selection ─► Registration (Customer/Owner/Manager)
    │
    ├─► Login ─► Regular User Dashboard
    │
    └─► [7 taps on logo] ─► Admin Login ─► Admin Dashboard
                                              │
                                              ├─► View All Users
                                              ├─► Create Admin
                                              ├─► Property Submissions (Coming Soon)
                                              └─► System Settings (Coming Soon)
```

## Admin Responsibilities

As an admin, you can:
- ✅ View all user information
- ✅ Manage user accounts
- ✅ Create additional administrators
- ✅ View system statistics
- 🔜 Review property submissions
- 🔜 Approve/reject properties
- 🔜 Configure system settings
- 🔜 View reports and analytics

## Best Practices

1. **Keep admin credentials secure** - these accounts have full system access
2. **Create admin accounts only for trusted personnel**
3. **Use strong passwords** for admin accounts
4. **Regularly review the admin user list** to ensure no unauthorized admins exist
5. **Document who has admin access** for accountability

## Troubleshooting

**Can't access admin login:**
- Make sure you're tapping the logo 7 times quickly (within 2 seconds between taps)
- Try again from the Welcome Screen

**Login fails with "Unauthorized":**
- The account exists but doesn't have admin role
- Check Firestore to ensure `role` field is set to `admin` (not `customer`, `property_owner`, or `property_manager`)

**Signed out after creating admin:**
- This is expected behavior
- Login again with your original admin credentials
- The new admin account is now active

## Next Steps

After creating your first admin account, you should:
1. Login and verify admin dashboard access
2. Create a backup admin account for redundancy
3. Document all admin account credentials securely
4. Test user management features
5. Plan for future admin features (property submissions, system settings, etc.)

## Support

For technical issues or questions about the admin system, refer to the project documentation or contact the development team.
