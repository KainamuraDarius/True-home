# True Home - Real Estate & Property Development Platform

A comprehensive Flutter platform connecting property seekers, real estate agents, property managers, and developers for rentals, property sales, hostel bookings, and real estate project discovery.

## 🎯 Platform Overview

**True Home** is a multi-role real estate platform with three main product categories:
1. **Properties** - Rentals, condos, and student hostels
2. **Projects** - Real estate development projects with Pandora payments integration
3. **Agents** - Verified property agents with ratings and verification system

---

## 📱 Core Features by User Role

### 👥 Customers
- **Browse Properties**: Rentals, condos, student hostels with detailed info
- **Explore Projects**: Real estate development projects by verified developers
- **Find Agents**: Discover and rate property agents
- **Schedule Tours**: Book property viewings with managers
- **Make Reservations**: Book hostel rooms directly (with Pandora payments)
- **Query Properties**: Multiple contact methods (call, WhatsApp, email, in-app form)
- **Favorites**: Save properties and projects for later

### 🏢 Property Managers
- **Property Management**: Add, edit, delete rental properties and condos
- **Hostel Management**: Manage hostel properties and room availability
- **Request Handling**: Respond to tour requests and customer inquiries
- **Dashboard Analytics**: Track property views and booking requests
- **Featured Promotions**: Promote properties using Pandora payments (UGX 200K)

### 🏭 Project Developers/Agents
- **Project Submission**: Submit real estate development projects for approval
- **Project Details**: Include location, pricing, status, amenities, and photos
- **Payment Integration**: Pay project advertising fee via Pandora (UGX 400K)
- **Agent Verification**: Verify status and access analytics
- **Dashboard**: Track submitted projects and performance metrics

### 🛡️ Admins
- **Content Review**: Approve/reject property submissions and projects
- **User Management**: Manage all users and their roles
- **Admin Panel**: Full system analytics and monitoring
- **Hostel Management**: Create and manage hostel properties
- **Verification Control**: Approve/reject agent verification requests
- **Notifications**: Send system-wide announcements to users
- **Trash Management**: Archive or permanently delete content

## 🏗️ Project Architecture

```
lib/
├── main.dart                              # App entry point (Customer/Agent/Manager)
├── main_admin.dart                        # Admin panel entry point
│
├── models/                                # Data Models (9 files)
│   ├── user_model.dart                   # User accounts with roles
│   ├── property_model.dart               # Properties (rentals, condos, hostels)
│   ├── project_model.dart                # Real estate development projects
│   ├── reservation_model.dart            # Hostel room reservations
│   ├── tour_request.dart                 # Property tour appointments
│   ├── contact_request.dart              # Customer inquiries
│   ├── property_submission.dart          # Property approval workflow
│   ├── agent_rating_model.dart           # Agent ratings and reviews
│   └── ... (additional models)
│
├── screens/                               # UI Screens (35+ screens)
│   │
│   ├── auth/                             # Authentication (4 screens)
│   │   ├── welcome_screen.dart
│   │   ├── login_screen.dart
│   │   ├── register_screen.dart
│   │   └── admin_login_screen.dart
│   │
│   ├── customer/                         # Customer Features (10 screens)
│   │   ├── customer_home_screen.dart
│   │   ├── all_projects_screen.dart
│   │   ├── project_details_screen.dart
│   │   ├── reserve_room_screen.dart
│   │   ├── find_agents_screen.dart
│   │   ├── agent_profile_screen.dart
│   │   ├── rate_agent_screen.dart
│   │   ├── become_agent_screen.dart
│   │   ├── edit_profile_screen.dart
│   │   └── reservation_confirmation_screen.dart
│   │
│   ├── property/                         # Property Management (6 screens)
│   │   ├── my_properties_screen.dart
│   │   ├── add_property_screen.dart
│   │   ├── edit_property_screen.dart
│   │   ├── agent_property_details_screen.dart
│   │   ├── property_details_screen.dart
│   │   └── property_review_screen.dart
│   │
│   ├── owner/                            # Agent/Developer Management (5 screens)
│   │   ├── agent_main_screen.dart
│   │   ├── agent_verification_screen.dart
│   │   ├── owner_dashboard_screen.dart
│   │   ├── verification_benefits_screen.dart
│   │   └── verification_document_upload_screen.dart
│   │
│   ├── common/                           # Shared Features (3 screens)
│   │   ├── submit_project_screen.dart
│   │   └── ... (common screens)
│   │
│   ├── admin/                            # Admin Panel (18 screens)
│   │   ├── admin_panel_screen.dart
│   │   ├── admin_dashboard_screen.dart
│   │   ├── admin_projects_screen.dart
│   │   ├── admin_properties_screen.dart
│   │   ├── admin_reservations_screen.dart
│   │   ├── admin_users_screen.dart
│   │   ├── admin_verification_requests_screen.dart
│   │   ├── admin_verified_agents_screen.dart
│   │   ├── manage_hostels_screen.dart
│   │   ├── manage_room_availability_screen.dart
│   │   ├── send_notification_screen.dart
│   │   ├── admin_trash_screen.dart
│   │   ├── property_review_screen.dart
│   │   └── ... (additional admin screens)
│   │
│   ├── plan/                             # Subscription/Plan (2 screens)
│   │   ├── plan_benefits_screen.dart
│   │   └── plan_selection_screen.dart
│   │
│   ├── manager/                          # Manager Features
│   │   └── manager_dashboard_screen.dart
│   │
│   ├── organization/                     # Organization Management
│   │   └── ... (org screens)
│   │
│   ├── agent/                            # Agent Management
│   │   └── ... (agent screens)
│   │
│   ├── maintenance_screen.dart           # Maintenance mode
│   └── (35+ total screens)
│
├── services/                              # Business Logic (27 services)
│   │
│   ├── auth_service.dart                 # Firebase authentication
│   ├── auth_action_link_service.dart     # Email action links
│   ├── auth_service_old_backend.dart     # Legacy backend (deprecated)
│   │
│   ├── property_service.dart             # Property CRUD & search
│   ├── property_submission_service.dart  # Property approval workflow
│   ├── tour_service.dart                 # Tour request management
│   ├── contact_service.dart              # Contact inquiry handling
│   ├── room_availability_service.dart    # Hostel room availability
│   │
│   ├── pandora_payment_service.dart      # 🔑 Pandora payments API
│   ├── mtn_momo_service.dart             # ⚠️ Deprecated
│   ├── airtel_money_service.dart         # ⚠️ Deprecated alternative
│   │
│   ├── project_service.dart              # Project CRUD & management
│   ├── agent_rating_service.dart         # Agent ratings system
│   │
│   ├── fcm_service.dart                  # Firebase Cloud Messaging
│   ├── notification_service.dart         # Local notifications
│   ├── scheduled_notification_service.dart # Scheduled notifications
│   │
│   ├── storage_service.dart              # Firebase Storage handling
│   ├── email_verification_service.dart   # Account verification
│   │
│   ├── preferences_service.dart          # Local preferences
│   ├── role_service.dart                 # Role-based access control
│   ├── organization_access_service.dart  # Organization management
│   ├── organization_invite_service.dart  # Org invitations
│   ├── post_auth_intent_service.dart     # Auth deep linking
│   ├── url_launcher_service.dart         # Phone/WhatsApp/Email/Maps
│   ├── view_tracking_service.dart        # Property view analytics
│   ├── maintenance_service.dart          # App maintenance mode
│   │
│   └── api_service.dart                  # HTTP client wrapper
│
├── widgets/                               # Reusable Components
│   ├── web_footer.dart
│   └── ... (custom widgets)
│
├── config/                                # Configuration
│   ├── firebase_options.dart             # Firebase initialization
│   └── ... (config files)
│
└── utils/                                 # Utilities
    ├── app_theme.dart                    # Theme & colors
    ├── app_constants.dart                # App-wide constants
    ├── currency_formatter.dart           # Currency utilities
    └── ... (helper utilities)

backend/                                   # Node.js Backend Server
├── server.js                             # Express API server
├── package.json
└── (PostgreSQL integration)

functions/                                 # Firebase Cloud Functions
├── index.js                              # Main functions
├── pandora_payment.js                    # Payment gateway proxy
├── pandora_payment_status.js             # Payment status checker
├── set_admin_role.js                     # Admin role management
└── package.json

android/, ios/, web/, linux/, macos/, windows/  # Platform-specific code
```

## 🔧 Active Services Summary

### ✅ Currently Active
- **Pandora Payments**: Hostel reservations & project advertising payments
- **Firebase**: Auth, Firestore, Storage, Cloud Functions, FCM
- **Google Maps**: Location and property mapping
- **Local Storage**: Preferences, draft auto-save
- **Email/Notifications**: FCM + Local notifications

### ⚠️ Deprecated (Not Used)
- **MTN MOMO**: Replaced by Pandora Payments
- **Airtel Money**: Replaced by Pandora Payments  
- **IMGBB**: Replaced by Firebase Storage
- **PostgreSQL Backend**: Partially deprecated, Firebase primary

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

