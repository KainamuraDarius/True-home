# True Home API Reference

Quick reference for using the services in your app.

## 🔐 Authentication Service

```dart
import 'package:true_home/services/auth_service.dart';
import 'package:true_home/models/user_model.dart';

final authService = AuthService();
```

### Sign Up
```dart
UserModel? user = await authService.signUpWithEmailAndPassword(
  email: 'user@example.com',
  password: 'password123',
  name: 'John Doe',
  phoneNumber: '+1234567890',
  role: UserRole.customer, // or .propertyManager, .propertyOwner, .admin
  companyName: 'My Company', // Optional, for managers/owners
  whatsappNumber: '+1234567890', // Optional
);
```

### Sign In
```dart
UserModel? user = await authService.signInWithEmailAndPassword(
  email: 'user@example.com',
  password: 'password123',
);
```

### Get Current User
```dart
User? currentUser = authService.currentUser;
UserModel? userData = await authService.getUserData(currentUser.uid);
```

### Sign Out
```dart
await authService.signOut();
```

## 🏠 Property Service

```dart
import 'package:true_home/services/property_service.dart';
import 'package:true_home/models/property.dart';

final propertyService = PropertyService();
```

### Get All Properties (Stream)
```dart
Stream<List<Property>> propertiesStream = propertyService.getAllProperties();

// Use in StreamBuilder:
StreamBuilder<List<Property>>(
  stream: propertiesStream,
  builder: (context, snapshot) {
    if (snapshot.hasData) {
      List<Property> properties = snapshot.data!;
      // Build your UI
    }
  },
)
```

### Search Properties
```dart
List<Property> results = await propertyService.searchProperties(
  searchQuery: 'apartment',
  type: PropertyType.rental,
  minPrice: 500,
  maxPrice: 2000,
  location: 'New York',
);
```

### Add Property
```dart
Property newProperty = Property(
  id: '',
  title: 'Modern Apartment',
  description: 'Beautiful 2BR apartment...',
  type: PropertyType.rental,
  status: PropertyStatus.available,
  price: 1500.0,
  location: '123 Main St, New York',
  latitude: 40.7128,
  longitude: -74.0060,
  imageUrls: ['url1', 'url2'],
  bedrooms: 2,
  bathrooms: 1,
  squareMeters: 80.0,
  amenities: ['Wi-Fi', 'Parking', 'Gym'],
  managerId: 'manager123',
  managerName: 'John Manager',
  managerPhone: '+1234567890',
  managerEmail: 'manager@example.com',
  managerWhatsApp: '+1234567890',
  createdAt: DateTime.now(),
  updatedAt: DateTime.now(),
);

String propertyId = await propertyService.addProperty(newProperty);
```

### Upload Images
```dart
import 'dart:io';

List<File> imageFiles = [...]; // From image picker
List<String> imageUrls = await propertyService.uploadImages(
  imageFiles,
  propertyId,
);
```

## 📅 Tour Service

```dart
import 'package:true_home/services/tour_service.dart';
import 'package:true_home/models/tour_request.dart';

final tourService = TourService();
```

### Create Tour Request
```dart
TourRequest request = TourRequest(
  id: '',
  propertyId: property.id,
  propertyTitle: property.title,
  customerId: currentUser.id,
  customerName: currentUser.name,
  customerPhone: currentUser.phoneNumber,
  customerEmail: currentUser.email,
  managerId: property.managerId,
  requestedDate: DateTime(2025, 12, 25),
  requestedTime: '10:00 AM',
  status: TourRequestStatus.pending,
  notes: 'Looking forward to viewing',
  createdAt: DateTime.now(),
  updatedAt: DateTime.now(),
);

String requestId = await tourService.createTourRequest(request);
```

### Get Tours by Customer (Stream)
```dart
Stream<List<TourRequest>> tours = tourService.getTourRequestsByCustomer(
  customerId,
);
```

### Get Tours by Manager (Stream)
```dart
Stream<List<TourRequest>> tours = tourService.getTourRequestsByManager(
  managerId,
);
```

### Confirm Tour
```dart
await tourService.confirmTourRequest(
  requestId,
  notes: 'Confirmed for 10 AM',
);
```

### Cancel Tour
```dart
await tourService.cancelTourRequest(requestId);
```

## 💬 Contact Service

```dart
import 'package:true_home/services/contact_service.dart';
import 'package:true_home/models/contact_request.dart';

final contactService = ContactService();
```

### Create Contact Request
```dart
ContactRequest request = ContactRequest(
  id: '',
  propertyId: property.id,
  propertyTitle: property.title,
  customerId: currentUser.id,
  customerName: currentUser.name,
  customerPhone: currentUser.phoneNumber,
  customerEmail: currentUser.email,
  managerId: property.managerId,
  message: 'I am interested in this property...',
  status: ContactRequestStatus.new_request,
  createdAt: DateTime.now(),
  updatedAt: DateTime.now(),
);

String requestId = await contactService.createContactRequest(request);
```

### Get Contacts by Manager (Stream)
```dart
Stream<List<ContactRequest>> contacts = 
  contactService.getContactRequestsByManager(managerId);
```

### Resolve Contact Request
```dart
await contactService.resolveContactRequest(
  requestId,
  'Thank you for your inquiry. The property is available...',
);
```

## 📝 Property Submission Service

```dart
import 'package:true_home/services/property_submission_service.dart';
import 'package:true_home/models/property_submission.dart';

final submissionService = PropertySubmissionService();
```

### Submit Property
```dart
PropertySubmission submission = PropertySubmission(
  id: '',
  ownerId: currentUser.id,
  ownerName: currentUser.name,
  ownerEmail: currentUser.email,
  ownerPhone: currentUser.phoneNumber,
  title: 'Cozy Studio',
  description: 'Perfect for students...',
  type: PropertyType.hostel,
  price: 500.0,
  location: '456 College Ave',
  latitude: 40.7128,
  longitude: -74.0060,
  imageUrls: ['url1', 'url2'],
  bedrooms: 1,
  bathrooms: 1,
  squareMeters: 30.0,
  amenities: ['Wi-Fi', 'Shared Kitchen'],
  createdAt: DateTime.now(),
  updatedAt: DateTime.now(),
);

String submissionId = await submissionService.submitProperty(submission);
```

### Get Owner's Submissions (Stream)
```dart
Stream<List<PropertySubmission>> submissions = 
  submissionService.getSubmissionsByOwner(ownerId);
```

### Approve Submission (Admin)
```dart
await submissionService.approveSubmission(
  submissionId,
  approvedPropertyId,
  adminNotes: 'Approved',
);
```

### Reject Submission (Admin)
```dart
await submissionService.rejectSubmission(
  submissionId,
  'Please provide more images',
  adminNotes: 'Needs improvement',
);
```

## 📞 URL Launcher Service

```dart
import 'package:true_home/services/url_launcher_service.dart';
```

### Make Phone Call
```dart
await UrlLauncherService.makePhoneCall('+1234567890');
```

### Send WhatsApp Message
```dart
await UrlLauncherService.sendWhatsApp(
  '+1234567890',
  message: 'Hi, I am interested in your property',
);
```

### Send Email
```dart
await UrlLauncherService.sendEmail(
  'manager@example.com',
  subject: 'Property Inquiry',
  body: 'I would like to know more...',
);
```

### Open Maps
```dart
await UrlLauncherService.openMaps(40.7128, -74.0060);
```

## 🎨 Using App Colors & Theme

```dart
import 'package:true_home/utils/app_theme.dart';

// Colors
Container(
  color: AppColors.primary,
  child: Text(
    'Hello',
    style: TextStyle(color: AppColors.textPrimary),
  ),
)

// Property Type Colors
Color rentalColor = AppColors.rental;
Color condoColor = AppColors.condo;
Color hostelColor = AppColors.hostel;

// Status Colors
Color successColor = AppColors.success;
Color errorColor = AppColors.error;
Color warningColor = AppColors.warning;
```

## 📱 Constants

```dart
import 'package:true_home/utils/app_constants.dart';

// Amenities List
List<String> amenities = AppConstants.commonAmenities;

// Tour Time Slots
List<String> timeSlots = AppConstants.tourTimeSlots;

// Price Ranges for Filters
List<Map<String, dynamic>> ranges = AppConstants.priceRanges;

// Currency
String currency = AppConstants.defaultCurrency; // 'USD'
```

## 🔄 Enums

### PropertyType
```dart
PropertyType.rental
PropertyType.condo
PropertyType.hostel
```

### PropertyStatus
```dart
PropertyStatus.available
PropertyStatus.rented
PropertyStatus.sold
PropertyStatus.pending
```

### UserRole
```dart
UserRole.customer
UserRole.propertyManager
UserRole.propertyOwner
UserRole.admin
```

### TourRequestStatus
```dart
TourRequestStatus.pending
TourRequestStatus.confirmed
TourRequestStatus.cancelled
TourRequestStatus.completed
```

### ContactRequestStatus
```dart
ContactRequestStatus.new_request
ContactRequestStatus.inProgress
ContactRequestStatus.resolved
```

### SubmissionStatus
```dart
SubmissionStatus.pending
SubmissionStatus.approved
SubmissionStatus.rejected
```

## 🎯 Common Patterns

### Loading State
```dart
bool isLoading = false;

setState(() => isLoading = true);
try {
  await someAsyncOperation();
} catch (e) {
  // Handle error
} finally {
  setState(() => isLoading = false);
}
```

### Error Handling
```dart
try {
  await propertyService.addProperty(property);
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text('Property added successfully'),
      backgroundColor: AppColors.success,
    ),
  );
} catch (e) {
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text('Error: ${e.toString()}'),
      backgroundColor: AppColors.error,
    ),
  );
}
```

### StreamBuilder Pattern
```dart
StreamBuilder<List<Property>>(
  stream: propertyService.getAllProperties(),
  builder: (context, snapshot) {
    if (snapshot.connectionState == ConnectionState.waiting) {
      return Center(child: CircularProgressIndicator());
    }
    
    if (snapshot.hasError) {
      return Center(child: Text('Error: ${snapshot.error}'));
    }
    
    if (!snapshot.hasData || snapshot.data!.isEmpty) {
      return Center(child: Text('No properties found'));
    }
    
    List<Property> properties = snapshot.data!;
    return ListView.builder(
      itemCount: properties.length,
      itemBuilder: (context, index) {
        return PropertyCard(property: properties[index]);
      },
    );
  },
)
```

---

## 📚 Quick Tips

1. Always handle errors with try-catch
2. Show loading indicators during async operations
3. Use StreamBuilder for real-time data
4. Test on real devices for location/camera features
5. Check Firebase console for backend errors
6. Use const constructors where possible for performance
7. Follow the established color scheme and styling

---

Happy coding! 🚀
