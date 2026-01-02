import 'package:flutter/material.dart';
import 'dart:typed_data';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../utils/app_theme.dart';
import '../../utils/database_helper.dart';
import '../../models/property_model.dart';
import '../common/profile_screen.dart';
import '../common/notifications_screen.dart';
import '../property/customer_properties_screen.dart';
import '../property/property_details_screen.dart';
import '../../services/notification_service.dart';

class CustomerHomeScreen extends StatefulWidget {
  const CustomerHomeScreen({super.key});

  @override
  State<CustomerHomeScreen> createState() => _CustomerHomeScreenState();
}

class _CustomerHomeScreenState extends State<CustomerHomeScreen> {
  int _currentIndex = 0;

  final List<Widget> _screens = [
    const HomeTab(),
    const SearchTab(),
    const FavoritesTab(),
    const ProfileScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _screens[_currentIndex],
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (index) {
          setState(() {
            _currentIndex = index;
          });
        },
        type: BottomNavigationBarType.fixed,
        selectedItemColor: AppColors.primary,
        unselectedItemColor: AppColors.textSecondary,
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.home_outlined),
            activeIcon: Icon(Icons.home),
            label: 'Home',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.search_outlined),
            activeIcon: Icon(Icons.search),
            label: 'Search',
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
}

class HomeTab extends StatefulWidget {
  const HomeTab({super.key});

  @override
  State<HomeTab> createState() => _HomeTabState();
}

class _HomeTabState extends State<HomeTab> {
  PropertyType? _selectedFilter;
  final NotificationService _notificationService = NotificationService();
  int _unreadCount = 0;

  @override
  void initState() {
    super.initState();
    _loadUnreadCount();
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('True Home'),
        actions: [
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
                      style: const TextStyle(
                        color: Colors.white,
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
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Hero Section
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
                  const Text(
                    'Find Your Dream Home',
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Browse rentals, condos, and student hostels',
                    style: TextStyle(fontSize: 16, color: Colors.white70),
                  ),
                  const SizedBox(height: 20),
                  // Quick Search
                  ElevatedButton(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) =>
                              const CustomerPropertiesScreen(),
                        ),
                      );
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: AppColors.primary,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 24,
                        vertical: 12,
                      ),
                      minimumSize: const Size(double.infinity, 48),
                    ),
                    child: const Text(
                      'Browse All Properties',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: TextField(
                      decoration: InputDecoration(
                        hintText: 'Search location, property...',
                        prefixIcon: const Icon(Icons.search),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide.none,
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 16,
                        ),
                      ),
                      onTap: () {
                        // Navigate to search tab
                      },
                      readOnly: true,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            // Property Types
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Browse by Type',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: _buildPropertyTypeCard(
                          context,
                          'Find Rentals',
                          Icons.apartment,
                          AppColors.rental,
                          PropertyType.rent,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _buildPropertyTypeCard(
                          context,
                          'For Sale',
                          Icons.home_work,
                          AppColors.condo,
                          PropertyType.sale,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(child: _buildClearFilterCard(context)),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            // Featured Properties
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    _selectedFilter == null
                        ? 'All Approved Properties'
                        : 'Properties for ${_selectedFilter == PropertyType.rent ? "Rent" : "Sale"}',
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  if (_selectedFilter != null)
                    TextButton(
                      onPressed: () {
                        setState(() {
                          _selectedFilter = null;
                        });
                      },
                      child: const Text('Clear Filter'),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            // Properties Grid
            StreamBuilder<QuerySnapshot>(
              stream: _selectedFilter == null
                  ? FirebaseFirestore.instance
                        .collection('properties')
                        .where('status', isEqualTo: 'approved')
                        .snapshots()
                  : FirebaseFirestore.instance
                        .collection('properties')
                        .where('status', isEqualTo: 'approved')
                        .where('type', isEqualTo: _selectedFilter!.name)
                        .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Padding(
                    padding: EdgeInsets.all(40),
                    child: Center(child: CircularProgressIndicator()),
                  );
                }

                if (snapshot.hasError) {
                  return Padding(
                    padding: const EdgeInsets.all(40),
                    child: Center(child: Text('Error: ${snapshot.error}')),
                  );
                }

                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
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
                                : 'No ${_selectedFilter == PropertyType.rent ? "rental" : "sale"} properties available',
                            style: TextStyle(color: Colors.grey[600]),
                          ),
                        ],
                      ),
                    ),
                  );
                }

                final properties = snapshot.data!.docs.map((doc) {
                  final data = doc.data() as Map<String, dynamic>;
                  data['id'] = doc.id;
                  return PropertyModel.fromJson(data);
                }).toList();

                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: GridView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 2,
                          childAspectRatio: 0.7,
                          crossAxisSpacing: 12,
                          mainAxisSpacing: 12,
                        ),
                    itemCount: properties.length,
                    itemBuilder: (context, index) {
                      return _buildPropertyCard(context, properties[index]);
                    },
                  ),
                );
              },
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Widget _buildPropertyTypeCard(
    BuildContext context,
    String title,
    IconData icon,
    Color color,
    PropertyType type,
  ) {
    final isSelected = _selectedFilter == type;
    return Card(
      elevation: isSelected ? 4 : 2,
      color: isSelected ? color.withOpacity(0.1) : null,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: isSelected ? BorderSide(color: color, width: 2) : BorderSide.none,
      ),
      child: InkWell(
        onTap: () {
          setState(() {
            _selectedFilter = type;
          });
        },
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: color, size: 32),
              ),
              const SizedBox(height: 8),
              Text(
                title,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildClearFilterCard(BuildContext context) {
    final isSelected = _selectedFilter == null;
    return Card(
      elevation: isSelected ? 4 : 2,
      color: isSelected ? AppColors.primary.withOpacity(0.1) : null,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: isSelected
            ? const BorderSide(color: AppColors.primary, width: 2)
            : BorderSide.none,
      ),
      child: InkWell(
        onTap: () {
          setState(() {
            _selectedFilter = null;
          });
        },
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.primary.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.clear_all,
                  color: AppColors.primary,
                  size: 32,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'All Properties',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPropertyCard(BuildContext context, PropertyModel property) {
    return Card(
      elevation: 2,
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
        borderRadius: BorderRadius.circular(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Property Image
            ClipRRect(
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(12),
              ),
              child: property.imageUrls.isNotEmpty
                  ? Image.network(
                      property.imageUrls.first,
                      height: 120,
                      width: double.infinity,
                      fit: BoxFit.cover,
                      loadingBuilder: (context, child, loadingProgress) {
                        if (loadingProgress == null) return child;
                        return Container(
                          height: 120,
                          width: double.infinity,
                          color: AppColors.surfaceLight,
                          child: const Center(
                            child: SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                              ),
                            ),
                          ),
                        );
                      },
                      errorBuilder: (context, error, stackTrace) {
                        return Container(
                          height: 120,
                          width: double.infinity,
                          color: AppColors.surfaceLight,
                          child: const Icon(
                            Icons.image_not_supported,
                            size: 30,
                          ),
                        );
                      },
                    )
                  : Container(
                      height: 120,
                      width: double.infinity,
                      color: AppColors.surfaceLight,
                      child: const Icon(Icons.image_not_supported, size: 30),
                    ),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      property.title,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimary,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        const Icon(
                          Icons.location_on_outlined,
                          size: 12,
                          color: AppColors.textSecondary,
                        ),
                        const SizedBox(width: 2),
                        Expanded(
                          child: Text(
                            property.location,
                            style: const TextStyle(
                              fontSize: 10,
                              color: AppColors.textSecondary,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    if (property.bedrooms > 0 || property.bathrooms > 0)
                      Row(
                        children: [
                          if (property.bedrooms > 0) ...[
                            const Icon(
                              Icons.bed,
                              size: 12,
                              color: AppColors.textSecondary,
                            ),
                            const SizedBox(width: 2),
                            Text(
                              '${property.bedrooms}',
                              style: const TextStyle(fontSize: 10),
                            ),
                            const SizedBox(width: 8),
                          ],
                          if (property.bathrooms > 0) ...[
                            const Icon(
                              Icons.bathtub,
                              size: 12,
                              color: AppColors.textSecondary,
                            ),
                            const SizedBox(width: 2),
                            Text(
                              '${property.bathrooms}',
                              style: const TextStyle(fontSize: 10),
                            ),
                          ],
                        ],
                      ),
                    const Spacer(),
                    Text(
                      'UGX ${_formatPrice(property.price)}${property.type == PropertyType.rent ? "/mo" : ""}',
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: AppColors.primary,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: property.type == PropertyType.rent
                            ? Colors.blue.withOpacity(0.1)
                            : Colors.green.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        property.type == PropertyType.rent ? 'RENT' : 'SALE',
                        style: TextStyle(
                          fontSize: 9,
                          fontWeight: FontWeight.bold,
                          color: property.type == PropertyType.rent
                              ? Colors.blue
                              : Colors.green,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatPrice(double price) {
    if (price >= 1000000) {
      return '${(price / 1000000).toStringAsFixed(1)}M';
    } else if (price >= 1000) {
      return '${(price / 1000).toStringAsFixed(0)}K';
    }
    return price.toStringAsFixed(0);
  }
}

// Placeholder tabs
class SearchTab extends StatefulWidget {
  const SearchTab({super.key});

  @override
  State<SearchTab> createState() => _SearchTabState();
}

class _SearchTabState extends State<SearchTab> {
  final TextEditingController _searchController = TextEditingController();
  PropertyType? _selectedType;
  String? _selectedLocation;
  double _minPrice = 0;
  double _maxPrice = 10000000;
  int? _bedrooms;
  int? _bathrooms;
  bool _showFilters = false;
  List<PropertyModel> _searchResults = [];
  bool _isSearching = false;
  List<String> _searchHistory = [];
  bool _showHistory = false;
  static const String _searchHistoryKey = 'search_history';
  static const int _maxHistoryItems = 10;

  @override
  void initState() {
    super.initState();
    _loadSearchHistory();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

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

    // Remove if already exists
    history.remove(query);

    // Add to the beginning
    history.insert(0, query);

    // Keep only last N items
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
    });
  }

  Future<void> _removeHistoryItem(String query) async {
    final prefs = await SharedPreferences.getInstance();
    List<String> history = prefs.getStringList(_searchHistoryKey) ?? [];
    history.remove(query);
    await prefs.setStringList(_searchHistoryKey, history);
    setState(() {
      _searchHistory = history;
    });
  }

  Future<void> _performSearch() async {
    setState(() => _isSearching = true);

    // Save search query to history if it's not empty
    if (_searchController.text.trim().isNotEmpty) {
      await _saveSearchQuery(_searchController.text.trim());
    }

    try {
      Query query = FirebaseFirestore.instance
          .collection('properties')
          .where('status', isEqualTo: 'approved');

      // Apply type filter
      if (_selectedType != null) {
        query = query.where('type', isEqualTo: _selectedType!.name);
      }

      // Apply location filter
      if (_selectedLocation != null && _selectedLocation!.isNotEmpty) {
        query = query
            .where('location', isGreaterThanOrEqualTo: _selectedLocation)
            .where('location', isLessThanOrEqualTo: '$_selectedLocation\uf8ff');
      }

      final snapshot = await query.get();
      List<PropertyModel> results = [];

      for (var doc in snapshot.docs) {
        final data = doc.data() as Map<String, dynamic>;
        data['id'] = doc.id;
        final property = PropertyModel.fromJson(data);

        // Apply additional filters
        bool matchesSearch = true;

        // Search query filter
        if (_searchController.text.isNotEmpty) {
          final searchTerm = _searchController.text.toLowerCase();
          matchesSearch =
              property.title.toLowerCase().contains(searchTerm) ||
              property.description.toLowerCase().contains(searchTerm) ||
              property.location.toLowerCase().contains(searchTerm);
        }

        // Price filter
        bool matchesPrice =
            property.price >= _minPrice && property.price <= _maxPrice;

        // Bedrooms filter
        bool matchesBedrooms =
            _bedrooms == null || property.bedrooms == _bedrooms;

        // Bathrooms filter
        bool matchesBathrooms =
            _bathrooms == null || property.bathrooms == _bathrooms;

        if (matchesSearch &&
            matchesPrice &&
            matchesBedrooms &&
            matchesBathrooms) {
          results.add(property);
        }
      }

      setState(() {
        _searchResults = results;
        _isSearching = false;
      });
    } catch (e) {
      setState(() => _isSearching = false);
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error searching: $e')));
      }
    }
  }

  void _clearFilters() {
    setState(() {
      _searchController.clear();
      _selectedType = null;
      _selectedLocation = null;
      _minPrice = 0;
      _maxPrice = 10000000;
      _bedrooms = null;
      _bathrooms = null;
      _searchResults = [];
    });
  }

  Future<bool> _isFavoriteProperty(String propertyId) async {
    final prefs = await SharedPreferences.getInstance();
    final favorites = prefs.getStringList('favorite_properties') ?? [];
    return favorites.contains(propertyId);
  }

  Future<void> _toggleFavoriteProperty(String propertyId) async {
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Search Properties'),
        actions: [
          IconButton(
            icon: Icon(
              _showFilters ? Icons.filter_alt : Icons.filter_alt_outlined,
            ),
            onPressed: () {
              setState(() => _showFilters = !_showFilters);
            },
          ),
        ],
      ),
      body: Column(
        children: [
          // Search Bar
          Container(
            padding: const EdgeInsets.all(16),
            color: Colors.white,
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Search by title, location...',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _searchController.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          _searchController.clear();
                          setState(() {
                            _showHistory = false;
                          });
                        },
                      )
                    : null,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                filled: true,
                fillColor: AppColors.background,
              ),
              onTap: () {
                if (_searchHistory.isNotEmpty) {
                  setState(() {
                    _showHistory = true;
                  });
                }
              },
              onChanged: (value) {
                setState(() {
                  _showHistory = value.isEmpty && _searchHistory.isNotEmpty;
                });
              },
              onSubmitted: (value) {
                setState(() {
                  _showHistory = false;
                });
                _performSearch();
              },
            ),
          ),

          // Search History
          if (_showHistory && _searchHistory.isNotEmpty)
            Container(
              color: Colors.white,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                    child: Row(
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
                          onPressed: () {
                            _clearSearchHistory();
                          },
                          child: const Text('Clear All'),
                        ),
                      ],
                    ),
                  ),
                  const Divider(height: 1),
                  ListView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: _searchHistory.length,
                    itemBuilder: (context, index) {
                      final query = _searchHistory[index];
                      return ListTile(
                        leading: const Icon(Icons.history, color: Colors.grey),
                        title: Text(query),
                        trailing: IconButton(
                          icon: const Icon(Icons.close, size: 20),
                          onPressed: () {
                            _removeHistoryItem(query);
                          },
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
              padding: const EdgeInsets.all(16),
              color: Colors.grey[100],
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
                        onPressed: _clearFilters,
                        child: const Text('Clear All'),
                      ),
                    ],
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
                    children: [
                      FilterChip(
                        label: const Text('Rent'),
                        selected: _selectedType == PropertyType.rent,
                        onSelected: (selected) {
                          setState(() {
                            _selectedType = selected ? PropertyType.rent : null;
                          });
                        },
                      ),
                      FilterChip(
                        label: const Text('Sale'),
                        selected: _selectedType == PropertyType.sale,
                        onSelected: (selected) {
                          setState(() {
                            _selectedType = selected ? PropertyType.sale : null;
                          });
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Price Range Filter
                  const Text(
                    'Price Range',
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 8),
                  RangeSlider(
                    values: RangeValues(_minPrice, _maxPrice),
                    min: 0,
                    max: 10000000,
                    divisions: 100,
                    labels: RangeLabels(
                      'UGX ${(_minPrice / 1000).toStringAsFixed(0)}k',
                      'UGX ${(_maxPrice / 1000).toStringAsFixed(0)}k',
                    ),
                    onChanged: (RangeValues values) {
                      setState(() {
                        _minPrice = values.start;
                        _maxPrice = values.end;
                      });
                    },
                  ),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('UGX ${(_minPrice / 1000).toStringAsFixed(0)}k'),
                      Text('UGX ${(_maxPrice / 1000).toStringAsFixed(0)}k'),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Bedrooms Filter
                  const Text(
                    'Bedrooms',
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    children: [1, 2, 3, 4, 5].map((num) {
                      return FilterChip(
                        label: Text('$num'),
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

                  // Bathrooms Filter
                  const Text(
                    'Bathrooms',
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    children: [1, 2, 3, 4].map((num) {
                      return FilterChip(
                        label: Text('$num'),
                        selected: _bathrooms == num,
                        onSelected: (selected) {
                          setState(() {
                            _bathrooms = selected ? num : null;
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
                      onPressed: _performSearch,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Text('Apply Filters'),
                    ),
                  ),
                ],
              ),
            ),

          // Search Results
          Expanded(
            child: _isSearching
                ? const Center(child: CircularProgressIndicator())
                : _searchResults.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.search_off,
                          size: 80,
                          color: Colors.grey[400],
                        ),
                        const SizedBox(height: 16),
                        Text(
                          _searchController.text.isEmpty && !_showFilters
                              ? 'Search for properties'
                              : 'No properties found',
                          style: TextStyle(
                            fontSize: 18,
                            color: Colors.grey[600],
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Try adjusting your filters',
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey[500],
                          ),
                        ),
                      ],
                    ),
                  )
                : GridView.builder(
                    padding: const EdgeInsets.all(16),
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 2,
                          childAspectRatio: 0.75,
                          crossAxisSpacing: 16,
                          mainAxisSpacing: 16,
                        ),
                    itemCount: _searchResults.length,
                    itemBuilder: (context, index) {
                      final property = _searchResults[index];
                      return _buildPropertyCard(property);
                    },
                  ),
          ),
        ],
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
        );
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
                  // Favorite Button Overlay
                  Positioned(
                    top: 8,
                    right: 8,
                    child: FutureBuilder<bool>(
                      future: _isFavoriteProperty(property.id),
                      builder: (context, snapshot) {
                        final isFav = snapshot.data ?? false;
                        return GestureDetector(
                          onTap: () async {
                            await _toggleFavoriteProperty(property.id);
                            setState(() {}); // Refresh UI
                          },
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
                            child: Icon(
                              isFav ? Icons.favorite : Icons.favorite_border,
                              color: isFav ? Colors.red : Colors.grey[600],
                              size: 20,
                            ),
                          ),
                        );
                      },
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
                    'UGX ${property.price.toStringAsFixed(0)}',
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

class FavoritesTab extends StatefulWidget {
  const FavoritesTab({super.key});

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
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
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
                      // Switch to home tab
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
              child: GridView.builder(
                padding: const EdgeInsets.all(16),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  childAspectRatio: 0.75,
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
                    'UGX ${property.price.toStringAsFixed(0)}',
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

class ProfileTab extends StatelessWidget {
  const ProfileTab({super.key});

  @override
  Widget build(BuildContext context) {
    return const ProfileScreen();
  }
}
