class ApiConfig {
  // ============================================
  // BACKEND CONFIGURATION - IMPORTANT!
  // ============================================
  
  // OPTION 1: Android Emulator or Physical Device via USB (RECOMMENDED)
  static const String _localhostUrl = 'http://localhost:3000/api';
  
  // OPTION 2: Physical Device via WiFi (use your computer's local IP)
  static const String _physicalDeviceUrl = 'http://192.168.0.133:3000/api'; // Updated IP
  
  // OPTION 3: Firebase (Recommended if you don't have a backend)
  static const bool useFirebase = false;
  
  // SELECT YOUR ENVIRONMENT:
  // Using localhost with USB forwarding (adb reverse tcp:3000 tcp:3000)
  static const String baseUrl = _localhostUrl;
  
  // ============================================
  // TROUBLESHOOTING:
  // ============================================
  // Using USB connected device? → Use _localhostUrl + run: adb reverse tcp:3000 tcp:3000
  // Using Physical Device via WiFi? → Use _physicalDeviceUrl (your computer's IP)
  // Your computer's IP: 192.168.0.133
  //
  // Don't forget to:
  // 1. Make sure backend is running (node server.js)
  // 2. For USB: Run 'adb reverse tcp:3000 tcp:3000'
  // 3. For WiFi: Both devices on same network, firewall allows port 3000
  
  // API Endpoints
  
  // Authentication
  static const String login = '/auth/login';
  static const String register = '/auth/register';
  static const String logout = '/auth/logout';
  static const String refreshToken = '/auth/refresh';
  static const String userProfile = '/auth/profile';
  
  // Properties
  static const String getProperties = '/properties';
  static const String createProperty = '/properties';
  static const String updateProperty = '/properties';
  static const String deleteProperty = '/properties';
  static const String searchProperties = '/properties/search';
  static const String uploadPropertyImages = '/properties/images';
  static const String deletePropertyImage = '/properties/images';
  static const String toggleFavorite = '/properties/favorite';
  static const String getFavorites = '/properties/favorites';
  
  // Tour Requests
  static const String createTourRequest = '/tour-requests';
  static const String getCustomerTourRequests = '/tour-requests/customer';
  static const String getManagerTourRequests = '/tour-requests/manager';
  static const String getTourRequestsByProperty = '/tour-requests/property';
  static const String getTourRequest = '/tour-requests';
  static const String updateTourRequestStatus = '/tour-requests';
  static const String deleteTourRequest = '/tour-requests';
  
  // Contact Requests
  static const String createContactRequest = '/contact-requests';
  static const String getCustomerContactRequests = '/contact-requests/customer';
  static const String getManagerContactRequests = '/contact-requests/manager';
  static const String getContactRequestsByProperty = '/contact-requests/property';
  static const String getContactRequest = '/contact-requests';
  static const String updateContactRequestStatus = '/contact-requests';
  static const String deleteContactRequest = '/contact-requests';
  
  // Property Submissions
  static const String createSubmission = '/property-submissions';
  static const String getOwnerSubmissions = '/property-submissions/owner';
  static const String getAllSubmissions = '/property-submissions';
  static const String getSubmission = '/property-submissions';
  static const String approveSubmission = '/property-submissions/approve';
  static const String rejectSubmission = '/property-submissions/reject';
  static const String updateSubmission = '/property-submissions';
  static const String deleteSubmission = '/property-submissions';
  static const String uploadSubmissionImages = '/property-submissions/images';
  
  // File uploads
  static const String uploadImage = '/upload/image';
  static const String uploadImages = '/upload/images';
  
  // Timeouts - increased for reliability
  static const Duration connectTimeout = Duration(seconds: 60);
  static const Duration receiveTimeout = Duration(seconds: 60);
  static const Duration sendTimeout = Duration(seconds: 60);
  
  // Retry configurations
  static const int maxRetries = 3;
  static const Duration retryDelay = Duration(seconds: 2);
  
  // Storage Keys
  static const String accessTokenKey = 'access_token';
  static const String refreshTokenKey = 'refresh_token';
  static const String userIdKey = 'user_id';
  static const String userRoleKey = 'user_role';
}
