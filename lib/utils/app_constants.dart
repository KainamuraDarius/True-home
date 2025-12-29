class AppConstants {
  // App Info
  static const String appName = 'True Home';
  static const String appVersion = '1.0.0';
  
  // Firebase Collections
  static const String usersCollection = 'users';
  static const String propertiesCollection = 'properties';
  static const String tourRequestsCollection = 'tour_requests';
  static const String contactRequestsCollection = 'contact_requests';
  static const String propertySubmissionsCollection = 'property_submissions';
  
  // Storage Paths
  static const String propertyImagesPath = 'properties/images';
  static const String propertyVideosPath = 'properties/videos';
  static const String profileImagesPath = 'profiles';
  
  // Shared Preferences Keys
  static const String userIdKey = 'userId';
  static const String userRoleKey = 'userRole';
  static const String isLoggedInKey = 'isLoggedIn';
  
  // Default Values
  static const String defaultCurrency = 'USD';
  static const int defaultPageSize = 20;
  static const double defaultMapZoom = 14.0;
  
  // Property Amenities
  static const List<String> commonAmenities = [
    'Wi-Fi',
    'Parking',
    'Swimming Pool',
    'Gym',
    'Security',
    'Air Conditioning',
    'Heating',
    'Balcony',
    'Garden',
    'Elevator',
    'Furnished',
    'Pet Friendly',
    'Laundry',
    'Kitchen',
    'Study Room',
  ];
  
  // Time Slots for Tours
  static const List<String> tourTimeSlots = [
    '09:00 AM',
    '10:00 AM',
    '11:00 AM',
    '12:00 PM',
    '01:00 PM',
    '02:00 PM',
    '03:00 PM',
    '04:00 PM',
    '05:00 PM',
    '06:00 PM',
  ];
  
  // Price Ranges (for filters)
  static const List<Map<String, dynamic>> priceRanges = [
    {'label': 'Under \$500', 'min': 0, 'max': 500},
    {'label': '\$500 - \$1000', 'min': 500, 'max': 1000},
    {'label': '\$1000 - \$2000', 'min': 1000, 'max': 2000},
    {'label': '\$2000 - \$5000', 'min': 2000, 'max': 5000},
    {'label': 'Above \$5000', 'min': 5000, 'max': double.infinity},
  ];
  
  // Validation
  static const int minPasswordLength = 6;
  static const int maxPropertyTitleLength = 100;
  static const int maxDescriptionLength = 1000;
  static const int maxImagesPerProperty = 10;
  static const int maxFileSize = 5 * 1024 * 1024; // 5MB
  
  // Contact
  static const String supportEmail = 'support@truehome.com';
  static const String supportPhone = '+1234567890';
}
