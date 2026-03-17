import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../utils/app_theme.dart';
import '../../utils/currency_formatter.dart';
import '../../utils/responsive_helper.dart';
import '../../models/property_model.dart';
import '../../models/project_model.dart';
import '../../models/user_model.dart';
import '../../utils/universities.dart';
import '../auth/login_screen.dart';
import '../auth/role_selection_screen.dart';
import '../common/profile_screen.dart';
import '../common/notifications_screen.dart';
import '../property/property_details_screen.dart';
import '../../services/notification_service.dart';
import '../../services/project_service.dart';
import '../../services/role_service.dart';
import '../../widgets/role_switcher.dart';
import '../../widgets/web_footer.dart';
import 'project_details_screen.dart';
import 'all_projects_screen.dart';

class CustomerHomeScreen extends StatefulWidget {
  const CustomerHomeScreen({super.key});

  @override
  State<CustomerHomeScreen> createState() => _CustomerHomeScreenState();
}

class _CustomerHomeScreenState extends State<CustomerHomeScreen> {
  int _currentIndex = 0;
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  UserModel? _currentUser;

  bool get _isGuestUser => FirebaseAuth.instance.currentUser == null;

  List<Widget> get _screens => [
    HomeTab(
      isWebNav: kIsWeb,
      onMenuTap: () => _scaffoldKey.currentState?.openDrawer(),
    ),
    _isGuestUser
        ? GuestAccessScreen(
            title: 'Login To Save Favorites',
            description:
                'Browsing is open, but saved items and account tools require signing in.',
          )
        : FavoritesTab(
            isWebNav: kIsWeb,
            onMenuTap: () => _scaffoldKey.currentState?.openDrawer(),
          ),
    _isGuestUser
        ? GuestAccessScreen(
            title: 'Create An Account',
            description:
                'Use your account to manage bookings, profile details, and other protected actions.',
          )
        : const ProfileScreen(showWebFooter: true),
  ];

  @override
  void initState() {
    super.initState();
    if (kIsWeb) {
      _loadUserData();
    }
  }

  Future<void> _loadUserData() async {
    final userId = FirebaseAuth.instance.currentUser?.uid;
    if (userId != null) {
      try {
        final userDoc = await FirebaseFirestore.instance
            .collection('users')
            .doc(userId)
            .get();
        if (userDoc.exists && mounted) {
          setState(() {
            _currentUser = UserModel.fromJson({
              ...userDoc.data()!,
              'id': userDoc.id,
            });
          });
        }
      } catch (e) {
        // Silently fail if user data can't be loaded
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDesktop = kIsWeb && ResponsiveHelper.isDesktop(context);
    
    return Scaffold(
      key: _scaffoldKey,
      drawer: kIsWeb && !isDesktop ? _buildDrawer() : null, // Drawer only for tablet web
      body: isDesktop 
          ? _buildDesktopLayout() 
          : _screens[_currentIndex],
      bottomNavigationBar: kIsWeb
          ? null
          : BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (index) {
          setState(() {
            _currentIndex = index;
          });
        },
        type: BottomNavigationBarType.fixed,
        selectedItemColor: Theme.of(context).colorScheme.primary,
        unselectedItemColor: AppColors.textSecondary,
        selectedFontSize: 15,
        unselectedFontSize: 14,
        iconSize: 30,
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.home_outlined),
            activeIcon: Icon(Icons.home),
            label: 'Home',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.favorite_outline),
            activeIcon: Icon(Icons.favorite),
            label: 'Favorites',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.person_outline),
            activeIcon: Icon(Icons.person),
            label: 'Profile',
          ),
        ],
      ),
    );
  }

  Widget _buildDrawer() {
    return Drawer(
        width: 300,
      child: Column(
        children: [
          // Header with user info
          UserAccountsDrawerHeader(
                         margin: EdgeInsets.zero,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  AppColors.primary,
                  AppColors.primary.withOpacity(0.8),
                ],
              ),
            ),
            accountName: Text(
              _currentUser?.name ?? 'User',
              style: const TextStyle(
                 fontWeight: FontWeight.bold,
                 fontSize: 20,
              ),
            ),
            accountEmail: Text(
              _currentUser?.email ?? '',
               style: const TextStyle(fontSize: 15),
            ),
            currentAccountPicture: CircleAvatar(
              backgroundColor: Colors.white,
                             radius: 32,
              child: Text(
                (_currentUser?.name ?? 'U')[0].toUpperCase(),
                style: TextStyle(
                   fontSize: 36,
                  fontWeight: FontWeight.bold,
                  color: AppColors.primary,
                ),
              ),
            ),
          ),

          // Navigation items
          Expanded(
             child: ListView(
                padding: EdgeInsets.zero,
                children: [
                  _buildDrawerItem(
                    icon: Icons.home,
                    title: 'Home',
                    index: 0,
                  ),
                  _buildDrawerItem(
                    icon: Icons.favorite,
                    title: 'Favorites',
                    index: 1,
                  ),
                  _buildDrawerItem(
                    icon: Icons.person,
                    title: 'Profile',
                    index: 2,
                  ),
                ],
             ),
          ),

          // Footer
          const Divider(),
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Text(
              'True Home',
              style: TextStyle(
                color: Colors.grey.shade600,
                 fontSize: 13,
                 fontWeight: FontWeight.w500,
              ),
              textAlign: TextAlign.center,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDrawerItem({
    required IconData icon,
    required String title,
    required int index,
  }) {
    final isSelected = _currentIndex == index;
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
      leading: Icon(
        icon,
        size: 28,
        color: isSelected ? AppColors.primary : Colors.grey.shade700,
      ),
      title: Text(
        title,
        style: TextStyle(
          fontSize: 16,
          color: isSelected ? AppColors.primary : Colors.grey.shade800,
          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
        ),
      ),
      selected: isSelected,
      selectedTileColor: AppColors.primary.withOpacity(0.1),
      onTap: () {
        setState(() {
          _currentIndex = index;
        });
        _scaffoldKey.currentState?.closeDrawer();
      },
    );
  }

  /// Desktop layout with fixed sidebar navigation
  Widget _buildDesktopLayout() {
    return Row(
      children: [
        // Fixed Sidebar Navigation
        _buildDesktopSidebar(),
        
        // Main Content Area
        Expanded(
          child: _screens[_currentIndex],
        ),
      ],
    );
  }

  Widget _buildDesktopSidebar() {
    return Container(
      width: ResponsiveHelper.getSidebarWidth(context),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(2, 0),
          ),
        ],
      ),
      child: Column(
        children: [
          // Logo Section
          Container(
            padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 20),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  AppColors.primary,
                  AppColors.primary.withOpacity(0.85),
                ],
              ),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    Icons.home_rounded,
                    color: AppColors.primary,
                    size: 28,
                  ),
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'True Home',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        'Find your perfect place',
                        style: TextStyle(
                          color: Colors.white70,
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          
          // User Info (if logged in)
          if (_currentUser != null) ...[
            Container(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 22,
                    backgroundColor: AppColors.primary.withOpacity(0.1),
                    child: Text(
                      (_currentUser?.name ?? 'U')[0].toUpperCase(),
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: AppColors.primary,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _currentUser?.name ?? 'User',
                          style: const TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 14,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        Text(
                          _currentUser?.email ?? '',
                          style: TextStyle(
                            color: Colors.grey.shade600,
                            fontSize: 12,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            Divider(height: 1, color: Colors.grey.shade200),
          ],
          
          const SizedBox(height: 8),
          
          // Navigation Items
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              children: [
                _buildSidebarItem(
                  icon: Icons.home_outlined,
                  activeIcon: Icons.home_rounded,
                  title: 'Home',
                  index: 0,
                ),
                _buildSidebarItem(
                  icon: Icons.favorite_outline,
                  activeIcon: Icons.favorite_rounded,
                  title: 'Favorites',
                  index: 1,
                ),
                _buildSidebarItem(
                  icon: Icons.person_outline,
                  activeIcon: Icons.person_rounded,
                  title: 'Profile',
                  index: 2,
                ),
              ],
            ),
          ),
          
          // Footer
          Container(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                Divider(height: 1, color: Colors.grey.shade200),
                const SizedBox(height: 16),
                Text(
                  '© 2026 True Home',
                  style: TextStyle(
                    color: Colors.grey.shade500,
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSidebarItem({
    required IconData icon,
    required IconData activeIcon,
    required String title,
    required int index,
  }) {
    final isSelected = _currentIndex == index;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Material(
        color: isSelected ? AppColors.primary.withOpacity(0.1) : Colors.transparent,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () {
            setState(() {
              _currentIndex = index;
            });
          },
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child: Row(
              children: [
                Icon(
                  isSelected ? activeIcon : icon,
                  size: 24,
                  color: isSelected ? AppColors.primary : Colors.grey.shade600,
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Text(
                    title,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                      color: isSelected ? AppColors.primary : Colors.grey.shade700,
                    ),
                  ),
                ),
                if (isSelected)
                  Container(
                    width: 4,
                    height: 20,
                    decoration: BoxDecoration(
                      color: AppColors.primary,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class HomeTab extends StatefulWidget {
  final bool isWebNav;
  final VoidCallback? onMenuTap;

  const HomeTab({super.key, this.isWebNav = false, this.onMenuTap});

  @override
  State<HomeTab> createState() => _HomeTabState();
}

class _HomeTabState extends State<HomeTab> {
  PropertyType? _selectedFilter = PropertyType.sale;
  final NotificationService _notificationService = NotificationService();
  final ProjectService _projectService = ProjectService();
  final RoleService _roleService = RoleService();
  int _unreadCount = 0;
  final ScrollController _scrollController = ScrollController();
  final GlobalKey _propertiesSectionKey = GlobalKey();
  UserModel? _currentUser;

  // Projects section state
  List<String> _projectLocations = [];

  // Properties location filter state
  String? _selectedPropertyLocation;
  List<String> _propertyLocations = [];
  bool _loadingPropertyLocations = false;

  // Hostel university filter state
  String? _selectedUniversity;
  final GlobalKey _universityDropdownKey = GlobalKey();

  // Property pagination state
  int _displayedPropertiesCount = 3; // Start with 3 properties
  static const int _propertiesPerPage = 10;

  // Search and filter state
  final TextEditingController _searchController = TextEditingController();
  final TextEditingController _minPriceController = TextEditingController();
  final TextEditingController _maxPriceController = TextEditingController();
  bool _showFilters = false;
  bool _isSearchActive = false;
  List<PropertyModel> _searchResults = [];
  double _minPrice = 0;
  double _maxPrice = 10000000;
  int? _bedrooms;
  PropertyType? _selectedPropertyType;
  List<String> _searchHistory = [];
  bool _showHistory = false;
  static const String _searchHistoryKey = 'search_history';
  static const int _maxHistoryItems = 10;

  // Autocomplete suggestions
  List<String> _searchSuggestions = [];
  bool _showSuggestions = false;
  final FocusNode _searchFocusNode = FocusNode();
  String _inlineAutocompleteSuggestion = '';
  Timer? _suggestionDebounce;
  bool _loadingDynamicSuggestions = false;
  List<String> _dynamicSearchTerms = [];

  // Common search terms for suggestions
  static const List<String> _commonLocations = [
    'Kampala',
    'Bugolobi',
    'Kololo',
    'Nakasero',
    'Ntinda',
    'Kansanga',
    'Makindye',
    'Muyenga',
    'Bukoto',
    'Naguru',
    'Kawempe',
    'Rubaga',
    'Entebbe',
    'Wakiso',
    'Mukono',
    'Jinja',
    'Namugongo',
    'Kireka',
    'Naalya',
    'Kyanja',
    'Najjera',
    'Kira',
    'Lubowa',
    'Munyonyo',
  ];

  static const List<String> _propertyTypes = [
    'Apartment',
    'House',
    'Hostel',
    'Condo',
    'Villa',
    'Studio',
    'Rental',
    'Rentals',
    'Condos',
    'Apartments',
    'Houses',
    'Hostels',
    'For Sale',
    'For Rent',
    'Room',
    'Bedsitter',
    'Single Room',
    'Double Room',
  ];

  // New Projects Carousel state
  List<PropertyModel> _newProjects = [];
  bool _loadingNewProjects = false;
  final PageController _newProjectsPageController = PageController(
    viewportFraction: 0.9,
  );
  final ValueNotifier<int> _currentNewProjectIndex = ValueNotifier<int>(0);

  @override
  void initState() {
    super.initState();
    
    // Initialize price controllers
    _minPriceController.text = '';
    _maxPriceController.text = '';
    
    // Load critical data first (non-blocking)
    Future.microtask(() async {
      _loadUnreadCount();
      _loadCurrentUser();
      _loadSearchHistory();
    });
    
    // Defer heavy data loading until after first frame
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        Future.delayed(const Duration(milliseconds: 300), () {
          if (mounted) {
            _loadProjectLocations();
            _loadPropertyLocations();
            _loadNewProjects();
            _loadDynamicSearchTerms();
          }
        });
      }
    });
  }

  @override
  void dispose() {
    _suggestionDebounce?.cancel();
    _searchController.dispose();
    _minPriceController.dispose();
    _maxPriceController.dispose();
    _searchFocusNode.dispose();
    _newProjectsPageController.dispose();
    _currentNewProjectIndex.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _loadCurrentUser() async {
    try {
      final user = await _roleService.getCurrentUser();
      if (mounted) {
        setState(() {
          _currentUser = user;
        });
      }
    } catch (e) {
      print('Error loading current user: $e');
    }
  }

  Future<void> _loadUnreadCount() async {
    final userId = FirebaseAuth.instance.currentUser?.uid;
    if (userId != null) {
      final count = await _notificationService.getUnreadCount(userId);
      if (mounted) {
        setState(() {
          _unreadCount = count;
        });
      }
    }
  }

  Future<bool> _isFavorite(String propertyId) async {
    final prefs = await SharedPreferences.getInstance();
    final favorites = prefs.getStringList('favorite_properties') ?? [];
    return favorites.contains(propertyId);
  }

  Future<void> _togglePropertyFavorite(String propertyId) async {
    final prefs = await SharedPreferences.getInstance();
    List<String> favorites = prefs.getStringList('favorite_properties') ?? [];

    if (favorites.contains(propertyId)) {
      favorites.remove(propertyId);
      await prefs.setStringList('favorite_properties', favorites);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                Icon(Icons.heart_broken, color: Colors.white),
                SizedBox(width: 8),
                Text('Removed from favorites'),
              ],
            ),
            duration: Duration(seconds: 1),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } else {
      favorites.add(propertyId);
      await prefs.setStringList('favorite_properties', favorites);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                Icon(Icons.favorite, color: Colors.red),
                SizedBox(width: 8),
                Text('Item added to favorites!'),
              ],
            ),
            duration: Duration(seconds: 2),
            behavior: SnackBarBehavior.floating,
            backgroundColor: Colors.green[700],
          ),
        );
      }
    }
  }

  // Search functionality methods
  Future<void> _loadSearchHistory() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _searchHistory = prefs.getStringList(_searchHistoryKey) ?? [];
    });
  }

  Future<void> _saveSearchQuery(String query) async {
    if (query.trim().isEmpty) return;

    final prefs = await SharedPreferences.getInstance();
    List<String> history = prefs.getStringList(_searchHistoryKey) ?? [];

    history.remove(query);
    history.insert(0, query);

    if (history.length > _maxHistoryItems) {
      history = history.sublist(0, _maxHistoryItems);
    }

    await prefs.setStringList(_searchHistoryKey, history);
    setState(() {
      _searchHistory = history;
    });
  }

  Future<void> _clearSearchHistory() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_searchHistoryKey);
    setState(() {
      _searchHistory = [];
      _showHistory = false;
    });
  }

  Future<void> _removeHistoryItem(String query) async {
    final prefs = await SharedPreferences.getInstance();
    List<String> history = prefs.getStringList(_searchHistoryKey) ?? [];
    history.remove(query);
    await prefs.setStringList(_searchHistoryKey, history);
    setState(() {
      _searchHistory = history;
      if (_searchHistory.isEmpty) {
        _showHistory = false;
      }
    });
  }

  Future<void> _performSearch() async {
    setState(() {
      _isSearchActive = true;
      _showHistory = false;
      _showSuggestions = false;
    });

    if (_searchController.text.trim().isNotEmpty) {
      await _saveSearchQuery(_searchController.text.trim());
    }

    try {
      Query query = FirebaseFirestore.instance
          .collection('properties')
          .where('status', isEqualTo: 'approved')
          .where('isActive', isEqualTo: true);

      if (_selectedFilter != null) {
        query = query.where('type', isEqualTo: _selectedFilter!.name);
      }

      final snapshot = await query.get();
      List<PropertyModel> results = [];

      // Sync text controllers with actual filter values
      final actualMinPrice = _minPriceController.text.isEmpty
          ? 0.0
          : (double.tryParse(_minPriceController.text) ?? 0.0);
      final actualMaxPrice = _maxPriceController.text.isEmpty
          ? 10000000.0
          : (double.tryParse(_maxPriceController.text) ?? 10000000.0);

      _minPrice = actualMinPrice;
      _maxPrice = actualMaxPrice;

      print('🔍 Filter Debug:');
      print('   Min Price: $_minPrice (text: "${_minPriceController.text}")');
      print('   Max Price: $_maxPrice (text: "${_maxPriceController.text}")');
      print('   Bedrooms: $_bedrooms');
      print('   Property Type: $_selectedPropertyType');
      print('   Search Term: ${_searchController.text}');
      print('   Total properties fetched: ${snapshot.docs.length}');

      for (var doc in snapshot.docs) {
        final data = doc.data() as Map<String, dynamic>;
        data['id'] = doc.id;
        final property = PropertyModel.fromJson(data);

        bool matchesSearch = true;
        if (_searchController.text.isNotEmpty) {
          final searchTerm = _searchController.text.toLowerCase();
          matchesSearch =
              property.title.toLowerCase().contains(searchTerm) ||
              property.description.toLowerCase().contains(searchTerm) ||
              property.location.toLowerCase().contains(searchTerm) ||
              property.address.toLowerCase().contains(searchTerm);
        }

        bool matchesPrice =
            property.price >= _minPrice && property.price <= _maxPrice;
        bool matchesBedrooms =
            _bedrooms == null || property.bedrooms >= _bedrooms!;
        bool matchesPropertyType =
            _selectedPropertyType == null ||
            property.type == _selectedPropertyType;

        if (matchesSearch &&
            matchesPrice &&
            matchesBedrooms &&
            matchesPropertyType) {
          results.add(property);
        }
      }

      print('   ✅ Properties matching filters: ${results.length}');

      setState(() {
        _searchResults = results;
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error searching: $e')));
      }
    }
  }

  void _clearSearch() {
    final shouldReloadLocations = _selectedFilter != PropertyType.sale;

    setState(() {
      _searchController.clear();
      _isSearchActive = false;
      _searchResults = [];
      _showHistory = false;
      _showFilters = false;
      _showSuggestions = false;
      _inlineAutocompleteSuggestion = '';
      _selectedFilter = PropertyType.sale;
      _minPrice = 0;
      _maxPrice = 10000000;
      _minPriceController.clear();
      _maxPriceController.clear();
      _bedrooms = null;
      _selectedPropertyType = null;
      _selectedPropertyLocation = null;
      _displayedPropertiesCount = 3; // Reset to show 3 properties initially
    });

    if (shouldReloadLocations) {
      _loadPropertyLocations();
    }
  }

  // Check if suggestion is a typo correction
  bool _isTypoCorrection(String query, String suggestion) {
    if (query.isEmpty || query.length < 2) return false;
    final queryLower = query.toLowerCase();
    final suggestionLower = suggestion.toLowerCase();

    // Not a typo if it's an exact match or starts with query
    if (suggestionLower == queryLower ||
        suggestionLower.startsWith(queryLower)) {
      return false;
    }

    // It's a typo correction if there's a small edit distance
    final distance = _levenshteinDistance(queryLower, suggestionLower);
    return distance > 0 && distance <= 3;
  }

  // Calculate Levenshtein distance for fuzzy matching
  int _levenshteinDistance(String s1, String s2) {
    s1 = s1.toLowerCase();
    s2 = s2.toLowerCase();

    if (s1 == s2) return 0;
    if (s1.isEmpty) return s2.length;
    if (s2.isEmpty) return s1.length;

    List<int> previousRow = List<int>.generate(s2.length + 1, (i) => i);

    for (int i = 0; i < s1.length; i++) {
      List<int> currentRow = [i + 1];

      for (int j = 0; j < s2.length; j++) {
        int insertions = previousRow[j + 1] + 1;
        int deletions = currentRow[j] + 1;
        int substitutions = previousRow[j] + (s1[i] == s2[j] ? 0 : 1);
        currentRow.add(
          [
            insertions,
            deletions,
            substitutions,
          ].reduce((a, b) => a < b ? a : b),
        );
      }

      previousRow = currentRow;
    }

    return previousRow[s2.length];
  }

  // Update search suggestions based on input
  void _updateSearchSuggestions(String query) {
    if (query.isEmpty) {
      setState(() {
        _searchSuggestions = [];
        _showSuggestions = false;
      });
      return;
    }

    final queryLower = query.toLowerCase();
    List<String> suggestions = [];

    // Combine all possible search terms
    final allTerms = [
      ..._commonLocations,
      ..._propertyTypes,
      ..._searchHistory,
      ..._dynamicSearchTerms,
    ];

    // Score each term based on similarity
    final scoredTerms = <MapEntry<String, int>>[];

    for (final term in allTerms) {
      final termLower = term.toLowerCase();

      // Exact match or starts with - highest priority
      if (termLower == queryLower) {
        scoredTerms.add(MapEntry(term, 0));
      } else if (termLower.startsWith(queryLower)) {
        scoredTerms.add(MapEntry(term, 1));
      } else if (termLower.contains(queryLower)) {
        scoredTerms.add(MapEntry(term, 2));
      } else {
        // Calculate Levenshtein distance for fuzzy matching
        final distance = _levenshteinDistance(queryLower, termLower);
        // Only include if distance is small (good match)
        if (distance <= 3 && queryLower.length > 2) {
          scoredTerms.add(MapEntry(term, distance + 10));
        }
      }
    }

    // Sort by score (lower is better) and take top 5
    scoredTerms.sort((a, b) => a.value.compareTo(b.value));
    suggestions = scoredTerms.take(5).map((e) => e.key).toList();

    // Remove duplicates while preserving order
    final seen = <String>{};
    suggestions = suggestions
        .where((term) => seen.add(term.toLowerCase()))
        .toList();

    print(
      '🔍 Search query: "$query" -> ${suggestions.length} suggestions: $suggestions',
    );

    // Set inline autocomplete suggestion (best match)
    String inlineSuggestion = '';
    if (suggestions.isNotEmpty) {
      final bestMatch = suggestions.first;
      final bestMatchLower = bestMatch.toLowerCase();
      // Only show inline if it starts with the query
      if (bestMatchLower.startsWith(queryLower)) {
        inlineSuggestion = bestMatch;
      }
    }

    setState(() {
      _searchSuggestions = suggestions;
      _showSuggestions = suggestions.isNotEmpty;
      _inlineAutocompleteSuggestion = inlineSuggestion;
    });
  }

  void _scheduleSuggestionsUpdate(String value) {
    _suggestionDebounce?.cancel();
    _suggestionDebounce = Timer(const Duration(milliseconds: 220), () {
      if (!mounted) return;
      _updateSearchSuggestions(value);
    });
  }

  Future<void> _loadDynamicSearchTerms() async {
    if (_loadingDynamicSuggestions) return;

    _loadingDynamicSuggestions = true;
    try {
      final querySnapshot = await FirebaseFirestore.instance
          .collection('properties')
          .where('status', isEqualTo: 'approved')
          .where('isActive', isEqualTo: true)
          .limit(120)
          .get();

      final terms = <String>{};
      for (final doc in querySnapshot.docs) {
        final data = doc.data();

        void addTerm(dynamic value) {
          if (value == null) return;
          final text = value.toString().trim();
          if (text.length >= 2) {
            terms.add(text);
          }
        }

        addTerm(data['title']);
        addTerm(data['location']);
        addTerm(data['address']);
        addTerm(data['companyName']);
        addTerm(data['university']);
      }

      if (mounted) {
        setState(() {
          _dynamicSearchTerms = terms.toList(growable: false);
        });
      }
    } catch (e) {
      print('Error loading dynamic search terms: $e');
    } finally {
      _loadingDynamicSuggestions = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: !widget.isWebNav,
        leading: widget.isWebNav
            ? IconButton(
                icon: const Icon(Icons.menu),
                onPressed: widget.onMenuTap,
              )
            : null,
        title: Row(
          children: [
            Image.asset(
              'assets/images/app_icon.png',
              height: 40,
              fit: BoxFit.contain,
            ),
          ],
        ),
        actions: [
          // Role Switcher (only shows if user has multiple roles)
          if (_currentUser != null)
            RoleSwitcher(
              user: _currentUser!,
              onRoleChanged: () {
                // Reload after role change
                _loadCurrentUser();
              },
            ),
          Stack(
            children: [
              IconButton(
                icon: const Icon(Icons.notifications_outlined),
                onPressed: () async {
                  await Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const NotificationsScreen(),
                    ),
                  );
                  _loadUnreadCount(); // Refresh count after returning
                },
              ),
              if (_unreadCount > 0)
                Positioned(
                  right: 8,
                  top: 8,
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: const BoxDecoration(
                      color: Colors.red,
                      shape: BoxShape.circle,
                    ),
                    constraints: const BoxConstraints(
                      minWidth: 18,
                      minHeight: 18,
                    ),
                    child: Text(
                      _unreadCount > 9 ? '9+' : '$_unreadCount',
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.onPrimary,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
      body: Column(
        children: [
          // Hero Section (fixed)
          Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [AppColors.primary, AppColors.primaryDark],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Find Your Dream Home',
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      color: Theme.of(context).colorScheme.onPrimary,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Browse rentals, hostels and properties for sale',
                    style: TextStyle(
                      fontSize: 16,
                      color: Theme.of(
                        context,
                      ).colorScheme.onPrimary.withOpacity(0.8),
                    ),
                  ),
                  const SizedBox(height: 20),
                  // Property type buttons
                  Row(
                    children: [
                      Expanded(
                        child: _buildPropertyTypeButton(
                          'Buy',
                          PropertyType.sale,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _buildPropertyTypeButton(
                          'Rent',
                          PropertyType.rent,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _buildPropertyTypeButton(
                          'Student Hostels',
                          PropertyType.hostel,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  // University filter (for student hostels)
                  if (_selectedFilter == PropertyType.hostel) ...[
                    InkWell(
                      key: _universityDropdownKey,
                      onTap: () => _showUniversityPicker(context),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 16,
                        ),
                        decoration: BoxDecoration(
                          color: Theme.of(
                            context,
                          ).colorScheme.primary.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: Theme.of(context).colorScheme.primary,
                            width: 2,
                          ),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              _selectedUniversity ?? 'Select University',
                              style: TextStyle(
                                fontSize: 16,
                                color: _selectedUniversity != null
                                    ? Theme.of(
                                        context,
                                      ).textTheme.bodyLarge!.color
                                    : Theme.of(
                                        context,
                                      ).textTheme.bodySmall!.color,
                              ),
                            ),
                            Icon(
                              Icons.arrow_drop_down,
                              color: Theme.of(context).colorScheme.primary,
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                  ],

                  // Search Bar with Filter Button
                  Row(
                    children: [
                      Expanded(
                        child: Stack(
                          children: [
                            Container(
                              decoration: BoxDecoration(
                                color: Theme.of(context).cardColor,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Stack(
                                alignment: Alignment.centerLeft,
                                children: [
                                  if (_inlineAutocompleteSuggestion.isNotEmpty)
                                    Padding(
                                      padding: const EdgeInsets.only(
                                        left: 52,
                                        top: 16,
                                        bottom: 16,
                                      ),
                                      child: Text(
                                        _inlineAutocompleteSuggestion,
                                        style: TextStyle(
                                          fontSize: 16,
                                          color: Theme.of(
                                            context,
                                          ).textTheme.bodySmall!.color,
                                        ),
                                      ),
                                    ),
                                  TextField(
                                    controller: _searchController,
                                    focusNode: _searchFocusNode,
                                    style: TextStyle(
                                      fontSize: 16,
                                      color: Theme.of(
                                        context,
                                      ).textTheme.bodyLarge!.color,
                                    ),
                                    decoration: InputDecoration(
                                      hintText:
                                          'Search by location, city, area, or property...',
                                      prefixIcon: const Icon(Icons.search),
                                      suffixIcon:
                                          _searchController.text.isNotEmpty ||
                                              _isSearchActive
                                          ? IconButton(
                                              icon: const Icon(Icons.clear),
                                              onPressed: _clearSearch,
                                            )
                                          : null,
                                      border: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(12),
                                        borderSide: BorderSide.none,
                                      ),
                                      fillColor: Colors.transparent,
                                      filled: true,
                                      contentPadding:
                                          const EdgeInsets.symmetric(
                                            horizontal: 16,
                                            vertical: 16,
                                          ),
                                    ),
                                    onTap: () {
                                      if (_searchHistory.isNotEmpty &&
                                          _searchController.text.isEmpty) {
                                        setState(() {
                                          _showHistory = true;
                                          _showSuggestions = false;
                                        });
                                      }
                                    },
                                    onChanged: (value) {
                                      _scheduleSuggestionsUpdate(value);
                                      setState(() {
                                        _showHistory = false;
                                        _isSearchActive = value.isNotEmpty;
                                      });
                                    },
                                    onSubmitted: (value) {
                                      if (value.isNotEmpty) {
                                        _performSearch();
                                      }
                                    },
                                  ),
                                ],
                              ),
                            ),
                            if (_showSuggestions && _searchSuggestions.isNotEmpty)
                              Positioned(
                                top: 60,
                                left: 0,
                                right: 0,
                                child: Material(
                                  elevation: 8,
                                  borderRadius: BorderRadius.circular(12),
                                  shadowColor: Colors.black.withOpacity(0.3),
                                  child: Container(
                                    constraints: const BoxConstraints(
                                      maxHeight: 250,
                                    ),
                                    decoration: BoxDecoration(
                                      color: Theme.of(context).cardColor,
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(
                                        color: Theme.of(context).dividerColor,
                                        width: 1,
                                      ),
                                    ),
                                    child: ListView.builder(
                                      shrinkWrap: true,
                                      padding: const EdgeInsets.symmetric(
                                        vertical: 4,
                                      ),
                                      itemCount: _searchSuggestions.length,
                                      itemBuilder: (context, index) {
                                        final suggestion =
                                            _searchSuggestions[index];
                                        final isTypo = _isTypoCorrection(
                                          _searchController.text,
                                          suggestion,
                                        );
                                        return ListTile(
                                          dense: true,
                                          leading: Icon(
                                            _commonLocations.contains(suggestion)
                                                ? Icons.location_on
                                                : _propertyTypes.contains(suggestion)
                                                    ? Icons.home
                                                    : Icons.history,
                                            color: Theme.of(
                                              context,
                                            ).colorScheme.primary,
                                            size: 20,
                                          ),
                                          title: RichText(
                                            text: TextSpan(
                                              children: [
                                                TextSpan(
                                                  text: suggestion,
                                                  style: TextStyle(
                                                    fontSize: 14,
                                                    color: Theme.of(context)
                                                        .textTheme
                                                        .bodyLarge!
                                                        .color,
                                                    fontWeight: FontWeight.w500,
                                                  ),
                                                ),
                                                if (isTypo)
                                                  TextSpan(
                                                    text:
                                                        '  (Did you mean this?)',
                                                    style: TextStyle(
                                                      fontSize: 12,
                                                      color: Colors.orange[700],
                                                      fontStyle:
                                                          FontStyle.italic,
                                                    ),
                                                  ),
                                              ],
                                            ),
                                          ),
                                          onTap: () {
                                            _searchController.text = suggestion;
                                            setState(() {
                                              _showSuggestions = false;
                                              _inlineAutocompleteSuggestion =
                                                  '';
                                            });
                                            _performSearch();
                                          },
                                        );
                                      },
                                    ),
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        decoration: BoxDecoration(
                          color: _showFilters
                              ? Theme.of(context).colorScheme.primary
                              : Theme.of(context).cardColor,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: _showFilters
                                ? Theme.of(context).colorScheme.primary
                                : Theme.of(context).dividerColor,
                            width: 1,
                          ),
                        ),
                        child: IconButton(
                          icon: Icon(
                            Icons.filter_list,
                            color: _showFilters
                                ? Theme.of(context).colorScheme.onPrimary
                                : Theme.of(context).iconTheme.color,
                          ),
                          onPressed: () {
                            setState(() => _showFilters = !_showFilters);
                          },
                          tooltip: 'Filter properties',
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

          Expanded(
            child: SingleChildScrollView(
              key: const PageStorageKey<String>('customer_home_scroll'),
              controller: _scrollController,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [

            // Search History
            if (_showHistory && _searchHistory.isNotEmpty)
              Container(
                color: Theme.of(context).cardColor,
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Recent Searches',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                        TextButton(
                          onPressed: _clearSearchHistory,
                          child: const Text('Clear All'),
                        ),
                      ],
                    ),
                    ListView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: _searchHistory.length,
                      itemBuilder: (context, index) {
                        final query = _searchHistory[index];
                        return ListTile(
                          leading: const Icon(
                            Icons.history,
                            color: Colors.grey,
                          ),
                          title: Text(query),
                          trailing: IconButton(
                            icon: const Icon(Icons.close, size: 20),
                            onPressed: () => _removeHistoryItem(query),
                          ),
                          onTap: () {
                            _searchController.text = query;
                            setState(() {
                              _showHistory = false;
                            });
                            _performSearch();
                          },
                        );
                      },
                    ),
                    const Divider(height: 1, thickness: 2),
                  ],
                ),
              ),

            // Filters Section
            if (_showFilters)
              Container(
                padding: const EdgeInsets.all(20),
                color: Theme.of(context).scaffoldBackgroundColor,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Filters',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        TextButton(
                          onPressed: () {
                            setState(() {
                              _minPrice = 0;
                              _maxPrice = 10000000;
                              _minPriceController.clear();
                              _maxPriceController.clear();
                              _bedrooms = null;
                              _selectedPropertyType = null;
                            });
                          },
                          child: const Text('Clear Filters'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // Price Range Filter
                    const Text(
                      'Price Range',
                      style: TextStyle(fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        // Minimum Price
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Minimum',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w500,
                                  color: Colors.grey,
                                ),
                              ),
                              const SizedBox(height: 6),
                              TextFormField(
                                controller: _minPriceController,
                                keyboardType: TextInputType.number,
                                decoration: InputDecoration(
                                  hintText: 'Enter minimum price',
                                  prefixText: 'UGX ',
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(8),
                                    borderSide: BorderSide(
                                      color: Colors.grey.shade300,
                                    ),
                                  ),
                                  enabledBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(8),
                                    borderSide: BorderSide(
                                      color: Colors.grey.shade300,
                                    ),
                                  ),
                                  focusedBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(8),
                                    borderSide: const BorderSide(
                                      color: AppColors.primary,
                                    ),
                                  ),
                                  contentPadding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 12,
                                  ),
                                  suffixIcon: PopupMenuButton<double>(
                                    icon: const Icon(Icons.arrow_drop_down),
                                    tooltip: 'Select preset price',
                                    onSelected: (value) {
                                      setState(() {
                                        _minPrice = value;
                                        _minPriceController.text = value == 0
                                            ? ''
                                            : CurrencyFormatter.format(value);
                                        if (_maxPrice <= _minPrice &&
                                            _minPrice > 0) {
                                          _maxPrice = _minPrice + 100000;
                                          _maxPriceController.text =
                                              CurrencyFormatter.format(
                                                _maxPrice,
                                              );
                                        }
                                      });
                                    },
                                    itemBuilder: (context) => [
                                      const PopupMenuItem(
                                        value: 0,
                                        child: Text('Any'),
                                      ),
                                      const PopupMenuItem(
                                        value: 100000,
                                        child: Text('100k'),
                                      ),
                                      const PopupMenuItem(
                                        value: 200000,
                                        child: Text('200k'),
                                      ),
                                      const PopupMenuItem(
                                        value: 300000,
                                        child: Text('300k'),
                                      ),
                                      const PopupMenuItem(
                                        value: 500000,
                                        child: Text('500k'),
                                      ),
                                      const PopupMenuItem(
                                        value: 700000,
                                        child: Text('700k'),
                                      ),
                                      const PopupMenuItem(
                                        value: 1000000,
                                        child: Text('1M'),
                                      ),
                                      const PopupMenuItem(
                                        value: 1500000,
                                        child: Text('1.5M'),
                                      ),
                                      const PopupMenuItem(
                                        value: 2000000,
                                        child: Text('2M'),
                                      ),
                                      const PopupMenuItem(
                                        value: 3000000,
                                        child: Text('3M'),
                                      ),
                                      const PopupMenuItem(
                                        value: 5000000,
                                        child: Text('5M'),
                                      ),
                                    ],
                                  ),
                                ),
                                onChanged: (value) {
                                  setState(() {
                                    _minPrice = value.isEmpty
                                        ? 0.0
                                        : CurrencyFormatter.parse(value);
                                  });
                                },
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 12),
                        // Maximum Price
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Maximum',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w500,
                                  color: Colors.grey,
                                ),
                              ),
                              const SizedBox(height: 6),
                              TextFormField(
                                controller: _maxPriceController,
                                keyboardType: TextInputType.number,
                                decoration: InputDecoration(
                                  hintText: 'Enter maximum price',
                                  prefixText: 'UGX ',
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(8),
                                    borderSide: BorderSide(
                                      color: Colors.grey.shade300,
                                    ),
                                  ),
                                  enabledBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(8),
                                    borderSide: BorderSide(
                                      color: Colors.grey.shade300,
                                    ),
                                  ),
                                  focusedBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(8),
                                    borderSide: const BorderSide(
                                      color: AppColors.primary,
                                    ),
                                  ),
                                  contentPadding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 12,
                                  ),
                                  suffixIcon: PopupMenuButton<double>(
                                    icon: const Icon(Icons.arrow_drop_down),
                                    tooltip: 'Select preset price',
                                    onSelected: (value) {
                                      setState(() {
                                        _maxPrice = value;
                                        _maxPriceController.text =
                                            CurrencyFormatter.format(value);
                                        if (_minPrice >= _maxPrice &&
                                            _maxPrice > 0) {
                                          _minPrice = _maxPrice > 100000
                                              ? _maxPrice - 100000
                                              : 0;
                                          _minPriceController.text =
                                              _minPrice == 0
                                              ? ''
                                              : CurrencyFormatter.format(
                                                  _minPrice,
                                                );
                                        }
                                      });
                                    },
                                    itemBuilder: (context) => [
                                      const PopupMenuItem(
                                        value: 200000,
                                        child: Text('200k'),
                                      ),
                                      const PopupMenuItem(
                                        value: 300000,
                                        child: Text('300k'),
                                      ),
                                      const PopupMenuItem(
                                        value: 500000,
                                        child: Text('500k'),
                                      ),
                                      const PopupMenuItem(
                                        value: 700000,
                                        child: Text('700k'),
                                      ),
                                      const PopupMenuItem(
                                        value: 1000000,
                                        child: Text('1M'),
                                      ),
                                      const PopupMenuItem(
                                        value: 1500000,
                                        child: Text('1.5M'),
                                      ),
                                      const PopupMenuItem(
                                        value: 2000000,
                                        child: Text('2M'),
                                      ),
                                      const PopupMenuItem(
                                        value: 3000000,
                                        child: Text('3M'),
                                      ),
                                      const PopupMenuItem(
                                        value: 5000000,
                                        child: Text('5M'),
                                      ),
                                      const PopupMenuItem(
                                        value: 7000000,
                                        child: Text('7M'),
                                      ),
                                      const PopupMenuItem(
                                        value: 10000000,
                                        child: Text('10M+'),
                                      ),
                                    ],
                                  ),
                                ),
                                onChanged: (value) {
                                  setState(() {
                                    _maxPrice = value.isEmpty
                                        ? 10000000.0
                                        : CurrencyFormatter.parse(value);
                                  });
                                },
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // Bedrooms Filter
                    const Text(
                      'Bedrooms (minimum)',
                      style: TextStyle(fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      children: [1, 2, 3, 4, 5].map((num) {
                        return FilterChip(
                          label: Text('$num+'),
                          selected: _bedrooms == num,
                          onSelected: (selected) {
                            setState(() {
                              _bedrooms = selected ? num : null;
                            });
                          },
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 16),

                    // Property Type Filter
                    const Text(
                      'Property Type',
                      style: TextStyle(fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: PropertyType.values.map((type) {
                        String label;
                        switch (type) {
                          case PropertyType.sale:
                            label = 'For Sale';
                            break;
                          case PropertyType.rent:
                            label = 'For Rent';
                            break;
                          case PropertyType.hostel:
                            label = 'Hostel';
                            break;
                        }
                        return FilterChip(
                          label: Text(label),
                          selected: _selectedPropertyType == type,
                          onSelected: (selected) {
                            setState(() {
                              _selectedPropertyType = selected ? type : null;
                            });
                          },
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 16),

                    // Apply Filters Button
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: () {
                          _performSearch();
                          setState(() {
                            _showFilters = false;
                          });
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: const Text(
                          'Apply Filters',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),

            // Show search results if search is active
            if (_isSearchActive) _buildSearchResults(),

            // Show normal content if search is not active
            if (!_isSearchActive) ...[
              const SizedBox(height: 24),

              // Show filtered properties FIRST only when a filter button is clicked
              if (_selectedFilter != null) ...[
                // Scroll anchor - positioned to hide everything above when scrolled to
                Container(
                  key: _propertiesSectionKey,
                  height: 1,
                  color: Colors.transparent,
                ),
                // Featured Properties Section - Shows when filter is active
                Container(
                  child: Column(
                    children: [
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                              child: Text(
                                _selectedPropertyLocation != null
                                    ? 'Properties in $_selectedPropertyLocation'
                                    : _selectedFilter == PropertyType.rent
                                    ? 'Properties for Rent'
                                    : _selectedFilter == PropertyType.sale
                                    ? 'Properties for Sale'
                                    : 'Student Hostels',
                                style: TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                  color: Theme.of(
                                    context,
                                  ).textTheme.bodyLarge!.color,
                                ),
                              ),
                            ),
                            TextButton(
                              onPressed: () {
                                setState(() {
                                  _selectedFilter = PropertyType.sale;
                                  _selectedPropertyLocation = null;
                                  _displayedPropertiesCount =
                                      3; // Reset pagination to 3
                                });
                                _loadPropertyLocations();
                              },
                              child: const Text('Clear Filter'),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),
                      // Location filter tabs
                      if (_propertyLocations.isNotEmpty) ...[
                        SizedBox(
                          height: 45,
                          child: ListView.builder(
                            scrollDirection: Axis.horizontal,
                            padding: const EdgeInsets.symmetric(horizontal: 20),
                            itemCount: _propertyLocations.length + 1,
                            itemBuilder: (context, index) {
                              if (index == 0) {
                                return Padding(
                                  padding: const EdgeInsets.only(right: 12),
                                  child: ChoiceChip(
                                    label: const Text('All Areas'),
                                    selected: _selectedPropertyLocation == null,
                                    onSelected: (selected) {
                                      if (selected) {
                                        setState(() {
                                          _selectedPropertyLocation = null;
                                          _displayedPropertiesCount =
                                              3; // Reset pagination to 3
                                        });
                                      }
                                    },
                                    selectedColor: Theme.of(
                                      context,
                                    ).colorScheme.primary,
                                    labelStyle: TextStyle(
                                      color: _selectedPropertyLocation == null
                                          ? Theme.of(
                                              context,
                                            ).colorScheme.onPrimary
                                          : Theme.of(
                                              context,
                                            ).textTheme.bodyLarge!.color,
                                      fontWeight:
                                          _selectedPropertyLocation == null
                                          ? FontWeight.bold
                                          : FontWeight.normal,
                                    ),
                                    backgroundColor: Colors.grey.shade200,
                                  ),
                                );
                              }
                              final location = _propertyLocations[index - 1];
                              final isSelected =
                                  location == _selectedPropertyLocation;
                              return Padding(
                                padding: const EdgeInsets.only(right: 12),
                                child: ChoiceChip(
                                  label: Text(location),
                                  selected: isSelected,
                                  onSelected: (selected) {
                                    if (selected) {
                                      setState(() {
                                        _selectedPropertyLocation = location;
                                        _displayedPropertiesCount =
                                            3; // Reset pagination to 3
                                      });
                                    }
                                  },
                                  selectedColor: Theme.of(
                                    context,
                                  ).colorScheme.primary,
                                  labelStyle: TextStyle(
                                    color: isSelected
                                        ? Theme.of(
                                            context,
                                          ).colorScheme.onPrimary
                                        : Theme.of(
                                            context,
                                          ).textTheme.bodyLarge!.color,
                                    fontWeight: isSelected
                                        ? FontWeight.bold
                                        : FontWeight.normal,
                                  ),
                                  backgroundColor: Theme.of(
                                    context,
                                  ).chipTheme.backgroundColor,
                                ),
                              );
                            },
                          ),
                        ),
                        const SizedBox(height: 12),
                      ],
                      const SizedBox(height: 8),
                      // Properties Grid
                      StreamBuilder<QuerySnapshot>(
                        stream: FirebaseFirestore.instance
                            .collection('properties')
                            .where('status', isEqualTo: 'approved')
                            .where('isActive', isEqualTo: true)
                            .orderBy('createdAt', descending: true)
                            .snapshots(),
                        builder: (context, snapshot) {
                          if (snapshot.connectionState ==
                              ConnectionState.waiting) {
                            return const Padding(
                              padding: EdgeInsets.all(40),
                              child: Center(child: CircularProgressIndicator()),
                            );
                          }

                          if (snapshot.hasError) {
                            return Padding(
                              padding: const EdgeInsets.all(40),
                              child: Center(
                                child: Text('Error: ${snapshot.error}'),
                              ),
                            );
                          }

                          if (!snapshot.hasData ||
                              snapshot.data!.docs.isEmpty) {
                            return Padding(
                              padding: const EdgeInsets.all(40),
                              child: Center(
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(
                                      Icons.home_outlined,
                                      size: 64,
                                      color: Theme.of(context)
                                          .textTheme
                                          .bodySmall!
                                          .color
                                          ?.withOpacity(0.4),
                                    ),
                                    const SizedBox(height: 16),
                                    Text(
                                      'No properties available yet',
                                      style: TextStyle(
                                        color: Theme.of(
                                          context,
                                        ).textTheme.bodySmall!.color,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          }

                          // Get all properties and apply filters
                          var allProperties = snapshot.data!.docs.map((doc) {
                            final data = doc.data() as Map<String, dynamic>;
                            data['id'] = doc.id;

                            return PropertyModel.fromJson(data);
                          }).toList();

                          // Filter by property type
                          if (_selectedFilter != null) {
                            allProperties = allProperties
                                .where((p) => p.type == _selectedFilter)
                                .toList();
                          }

                          // Filter by university (for hostels)
                          if (_selectedFilter == PropertyType.hostel &&
                              _selectedUniversity != null) {
                            allProperties = allProperties
                                .where(
                                  (p) => p.university == _selectedUniversity,
                                )
                                .toList();
                          }

                          // Filter by location
                          List<PropertyModel> filteredProperties = [];
                          List<PropertyModel> otherAreaProperties = [];

                          if (_selectedPropertyLocation != null) {
                            filteredProperties = allProperties
                                .where(
                                  (p) =>
                                      p.location.trim().toLowerCase() ==
                                      _selectedPropertyLocation!
                                          .trim()
                                          .toLowerCase(),
                                )
                                .toList();

                            // Get properties from other areas for suggestions
                            otherAreaProperties = allProperties
                                .where(
                                  (p) =>
                                      p.location.trim().toLowerCase() !=
                                      _selectedPropertyLocation!
                                          .trim()
                                          .toLowerCase(),
                                )
                                .take(4)
                                .toList();
                          } else {
                            filteredProperties = allProperties;
                          }

                          final properties = filteredProperties;

                          // Show properties or empty state with suggestions
                          if (properties.isEmpty &&
                              _selectedPropertyLocation != null) {
                            return Padding(
                              padding: const EdgeInsets.all(20),
                              child: Column(
                                children: [
                                  Icon(
                                    Icons.location_off,
                                    size: 64,
                                    color: Colors.grey[400],
                                  ),
                                  const SizedBox(height: 16),
                                  Text(
                                    _selectedPropertyLocation != null && _selectedFilter == PropertyType.hostel
                                        ? 'We are currently onboarding listings in $_selectedPropertyLocation. Please check back shortly!'
                                        : 'No properties available in $_selectedPropertyLocation yet',
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                      fontSize: 16,
                                      color: Colors.grey[700],
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    'But here are some properties in other areas that might interest you:',
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                      fontSize: 14,
                                      color: Colors.grey[600],
                                    ),
                                  ),
                                  const SizedBox(height: 24),
                                  if (otherAreaProperties.isNotEmpty)
                                    ListView.builder(
                                      shrinkWrap: true,
                                      physics:
                                          const NeverScrollableScrollPhysics(),
                                      itemCount: otherAreaProperties.length,
                                      itemBuilder: (context, index) {
                                        return Padding(
                                          padding: const EdgeInsets.only(
                                            bottom: 16,
                                          ),
                                          child: _buildPropertyCard(
                                            context,
                                            otherAreaProperties[index],
                                          ),
                                        );
                                      },
                                    ),
                                ],
                              ),
                            );
                          }

                          if (properties.isEmpty) {
                            return Padding(
                              padding: const EdgeInsets.all(40),
                              child: Center(
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(
                                      Icons.home_outlined,
                                      size: 64,
                                      color: Colors.grey[400],
                                    ),
                                    const SizedBox(height: 16),
                                    Text(
                                      _selectedFilter == null
                                          ? 'No properties available yet'
                                          : _selectedFilter == PropertyType.hostel
                                              ? 'We are currently onboarding listings in this area. Please check back shortly!'
                                              : 'No ${_selectedFilter == PropertyType.rent
                                                    ? "rental"
                                                    : "sale"} properties available',
                                      style: TextStyle(color: Colors.grey[600]),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          }

                          // Calculate properties to display
                          final totalProperties = properties.length;
                          final propertiesToDisplay = properties
                              .take(_displayedPropertiesCount)
                              .toList();
                          final hasMore =
                              totalProperties > _displayedPropertiesCount;

                          return Column(
                            children: [
                              // Responsive property list - grid on desktop, list on mobile
                              Center(
                                child: ConstrainedBox(
                                  constraints: BoxConstraints(
                                    maxWidth: ResponsiveHelper.getMaxContentWidth(context),
                                  ),
                                  child: Padding(
                                    padding: ResponsiveHelper.getContentPadding(context),
                                    child: ResponsiveHelper.isDesktop(context)
                                        ? GridView.builder(
                                            shrinkWrap: true,
                                            physics: const NeverScrollableScrollPhysics(),
                                            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                                              crossAxisCount: ResponsiveHelper.getGridCrossAxisCount(
                                                context,
                                                mobileCount: 1,
                                                tabletCount: 2,
                                                desktopCount: 3,
                                                largeDesktopCount: 4,
                                              ),
                                              childAspectRatio: 0.75,
                                              crossAxisSpacing: 20,
                                              mainAxisSpacing: 20,
                                            ),
                                            itemCount: propertiesToDisplay.length,
                                            itemBuilder: (context, index) {
                                              return _buildPropertyCard(
                                                context,
                                                propertiesToDisplay[index],
                                              );
                                            },
                                          )
                                        : ListView.builder(
                                            shrinkWrap: true,
                                            physics: const NeverScrollableScrollPhysics(),
                                            itemCount: propertiesToDisplay.length,
                                            itemBuilder: (context, index) {
                                              return Padding(
                                                padding: const EdgeInsets.only(bottom: 16),
                                                child: _buildPropertyCard(
                                                  context,
                                                  propertiesToDisplay[index],
                                                ),
                                              );
                                            },
                                          ),
                                  ),
                                ),
                              ),
                              if (hasMore) ...[
                                const SizedBox(height: 12),
                                Padding(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 16,
                                  ),
                                  child: Container(
                                    decoration: BoxDecoration(
                                      gradient: LinearGradient(
                                        colors: [
                                          AppColors.primary.withOpacity(0.05),
                                          AppColors.primary.withOpacity(0.1),
                                        ],
                                      ),
                                      borderRadius: BorderRadius.circular(16),
                                      border: Border.all(
                                        color: AppColors.primary.withOpacity(
                                          0.3,
                                        ),
                                        width: 1.5,
                                      ),
                                    ),
                                    child: Material(
                                      color: Colors.transparent,
                                      child: InkWell(
                                        onTap: () {
                                          setState(() {
                                            _displayedPropertiesCount +=
                                                _propertiesPerPage;
                                          });
                                        },
                                        borderRadius: BorderRadius.circular(16),
                                        child: Padding(
                                          padding: const EdgeInsets.symmetric(
                                            vertical: 20,
                                            horizontal: 24,
                                          ),
                                          child: Column(
                                            children: [
                                              Row(
                                                mainAxisAlignment:
                                                    MainAxisAlignment.center,
                                                children: [
                                                  Icon(
                                                    Icons.add_circle_outline,
                                                    color: AppColors.primary,
                                                    size: 24,
                                                  ),
                                                  const SizedBox(width: 12),
                                                  Text(
                                                    'View More Properties',
                                                    style: TextStyle(
                                                      color: AppColors.primary,
                                                      fontSize: 17,
                                                      fontWeight:
                                                          FontWeight.bold,
                                                      letterSpacing: 0.5,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                              const SizedBox(height: 8),
                                              Text(
                                                '${totalProperties - propertiesToDisplay.length} more available',
                                                style: TextStyle(
                                                  fontSize: 13,
                                                  color: AppColors.primary
                                                      .withOpacity(0.8),
                                                  fontWeight: FontWeight.w500,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 12),
                                Padding(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 16,
                                  ),
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 16,
                                          vertical: 8,
                                        ),
                                        decoration: BoxDecoration(
                                          color: Theme.of(context).cardColor,
                                          borderRadius: BorderRadius.circular(
                                            20,
                                          ),
                                          border: Border.all(
                                            color: Theme.of(
                                              context,
                                            ).dividerColor,
                                          ),
                                        ),
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Icon(
                                              Icons.visibility,
                                              size: 16,
                                              color: Theme.of(
                                                context,
                                              ).textTheme.bodySmall!.color,
                                            ),
                                            const SizedBox(width: 6),
                                            Text(
                                              'Showing ${propertiesToDisplay.length} of $totalProperties',
                                              textAlign: TextAlign.center,
                                              style: TextStyle(
                                                fontSize: 13,
                                                color: Theme.of(
                                                  context,
                                                ).textTheme.bodyMedium!.color,
                                                fontWeight: FontWeight.w600,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ],
                          );
                        },
                      ),
                      const SizedBox(height: 24),
                    ],
                  ),
                ), // Close Container for filtered properties section
                const SizedBox(height: 24),
              ], // Close if (_selectedFilter != null)
              // Browse New Projects Section
              _buildBrowseNewProjectsSection(),
              const SizedBox(height: 24),
              if (kIsWeb) const WebFooter(),
            ],
          ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchResults() {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '${_searchResults.length} ${_searchResults.length == 1 ? "property" : "properties"} found',
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              if (_searchResults.isNotEmpty)
                TextButton.icon(
                  onPressed: _clearSearch,
                  icon: const Icon(Icons.close, size: 18),
                  label: const Text('Clear'),
                ),
            ],
          ),
          const SizedBox(height: 16),
          _searchResults.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const SizedBox(height: 40),
                      Icon(
                        Icons.search_off,
                        size: 80,
                        color: Theme.of(
                          context,
                        ).textTheme.bodySmall!.color?.withOpacity(0.4),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'No properties found',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w500,
                          color: Theme.of(context).textTheme.bodyMedium!.color,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Try adjusting your search or filters',
                        style: TextStyle(
                          fontSize: 14,
                          color: Theme.of(context).textTheme.bodySmall!.color,
                        ),
                      ),
                      const SizedBox(height: 16),
                      Container(
                        padding: const EdgeInsets.all(16),
                        margin: const EdgeInsets.symmetric(horizontal: 32),
                        decoration: BoxDecoration(
                          color: Theme.of(context).cardColor,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: Theme.of(context).dividerColor,
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Active Filters:',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: Theme.of(
                                  context,
                                ).textTheme.bodyMedium!.color,
                              ),
                            ),
                            const SizedBox(height: 8),
                            if (_searchController.text.isNotEmpty)
                              Text('• Search: "${_searchController.text}"'),
                            Text(
                              '• Price: UGX ${CurrencyFormatter.format(_minPrice)} - ${CurrencyFormatter.format(_maxPrice)}',
                            ),
                            if (_bedrooms != null)
                              Text('• Bedrooms: $_bedrooms+'),
                            if (_selectedPropertyType != null)
                              Text(
                                '• Type: ${_selectedPropertyType.toString().split('.').last}',
                              ),
                          ],
                        ),
                      ),
                    ],
                  ),
                )
              : ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: _searchResults.length,
                  separatorBuilder: (context, index) =>
                      const SizedBox(height: 16),
                  itemBuilder: (context, index) {
                    return _buildSearchResultCard(
                      context,
                      _searchResults[index],
                    );
                  },
                ),
        ],
      ),
    );
  }

  Widget _buildPropertyTypeButton(String label, PropertyType type) {
    final isSelected = _selectedFilter == type;
    return ElevatedButton(
      onPressed: () {
        setState(() {
          _selectedFilter = type;
          _displayedPropertiesCount =
              3; // Reset pagination to 3 when filter changes
          _selectedPropertyLocation = null; // Reset location filter
        });
        // Reload locations for the selected property type
        _loadPropertyLocations();

        // For hostels, scroll to university dropdown and open picker
        if (type == PropertyType.hostel && !isSelected) {
          Future.delayed(const Duration(milliseconds: 100), () {
            final context = _universityDropdownKey.currentContext;
            if (context != null) {
              final RenderBox? renderBox =
                  context.findRenderObject() as RenderBox?;
              if (renderBox != null) {
                final position = renderBox.localToGlobal(Offset.zero);
                final scrollPosition =
                    _scrollController.offset + position.dy - 100;

                _scrollController
                    .animateTo(
                      scrollPosition,
                      duration: const Duration(milliseconds: 500),
                      curve: Curves.easeInOut,
                    )
                    .then((_) {
                      // Open university picker after scrolling
                      Future.delayed(const Duration(milliseconds: 300), () {
                        _showUniversityPicker(context);
                      });
                    });
              }
            }
          });
          return;
        }
        // For rent and sale buttons, no automatic scrolling
      },
      style: ElevatedButton.styleFrom(
        backgroundColor: isSelected
            ? Theme.of(context).colorScheme.primary
            : Theme.of(context).cardColor,
        foregroundColor: isSelected
            ? Theme.of(context).colorScheme.onPrimary
            : Theme.of(context).textTheme.bodyLarge!.color,
        elevation: isSelected ? 4 : 1,
        padding: const EdgeInsets.symmetric(vertical: 12),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
          side: BorderSide(
            color: isSelected
                ? Theme.of(context).colorScheme.primary
                : Theme.of(context).dividerColor,
            width: 1,
          ),
        ),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 13,
          fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
        ),
      ),
    );
  }

  // Show university picker modal
  void _showUniversityPicker(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (BuildContext context) {
        return Container(
          decoration: BoxDecoration(
            color: Theme.of(context).cardColor,
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(20),
              topRight: Radius.circular(20),
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.primary,
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(20),
                    topRight: Radius.circular(20),
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Select University',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Theme.of(context).colorScheme.onPrimary,
                      ),
                    ),
                    IconButton(
                      icon: Icon(
                        Icons.close,
                        color: Theme.of(context).colorScheme.onPrimary,
                      ),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
              ),
              Flexible(
                child: ListView(
                  shrinkWrap: true,
                  children: [
                    ListTile(
                      leading: Icon(
                        Icons.school,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                      title: const Text(
                        'All Universities',
                        style: TextStyle(fontWeight: FontWeight.w500),
                      ),
                      trailing: _selectedUniversity == null
                          ? Icon(
                              Icons.check,
                              color: Theme.of(context).colorScheme.primary,
                            )
                          : null,
                      onTap: () {
                        Navigator.pop(context);
                        setState(() {
                          _selectedUniversity = null;
                        });
                        _scrollToProperties();
                      },
                    ),
                    const Divider(),
                    ...universities.map((university) {
                      final isSelected = _selectedUniversity == university;
                      return ListTile(
                        leading: Icon(
                          Icons.school_outlined,
                          color: isSelected
                              ? Theme.of(context).colorScheme.primary
                              : Theme.of(context).textTheme.bodySmall!.color,
                        ),
                        title: Text(
                          university,
                          style: TextStyle(
                            fontWeight: isSelected
                                ? FontWeight.w600
                                : FontWeight.normal,
                            color: isSelected
                                ? Theme.of(context).colorScheme.primary
                                : Theme.of(context).textTheme.bodyLarge!.color,
                          ),
                        ),
                        trailing: isSelected
                            ? Icon(
                                Icons.check,
                                color: Theme.of(context).colorScheme.primary,
                              )
                            : null,
                        onTap: () {
                          Navigator.pop(context);
                          setState(() {
                            _selectedUniversity = university;
                          });
                          _scrollToProperties();
                        },
                      );
                    }),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  // Helper method to scroll to properties section
  void _scrollToProperties() {
    Future.delayed(const Duration(milliseconds: 100), () {
      final context = _propertiesSectionKey.currentContext;
      if (context != null) {
        final RenderBox? renderBox = context.findRenderObject() as RenderBox?;
        if (renderBox != null) {
          final position = renderBox.localToGlobal(Offset.zero);
          final scrollPosition = _scrollController.offset + position.dy;

          _scrollController.animateTo(
            scrollPosition,
            duration: const Duration(milliseconds: 500),
            curve: Curves.easeInOut,
          );
        }
      }
    });
  }

  // Normalize a location string to Title Case (e.g. 'kololo' → 'Kololo', 'NEW kampala' → 'New Kampala')
  String _toTitleCase(String text) {
    return text.trim().split(' ').map((word) {
      if (word.isEmpty) return '';
      return '${word[0].toUpperCase()}${word.substring(1).toLowerCase()}';
    }).join(' ');
  }

  // Load available project locations
  Future<void> _loadProjectLocations() async {
    final locations = await _projectService.getAvailableLocations();
    if (mounted) {
      setState(() {
        _projectLocations = locations;
      });
    }
  }

  // Load available property locations from Firestore
  Future<void> _loadPropertyLocations() async {
    if (!mounted) return;
    
    setState(() {
      _loadingPropertyLocations = true;
    });

    try {
      // Optimized: Only fetch location field, limit to reduce load
      var query = FirebaseFirestore.instance
          .collection('properties')
          .where('status', isEqualTo: 'approved')
          .where('isActive', isEqualTo: true)
          .limit(200); // Limit to first 200 properties for faster loading

      // Filter by property type if a filter is selected
      if (_selectedFilter != null) {
        query = query.where('type', isEqualTo: _selectedFilter!.name);
      }

      final querySnapshot = await query.get();

      // Use a map keyed on the normalised (lower-cased) name so that
      // 'kololo' and 'Kololo' are treated as the same location.
      final Map<String, String> locationMap = {};
      for (var doc in querySnapshot.docs) {
        final data = doc.data();
        if (data['location'] != null &&
            data['location'].toString().isNotEmpty) {
          final raw = data['location'] as String;
          final normalised = _toTitleCase(raw);
          locationMap.putIfAbsent(normalised.toLowerCase(), () => normalised);
        }
      }
      final Set<String> locations = locationMap.values.toSet();

      if (mounted) {
        setState(() {
          _propertyLocations = locations.toList()..sort();
          _loadingPropertyLocations = false;
        });
      }
    } catch (e) {
      print('Error loading property locations: $e');
      if (mounted) {
        setState(() {
          _loadingPropertyLocations = false;
        });
      }
    }
  }

  // Load new projects for rotating carousel
  Future<void> _loadNewProjects() async {
    if (!mounted) return;
    
    setState(() {
      _loadingNewProjects = true;
    });

    try {
      final now = DateTime.now();

      // Optimized: Query with limit for faster loading
      final querySnapshot = await FirebaseFirestore.instance
          .collection('properties')
          .where('status', isEqualTo: 'approved')
          .where('isActive', isEqualTo: true)
          .where('isNewProject', isEqualTo: true)
          .where('hasActivePromotion', isEqualTo: true)
          .limit(10) // Only load up to 10 promoted projects
          .get();

      List<PropertyModel> newProjects = [];

      for (var doc in querySnapshot.docs) {
        final data = doc.data();
        data['id'] = doc.id;
        final property = PropertyModel.fromJson(data);

        // Check if promotion is still active
        if (property.promotionEndDate == null ||
            property.promotionEndDate!.isAfter(now)) {
          newProjects.add(property);
        }
        
        // Break early if we have enough
        if (newProjects.length >= 6) break;
      }

      // Shuffle for variety
      newProjects.shuffle();
      
      // Limit to max 6 projects
      if (newProjects.length > 6) {
        newProjects = newProjects.sublist(0, 6);
      }

      if (mounted) {
        setState(() {
          _newProjects = newProjects;
          _loadingNewProjects = false;
        });
      }
    } catch (e) {
      print('Error loading new projects: $e');
      if (mounted) {
        setState(() {
          _loadingNewProjects = false;
        });
      }
    }
  }

  // Build Browse New Projects Section - Now using separate widget to prevent scroll jumps
  Widget _buildBrowseNewProjectsSection() {
    return BrowseNewProjectsSection(
      projectLocations: _projectLocations,
    );
  }

  // Build New Projects Carousel
  Widget _buildNewProjectsCarousel() {
    if (_loadingNewProjects) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(20),
          child: CircularProgressIndicator(),
        ),
      );
    }

    if (_newProjects.isEmpty) {
      return const SizedBox.shrink(); // Don't show section if no projects
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 20),
          child: Row(
            children: [
              Icon(
                Icons.star_border_rounded,
                color: AppColors.primary,
                size: 24,
              ),
              SizedBox(width: 8),
              Text(
                'Spotlight Properties',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: 340,
          child: PageView.builder(
            controller: _newProjectsPageController,
            itemCount: _newProjects.length,
            physics: const PageScrollPhysics(),
            onPageChanged: (index) {
              _currentNewProjectIndex.value = index;
            },
            itemBuilder: (context, index) {
              return _buildNewProjectCard(_newProjects[index]);
            },
          ),
        ),
        const SizedBox(height: 12),
        // Page indicators
        ValueListenableBuilder<int>(
          valueListenable: _currentNewProjectIndex,
          builder: (context, currentIndex, child) {
            return Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(
                _newProjects.length,
                (index) => Container(
                  margin: const EdgeInsets.symmetric(horizontal: 4),
                  width: currentIndex == index ? 24 : 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: currentIndex == index
                        ? AppColors.primary
                        : Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ),
            );
          },
        ),
      ],
    );
  }

  // Build New Project Card
  Widget _buildNewProjectCard(PropertyModel property) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: GestureDetector(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => PropertyDetailsScreen(property: property),
            ),
          );
        },
        child: Card(
          elevation: 6,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          clipBehavior: Clip.antiAlias,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              // Image with gradient overlay and "NEW" badge
              Stack(
                children: [
                  ClipRRect(
                    borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(16),
                    ),
                    child: property.imageUrls.isNotEmpty
                        ? CachedNetworkImage(
                            imageUrl: property.imageUrls[0],
                            height: 220,
                            width: double.infinity,
                            fit: BoxFit.cover,
                            placeholder: (context, url) => Container(
                              height: 220,
                              color: Theme.of(context).cardColor,
                              child: const Center(
                                child: CircularProgressIndicator(),
                              ),
                            ),
                            errorWidget: (context, url, error) {
                              return Container(
                                height: 220,
                                color: Theme.of(context).cardColor,
                                child: const Center(
                                  child: Icon(
                                    Icons.image_not_supported,
                                    size: 50,
                                  ),
                                ),
                              );
                            },
                          )
                        : Container(
                            height: 220,
                            color: Theme.of(context).cardColor,
                            child: const Center(
                              child: Icon(Icons.image_not_supported, size: 50),
                            ),
                          ),
                  ),
                  // Gradient overlay
                  Positioned.fill(
                    child: Container(
                      decoration: BoxDecoration(
                        borderRadius: const BorderRadius.vertical(
                          top: Radius.circular(16),
                        ),
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            Colors.transparent,
                            Colors.black.withOpacity(0.5),
                          ],
                        ),
                      ),
                    ),
                  ),
                  // Sale/Rent badge
                  Positioned(
                    top: 12,
                    left: 12,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.red,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        property.type == PropertyType.sale
                            ? 'FOR SALE'
                            : 'FOR RENT',
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.onError,
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ),
                  // Promotion badge
                  if (property.hasActivePromotion)
                    Positioned(
                      top: 12,
                      right: 12,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.primary,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.local_fire_department,
                              color: Theme.of(context).colorScheme.onPrimary,
                              size: 14,
                            ),
                            SizedBox(width: 4),
                            Text(
                              'Featured',
                              style: TextStyle(
                                color: Theme.of(context).colorScheme.onPrimary,
                                fontWeight: FontWeight.bold,
                                fontSize: 11,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
              // Property details
              Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      property.title,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Theme.of(context).textTheme.bodyLarge!.color,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Icon(
                          Icons.location_on,
                          size: 14,
                          color: Theme.of(context).textTheme.bodySmall!.color,
                        ),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            property.location,
                            style: TextStyle(
                              color: Theme.of(
                                context,
                              ).textTheme.bodySmall!.color,
                              fontSize: 13,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      '${property.currency} ${CurrencyFormatter.format(property.price)}',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // Search result card with horizontal layout - no overflow issues
  Widget _buildSearchResultCard(BuildContext context, PropertyModel property) {
    final isDesktop = ResponsiveHelper.isDesktop(context);
    final cardImageHeight = isDesktop ? 250.0 : 210.0;

    return Card(
      elevation: 3,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: InkWell(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => PropertyDetailsScreen(property: property),
            ),
          );
        },
        borderRadius: BorderRadius.circular(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Stack(
              children: [
                SizedBox(
                  width: double.infinity,
                  height: cardImageHeight,
                  child: property.imageUrls.isNotEmpty
                      ? CachedNetworkImage(
                          imageUrl: property.imageUrls.first,
                          fit: BoxFit.cover,
                          placeholder: (context, url) => Container(
                            color: Theme.of(context).cardColor,
                            child: const Center(
                              child: SizedBox(
                                width: 24,
                                height: 24,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              ),
                            ),
                          ),
                          errorWidget: (context, url, error) => Container(
                            color: Theme.of(context).cardColor,
                            child: const Center(
                              child: Icon(Icons.image_not_supported, size: 48),
                            ),
                          ),
                        )
                      : Container(
                          color: Colors.grey[300],
                          child: const Center(
                            child: Icon(Icons.home, size: 52, color: Colors.grey),
                          ),
                        ),
                ),
                Positioned(
                  top: 12,
                  left: 12,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: property.type == PropertyType.sale
                          ? Colors.green
                          : property.type == PropertyType.rent
                          ? Colors.blue
                          : Colors.orange,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Text(
                      property.type == PropertyType.sale
                          ? 'FOR SALE'
                          : property.type == PropertyType.rent
                          ? 'FOR RENT'
                          : 'HOSTEL',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ],
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 14, 14, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    property.title,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Icon(
                        Icons.location_on,
                        size: 16,
                        color: Colors.grey[700],
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          property.location,
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey[700],
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  if (property.companyName.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Icon(
                          Icons.business,
                          size: 16,
                          color: Colors.grey[700],
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            property.companyName,
                            style: const TextStyle(fontSize: 13),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ],
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 12,
                    runSpacing: 6,
                    children: [
                      if (property.type == PropertyType.hostel &&
                          property.university != null &&
                          property.university!.isNotEmpty)
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.school, size: 16, color: Colors.grey),
                            const SizedBox(width: 4),
                            Text(
                              property.university!,
                              style: const TextStyle(fontSize: 12),
                            ),
                          ],
                        ),
                      if (property.type != PropertyType.hostel &&
                          property.bedrooms > 0)
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.bed, size: 16, color: Colors.grey),
                            const SizedBox(width: 4),
                            Text('${property.bedrooms} beds'),
                          ],
                        ),
                      if (property.type != PropertyType.hostel &&
                          property.bathrooms > 0)
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              Icons.bathtub,
                              size: 16,
                              color: Colors.grey,
                            ),
                            const SizedBox(width: 4),
                            Text('${property.bathrooms} baths'),
                          ],
                        ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text(
                    '${property.currency} ${CurrencyFormatter.format(property.price)}',
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: AppColors.primary,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPropertyCard(BuildContext context, PropertyModel property) {
    final isDesktopGrid = ResponsiveHelper.isDesktop(context);
    final imageHeight = isDesktopGrid ? 160.0 : 180.0;
    
    return Card(
      elevation: 2,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => PropertyDetailsScreen(property: property),
            ),
          );
        },
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: isDesktopGrid ? MainAxisSize.max : MainAxisSize.min,
          children: [
            // Property Image - Use AspectRatio for grid, fixed height for list
            isDesktopGrid
                ? Expanded(
                    flex: 3,
                    child: _buildPropertyImage(property, null),
                  )
                : _buildPropertyImage(property, imageHeight),
            // Property Details
            isDesktopGrid
                ? Expanded(
                    flex: 2,
                    child: _buildPropertyDetails(property),
                  )
                : _buildPropertyDetails(property),
          ],
        ),
      ),
    );
  }

  Widget _buildPropertyImage(PropertyModel property, double? height) {
    return Stack(
      fit: height == null ? StackFit.expand : StackFit.loose,
      children: [
        ClipRRect(
          borderRadius: height != null 
              ? const BorderRadius.vertical(top: Radius.circular(12))
              : BorderRadius.zero,
          child: property.imageUrls.isNotEmpty
              ? Image.network(
                  property.imageUrls.first,
                  width: double.infinity,
                  height: height,
                  fit: BoxFit.cover,
                  loadingBuilder: (context, child, loadingProgress) {
                    if (loadingProgress == null) return child;
                    return Container(
                      height: height ?? double.infinity,
                      width: double.infinity,
                      color: AppColors.surfaceLight,
                      child: const Center(
                        child: SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                      ),
                    );
                  },
                  errorBuilder: (context, error, stackTrace) {
                    return Container(
                      height: height ?? double.infinity,
                      width: double.infinity,
                      color: Colors.grey.shade200,
                      child: const Icon(
                        Icons.broken_image,
                        size: 40,
                        color: Colors.grey,
                      ),
                    );
                  },
                )
              : Container(
                  height: height ?? double.infinity,
                  width: double.infinity,
                  color: Colors.grey.shade200,
                  child: const Icon(
                    Icons.home_outlined,
                    size: 40,
                    color: Colors.grey,
                  ),
                ),
        ),
        // Sold Out Badge
        if (!property.isActive)
          Positioned(
            top: 8,
            left: 8,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.red,
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Text(
                'SOLD OUT',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 10,
                ),
              ),
            ),
          ),
        // Property Type Badge
        Positioned(
          top: 8,
          right: 8,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: property.type == PropertyType.hostel
                  ? Colors.purple
                  : property.type == PropertyType.rent
                      ? Colors.blue
                      : Colors.green,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              property.type == PropertyType.hostel
                  ? 'HOSTEL'
                  : property.type == PropertyType.rent
                      ? 'RENT'
                      : 'SALE',
              style: const TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildPropertyDetails(PropertyModel property) {
    return Padding(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            property.title,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: AppColors.textPrimary,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              const Icon(
                Icons.location_on_outlined,
                size: 14,
                color: AppColors.textSecondary,
              ),
              const SizedBox(width: 2),
              Expanded(
                child: Text(
                  property.location,
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.textSecondary,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          if (property.bedrooms > 0 || property.bathrooms > 0) ...[
            const SizedBox(height: 4),
            Row(
              children: [
                if (property.bedrooms > 0) ...[
                  const Icon(Icons.bed, size: 14, color: AppColors.textSecondary),
                  const SizedBox(width: 2),
                  Text('${property.bedrooms}', style: const TextStyle(fontSize: 11)),
                  const SizedBox(width: 8),
                ],
                if (property.bathrooms > 0) ...[
                  const Icon(Icons.bathtub, size: 14, color: AppColors.textSecondary),
                  const SizedBox(width: 2),
                  Text('${property.bathrooms}', style: const TextStyle(fontSize: 11)),
                ],
              ],
            ),
          ],
          const SizedBox(height: 6),
          Text(
            property.type == PropertyType.hostel && property.roomTypes.isNotEmpty
                ? 'From ${property.currency} ${CurrencyFormatter.format(property.roomTypes.map((rt) => rt.price).reduce((a, b) => a < b ? a : b))}'
                : '${property.currency} ${CurrencyFormatter.format(property.price)}${property.type == PropertyType.rent ? "/month" : property.type == PropertyType.hostel ? "/sem" : ""}',
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: AppColors.primary,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}

class FavoritesTab extends StatefulWidget {
  final bool isWebNav;
  final VoidCallback? onMenuTap;

  const FavoritesTab({super.key, this.isWebNav = false, this.onMenuTap});

  @override
  State<FavoritesTab> createState() => _FavoritesTabState();
}

class _FavoritesTabState extends State<FavoritesTab> {
  List<String> _favoritePropertyIds = [];
  List<PropertyModel> _favoriteProperties = [];
  bool _isLoading = true;
  static const String _favoritesKey = 'favorite_properties';

  @override
  void initState() {
    super.initState();
    _loadFavorites();
  }

  Future<void> _loadFavorites() async {
    setState(() => _isLoading = true);

    try {
      final prefs = await SharedPreferences.getInstance();
      _favoritePropertyIds = prefs.getStringList(_favoritesKey) ?? [];

      if (_favoritePropertyIds.isEmpty) {
        setState(() {
          _favoriteProperties = [];
          _isLoading = false;
        });
        return;
      }

      // Fetch properties from Firestore
      List<PropertyModel> properties = [];
      for (String propertyId in _favoritePropertyIds) {
        try {
          final doc = await FirebaseFirestore.instance
              .collection('properties')
              .doc(propertyId)
              .get();

          if (doc.exists) {
            final data = doc.data() as Map<String, dynamic>;
            data['id'] = doc.id;
            properties.add(PropertyModel.fromJson(data));
          }
        } catch (e) {
          print('Error loading property $propertyId: $e');
        }
      }

      setState(() {
        _favoriteProperties = properties;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error loading favorites: $e')));
      }
    }
  }

  Future<void> _removeFavorite(String propertyId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _favoritePropertyIds.remove(propertyId);
      await prefs.setStringList(_favoritesKey, _favoritePropertyIds);

      setState(() {
        _favoriteProperties.removeWhere((p) => p.id == propertyId);
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Removed from favorites'),
            duration: Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error removing favorite: $e')));
      }
    }
  }

  Future<void> _clearAllFavorites() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Clear All Favorites'),
        content: const Text('Are you sure you want to remove all favorites?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Clear All'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        final prefs = await SharedPreferences.getInstance();
        await prefs.remove(_favoritesKey);

        setState(() {
          _favoritePropertyIds = [];
          _favoriteProperties = [];
        });

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('All favorites cleared')),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error clearing favorites: $e')),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: !widget.isWebNav,
        leading: widget.isWebNav
            ? IconButton(
                icon: const Icon(Icons.menu),
                onPressed: widget.onMenuTap,
              )
            : null,
        title: const Text('My Favorites'),
        actions: [
          if (_favoriteProperties.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.delete_sweep),
              onPressed: _clearAllFavorites,
              tooltip: 'Clear all favorites',
            ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _favoriteProperties.isEmpty
          ? SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const SizedBox(height: 48),
                  Icon(
                    Icons.favorite_border,
                    size: 100,
                    color: Colors.grey[400],
                  ),
                  const SizedBox(height: 24),
                  Text(
                    'No Favorites Yet',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: Colors.grey[600],
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Save properties you like by tapping the heart icon',
                    style: TextStyle(fontSize: 16, color: Colors.grey[500]),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 32),
                  ElevatedButton.icon(
                    onPressed: () {
                      final homeState = context
                          .findAncestorStateOfType<_CustomerHomeScreenState>();
                      homeState?.setState(() {
                        homeState._currentIndex = 0;
                      });
                    },
                    icon: const Icon(Icons.search),
                    label: const Text('Browse Properties'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 32,
                        vertical: 16,
                      ),
                    ),
                  ),
                ],
              ),
            )
          : RefreshIndicator(
              onRefresh: _loadFavorites,
              child: ListView(
                children: [
                  Padding(
                    padding: ResponsiveHelper.getContentPadding(context),
                    child: Center(
                      child: ConstrainedBox(
                        constraints: BoxConstraints(
                          maxWidth: ResponsiveHelper.getMaxContentWidth(context),
                        ),
                        child: GridView.builder(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: ResponsiveHelper.getGridCrossAxisCount(context),
                            childAspectRatio: ResponsiveHelper.getPropertyCardAspectRatio(context),
                            crossAxisSpacing: 16,
                            mainAxisSpacing: 16,
                          ),
                          itemCount: _favoriteProperties.length,
                          itemBuilder: (context, index) {
                            final property = _favoriteProperties[index];
                            return _buildPropertyCard(property);
                          },
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  Widget _buildPropertyCard(PropertyModel property) {
    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => PropertyDetailsScreen(property: property),
          ),
        ).then((_) => _loadFavorites());
      },
      child: Card(
        elevation: 2,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Property Image with Favorite Button
            Expanded(
              child: Stack(
                children: [
                  ClipRRect(
                    borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(12),
                    ),
                    child: property.imageUrls.isNotEmpty
                        ? Image.network(
                            property.imageUrls[0],
                            width: double.infinity,
                            height: double.infinity,
                            fit: BoxFit.cover,
                            loadingBuilder: (context, child, loadingProgress) {
                              if (loadingProgress == null) return child;
                              return Container(
                                color: Colors.grey[300],
                                child: const Icon(
                                  Icons.home,
                                  size: 50,
                                  color: Colors.grey,
                                ),
                              );
                            },
                            errorBuilder: (context, error, stackTrace) {
                              return Container(
                                color: Colors.grey[300],
                                child: const Icon(
                                  Icons.home,
                                  size: 50,
                                  color: Colors.grey,
                                ),
                              );
                            },
                          )
                        : Container(
                            color: Colors.grey[300],
                            child: const Icon(
                              Icons.home,
                              size: 50,
                              color: Colors.grey,
                            ),
                          ),
                  ),
                  // Favorite Button
                  Positioned(
                    top: 8,
                    right: 8,
                    child: GestureDetector(
                      onTap: () => _removeFavorite(property.id),
                      child: Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.2),
                              blurRadius: 4,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: const Icon(
                          Icons.favorite,
                          color: Colors.red,
                          size: 20,
                        ),
                      ),
                    ),
                  ),
                  // Property Type Badge
                  Positioned(
                    top: 8,
                    left: 8,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: property.type == PropertyType.rent
                            ? Colors.blue
                            : Colors.green,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        property.type == PropertyType.rent ? 'RENT' : 'SALE',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            // Property Details
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    property.title,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      const Icon(
                        Icons.location_on,
                        size: 12,
                        color: Colors.grey,
                      ),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          property.location,
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey[600],
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Icon(Icons.bed, size: 14, color: Colors.grey[600]),
                      const SizedBox(width: 4),
                      Text(
                        '${property.bedrooms}',
                        style: const TextStyle(fontSize: 12),
                      ),
                      const SizedBox(width: 12),
                      Icon(Icons.bathroom, size: 14, color: Colors.grey[600]),
                      const SizedBox(width: 4),
                      Text(
                        '${property.bathrooms}',
                        style: const TextStyle(fontSize: 12),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${property.currency} ${property.price.toStringAsFixed(0)}',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      color: AppColors.primary,
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// Separate StatefulWidget to prevent scroll jumping when switching locations
class BrowseNewProjectsSection extends StatefulWidget {
  final List<String> projectLocations;

  const BrowseNewProjectsSection({
    super.key,
    required this.projectLocations,
  });

  @override
  State<BrowseNewProjectsSection> createState() => _BrowseNewProjectsSectionState();
}

class _BrowseNewProjectsSectionState extends State<BrowseNewProjectsSection> {
  final ProjectService _projectService = ProjectService();
  String _selectedProjectLocation = '';
  List<Project> _locationProjects = [];
  bool _loadingProjects = false;

  @override
  void initState() {
    super.initState();
    if (widget.projectLocations.isNotEmpty) {
      _selectedProjectLocation = widget.projectLocations.first;
      _loadProjectsForLocation(_selectedProjectLocation);
    }
  }

  @override
  void didUpdateWidget(BrowseNewProjectsSection oldWidget) {
    super.didUpdateWidget(oldWidget);
    // If locations changed and current selection is not in new list
    if (widget.projectLocations.isNotEmpty &&
        !widget.projectLocations.contains(_selectedProjectLocation)) {
      _selectedProjectLocation = widget.projectLocations.first;
      _loadProjectsForLocation(_selectedProjectLocation);
    }
  }

  Future<void> _loadProjectsForLocation(String location) async {
    if (!mounted) return;

    // Prevent reload if same location and already has data
    if (_selectedProjectLocation == location && _locationProjects.isNotEmpty) {
      return;
    }

    // Update selection and set loading state before querying.
    setState(() {
      _selectedProjectLocation = location;
      _loadingProjects = true;
    });
    
    final projects = await _projectService.getProjectsByLocation(location);

    if (mounted) {
      setState(() {
        _locationProjects = projects;
        _loadingProjects = false;
      });

      // Increment view counts for displayed projects
      for (var project in projects.take(5)) {
        _projectService.incrementViewCount(project.id);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.projectLocations.isEmpty) {
      return const SizedBox.shrink();
    }

    return Column(
      key: const ValueKey('browse_projects_section'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          margin: const EdgeInsets.symmetric(horizontal: 20),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                Theme.of(context).colorScheme.primary.withOpacity(0.10),
                Theme.of(context).cardColor,
              ],
            ),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: Theme.of(context).colorScheme.primary.withOpacity(0.2),
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.primary,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  Icons.domain_add_rounded,
                  color: Theme.of(context).colorScheme.onPrimary,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Browse New Projects In Uganda',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Theme.of(context).textTheme.bodyLarge!.color,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Explore residential and commercial developments by area.',
                      style: TextStyle(
                        fontSize: 13,
                        color: Theme.of(context).textTheme.bodySmall!.color,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        // Location tabs
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Wrap(
            spacing: 12,
            runSpacing: 12,
            children: widget.projectLocations.map((location) {
              final isSelected = location == _selectedProjectLocation;
              return InkWell(
                onTap: () {
                  if (location != _selectedProjectLocation) {
                    _loadProjectsForLocation(location);
                  }
                },
                borderRadius: BorderRadius.circular(20),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? Theme.of(context).colorScheme.primary
                        : Theme.of(context).chipTheme.backgroundColor,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: isSelected
                          ? Theme.of(context).colorScheme.primary
                          : Colors.grey.shade300,
                      width: 1,
                    ),
                  ),
                  child: Text(
                    location,
                    style: TextStyle(
                      color: isSelected
                          ? Theme.of(context).colorScheme.onPrimary
                          : Theme.of(context).textTheme.bodyLarge!.color,
                      fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ),
        const SizedBox(height: 16),
        // Projects horizontal list
        if (_locationProjects.isEmpty && !_loadingProjects)
          Padding(
            padding: const EdgeInsets.all(20),
            child: Center(
              child: Column(
                children: [
                  Icon(
                    Icons.apartment,
                    size: 48,
                    color: Theme.of(context).textTheme.bodySmall!.color?.withOpacity(0.4),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'No projects in $_selectedProjectLocation yet',
                    style: TextStyle(
                      color: Theme.of(context).textTheme.bodySmall!.color,
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ),
          )
        else
          Column(
            children: [
              SizedBox(
                height: 320,
                child: Stack(
                  children: [
                    // Show projects list (or empty container during first load)
                    if (_locationProjects.isNotEmpty)
                      ListView.builder(
                        scrollDirection: Axis.horizontal,
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        physics: const ClampingScrollPhysics(),
                        primary: false,
                        shrinkWrap: true,
                        itemCount: _locationProjects.length > 3 ? 3 : _locationProjects.length,
                        itemBuilder: (context, index) {
                          return _buildProjectCard(_locationProjects[index], context);
                        },
                      ),
                    // Show loading overlay only during loading
                    if (_loadingProjects)
                      Container(
                        color: Theme.of(context).scaffoldBackgroundColor.withOpacity(0.8),
                        child: const Center(
                          child: CircularProgressIndicator(),
                        ),
                      ),
                  ],
                ),
              ),
              // View More button if there are more than 3 projects
              if (_locationProjects.length > 3)
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 12,
                  ),
                  child: SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: () {
                        // Navigate to a full list view of projects
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => AllProjectsScreen(
                              location: _selectedProjectLocation,
                              projects: _locationProjects,
                            ),
                          ),
                        );
                      },
                      icon: const Icon(Icons.arrow_forward),
                      label: const Text('View More'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Theme.of(context).colorScheme.primary,
                        side: BorderSide(
                          color: Theme.of(context).colorScheme.primary,
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
      ],
    );
  }

  Widget _buildProjectCard(Project project, BuildContext context) {
    return GestureDetector(
      onTap: () {
        _projectService.incrementClickCount(project.id);
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => ProjectDetailsScreen(project: project),
          ),
        );
      },
      child: Container(
        width: 300,
        margin: const EdgeInsets.only(right: 16),
        decoration: BoxDecoration(
          color: Theme.of(context).cardColor,
          borderRadius: BorderRadius.circular(14),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.08),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Project image
            Stack(
              children: [
                ClipRRect(
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(14)),
                  child: project.imageUrls.isNotEmpty
                      ? CachedNetworkImage(
                          imageUrl: project.imageUrls.first,
                          height: 180,
                          width: double.infinity,
                          fit: BoxFit.cover,
                          memCacheWidth: 900,
                          fadeInDuration: const Duration(milliseconds: 120),
                          placeholder: (context, _) => Container(
                            height: 180,
                            color: Colors.grey.shade200,
                            child: const Center(
                              child: SizedBox(
                                width: 22,
                                height: 22,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              ),
                            ),
                          ),
                          errorWidget: (context, _, __) {
                            return Container(
                              height: 180,
                              color: Colors.grey[300],
                              child: const Icon(Icons.apartment, size: 48),
                            );
                          },
                        )
                      : Container(
                          height: 180,
                          color: Colors.grey[300],
                          child: const Icon(Icons.apartment, size: 48),
                        ),
                ),
                if (project.isFirstPlaceSubscriber)
                  Positioned(
                    top: 10,
                    left: 10,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: Colors.amber.shade700,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: const Text(
                        'FEATURED',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
            // Project details
            Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    project.name,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      const Icon(Icons.location_on, size: 14, color: Colors.grey),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          project.location,
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey[600],
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    project.description,
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey[700],
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Icon(Icons.visibility_outlined, size: 14, color: Colors.grey.shade600),
                      const SizedBox(width: 4),
                      Text(
                        '${project.viewCount} views',
                        style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class ProfileTab extends StatelessWidget {
  const ProfileTab({super.key});

  @override
  Widget build(BuildContext context) {
    return const ProfileScreen(showWebFooter: true);
  }
}

class GuestAccessScreen extends StatelessWidget {
  final String title;
  final String description;

  const GuestAccessScreen({
    super.key,
    required this.title,
    required this.description,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 460),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 88,
                  height: 88,
                  decoration: BoxDecoration(
                    color: AppColors.primary.withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.lock_outline_rounded,
                    size: 42,
                    color: AppColors.primary,
                  ),
                ),
                const SizedBox(height: 20),
                Text(
                  title,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  description,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 15,
                    height: 1.5,
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const LoginScreen(),
                        ),
                      );
                    },
                    child: const Text('Login'),
                  ),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const RoleSelectionScreen(),
                        ),
                      );
                    },
                    child: const Text('Create Account'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

