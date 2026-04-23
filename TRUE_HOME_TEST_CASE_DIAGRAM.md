@startuml
title True Home - System Testing Workflow (Actual Project Structure)

start

|Admin|
start

' ═════════════════════════════════════════════════════════════
' PHASE 1: SYSTEM INITIALIZATION & USER REGISTRATION
' ═════════════════════════════════════════════════════════════
:Admin: Log in via admin_login_screen.dart;
:Admin: Access admin_panel_screen.dart;
:Admin: Configure system settings\n<i>Firestore + Firebase</i>;

|Customer/Agent|
:User: Visit welcome_screen.dart;
:User: Register on register_screen.dart\n<i>Email/Password + Role Selection</i>;
:User: Select role\n<i>Customer, Agent, Manager, or try both</i>;
:User: Log in via login_screen.dart;

|System|
:Firebase: Create user auth account;
:Firebase: Create user document in Firestore;
:Firebase: Set user role and profile;
:FCM: Initialize push notifications;
:Notification: Send welcome message;

' ═════════════════════════════════════════════════════════════
' PHASE 2A: PROPERTY SUBMISSION WORKFLOW
' ═════════════════════════════════════════════════════════════
|Property Owner|
:Owner: Access owner_dashboard_screen.dart;
:Owner: Click \"Submit Property\";
note right
  Data Model: property_submission.dart
  Service: property_submission_service.dart
end note

|Owner: Add Property|
:Owner: Fill add_property_screen.dart\n<i>Type: Rental/Condo/Hostel</i>;
:Owner: Enter property details\n<i>Name, Location, Price, Rooms, Bathrooms</i>;
:Owner: Upload images via image_picker\n<i>Min 3 required via Firebase Storage</i>;
:Owner: Set amenities & description;
:Owner: Submit for approval;

|System|
:Create PropertySubmission record (pending);
:Save images to Firebase Storage;
:Save to Firestore: properties collection;
:Notify admin_projects_screen.dart;
note right
  Status: pending
  Service: storage_service.dart
end note

' ─── Admin Review Property ──────────────
|Admin|
:Admin: View admin_properties_screen.dart;
:Admin: Review pending properties;

if (Property valid?) then (✅ Yes)

  |Admin|
  :Verify photos quality;
  :Check location accuracy;
  :Approve via property_review_screen.dart;

  |System|
  :Update status → approved;
  :Make visible in customer listings;
  :Send FCM notification to owner;
  :Update property_model.dart status;

else (❌ No)

  |Admin|
  :Review rejection reasons;
  :Reject with feedback;

  |System|
  :Update status → rejected;
  :Store rejection reason;
  :Send FCM to owner;
  
  |Owner|
  :Receive rejection notification;
  :Edit via edit_property_screen.dart;
  :Resubmit property;

endif

' ═════════════════════════════════════════════════════════════
' PHASE 2B: PROJECT SUBMISSION WORKFLOW (Real Estate Projects)
' ═════════════════════════════════════════════════════════════
|Developer|
:Developer: Access agent_main_screen.dart;
:Developer: Click \"Submit Project\";
note right
  Data Model: project_model.dart
  Service: project_service.dart
end note

|Developer: Submit Project|
:Developer: Fill submit_project_screen.dart;
:Developer: Enter project details\n<i>Name, Status, Location, Price Range</i>;
:Developer: Upload project images\n<i>3+ images via Firebase Storage</i>;
:Developer: Add company info\n<i>Name, Website, Phone, Email</i>;
:Developer: Choose advertising plan;

if (Want to advertise?) then (✅ Pay Now)

  |Developer|
  :Click \"Advertise Project\";
  :Amount: UGX 400,000;
  note right
    Payment: Pandora Payments API
    Service: pandora_payment_service.dart
  end note

  |System|
  :Initialize Pandora payment;
  :Generate payment request;

  |Developer|
  :Enter 4-digit PIN;

  |System|
  note right
    Endpoint: pandora_payment.js
    Gateway: Pandora Payments API
    Status: Processing...
  end note
  :Call Pandora API via Cloud Function;

  if (Payment success?) then (✅ Confirmed)

    |System|
    :Save _developerAdvertisingPaymentReference;
    :Set _developerAdvertisingAccessMode = 'paid';
    :Enable advertising features;
    :Mark project as \"Featured\";

  else (❌ Failed)

    |System|
    :Log payment error;
    :Send error notification;
    :Offer retry option;

  endif

else (⏭️ Skip)

  |Developer|
  :Submit without advertising;

endif

:Developer: Submit project;

|System|
:Create ProjectSubmission record (pending);
:Save project to Firestore;
:Notify admin_projects_screen.dart;

' ─── Admin Review Project ──────────────
|Admin|
:Admin: View admin_projects_screen.dart;
:Admin: Review pending projects;

if (Project valid?) then (✅ Yes)

  |Admin|
  :Approve project;

  |System|
  :Update status → approved;
  :Make visible in all_projects_screen.dart;
  :Send FCM to developer;

else (❌ No)

  |Admin|
  :Reject project;

  |System|
  :Update status → rejected;
  :Send FCM to developer;

endif

' ═════════════════════════════════════════════════════════════
' PHASE 3: AGENT VERIFICATION & RATING SYSTEM
' ═════════════════════════════════════════════════════════════
|Agent/Developer|
:Agent: Access agent_verification_screen.dart;
:Agent: View verification_benefits_screen.dart;
:Agent: Upload verification documents\n<i>via verification_document_upload_screen.dart</i>;
note right
  Data Model: agent_rating_model.dart
  Service: agent_rating_service.dart
end note

|System|
:Create verification request;
:Save documents to Firebase Storage;
:Notify admin_verification_requests_screen.dart;

|Admin|
:Admin: Review verification requests;

if (Documents valid?) then (✅ Verified)

  |Admin|
  :Approve agent verification;

  |System|
  :Add agent to verified list;
  :Update admin_verified_agents_screen.dart;
  :Enable enhanced profile visibility;
  :Send FCM to agent;

else (❌ Insufficient)

  |Admin|
  :Request additional docs;

endif

' ─── Customer Rates Agent ──────────────
|Customer|
:Customer: Complete booking with agent;
:Customer: Access rate_agent_screen.dart;
:Customer: Leave rating & review\n<i>Stars + Comments</i>;

|System|
:Save rating to agent_rating_model;
:Update agent average rating;
:Increment review count;
:Update agent profile visibility;

' ═════════════════════════════════════════════════════════════
' PHASE 4: CUSTOMER DISCOVERY & BROWSING
' ═════════════════════════════════════════════════════════════
|Customer|
:Customer: Open customer_home_screen.dart;
note right
  Service: view_tracking_service.dart
  Database: Firestore (properties, projects)
end note
:Customer: View featured properties carousel;
:Customer: Browse properties grid;

if (Browse what?) then (🏠 Properties)

  |Customer|
  :Tap property card;
  :View agent_property_details_screen.dart\n<i>Photos, Price, Location, Amenities</i>;

else if (🏢 Projects)

  |Customer|
  :Access all_projects_screen.dart;
  :Tap project;
  :View project_details_screen.dart;

else (👥 Agents)

  |Customer|
  :Access find_agents_screen.dart;
  :View verified agents with ratings;
  :Tap agent_profile_screen.dart;

endif

|Customer|
if (Use filters?) then (✅ Yes)

  |Customer|
  :Apply filters\n<i>Location, Price, Type, Status</i>;
  :Sort by rating/price/new;

endif

|System|
:Record view via view_tracking_service.dart;
:Update property view count;

' ═════════════════════════════════════════════════════════════
' PHASE 5: CUSTOMER INTERACTION (Multi-Channel)
' ═════════════════════════════════════════════════════════════
|Customer|
:Customer: On property/project details screen;
:Customer: Choose contact method;

if (Contact via?) then (📞 Call)

  |Customer|
  :Tap \"Call\" button;
  :Service: url_launcher_service.dart;
  :Initiate phone call;

else if (💬 WhatsApp)

  |Customer|
  :Tap \"WhatsApp\";
  :Open WhatsApp with agent;

else if (📧 Email)

  |Customer|
  :Tap \"Email\";
  :Send inquiry email;

else (📝 In-App Form)

  |Customer|
  :Fill inquiry form;
  :Include mobile number & message;

endif

|System|
:Create contact_request record;
note right
  Data Model: contact_request.dart
  Service: contact_service.dart
end note
:Save to Firestore contacts collection;
:Send FCM to property manager;
:Send email notification if applicable;

|Property Manager|
:Manager: Receive notification;
:Manager: View pending inquiries;
:Manager: Respond to customer;

' ═════════════════════════════════════════════════════════════
' PHASE 6: HOSTEL RESERVATIONS (With Pandora Payment)
' ═════════════════════════════════════════════════════════════
|Customer|
:Customer: Browse hostel properties;
:Customer: Select hostel;
:Customer: Click \"Reserve Room\";

|System|
:Load hostel room data;
note right
  Screen: reserve_room_screen.dart
  Service: room_availability_service.dart
  Model: reservation_model.dart
end note

|Customer: Reserve|
:Fill reservation form\n<i>Name, Email, Phone Number</i>;
:Select check-in/check-out dates;
:Select room type & quantity;
:Review total amount (UGX);

|System|
:Calculate total price;
:Display reservation summary;
:Initialize Pandora payment;
note right
  Service: pandora_payment_service.dart
  Amount: Property-dependent (typical: 200K+)
end note

|Customer|
:Tap \"Proceed to Payment\";

|System|
:Call pandora_payment.js Cloud Function;
:Send initiate request to Pandora API;
:Display PIN entry dialog;

|Customer|
:Enter 4-digit PIN\n<i>Provided by MTN/provider</i>;

|System|
:Call Pandora confirm endpoint;
:Validate PIN;

if (Payment accepted?) then (✅ Success)

  |System|
  :Save transaction ID to reservation;
  :Create reservation_model record;
  :Update room availability;
  :Reduce available rooms;
  :Update Firestore rooms data;
  :Show reservation_confirmation_screen.dart;
  :Send FCM to customer & manager;
  :Send confirmation email;

else (❌ Failed)

  |System|
  :Log payment error;
  :Show error message;
  :Restore room availability;
  :Offer retry or alternative;

endif

|Property Manager|
:Manager: View admin_reservations_screen.dart;
:Manager: See pending reservations;
:Manager: Confirm/prepare rooms;

' ═════════════════════════════════════════════════════════════
' PHASE 7: TOUR SCHEDULING
' ═════════════════════════════════════════════════════════════
|Customer|
:Customer: On property details;
:Customer: Tap \"Schedule Tour\";
note right
  Data Model: tour_request.dart
  Service: tour_service.dart
end note

|Customer|
:Select preferred date & time;
:Add tour notes (optional);
:Confirm tour request;

|System|
:Create tour_request record;
:Set status = pending;
:Send FCM to property manager;
:Send email notification;

|Property Manager|
:Manager: Receive tour notification;
:Manager: View tour requests in app;

if (Can accommodate?) then (✅ Yes)

  |Property Manager|
  :Confirm tour;
  :Send confirmation to customer;

  |System|
  :Update tour status → confirmed;
  :Send reminder before tour date;

else (❌ No)

  |Property Manager|
  :Decline tour;
  :Suggest alternative times;

  |System|
  :Update tour status → rejected;
  :Notify customer;

endif

' ═════════════════════════════════════════════════════════════
' PHASE 8: PROPERTY PROMOTION (Paid Feature)
' ═════════════════════════════════════════════════════════════
|Property Manager|
:Manager: Access my_properties_screen.dart;
:Manager: View property list;
:Manager: Click \"Promote\" on property;
note right
  Service: pandora_payment_service.dart
  Amount: UGX 200,000 for 30 days
end note

|Manager: Payment Flow|
:Display promotion options;

if (Featured boost?) then (✅ Enable)

  |Manager|
  :Cost: UGX 200,000 (30 days);
  :Click \"Promote Now\";

  |System|
  :Initialize Pandora payment;

  |Manager|
  :Enter 4-digit PIN;

  |System|
  :Process via Pandora API;

  if (Payment success?) then (✅ Approved)

    |System|
    :Mark property as featured;
    :Boost visibility in listings;
    :Prioritize in search results;
    :Set 30-day expiry timer;
    :Send confirmation to manager;

  else (❌ Failed)

    |System|
    :Log transaction failure;
    :Send error notification;

  endif

else (⏭️ Skip)

endif

' ═════════════════════════════════════════════════════════════
' PHASE 9: ADMIN MANAGEMENT & CONTROL
' ═════════════════════════════════════════════════════════════
|Admin|
:Admin: Access admin_dashboard_screen.dart;
:Admin: View system statistics;

note right
  Screens:
  • admin_properties_screen.dart
  • admin_projects_screen.dart
  • admin_reservations_screen.dart
  • admin_users_screen.dart
  • manage_hostels_screen.dart
  • send_notification_screen.dart
  • admin_trash_screen.dart
end note

if (Admin task?) then (📋 Properties)

  |Admin|
  :Review property submissions;
  :Approve/reject via property_review_screen.dart;

else if (👥 Users)

  |Admin|
  :Manage user roles & access;
  :View admin_users_screen.dart;

else if (🏨 Hostels)

  |Admin|
  :Add hostel via add_hostel_screen.dart;
  :Manage room availability;
  :View reservations;

else if (📢 Notifications)

  |Admin|
  :Send system notifications;
  :via send_notification_screen.dart;
  :Broadcast to users via FCM;

else (🗑️ Trash)

  |Admin|
  :Manage deleted content;
  :via admin_trash_screen.dart;
  :Permanently delete or restore;

endif

' ═════════════════════════════════════════════════════════════
' PHASE 10: ANALYTICS & REPORTING
' ═════════════════════════════════════════════════════════════
|Admin|
:Admin Dashboard Statistics\n<i>Properties, Projects, Users, Revenue</i>;

|Property Manager|
:Manager: View dashboard\n<i>Property views, bookings, inquiries</i>;
:Manager: Track analytics\n<i>via view_tracking_service.dart</i>;

|Agent|
:Agent: View agent_main_screen.dart\n<i>Project performance, ratings, reviews</i>;

|Customer|
:Customer: View bookings & history;
:Customer: Track favorite properties;

|Developer|
:Developer: Access owner_dashboard_screen.dart;
:Developer: Monitor project submissions;
:Developer: Track project visibility;

stop

note bottom
  **Architecture Summary**
  
  **Data Storage**: Firebase Firestore (primary) + PostgreSQL (secondary)
  **Images**: Firebase Storage (storage_service.dart)
  **Authentication**: Firebase Auth (auth_service.dart)
  **Notifications**: FCM + Local (fcm_service.dart, notification_service.dart)
  **Payments**: Pandora Payments API via Cloud Functions
  **Key Services**: 27 active services across property, project, agent, payment, and notification management
end note
@enduml
