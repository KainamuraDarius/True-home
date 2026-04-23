# True Home - Current Project Structure (Updated 2026-04-22)

This document reflects the **actual current state** of the True Home project, NOT previous iterations.

---

## 📋 Executive Summary

**True Home** is a Flutter-based real estate platform with:
- ✅ **Multi-role system**: Customers, Agents, Developers, Managers, Admins
- ✅ **Three product categories**: Properties, Projects, Agents
- ✅ **Payment integration**: Pandora Payments (UGX 200K for property promotion, UGX 400K for project advertising)
- ✅ **Advanced features**: Agent verification, ratings, hostel management, reservations
- ✅ **Admin panel**: Full system management and analytics

---

## 📁 File Structure Overview

```
lib/
├── main.dart                              # ⭐ Customer/Agent/Manager app entry
├── main_admin.dart                        # ⭐ Admin panel entry
│
├── models/ (9 models)                    # Data structures
│   ├── user_model.dart                   # User with role-based fields
│   ├── property_model.dart               # Property (rental/condo/hostel)
│   ├── project_model.dart                # Real estate development project
│   ├── reservation_model.dart            # Hostel room reservation
│   ├── tour_request.dart                 # Tour request/appointment
│   ├── contact_request.dart              # Customer inquiry
│   ├── property_submission.dart          # Property for admin approval
│   ├── agent_rating_model.dart           # Agent reviews/ratings
│   └── ... (other models)
│
├── screens/ (35+ screens)                # User Interface
│   ├── auth/                             # Authentication
│   │   ├── welcome_screen.dart
│   │   ├── login_screen.dart
│   │   ├── register_screen.dart
│   │   └── admin_login_screen.dart
│   │
│   ├── customer/                         # Customer features
│   │   ├── customer_home_screen.dart     # Main browsing interface
│   │   ├── all_projects_screen.dart      # Browse real estate projects
│   │   ├── project_details_screen.dart   # Project details view
│   │   ├── find_agents_screen.dart       # Agent discovery
│   │   ├── agent_profile_screen.dart     # Agent information
│   │   ├── rate_agent_screen.dart        # Leave agent reviews
│   │   ├── become_agent_screen.dart      # Convert to agent
│   │   ├── reserve_room_screen.dart      # Hostel reservation + Pandora payment
│   │   ├── reservation_confirmation_screen.dart
│   │   └── edit_profile_screen.dart
│   │
│   ├── property/                         # Property management
│   │   ├── my_properties_screen.dart
│   │   ├── add_property_screen.dart
│   │   ├── edit_property_screen.dart
│   │   ├── property_details_screen.dart
│   │   ├── agent_property_details_screen.dart
│   │   └── property_review_screen.dart
│   │
│   ├── owner/                            # Agent/Developer features
│   │   ├── agent_main_screen.dart
│   │   ├── owner_dashboard_screen.dart
│   │   ├── agent_verification_screen.dart
│   │   ├── verification_benefits_screen.dart
│   │   └── verification_document_upload_screen.dart
│   │
│   ├── common/                           # Shared screens
│   │   ├── submit_project_screen.dart    # Submit projects + Pandora payment
│   │   └── ... (other common)
│   │
│   ├── admin/                            # Admin panel (18+ screens)
│   │   ├── admin_panel_screen.dart       # Admin main dashboard
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
│   │   └── ... (more admin screens)
│   │
│   ├── plan/                             # Plans/Subscriptions
│   │   ├── plan_benefits_screen.dart
│   │   └── plan_selection_screen.dart
│   │
│   ├── manager/
│   ├── organization/
│   ├── agent/
│   ├── maintenance_screen.dart           # Maintenance mode
│   └── ... (35+ total screens)
│
├── services/ (27 active services)        # Business Logic
│   │
│   ├─ Authentication
│   │   ├── auth_service.dart             # ✅ Firebase Auth
│   │   ├── auth_action_link_service.dart # Email action links
│   │   └── auth_service_old_backend.dart # ⚠️ Legacy (deprecated)
│   │
│   ├─ Property Management
│   │   ├── property_service.dart         # ✅ Property CRUD
│   │   ├── property_submission_service.dart # ✅ Approval workflow
│   │   ├── tour_service.dart             # ✅ Tour scheduling
│   │   ├── contact_service.dart          # ✅ Inquiries
│   │   └── room_availability_service.dart # ✅ Hostel rooms
│   │
│   ├─ Payment & Transactions
│   │   ├── pandora_payment_service.dart  # ✅ PRIMARY: UGX payments
│   │   ├── mtn_momo_service.dart         # ⚠️ DEPRECATED
│   │   └── airtel_money_service.dart     # ⚠️ DEPRECATED
│   │
│   ├─ Projects & Agents
│   │   ├── project_service.dart          # ✅ Project CRUD
│   │   └── agent_rating_service.dart     # ✅ Agent ratings
│   │
│   ├─ Notifications
│   │   ├── fcm_service.dart              # ✅ Firebase Cloud Messaging
│   │   ├── notification_service.dart     # ✅ Local notifications
│   │   └── scheduled_notification_service.dart # ✅ Scheduled
│   │
│   ├─ Storage & Persistence
│   │   ├── storage_service.dart          # ✅ Firebase Storage images
│   │   ├── preferences_service.dart      # ✅ Local preferences
│   │   └── email_verification_service.dart # ✅ Account verification
│   │
│   ├─ Access & Organization
│   │   ├── role_service.dart             # ✅ Role-based control
│   │   ├── organization_access_service.dart # ✅ Org management
│   │   └── organization_invite_service.dart # ✅ Org invites
│   │
│   ├─ Utilities
│   │   ├── url_launcher_service.dart     # ✅ Call/WhatsApp/Email/Maps
│   │   ├── view_tracking_service.dart    # ✅ Analytics
│   │   ├── post_auth_intent_service.dart # ✅ Deep linking
│   │   ├── maintenance_service.dart      # ✅ App maintenance mode
│   │   └── api_service.dart              # ✅ HTTP client wrapper
│
├── widgets/                              # Reusable UI Components
│   ├── web_footer.dart
│   └── ... (custom widgets)
│
├── config/                               # Configuration
│   ├── firebase_options.dart             # ✅ Firebase setup
│   └── api_config.dart                   # ✅ API configuration
│
└── utils/                                # Utilities
    ├── app_theme.dart                    # ✅ Theme & colors
    ├── app_constants.dart                # ✅ App constants
    ├── currency_formatter.dart           # ✅ UGX formatting
    └── ... (helper utilities)

backend/                                   # Node.js Backend Server
├── server.js                             # Express API
├── connect_db.sh                         # DB connection script
├── start.sh                              # Startup script
├── package.json
└── (PostgreSQL)

functions/                                 # Firebase Cloud Functions
├── index.js                              # Main entry
├── pandora_payment.js                    # ✅ Payment API proxy
├── pandora_payment_status.js             # ✅ Status checker
├── set_admin_role.js                     # ✅ Admin role assignment
├── add_admin_role.js
└── package.json

android/, ios/, web/, linux/, macos/, windows/
├── Platform-specific implementations
└── Firebase config files
```

---

## 🔑 Key Integration Points

### 1. **Authentication**
- **Provider**: Firebase Auth (email/password)
- **Services**: `auth_service.dart`, `auth_action_link_service.dart`
- **Features**: Role-based login, deep linking support, email verification

### 2. **Payment Processing** ✅
- **Primary**: Pandora Payments API
- **Service**: `pandora_payment_service.dart`
- **Usage**:
  - Hostel reservations: UGX 200,000 one-time
  - Project advertising: UGX 400,000 per project
  - Property promotion: UGX 200,000 featured boost
- **Cloud Functions**: `pandora_payment.js`, `pandora_payment_status.js`

### 3. **Cloud Storage**
- **Provider**: Firebase Storage
- **Service**: `storage_service.dart`
- **Usage**: Property images, project images, user avatars
- **Replaces**: IMGBB (deprecated)

### 4. **Database**
- **Primary**: Firestore (real-time)
- **Collections**: users, properties, projects, reservations, agents, etc.
- **Secondary**: PostgreSQL via Node.js backend (optional)

### 5. **Notifications**
- **Push**: Firebase Cloud Messaging (FCM)
- **Local**: Flutter Local Notifications
- **Scheduled**: Custom scheduler in `scheduled_notification_service.dart`

### 6. **Mapping**
- **Provider**: Google Maps Flutter
- **Usage**: Property location display, agent search by location

---

## 📊 Data Models Summary

| Model | Purpose | Status |
|-------|---------|--------|
| `user_model.dart` | User accounts, roles | ✅ Active |
| `property_model.dart` | Rentals, condos, hostels | ✅ Active |
| `project_model.dart` | Real estate projects | ✅ Active |
| `reservation_model.dart` | Hostel bookings | ✅ Active |
| `tour_request.dart` | Property viewing requests | ✅ Active |
| `contact_request.dart` | Customer inquiries | ✅ Active |
| `property_submission.dart` | Admin approval workflow | ✅ Active |
| `agent_rating_model.dart` | Agent reviews | ✅ Active |

---

## 🚀 Active Features

### ✅ Implemented & Live
- User authentication with 4 roles
- Property browsing (rentals, condos, hostels)
- Project discovery and submission
- Agent verification and ratings
- Hostel reservations with Pandora payments
- Property promotion with Pandora payments
- Admin management panel
- Tour request scheduling
- Contact inquiry system
- FCM + local notifications
- Role-based access control

### ⚠️ Removed/Deprecated
- ~~MTN MOMO payments~~ → Use Pandora
- ~~Airtel Money~~ → Use Pandora
- ~~IMGBB image hosting~~ → Use Firebase Storage
- ~~PostgreSQL backend~~ → Primary: Firebase

---

## 📚 Documentation Files Status

| File | Status | Purpose |
|------|--------|---------|
| README.md | ✅ Updated | Project overview |
| STRUCTURE_CURRENT.md | ✅ Current | This file - actual structure |
| PROJECT_SUMMARY.md | ⚠️ Old | Original design doc |
| API_REFERENCE.md | ⚠️ Partial | API documentation |
| TRUE_HOME_TEST_CASE_DIAGRAM.md | ✅ New | Test workflows |
| BACKEND_SETUP.md | ⚠️ Reference | Backend configuration |
| ADMIN_SETUP_GUIDE.md | ✅ Valid | Admin guide |
| IOS_BUILD_GUIDE.md | ✅ Valid | iOS build process |
| PLAY_STORE_UPLOAD_GUIDE.md | ✅ Valid | Android deployment |
| **MTN_MOMO_SETUP.md** | ⛔ DELETE | Obsolete |
| **GET_MTN_CREDENTIALS.md** | ⛔ DELETE | Obsolete |
| **EMAIL_TO_MTN.txt** | ⛔ DELETE | Obsolete |
| **IMGBB_SETUP.md** | ⛔ DELETE | Obsolete |
| **IMGBB_INTEGRATION.md** | ⛔ DELETE | Obsolete |
| **PANDORA_IMPLEMENTATION_SUMMARY.md** | ⛔ DELETE | Redundant |
| **PANDORA_PAYMENTS_FIXED.md** | ⛔ DELETE | Redundant |

---

## 🧹 Cleanup Recommendations

### 🗑️ Files to Delete

**Obsolete Integration Docs** (Replaced by Pandora):
- `MTN_MOMO_SETUP.md`
- `GET_MTN_CREDENTIALS.md`
- `EMAIL_TO_MTN.txt`
- `IMGBB_INTEGRATION.md`
- `IMGBB_SETUP.md`

**Redundant Pandora Docs** (Keep only one consolidated):
- `PANDORA_IMPLEMENTATION_SUMMARY.md` (duplicate info)
- `PANDORA_PAYMENTS_FIXED.md` (old fixes, covered in SETUP_CHECKLIST)

**Obsolete Test Files** (Root directory):
- `test_auth_methods.dart`
- `test_detailed_diag.dart`
- `test_pandora_credentials.dart`
- `test_pandora_payment.dart`
- `setup_airtel.dart` (in root and android/)
- `test_mtn_connection.dart` (android/)
- `try_alternative_setup.dart` (android/)

**Obsolete Setup Scripts**:
- `prepare_play_store_assets.sh`
- `setup_icon.sh`
- `resize_icon.dart`
- `create_default_icon.dart`
- `update_storage_rules.sh`
- `setup_airtel.dart`

---

## 🎯 Project Health Status

| Aspect | Status | Notes |
|--------|--------|-------|
| **Codebase** | ✅ Current | All active services documented |
| **Documentation** | ⚠️ Needs cleanup | Remove 15+ obsolete files |
| **Dependencies** | ✅ Updated | pubspec.yaml v1.0.8+108 |
| **Payment System** | ✅ Pandora | Fully integrated |
| **Database** | ✅ Firestore | Primary, PostgreSQL fallback |
| **Deployment** | ✅ Ready | Android & iOS ready |

---

## 📝 Next Steps

1. ✅ Update README with current features
2. ✅ Create STRUCTURE_CURRENT.md (this file)
3. ⏳ Delete 15+ obsolete MD files
4. ⏳ Delete 8+ obsolete test files
5. ⏳ Remove deprecated service templates
6. ⏳ Update NEXT_STEPS.md with current roadmap

---

*Last Updated: 22 April 2026*
