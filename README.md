# True Home - Real Estate App

A comprehensive Flutter real estate application for browsing rentals, buying condos, and finding student hostels.

## 📱 Features

### For Customers (Users)
- **Browse Properties**: View rentals, condos for sale, and student hostels
- **Property Details**: 
  - Price (rent/sale)
  - Location with map integration
  - Photos & videos
  - Property type, rooms, bathrooms, amenities
- **Contact Management**:
  - Direct call
  - WhatsApp integration
  - Email
  - In-app contact form
- **Schedule Property Tours**: Pick date & time for viewings
- **Search & Filters**:
  - Filter by location
  - Price range
  - Property type (rental/condo/hostel)
- **Favorites**: Save properties for later

### For Property Managers
- **Property Management**:
  - Add new properties
  - Edit prices & availability
  - Upload photos
  - Manage property details
- **Request Management**:
  - View and manage tour requests
  - Respond to contact inquiries
  - Track request status
- **Dashboard**: Overview of properties and pending requests

### For Property Owners
- **Submit Properties**: Submit properties to admins for approval
- **Track Submissions**: View status of submitted properties (pending/approved/rejected)
- **Property Details**: Provide comprehensive property information

### For Admins
- **Review Submissions**: Approve or reject property submissions
- **Content Moderation**: Ensure quality of listed properties
- **User Management**: Oversee all users and properties

## 🏗️ Project Structure

```
lib/
├── main.dart                    # App entry point
├── models/                      # Data models
│   ├── property.dart           # Property model with type & status
│   ├── user_model.dart         # User model with roles
│   ├── tour_request.dart       # Tour scheduling model
│   ├── contact_request.dart    # Contact inquiry model
│   └── property_submission.dart # Owner submission model
├── services/                    # Business logic
│   ├── auth_service.dart       # Authentication
│   ├── property_service.dart   # Property CRUD
│   ├── tour_service.dart       # Tour management
│   ├── contact_service.dart    # Contact handling
│   ├── property_submission_service.dart # Submission handling
│   └── url_launcher_service.dart # External communication
├── screens/                     # UI screens
│   ├── auth/                   # Authentication screens
│   │   ├── welcome_screen.dart
│   │   ├── login_screen.dart
│   │   └── register_screen.dart
│   ├── customer/               # Customer screens
│   │   └── customer_home_screen.dart
│   ├── manager/                # Property manager screens
│   │   └── manager_dashboard_screen.dart
│   └── owner/                  # Property owner screens
│       └── owner_dashboard_screen.dart
└── utils/                       # Utilities & constants
    ├── app_theme.dart          # App theme & colors
    └── app_constants.dart      # Constants & configurations
```

## 🚀 Getting Started

### Prerequisites
- Flutter SDK (3.10.4 or higher)
- Dart SDK
- Firebase account (for backend)
- Android Studio / VS Code
- Android/iOS emulator or physical device

### Installation

1. **Clone the repository**
   ```bash
   git clone <your-repo-url>
   cd true_home
   ```

2. **Install dependencies**
   ```bash
   flutter pub get
   ```

3. **Firebase Setup** (Required)
   
   a. Create a Firebase project at https://console.firebase.google.com
   
   b. Add Android app:
      - Package name: `com.example.true_home` (or your package name)
      - Download `google-services.json`
      - Place it in `android/app/`
   
   c. Add iOS app (if targeting iOS):
      - Bundle ID: `com.example.trueHome` (or your bundle ID)
      - Download `GoogleService-Info.plist`
      - Place it in `ios/Runner/`
   
   d. Enable Firebase services:
      - **Authentication**: Enable Email/Password sign-in
      - **Cloud Firestore**: Create database in production mode
      - **Storage**: Enable for image/video uploads
   
   e. Firestore Security Rules (initial setup):
   ```javascript
   rules_version = '2';
   service cloud.firestore {
     match /databases/{database}/documents {
       match /{document=**} {
         allow read, write: if request.auth != null;
       }
     }
   }
   ```
   
   f. Storage Security Rules:
   ```javascript
   rules_version = '2';
   service firebase.storage {
     match /b/{bucket}/o {
       match /{allPaths=**} {
         allow read, write: if request.auth != null;
       }
     }
   }
   ```

4. **Configure Firebase in the app**
   
   Run the FlutterFire CLI:
   ```bash
   # Install FlutterFire CLI
   dart pub global activate flutterfire_cli
   
   # Configure Firebase
   flutterfire configure
   ```
   
   Then uncomment the Firebase initialization in [lib/main.dart](lib/main.dart):
   ```dart
   await Firebase.initializeApp();
   ```

5. **Run the app**
   ```bash
   flutter run
   ```

## 📦 Key Dependencies

- `firebase_core`: Firebase initialization
- `firebase_auth`: User authentication
- `cloud_firestore`: Database
- `firebase_storage`: File storage
- `provider`: State management
- `google_maps_flutter`: Map integration
- `url_launcher`: Phone/WhatsApp/Email integration
- `image_picker`: Image selection
- `cached_network_image`: Image caching
- `carousel_slider`: Image carousels
- `geolocator`: Location services
- `intl`: Internationalization

## 🎨 Design

The app uses a modern, clean design with:
- **Primary Color**: Blue (#2563EB)
- **Secondary Color**: Green (#10B981)
- **Accent Color**: Amber (#F59E0B)
- Material Design 3 components
- Custom color scheme for property types:
  - Rentals: Purple
  - Condos: Pink
  - Hostels: Cyan

## 🔐 User Roles

1. **Customer**: Browse and inquire about properties
2. **Property Manager**: Manage properties and respond to requests
3. **Property Owner**: Submit properties for approval
4. **Admin**: Review submissions and moderate content

## 🌟 Key Features

### No In-App Payments
The app focuses on connecting users with property managers. All payment transactions happen outside the app.

### Communication Channels
- Direct phone calls
- WhatsApp integration
- Email support
- In-app messaging

### Property Submission Workflow
1. Property owner submits property details
2. Admin reviews submission
3. Admin approves/rejects
4. If approved, property appears in listings
5. Owner gets notified of status

## 🔧 Development Status

### ✅ Completed
- Project structure
- Data models
- Service layer
- Authentication screens
- Basic customer UI
- Manager & owner dashboards
- Theme & styling

### 🚧 To Be Implemented
- Property details screen
- Search & filters functionality
- Tour scheduling UI
- Contact form implementation
- Favorites functionality
- Property submission form
- Admin approval interface
- Image upload UI
- Map integration
- Notifications
- User profile management

## 📱 Screenshots

(Add screenshots here once the app UI is complete)

## 🤝 Contributing

1. Fork the project
2. Create your feature branch (`git checkout -b feature/AmazingFeature`)
3. Commit your changes (`git commit -m 'Add some AmazingFeature'`)
4. Push to the branch (`git push origin feature/AmazingFeature`)
5. Open a Pull Request

## 📄 License

This project is licensed under the MIT License - see the LICENSE file for details.

## 👥 Contact

For support or inquiries:
- Email: support@truehome.com
- Phone: +1234567890

## 🙏 Acknowledgments

- Flutter team for the amazing framework
- Firebase for backend services
- All contributors to the open-source packages used

---

**Note**: Remember to set up Firebase before running the app. The app will not function without proper Firebase configuration.

