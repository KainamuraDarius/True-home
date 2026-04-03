import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:url_launcher/url_launcher.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../models/property_model.dart';
import '../../models/user_model.dart';
import '../../widgets/agent_name_with_badge.dart';
import '../../utils/app_theme.dart';
import '../../utils/currency_formatter.dart';
import '../auth/login_screen.dart';
import '../auth/role_selection_screen.dart';
import '../customer/agent_profile_screen.dart';
import '../customer/reserve_room_screen.dart';
import '../../widgets/fullscreen_image_viewer.dart';
import '../../services/view_tracking_service.dart';

class PropertyDetailsScreen extends StatefulWidget {
  final PropertyModel property;

  const PropertyDetailsScreen({super.key, required this.property});

  @override
  State<PropertyDetailsScreen> createState() => _PropertyDetailsScreenState();
}

class _PropertyDetailsScreenState extends State<PropertyDetailsScreen> {
  int _currentImageIndex = 0;
  bool _isFavorite = false;
  static const String _favoritesKey = 'favorite_properties';
  UserRole? _currentUserRole;
  List<UserRole> _currentUserRoles = [];
  final ViewTrackingService _viewTrackingService = ViewTrackingService();

  @override
  void initState() {
    super.initState();
    _checkFavoriteStatus();
    _getCurrentUserRole();
    _trackPropertyView(); // Track this view
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _prefetchGalleryImages();
    });
  }

  Future<void> _prefetchGalleryImages() async {
    if (!mounted || widget.property.imageUrls.isEmpty) {
      return;
    }

    final galleryImages = widget.property.imageUrls.take(6);
    for (final imageUrl in galleryImages) {
      try {
        await precacheImage(CachedNetworkImageProvider(imageUrl), context);
      } catch (_) {
        // Ignore prefetch errors and keep UI responsive.
      }
    }
  }

  Future<void> _prefetchImageAtIndex(int index) async {
    if (!mounted || widget.property.imageUrls.isEmpty) {
      return;
    }

    final indexes = {
      index - 1,
      index,
      index + 1,
    }.where((i) => i >= 0 && i < widget.property.imageUrls.length);

    for (final i in indexes) {
      try {
        await precacheImage(
          CachedNetworkImageProvider(widget.property.imageUrls[i]),
          context,
        );
      } catch (_) {
        // Ignore prefetch errors.
      }
    }
  }

  void _openGalleryZoom(int initialIndex) {
    if (widget.property.imageUrls.isEmpty) return;

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => FullscreenImageViewer(
          imageUrls: widget.property.imageUrls,
          initialIndex: initialIndex,
          title: widget.property.title,
        ),
      ),
    );
  }

  // Track property view
  Future<void> _trackPropertyView() async {
    try {
      await _viewTrackingService.trackPropertyView(
        propertyId: widget.property.id,
        ownerId: widget.property.ownerId,
      );
    } catch (e) {
      debugPrint('❌ Error tracking view: $e');
    }
  }

  Future<void> _getCurrentUserRole() async {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser != null) {
      try {
        final userDoc = await FirebaseFirestore.instance
            .collection('users')
            .doc(currentUser.uid)
            .get();

        if (userDoc.exists) {
          final userData = UserModel.fromJson(userDoc.data()!);
          if (mounted) {
            setState(() {
              _currentUserRole = userData.activeRole;
              _currentUserRoles = userData.roles;
            });
          }
        }
      } on FirebaseException catch (e) {
        if (e.code == 'permission-denied') {
          if (mounted) {
            setState(() {
              _currentUserRole = null;
              _currentUserRoles = [];
            });
          }
          if (kDebugMode) {
            debugPrint('Guest mode: role lookup is not permitted.');
          }
          return;
        }
      } catch (e) {
        if (kDebugMode) {
          debugPrint('Error getting user role: $e');
        }
      }
    }
  }

  // Gender policy helper methods
  Color _getGenderPolicyColor(GenderPolicy policy) {
    switch (policy) {
      case GenderPolicy.maleOnly:
        return Colors.blue;
      case GenderPolicy.femaleOnly:
        return Colors.pink;
      case GenderPolicy.mixed:
        return Colors.blue;
    }
  }

  IconData _getGenderPolicyIcon(GenderPolicy policy) {
    switch (policy) {
      case GenderPolicy.maleOnly:
        return Icons.male;
      case GenderPolicy.femaleOnly:
        return Icons.female;
      case GenderPolicy.mixed:
        return Icons.people;
    }
  }

  String _getGenderPolicyLabel(GenderPolicy policy) {
    switch (policy) {
      case GenderPolicy.maleOnly:
        return 'Male Only';
      case GenderPolicy.femaleOnly:
        return 'Female Only';
      case GenderPolicy.mixed:
        return 'Mixed Gender';
    }
  }

  Future<void> _checkFavoriteStatus() async {
    final prefs = await SharedPreferences.getInstance();
    final favorites = prefs.getStringList(_favoritesKey) ?? [];
    setState(() {
      _isFavorite = favorites.contains(widget.property.id);
    });
  }

  Future<void> _toggleFavorite() async {
    if (!_requireAuthentication(
      title: 'Login Required',
      message: 'Create an account or log in to save properties to favorites.',
    )) {
      return;
    }

    try {
      final prefs = await SharedPreferences.getInstance();
      List<String> favorites = prefs.getStringList(_favoritesKey) ?? [];

      if (_isFavorite) {
        favorites.remove(widget.property.id);
        await prefs.setStringList(_favoritesKey, favorites);
        setState(() => _isFavorite = false);

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Removed from favorites'),
              duration: Duration(seconds: 2),
            ),
          );
        }
      } else {
        favorites.add(widget.property.id);
        await prefs.setStringList(_favoritesKey, favorites);
        setState(() => _isFavorite = true);

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Added to favorites!'),
              duration: Duration(seconds: 2),
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error updating favorites: $e')));
      }
    }
  }

  bool _requireAuthentication({
    required String title,
    required String message,
  }) {
    if (FirebaseAuth.instance.currentUser != null) {
      return true;
    }

    showModalBottomSheet(
      context: context,
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  message,
                  style: const TextStyle(fontSize: 14, color: Colors.grey),
                ),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () {
                      Navigator.pop(context);
                      Navigator.push(
                        this.context,
                        MaterialPageRoute(builder: (_) => const LoginScreen()),
                      );
                    },
                    child: const Text('Login'),
                  ),
                ),
                const SizedBox(height: 10),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton(
                    onPressed: () {
                      Navigator.pop(context);
                      Navigator.push(
                        this.context,
                        MaterialPageRoute(
                          builder: (_) => const RoleSelectionScreen(),
                        ),
                      );
                    },
                    child: const Text('Create Account'),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );

    return false;
  }

  Future<String?> _getAgentProfileImage() async {
    // First try to use the image from property
    if (widget.property.agentProfileImageUrl != null &&
        widget.property.agentProfileImageUrl!.isNotEmpty) {
      return widget.property.agentProfileImageUrl;
    }

    // If not available, fetch from agent's user profile
    try {
      final agentDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(widget.property.ownerId)
          .get();

      if (agentDoc.exists) {
        return agentDoc.data()?['profileImageUrl'];
      }
    } on FirebaseException catch (e) {
      if (e.code == 'permission-denied') {
        if (kDebugMode) {
          debugPrint('Guest mode: agent profile image read is not permitted.');
        }
        return null;
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('Error fetching agent profile image: $e');
      }
    }

    return null;
  }

  Future<bool> _checkAgentVerificationStatus() async {
    try {
      final agentDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(widget.property.ownerId)
          .get();

      if (agentDoc.exists) {
        final data = agentDoc.data();
        return data?['isVerified'] == true;
      }
    } on FirebaseException catch (e) {
      if (e.code == 'permission-denied') {
        if (kDebugMode) {
          debugPrint('Guest mode: agent verification read is not permitted.');
        }
        return false;
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('Error checking agent verification status: $e');
      }
    }

    return false;
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Property Details'),
        backgroundColor: AppColors.primary,
        actions: [
          IconButton(
            icon: Icon(_isFavorite ? Icons.favorite : Icons.favorite_border),
            color: _isFavorite ? Colors.red : null,
            onPressed: _toggleFavorite,
          ),
          IconButton(
            icon: const Icon(Icons.share),
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Share feature coming soon!')),
              );
            },
          ),
        ],
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Image Gallery
            if (widget.property.imageUrls.isNotEmpty)
              Stack(
                children: [
                  SizedBox(
                    height: 300,
                    child: PageView.builder(
                      itemCount: widget.property.imageUrls.length,
                      onPageChanged: (index) {
                        setState(() {
                          _currentImageIndex = index;
                        });
                        _prefetchImageAtIndex(index);
                      },
                      itemBuilder: (context, index) {
                        final imageUrl = widget.property.imageUrls[index];
                        return GestureDetector(
                          onTap: () => _openGalleryZoom(index),
                          child: CachedNetworkImage(
                            imageUrl: imageUrl,
                            fit: BoxFit.cover,
                            width: double.infinity,
                            memCacheWidth: 1600,
                            maxWidthDiskCache: 1600,
                            fadeInDuration: Duration.zero,
                            placeholder: (context, url) => Container(
                              color: Colors.grey[300],
                              child: const Center(
                                child: CircularProgressIndicator(),
                              ),
                            ),
                            errorWidget: (context, url, error) {
                              return Container(
                                color: Colors.grey[300],
                                child: const Icon(
                                  Icons.image_not_supported,
                                  size: 64,
                                ),
                              );
                            },
                          ),
                        );
                      },
                    ),
                  ),
                  Positioned(
                    top: 16,
                    right: 16,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: widget.property.type == PropertyType.sale
                            ? Colors.green
                            : Colors.blue,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        widget.property.type == PropertyType.sale
                            ? 'FOR SALE'
                            : 'FOR RENT',
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                  // Sold Out Banner
                  if (!widget.property.isActive)
                    Positioned(
                      top: 16,
                      left: 16,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.red,
                          borderRadius: BorderRadius.circular(20),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.3),
                              blurRadius: 8,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: const Text(
                          'SOLD OUT',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                      ),
                    ),
                  Positioned(
                    bottom: 16,
                    right: 16,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.black54,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Text(
                        '${_currentImageIndex + 1}/${widget.property.imageUrls.length}',
                        style: const TextStyle(color: Colors.white),
                      ),
                    ),
                  ),
                ],
              ),

            // Property Details
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.property.title,
                    style: textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Price (hidden for hostels - they show room pricing below)
                  if (widget.property.type != PropertyType.hostel) ...[
                    Text(
                      '${widget.property.currency} ${CurrencyFormatter.format(widget.property.price)}${widget.property.type == PropertyType.rent
                          ? '/month'
                          : widget.property.type == PropertyType.hostel
                          ? '/semester'
                          : ''}',
                      style: textTheme.displaySmall?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: AppColors.primary,
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],

                  // University (for hostels)
                  if (widget.property.type == PropertyType.hostel &&
                      widget.property.university != null) ...[
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            AppColors.primary.withOpacity(0.1),
                            Colors.white,
                          ],
                        ),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: AppColors.primary.withOpacity(0.3),
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.school,
                            color: AppColors.primary,
                            size: 28,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Near University',
                                  style: textTheme.labelMedium?.copyWith(
                                    color: Colors.grey,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  widget.property.university!,
                                  style: textTheme.titleMedium?.copyWith(
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],

                  // Gender Policy (for hostels)
                  if (widget.property.type == PropertyType.hostel) ...[
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            _getGenderPolicyColor(
                              widget.property.genderPolicy,
                            ).withOpacity(0.1),
                            Colors.white,
                          ],
                        ),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: _getGenderPolicyColor(
                            widget.property.genderPolicy,
                          ).withOpacity(0.3),
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            _getGenderPolicyIcon(widget.property.genderPolicy),
                            color: _getGenderPolicyColor(
                              widget.property.genderPolicy,
                            ),
                            size: 28,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Gender Policy',
                                  style: textTheme.labelMedium?.copyWith(
                                    color: Colors.grey,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  _getGenderPolicyLabel(
                                    widget.property.genderPolicy,
                                  ),
                                  style: textTheme.titleMedium?.copyWith(
                                    fontWeight: FontWeight.w700,
                                    color: _getGenderPolicyColor(
                                      widget.property.genderPolicy,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],

                  // Room Structure (for hostels)
                  if (widget.property.type == PropertyType.hostel &&
                      widget.property.roomStructure != null) ...[
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.teal.shade50,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.teal.shade200),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            widget.property.roomStructure == 'Self Contained'
                                ? Icons.bathtub
                                : Icons.meeting_room,
                            color: Colors.teal.shade700,
                            size: 28,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Room Structure',
                                  style: textTheme.labelMedium?.copyWith(
                                    color: Colors.grey,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  widget.property.roomStructure!,
                                  style: textTheme.titleMedium?.copyWith(
                                    fontWeight: FontWeight.w700,
                                    color: Colors.teal.shade700,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],

                  Row(
                    children: [
                      const Icon(Icons.location_on, color: Colors.grey),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          widget.property.location,
                          style: textTheme.bodyLarge?.copyWith(
                            color: Colors.grey,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),

                  // Room Types (for hostels)
                  if (widget.property.type == PropertyType.hostel &&
                      widget.property.roomTypes.isNotEmpty) ...[
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade50,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.grey.shade300),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Available Room Types',
                            style: textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 12),
                          ...widget.property.roomTypes.map((roomType) {
                            return Padding(
                              padding: const EdgeInsets.only(bottom: 12),
                              child: Container(
                                padding: const EdgeInsets.all(16),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: AppColors.primary.withOpacity(0.3),
                                  ),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withOpacity(0.03),
                                      blurRadius: 10,
                                      offset: const Offset(0, 4),
                                    ),
                                  ],
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Icon(
                                          _getRoomTypeIcon(roomType.name),
                                          color: AppColors.primary,
                                          size: 24,
                                        ),
                                        const SizedBox(width: 12),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                roomType.name,
                                                style: textTheme.titleMedium
                                                    ?.copyWith(
                                                      fontWeight:
                                                          FontWeight.w700,
                                                      height: 1.2,
                                                    ),
                                              ),
                                              const SizedBox(height: 6),
                                              Container(
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                      horizontal: 10,
                                                      vertical: 6,
                                                    ),
                                                decoration: BoxDecoration(
                                                  color: AppColors.primary
                                                      .withOpacity(0.08),
                                                  borderRadius:
                                                      BorderRadius.circular(
                                                        999,
                                                      ),
                                                  border: Border.all(
                                                    color: AppColors.primary
                                                        .withOpacity(0.12),
                                                  ),
                                                ),
                                                child: Text(
                                                  '${widget.property.currency} ${CurrencyFormatter.format(roomType.price)} / ${roomType.pricingPeriod.name}',
                                                  style: textTheme.labelMedium
                                                      ?.copyWith(
                                                        fontWeight:
                                                            FontWeight.w700,
                                                        color:
                                                            AppColors.primary,
                                                      ),
                                                ),
                                              ),
                                              const SizedBox(height: 8),
                                              Wrap(
                                                spacing: 8,
                                                runSpacing: 8,
                                                crossAxisAlignment:
                                                    WrapCrossAlignment.center,
                                                children: [
                                                  Container(
                                                    padding:
                                                        const EdgeInsets.symmetric(
                                                          horizontal: 8,
                                                          vertical: 4,
                                                        ),
                                                    decoration: BoxDecoration(
                                                      color:
                                                          roomType
                                                              .hasAvailability
                                                          ? Colors.green
                                                                .withOpacity(
                                                                  0.1,
                                                                )
                                                          : Colors.red
                                                                .withOpacity(
                                                                  0.1,
                                                                ),
                                                      borderRadius:
                                                          BorderRadius.circular(
                                                            999,
                                                          ),
                                                      border: Border.all(
                                                        color:
                                                            roomType
                                                                .hasAvailability
                                                            ? Colors.green
                                                            : Colors.red,
                                                      ),
                                                    ),
                                                    child: Text(
                                                      roomType.hasAvailability
                                                          ? '${roomType.availableRooms} Available'
                                                          : 'Fully Booked',
                                                      style: textTheme
                                                          .labelMedium
                                                          ?.copyWith(
                                                            fontWeight:
                                                                FontWeight.w600,
                                                            color:
                                                                roomType
                                                                    .hasAvailability
                                                                ? Colors
                                                                      .green
                                                                      .shade700
                                                                : Colors
                                                                      .red
                                                                      .shade700,
                                                          ),
                                                    ),
                                                  ),
                                                  if (roomType.totalRooms > 0)
                                                    Text(
                                                      'of ${roomType.totalRooms}',
                                                      style: textTheme
                                                          .labelSmall
                                                          ?.copyWith(
                                                            color: Colors
                                                                .grey
                                                                .shade600,
                                                          ),
                                                    ),
                                                ],
                                              ),
                                            ],
                                          ),
                                        ),
                                      ],
                                    ),
                                    // Guests can see the CTA, but booking itself requires login.
                                    if (FirebaseAuth.instance.currentUser ==
                                            null ||
                                        _currentUserRole == UserRole.customer ||
                                        _currentUserRoles.contains(
                                          UserRole.customer,
                                        )) ...[
                                      const SizedBox(height: 12),
                                      SizedBox(
                                        width: double.infinity,
                                        child: FilledButton.icon(
                                          onPressed: () {
                                            if (!_requireAuthentication(
                                              title: 'Login To Book',
                                              message:
                                                  'Bookings require an account so we can connect you with the hostel and keep your reservation records.',
                                            )) {
                                              return;
                                            }

                                            Navigator.push(
                                              context,
                                              MaterialPageRoute(
                                                builder: (context) =>
                                                    ReserveRoomScreen(
                                                      property: widget.property,
                                                      roomType: roomType,
                                                    ),
                                              ),
                                            );
                                          },
                                          icon: const Icon(
                                            Icons.book_online,
                                            size: 18,
                                          ),
                                          label: const Text(
                                            'Request Reservation',
                                          ),
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                            );
                          }),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),
                  ],

                  // Features (only show for non-hostels)
                  if (widget.property.type != PropertyType.hostel) ...[
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        _buildFeatureCard(
                          Icons.bed,
                          '${widget.property.bedrooms}',
                          'Bedrooms',
                        ),
                        _buildFeatureCard(
                          Icons.bathtub,
                          '${widget.property.bathrooms}',
                          'Bathrooms',
                        ),
                        _buildFeatureCard(
                          Icons.square_foot,
                          '${widget.property.areaSqft.toInt()}',
                          'sq ft',
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),
                  ],

                  const Divider(),
                  const SizedBox(height: 16),
                  Text(
                    'Description',
                    style: textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    widget.property.description,
                    style: textTheme.bodyLarge?.copyWith(height: 1.5),
                  ),
                  const SizedBox(height: 24),

                  // Amenities Section
                  if (widget.property.amenities.isNotEmpty) ...[
                    const Divider(),
                    const SizedBox(height: 16),
                    Text(
                      'Amenities',
                      style: textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: widget.property.amenities.map((amenity) {
                        return Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 8,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.primary.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: AppColors.primary.withOpacity(0.3),
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                _getAmenityIcon(amenity),
                                size: 16,
                                color: AppColors.primary,
                              ),
                              const SizedBox(width: 6),
                              Text(
                                amenity,
                                style: textTheme.bodyMedium?.copyWith(
                                  color: AppColors.primary,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 24),
                  ],

                  const Divider(),
                  const SizedBox(height: 16),
                  Text(
                    widget.property.type == PropertyType.hostel
                        ? 'Contact Support'
                        : 'Contact Information',
                    style: textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 16),
                  // Agent Profile Section
                  InkWell(
                    onTap: () async {
                      // Fetch agent UserModel from Firestore
                      try {
                        final agentDoc = await FirebaseFirestore.instance
                            .collection('users')
                            .doc(widget.property.ownerId)
                            .get();

                        if (agentDoc.exists && mounted) {
                          final agentUser = UserModel.fromJson({
                            ...agentDoc.data()!,
                            'id': agentDoc.id,
                          });

                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) =>
                                  AgentProfileScreen(agent: agentUser),
                            ),
                          );
                        } else {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Agent profile not found'),
                            ),
                          );
                        }
                      } on FirebaseException catch (e) {
                        if (e.code == 'permission-denied') {
                          if (!mounted) return;
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text(
                                'Please log in to view the agent profile.',
                              ),
                            ),
                          );
                          return;
                        }
                      } catch (e) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('Error loading agent profile: $e'),
                          ),
                        );
                      }
                    },
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [Colors.blue.shade50, Colors.white],
                        ),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.blue.shade200),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.blue.withOpacity(0.1),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              // Agent Profile Image
                              Container(
                                width: 70,
                                height: 70,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: Colors.blue.shade300,
                                    width: 3,
                                  ),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.blue.withOpacity(0.2),
                                      blurRadius: 8,
                                      offset: const Offset(0, 2),
                                    ),
                                  ],
                                ),
                                child: ClipOval(
                                  child: FutureBuilder<String?>(
                                    future: _getAgentProfileImage(),
                                    builder: (context, snapshot) {
                                      if (snapshot.connectionState ==
                                          ConnectionState.waiting) {
                                        return Container(
                                          color: Colors.blue.shade100,
                                          child: Center(
                                            child: SizedBox(
                                              width: 20,
                                              height: 20,
                                              child: CircularProgressIndicator(
                                                strokeWidth: 2,
                                                valueColor:
                                                    AlwaysStoppedAnimation<
                                                      Color
                                                    >(Colors.blue.shade700),
                                              ),
                                            ),
                                          ),
                                        );
                                      }

                                      final imageUrl = snapshot.data;
                                      if (imageUrl != null &&
                                          imageUrl.isNotEmpty &&
                                          imageUrl.startsWith('http')) {
                                        return Image.network(
                                          imageUrl,
                                          fit: BoxFit.cover,
                                          errorBuilder:
                                              (context, error, stackTrace) {
                                                return Container(
                                                  color: Colors.blue.shade100,
                                                  child: Icon(
                                                    Icons.person,
                                                    size: 40,
                                                    color: Colors.blue.shade700,
                                                  ),
                                                );
                                              },
                                        );
                                      } else {
                                        return Container(
                                          color: Colors.blue.shade100,
                                          child: Icon(
                                            Icons.person,
                                            size: 40,
                                            color: Colors.blue.shade700,
                                          ),
                                        );
                                      }
                                    },
                                  ),
                                ),
                              ),
                              const SizedBox(width: 16),
                              // Agent Info
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    if (widget
                                        .property
                                        .companyName
                                        .isNotEmpty) ...{
                                      Row(
                                        children: [
                                          Icon(
                                            Icons.business,
                                            color: Colors.blue.shade700,
                                            size: 18,
                                          ),
                                          const SizedBox(width: 6),
                                          Expanded(
                                            child: Text(
                                              widget.property.companyName,
                                              style: TextStyle(
                                                fontSize: 16,
                                                fontWeight: FontWeight.bold,
                                                color: Colors.blue.shade900,
                                              ),
                                              maxLines: 2,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 8),
                                    },
                                    if (widget.property.type ==
                                            PropertyType.hostel &&
                                        widget.property.ownerName.isNotEmpty)
                                      Text(
                                        widget.property.ownerName,
                                        style: TextStyle(
                                          fontSize: 15,
                                          fontWeight: FontWeight.w500,
                                          color: Colors.blue.shade700,
                                        ),
                                      )
                                    else if (widget
                                        .property
                                        .agentName
                                        .isNotEmpty)
                                      FutureBuilder<bool>(
                                        future: _checkAgentVerificationStatus(),
                                        builder: (context, snapshot) {
                                          final isVerified =
                                              snapshot.data ?? false;
                                          return AgentNameWithBadge(
                                            name: widget.property.agentName,
                                            isVerified: isVerified,
                                            style: TextStyle(
                                              fontSize: 15,
                                              fontWeight: FontWeight.w500,
                                              color: Colors.blue.shade700,
                                            ),
                                            iconColor: Colors.blue.shade600,
                                            iconSize: 18,
                                          );
                                        },
                                      ),
                                    const SizedBox(height: 4),
                                    // Verified Badge - Only show if agent is verified
                                    FutureBuilder<bool>(
                                      future: _checkAgentVerificationStatus(),
                                      builder: (context, snapshot) {
                                        if (snapshot.connectionState ==
                                            ConnectionState.waiting) {
                                          return const SizedBox.shrink();
                                        }

                                        final isVerified =
                                            snapshot.data ?? false;

                                        if (!isVerified) {
                                          return const SizedBox.shrink();
                                        }

                                        return Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 10,
                                            vertical: 4,
                                          ),
                                          decoration: BoxDecoration(
                                            color: Colors.blue.shade700,
                                            borderRadius: BorderRadius.circular(
                                              12,
                                            ),
                                          ),
                                          child: const Text(
                                            'Verified Agent',
                                            style: TextStyle(
                                              fontSize: 11,
                                              color: Colors.white,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        );
                                      },
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 8),
                              Icon(
                                Icons.arrow_forward_ios,
                                size: 20,
                                color: Colors.blue.shade600,
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Center(
                            child: Text(
                              'Tap to view full profile',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.blue.shade600,
                                fontStyle: FontStyle.italic,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Only show 'Contact Support' tab here. Custodian contact info is shown after reservation.
                  const SizedBox(height: 24),

                  // Inspection Fee Section (show if inspection fee is set and greater than 0)
                  if (widget.property.inspectionFee != null &&
                      widget.property.inspectionFee! > 0) ...[
                    const Divider(),
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [Colors.orange.shade50, Colors.white],
                        ),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: Colors.orange.shade300,
                          width: 2,
                        ),
                      ),
                      child: Column(
                        children: [
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: Colors.orange.shade100,
                                  shape: BoxShape.circle,
                                ),
                                child: Icon(
                                  Icons.remove_red_eye,
                                  color: Colors.orange.shade700,
                                  size: 28,
                                ),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text(
                                      'Property Inspection',
                                      style: TextStyle(
                                        fontSize: 18,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.black87,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 12,
                                        vertical: 6,
                                      ),
                                      decoration: BoxDecoration(
                                        color: Colors.orange.shade700,
                                        borderRadius: BorderRadius.circular(20),
                                      ),
                                      child: Text(
                                        'UGX ${(widget.property.inspectionFee ?? 30000).toInt().toString().replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (Match m) => '${m[1]},')}',
                                        style: const TextStyle(
                                          fontSize: 20,
                                          fontWeight: FontWeight.bold,
                                          color: Colors.white,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.orange.shade50,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: Colors.orange.shade200),
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  Icons.info_outline,
                                  color: Colors.orange.shade700,
                                  size: 24,
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Text(
                                    'IMPORTANT: Pay UGX ${(widget.property.inspectionFee ?? 30000).toInt().toString().replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (Match m) => '${m[1]},')} after confirming property availability.',
                                    style: TextStyle(
                                      fontSize: 14,
                                      height: 1.4,
                                      color: Colors.orange.shade900,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],

                  // Hostel Booking Benefits Section (only for student hostels)
                  if (widget.property.type == PropertyType.hostel) ...[
                    const Divider(),
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [Colors.blue.shade50, Colors.white],
                        ),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppColors.primary, width: 2),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: AppColors.primary.withOpacity(0.2),
                                  shape: BoxShape.circle,
                                ),
                                child: Icon(
                                  Icons.verified_user,
                                  color: AppColors.primary,
                                  size: 32,
                                ),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text(
                                      'Book with Confidence',
                                      style: TextStyle(
                                        fontSize: 20,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.black87,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      'Your trusted hostel reservation platform',
                                      style: TextStyle(
                                        fontSize: 14,
                                        color: Colors.grey.shade700,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 20),
                          _buildBenefitItem(
                            Icons.shield_outlined,
                            'Verified Properties',
                            'All hostels are verified and approved by our admin team',
                          ),
                          const SizedBox(height: 12),
                          _buildBenefitItem(
                            Icons.payment,
                            'Secure Payment',
                            'Your payment is protected with our secure booking system',
                          ),
                          const SizedBox(height: 12),
                          _buildBenefitItem(
                            Icons.support_agent,
                            '24/7 Support',
                            'Contact us anytime if you need assistance with your reservation',
                          ),
                          const SizedBox(height: 12),
                          _buildBenefitItem(
                            Icons.schedule,
                            'Instant Confirmation',
                            'Get immediate booking confirmation and room details',
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],
                ],
              ),
            ),

            // More Properties from this Agent Section
            const Divider(height: 32),
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'More Properties from this Agent',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 16),
                  StreamBuilder<QuerySnapshot>(
                    stream: FirebaseFirestore.instance
                        .collection('properties')
                        .where('ownerId', isEqualTo: widget.property.ownerId)
                        .where('status', isEqualTo: 'approved')
                        .limit(10)
                        .snapshots(),
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return const Center(
                          child: Padding(
                            padding: EdgeInsets.all(20.0),
                            child: CircularProgressIndicator(),
                          ),
                        );
                      }

                      if (snapshot.hasError) {
                        return Center(child: Text('Error: ${snapshot.error}'));
                      }

                      if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                        return const Center(
                          child: Padding(
                            padding: EdgeInsets.all(20.0),
                            child: Text('No other properties from this agent'),
                          ),
                        );
                      }

                      // Filter out current property
                      final properties = snapshot.data!.docs
                          .map(
                            (doc) => PropertyModel.fromJson({
                              ...doc.data() as Map<String, dynamic>,
                              'id': doc.id,
                            }),
                          )
                          .where((prop) => prop.id != widget.property.id)
                          .toList();

                      if (properties.isEmpty) {
                        return const Center(
                          child: Padding(
                            padding: EdgeInsets.all(20.0),
                            child: Text('No other properties from this agent'),
                          ),
                        );
                      }

                      return SizedBox(
                        height: 280,
                        child: ListView.builder(
                          scrollDirection: Axis.horizontal,
                          itemCount: properties.length,
                          itemBuilder: (context, index) {
                            final property = properties[index];
                            return GestureDetector(
                              onTap: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) => PropertyDetailsScreen(
                                      property: property,
                                    ),
                                  ),
                                );
                              },
                              child: Container(
                                width: 250,
                                margin: const EdgeInsets.only(right: 16),
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(12),
                                  color: Colors.white,
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withOpacity(0.1),
                                      blurRadius: 8,
                                      offset: const Offset(0, 4),
                                    ),
                                  ],
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    // Property Image
                                    ClipRRect(
                                      borderRadius: const BorderRadius.vertical(
                                        top: Radius.circular(12),
                                      ),
                                      child: property.imageUrls.isNotEmpty
                                          ? CachedNetworkImage(
                                              imageUrl:
                                                  property.imageUrls.first,
                                              height: 150,
                                              width: double.infinity,
                                              fit: BoxFit.cover,
                                              placeholder: (context, url) =>
                                                  Container(
                                                    color: Colors.grey[300],
                                                    child: const Center(
                                                      child:
                                                          CircularProgressIndicator(),
                                                    ),
                                                  ),
                                              errorWidget:
                                                  (
                                                    context,
                                                    url,
                                                    error,
                                                  ) => Container(
                                                    color: Colors.grey[300],
                                                    child: const Icon(
                                                      Icons.image_not_supported,
                                                      size: 48,
                                                    ),
                                                  ),
                                            )
                                          : Container(
                                              height: 150,
                                              color: Colors.grey[300],
                                              child: const Icon(
                                                Icons.home,
                                                size: 48,
                                              ),
                                            ),
                                    ),
                                    // Property Details
                                    Padding(
                                      padding: const EdgeInsets.all(12.0),
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            property.title,
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
                                              Icon(
                                                Icons.location_on,
                                                size: 14,
                                                color: Colors.grey[600],
                                              ),
                                              const SizedBox(width: 4),
                                              Expanded(
                                                child: Text(
                                                  property.location,
                                                  style: TextStyle(
                                                    fontSize: 13,
                                                    color: Colors.grey[600],
                                                  ),
                                                  maxLines: 1,
                                                  overflow:
                                                      TextOverflow.ellipsis,
                                                ),
                                              ),
                                            ],
                                          ),
                                          const SizedBox(height: 8),
                                          Text(
                                            '${property.currency} ${CurrencyFormatter.format(property.price)}${property.type == PropertyType.rent
                                                ? '/month'
                                                : property.type == PropertyType.hostel
                                                ? '/semester'
                                                : ''}',
                                            style: const TextStyle(
                                              fontSize: 16,
                                              fontWeight: FontWeight.bold,
                                              color: AppColors.primary,
                                            ),
                                          ),
                                          const SizedBox(height: 4),
                                          Row(
                                            children: [
                                              Icon(
                                                Icons.bed,
                                                size: 14,
                                                color: Colors.grey[600],
                                              ),
                                              const SizedBox(width: 4),
                                              Text(
                                                '${property.bedrooms} beds',
                                                style: TextStyle(
                                                  fontSize: 12,
                                                  color: Colors.grey[600],
                                                ),
                                              ),
                                              const SizedBox(width: 12),
                                              Icon(
                                                Icons.bathroom,
                                                size: 14,
                                                color: Colors.grey[600],
                                              ),
                                              const SizedBox(width: 4),
                                              Text(
                                                '${property.bathrooms} baths',
                                                style: TextStyle(
                                                  fontSize: 12,
                                                  color: Colors.grey[600],
                                                ),
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
                          },
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
      bottomNavigationBar: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 4,
              offset: const Offset(0, -2),
            ),
          ],
        ),
        child: SafeArea(
          child: Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () {
                    if (widget.property.contactPhone.isNotEmpty) {
                      _makePhoneCall(widget.property.contactPhone);
                    } else {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('No contact phone available'),
                        ),
                      );
                    }
                  },
                  icon: const Icon(Icons.phone),
                  label: const Text('Call'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () {
                    if (widget.property.whatsappPhone.isNotEmpty) {
                      _openWhatsApp(widget.property.whatsappPhone);
                    } else {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('No WhatsApp contact available'),
                        ),
                      );
                    }
                  },
                  icon: const Icon(Icons.chat),
                  label: const Text('WhatsApp'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFeatureCard(IconData icon, String value, String label) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.primary.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        children: [
          Icon(icon, size: 32, color: AppColors.primary),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: AppColors.primary,
            ),
          ),
          Text(label, style: TextStyle(fontSize: 12, color: Colors.grey[600])),
        ],
      ),
    );
  }

  Widget _buildContactCard({
    required IconData icon,
    required String title,
    required String value,
    Color? color,
    required VoidCallback onTap,
  }) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: (color ?? AppColors.primary).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, color: color ?? AppColors.primary),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      value,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(Icons.arrow_forward_ios, size: 16, color: Colors.grey[400]),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBenefitItem(IconData icon, String title, String description) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: AppColors.primary.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, color: AppColors.primary, size: 20),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: Colors.black87,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                description,
                style: TextStyle(
                  fontSize: 13,
                  color: Colors.grey.shade700,
                  height: 1.3,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Future<void> _makePhoneCall(String phoneNumber) async {
    final Uri phoneUri = Uri(scheme: 'tel', path: phoneNumber);
    if (await canLaunchUrl(phoneUri)) {
      await launchUrl(phoneUri);
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not launch phone call')),
        );
      }
    }
  }

  Future<void> _openWhatsApp(String phoneNumber) async {
    // Remove any non-digit characters
    String cleanNumber = phoneNumber.replaceAll(RegExp(r'[^\d]'), '');

    // Handle Uganda phone numbers (starting with 0)
    if (cleanNumber.startsWith('0')) {
      cleanNumber = '256${cleanNumber.substring(1)}';
    }
    // Handle numbers that already have 256 but no +
    else if (cleanNumber.startsWith('256')) {
      // Already in correct format
    }
    // Handle numbers with + prefix
    else if (phoneNumber.startsWith('+')) {
      cleanNumber = phoneNumber.replaceAll(RegExp(r'[^\d]'), '');
    }

    final Uri whatsappUri = Uri.parse('https://wa.me/$cleanNumber');

    if (await canLaunchUrl(whatsappUri)) {
      await launchUrl(whatsappUri, mode: LaunchMode.externalApplication);
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not open WhatsApp')),
        );
      }
    }
  }

  Future<void> _sendEmail(String email) async {
    final Uri emailUri = Uri(
      scheme: 'mailto',
      path: email,
      query: 'subject=Inquiry about ${widget.property.title}',
    );

    if (await canLaunchUrl(emailUri)) {
      await launchUrl(emailUri);
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not open email app')),
        );
      }
    }
  }

  IconData _getAmenityIcon(String amenity) {
    switch (amenity.toLowerCase()) {
      case 'swimming pool':
        return Icons.pool;
      case 'gym':
        return Icons.fitness_center;
      case 'parking':
        return Icons.local_parking;
      case 'security':
        return Icons.security;
      case 'garden':
        return Icons.yard;
      case 'balcony':
        return Icons.balcony;
      case 'air conditioning':
        return Icons.ac_unit;
      case 'heating':
        return Icons.heat_pump;
      case 'wi-fi':
        return Icons.wifi;
      case 'elevator':
        return Icons.elevator;
      case 'backup generator':
        return Icons.power;
      case 'water tank':
        return Icons.water_drop;
      case 'cctv':
        return Icons.videocam;
      case 'playground':
        return Icons.child_care;
      case 'laundry':
        return Icons.local_laundry_service;
      case 'pets allowed':
        return Icons.pets;
      default:
        return Icons.check_circle;
    }
  }

  IconData _getRoomTypeIcon(String roomType) {
    if (roomType.toLowerCase().contains('single')) {
      return Icons.person;
    } else if (roomType.toLowerCase().contains('double')) {
      return Icons.people;
    } else if (roomType.toLowerCase().contains('triple')) {
      return Icons.group;
    } else if (roomType.toLowerCase().contains('shared')) {
      return Icons.groups;
    }
    return Icons.hotel;
  }
}
