# Setup Guide for Collaborators

This guide will help you set up the True Home project on your local machine.

## 🔐 Sensitive Files Not in Git

The following files contain API keys and credentials and are **NOT** included in the repository:

1. `lib/services/mtn_momo_service.dart` - MTN MoMo payment credentials
2. `lib/services/airtel_money_service.dart` - Airtel Money payment credentials  
3. `lib/config/api_keys.dart` - ImgBB API key
4. `lib/firebase_options.dart` - Firebase configuration
5. `android/app/google-services.json` - Google Services config
6. `backend/.env` - Backend environment variables

## 📋 Prerequisites

- Flutter SDK (latest stable version)
- Android Studio / VS Code
- Git
- Node.js (for backend)

## 🚀 Setup Steps

### 1. Clone the Repository

```bash
git clone https://github.com/KainamuraDarius/True-home.git
cd True-home
```

### 2. Get Credentials from Team Lead

Contact **Darius** to get:
- MTN MoMo credentials
- Airtel Money credentials (when available)
- ImgBB API key
- Firebase configuration files
- Google Services JSON file

### 3. Create Payment Service Files

#### MTN MoMo Service

Copy the template:
```bash
cp lib/services/mtn_momo_service.dart.template lib/services/mtn_momo_service.dart
```

Then add the credentials provided by the team lead in `lib/services/mtn_momo_service.dart`:
```dart
final String subscriptionKey = 'YOUR_KEY_HERE';
String? apiUser = 'YOUR_API_USER_HERE';
String? apiKey = 'YOUR_API_KEY_HERE';
```

#### Airtel Money Service

Copy the template:
```bash
cp lib/services/airtel_money_service.dart.template lib/services/airtel_money_service.dart
```

Add credentials when team lead provides them.

### 4. Create ImgBB API Keys File

Create `lib/config/api_keys.dart`:

```dart
class ApiKeys {
  // Get this from team lead or create at https://imgbb.com/
  static const String imgbbApiKey = 'YOUR_IMGBB_API_KEY';
}
```

### 5. Add Firebase Configuration

**For Android:**
- Place `google-services.json` in `android/app/`

**For Flutter:**
- Place `firebase_options.dart` in `lib/`

### 6. Backend Setup (Optional)

If working on backend features:

```bash
cd backend
npm install
```

Create `backend/.env`:
```env
PORT=3000
DB_USER=postgres
DB_HOST=localhost
DB_NAME=true_home_db
DB_PASSWORD=your_password
DB_PORT=5432

JWT_SECRET=your-jwt-secret
JWT_REFRESH_SECRET=your-refresh-secret

EMAIL_USER=your-email@gmail.com
EMAIL_PASSWORD=your-app-password
```

### 7. Install Flutter Dependencies

```bash
flutter pub get
```

### 8. Run the App

```bash
flutter run
```

## 🏗️ Project Structure

```
lib/
├── config/          # Configuration files (API keys)
├── models/          # Data models
├── screens/         # UI screens
│   ├── admin/      # Admin features
│   ├── agent/      # Property agent features
│   └── customer/   # Customer features
├── services/        # Business logic & APIs
│   ├── mtn_momo_service.dart       # MTN payments
│   ├── airtel_money_service.dart   # Airtel payments
│   └── imgbb_service.dart          # Image uploads
└── utils/          # Utility functions
```

## 🆕 Recent Changes

### Latest Features (January 2026)

1. **Inspection Fee Dropdown**
   - Location: `lib/screens/property/add_property_screen.dart`
   - Agents can select inspection fees from 10k to 100k UGX
   - "No Inspection Fee" option available
   - Applies to both sale and rental properties

2. **Dual Payment Options**
   - Location: `lib/screens/customer/reserve_room_screen.dart`
   - Customers can choose between MTN MoMo or Airtel Money
   - Mock mode enabled for testing without real credentials
   - Payment dialogs with provider-specific branding

3. **Property Model Updates**
   - Added `inspectionFee` field
   - Supports nullable double for optional fees

## 🧪 Testing

### Payment Testing (Mock Mode)

Both payment services run in mock mode by default:
- MTN MoMo: `useMockMode = true` in mtn_momo_service.dart
- Airtel Money: `useMockMode = true` in airtel_money_service.dart

This allows testing the payment flow without real API calls.

### Test Credentials

For testing, use:
- Phone: Any valid format (e.g., +256700000000)
- Payments will simulate success after 2 seconds

## 📝 Development Guidelines

### Before Committing

1. **Never commit sensitive data:**
   - API keys
   - Credentials
   - Environment variables
   - Firebase config files

2. **Check .gitignore:**
   - Ensure sensitive files are listed
   - Use `git status` to verify

3. **Use templates:**
   - Create `.template` versions of sensitive files
   - Document in SETUP_FOR_COLLABORATORS.md

### Git Workflow

```bash
# Create feature branch
git checkout -b feature/your-feature-name

# Make changes and commit
git add .
git commit -m "Description of changes"

# Push to remote
git push origin feature/your-feature-name

# Create pull request on GitHub
```

## 🆘 Need Help?

- Check existing documentation in the repo
- Contact team lead: Darius
- Review setup guides:
  - `MTN_MOMO_SETUP.md`
  - `IMGBB_SETUP.md`
  - `BACKEND_SETUP.md`

## 🔗 Useful Links

- **Live App:** https://truehome-9a244.web.app
- **GitHub Repo:** https://github.com/KainamuraDarius/True-home.git
- **Firebase Console:** https://console.firebase.google.com/project/truehome-9a244
- **MTN MoMo Docs:** https://momodeveloper.mtn.com/
- **Airtel Docs:** https://developers.airtel.africa/

---

**Last Updated:** January 31, 2026
