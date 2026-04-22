import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:url_launcher/url_launcher.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../models/property_model.dart';
import '../../models/user_model.dart';
import '../../utils/app_theme.dart';
import '../../utils/currency_formatter.dart';
import '../auth/login_screen.dart';
import '../auth/role_selection_screen.dart';
import '../customer/agent_profile_screen.dart';
import '../customer/reserve_room_screen.dart';
import '../../widgets/fullscreen_image_viewer.dart';
import '../../services/view_tracking_service.dart';
import '../../services/post_auth_intent_service.dart';

class PropertyDetailsScreen extends StatefulWidget {
  final PropertyModel property;

  const PropertyDetailsScreen({super.key, required this.property});

  @override
  State<PropertyDetailsScreen> createState() => _PropertyDetailsScreenState();
}

class _PropertyDetailsScreenState extends State<PropertyDetailsScreen> {
  static const String _publicWebAppBaseUrl = 'https://truehome-9a244.web.app';
  int _currentImageIndex = 0;
  bool _isFavorite = false;
  static const String _favoritesKey = 'favorite_properties';
  UserRole? _currentUserRole;
  List<UserRole> _currentUserRoles = [];
  final ViewTrackingService _viewTrackingService = ViewTrackingService();

  late final Future<bool> _agentVerifiedFuture;
  late final Future<String?> _agentProfileImageFuture;

  @override
  void initState() {
    super.initState();
    _checkFavoriteStatus();
    _getCurrentUserRole();
    _trackPropertyView();
    _agentVerifiedFuture = _checkAgentVerificationStatus();
    _agentProfileImageFuture = _getAgentProfileImage();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _prefetchGalleryImages();
    });
  }

  Future<void> _prefetchGalleryImages() async {
    if (!mounted || widget.property.imageUrls.isEmpty) return;

    final galleryImages = widget.property.imageUrls.take(6);
    for (final imageUrl in galleryImages) {
      try {
        await precacheImage(CachedNetworkImageProvider(imageUrl), context);
      } catch (_) {}
    }
  }

  Future<void> _prefetchImageAtIndex(int index) async {
    if (!mounted || widget.property.imageUrls.isEmpty) return;

    final indexes = {index - 1, index, index + 1}
        .where((i) => i >= 0 && i < widget.property.imageUrls.length);

    for (final i in indexes) {
      try {
        await precacheImage(
          CachedNetworkImageProvider(widget.property.imageUrls[i]),
          context,
        );
      } catch (_) {}
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

  Future<void> _trackPropertyView() async {
    if (FirebaseAuth.instance.currentUser == null) {
      return;
    }

    try {
      await _viewTrackingService.trackPropertyView(
        propertyId: widget.property.id,
        ownerId: widget.property.ownerId,
      );
    } on FirebaseException catch (e) {
      if (e.code != 'permission-denied' && kDebugMode) {
        debugPrint('Error tracking view: $e');
      }
    } catch (e) {
      if (kDebugMode) debugPrint('Error tracking view: $e');
    }
  }

  Future<void> _getCurrentUserRole() async {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) return;

    try {
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(currentUser.uid)
          .get();

      if (userDoc.exists && mounted) {
        final userData = UserModel.fromJson(userDoc.data()!);
        setState(() {
          _currentUserRole = userData.activeRole;
          _currentUserRoles = userData.roles;
        });
      }
    } on FirebaseException catch (e) {
      if (e.code == 'permission-denied') {
        if (mounted) {
          setState(() {
            _currentUserRole = null;
            _currentUserRoles = [];
          });
        }
        if (kDebugMode) debugPrint('Guest mode: role lookup is not permitted.');
      }
    } catch (e) {
      if (kDebugMode) debugPrint('Error getting user role: $e');
    }
  }

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
    )) return;

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
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error updating favorites: $e')),
        );
      }
    }
  }

  bool _requireAuthentication({
    required String title,
    required String message,
    PostAuthIntent? postAuthIntent,
  }) {
    if (FirebaseAuth.instance.currentUser != null) return true;

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
                      if (postAuthIntent != null) {
                        PostAuthIntentService.instance.setIntent(postAuthIntent);
                      }
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
                      if (postAuthIntent != null) {
                        PostAuthIntentService.instance.setIntent(postAuthIntent);
                      }
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
    if (widget.property.agentProfileImageUrl != null &&
        widget.property.agentProfileImageUrl!.isNotEmpty) {
      return widget.property.agentProfileImageUrl;
    }

    if (FirebaseAuth.instance.currentUser == null) {
      return null;
    }

    try {
      final agentDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(widget.property.ownerId)
          .get();

      if (agentDoc.exists) {
        return agentDoc.data()?['profileImageUrl'] as String?;
      }
    } on FirebaseException catch (e) {
      if (e.code != 'permission-denied' && kDebugMode) {
        debugPrint('Error fetching agent profile image: $e');
      }
    } catch (e) {
      if (kDebugMode) debugPrint('Error fetching agent profile image: $e');
    }

    return null;
  }

  Future<bool> _checkAgentVerificationStatus() async {
    if (FirebaseAuth.instance.currentUser == null) {
      return false;
    }

    try {
      final agentDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(widget.property.ownerId)
          .get();

      if (agentDoc.exists) {
        return agentDoc.data()?['isVerified'] == true;
      }
    } on FirebaseException catch (e) {
      if (e.code != 'permission-denied' && kDebugMode) {
        debugPrint('Error checking agent verification status: $e');
      }
    } catch (e) {
      if (kDebugMode) debugPrint('Error checking agent verification status: $e');
    }

    return false;
  }

  Future<void> _navigateToAgentProfile() async {
    if (!_requireAuthentication(
      title: 'Login Required',
      message:
          'Sign in to view full agent details and rate this agent.',
    )) {
      return;
    }

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
            builder: (_) => AgentProfileScreen(agent: agentUser),
          ),
        );
      } else if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Agent details are not available yet.')),
        );
      }
    } on FirebaseException catch (e) {
      if (!mounted) return;
      final message = e.code == 'permission-denied'
          ? 'Please sign in to view full agent details.'
          : 'Could not open agent details right now. Please try again.';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message)),
      );
      if (e.code != 'permission-denied' && kDebugMode) {
        debugPrint('Error navigating to agent profile: $e');
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Could not open agent details right now. Please try again.'),
        ),
      );
      if (kDebugMode) debugPrint('Error navigating to agent profile: $e');
    }
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
                        setState(() => _currentImageIndex = index);
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
                            filterQuality: FilterQuality.high,
                            memCacheWidth: 2400,
                            maxWidthDiskCache: 2400,
                            fadeInDuration: Duration.zero,
                            placeholder: (context, url) => Container(
                              color: Colors.grey[300],
                              child: const Center(
                                child: CircularProgressIndicator(),
                              ),
                            ),
                            errorWidget: (context, url, error) => Container(
                              color: Colors.grey[300],
                              child: const Icon(
                                Icons.image_not_supported,
                                size: 64,
                              ),
                            ),
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

                  // Price (hidden for hostels — room pricing shown below)
                  if (widget.property.type != PropertyType.hostel) ...[
                    Text(
                      '${widget.property.currency} ${CurrencyFormatter.format(widget.property.price)}${widget.property.type == PropertyType.rent ? '/month' : ''}',
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
                          Icon(Icons.school, color: AppColors.primary, size: 28),
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
                            _getGenderPolicyColor(widget.property.genderPolicy)
                                .withOpacity(0.1),
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
                                                  fontWeight: FontWeight.w700,
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
                                                      BorderRadius.circular(999),
                                                  border: Border.all(
                                                    color: AppColors.primary
                                                        .withOpacity(0.12),
                                                  ),
                                                ),
                                                child: Text(
                                                  _canShowHostelPriceToCustomers(
                                                          widget.property)
                                                      ? '${widget.property.currency} ${CurrencyFormatter.format(roomType.price)} / ${roomType.pricingPeriod.name}'
                                                      : 'Price on request',
                                                  style: textTheme.labelMedium
                                                      ?.copyWith(
                                                    fontWeight: FontWeight.w700,
                                                    color: AppColors.primary,
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
                                                      color: roomType
                                                              .hasAvailability
                                                          ? Colors.green
                                                              .withOpacity(0.1)
                                                          : Colors.red
                                                              .withOpacity(0.1),
                                                      borderRadius:
                                                          BorderRadius.circular(
                                                              999),
                                                      border: Border.all(
                                                        color: roomType
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
                                                        color: roomType
                                                                .hasAvailability
                                                            ? Colors
                                                                .green.shade700
                                                            : Colors.red.shade700,
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
                                                            .grey.shade600,
                                                      ),
                                                    ),
                                                ],
                                              ),
                                            ],
                                          ),
                                        ),
                                      ],
                                    ),
                                    // Guests can see the CTA; booking itself requires login.
                                    if (FirebaseAuth.instance.currentUser ==
                                            null ||
                                        _currentUserRole ==
                                            UserRole.customer ||
                                        _currentUserRoles
                                            .contains(UserRole.customer)) ...[
                                      const SizedBox(height: 12),
                                      SizedBox(
                                        width: double.infinity,
                                        child: FilledButton.icon(
                                          onPressed: () {
                                            if (!_requireAuthentication(
                                              title: 'Login To Book',
                                              message:
                                                  'Bookings require an account so we can connect you with the hostel and keep your reservation records.',
                                            )) return;

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
                                          label:
                                              const Text('Request Reservation'),
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

                  // Property metrics
                  if (widget.property.type != PropertyType.hostel &&
                      widget.property.type != PropertyType.commercial) ...[
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        if (widget.property.bedrooms > 0)
                          _buildFeatureCard(
                            Icons.bed,
                            '${widget.property.bedrooms}',
                            'Bedrooms',
                          ),
                        if (widget.property.bathrooms > 0)
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

                  if (_shouldShowContactCard) ...[
                    const Divider(),
                    const SizedBox(height: 24),
                    // Section Header
                    Text(
                      'Contact Support',
                      style: textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w800,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Container(
                      width: double.infinity,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            AppColors.primary.withOpacity(0.08),
                            AppColors.primary.withOpacity(0.03),
                          ],
                        ),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: AppColors.primary.withOpacity(0.12),
                          width: 1.5,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.primary.withOpacity(0.08),
                            blurRadius: 20,
                            offset: const Offset(0, 8),
                          ),
                        ],
                      ),
                      child: InkWell(
                        onTap: _navigateToAgentProfile,
                        borderRadius: BorderRadius.circular(20),
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(20, 24, 20, 24),
                          child: Column(
                            children: [
                              // Agent Avatar Section
                              Stack(
                                alignment: Alignment.center,
                                children: [
                                  // Background circle with gradient
                                  Container(
                                    width: 100,
                                    height: 100,
                                    decoration: BoxDecoration(
                                      gradient: LinearGradient(
                                        begin: Alignment.topLeft,
                                        end: Alignment.bottomRight,
                                        colors: [
                                          AppColors.primary.withOpacity(0.15),
                                          AppColors.primary.withOpacity(0.05),
                                        ],
                                      ),
                                      shape: BoxShape.circle,
                                    ),
                                  ),
                                  // Avatar with border
                                  FutureBuilder<String?>(
                                    future: _agentProfileImageFuture,
                                    builder: (context, snapshot) {
                                      final imageUrl = snapshot.data?.trim();
                                      final hasImage =
                                          imageUrl != null && imageUrl.isNotEmpty;

                                      return Container(
                                        decoration: BoxDecoration(
                                          shape: BoxShape.circle,
                                          border: Border.all(
                                            color: AppColors.primary,
                                            width: 3,
                                          ),
                                          boxShadow: [
                                            BoxShadow(
                                              color:
                                                  AppColors.primary
                                                      .withOpacity(0.3),
                                              blurRadius: 16,
                                              offset: const Offset(0, 4),
                                            ),
                                          ],
                                        ),
                                        child: CircleAvatar(
                                          radius: 44,
                                          backgroundColor: Colors.white,
                                          backgroundImage: hasImage
                                              ? CachedNetworkImageProvider(
                                                  imageUrl,
                                                )
                                              : null,
                                          child: hasImage
                                              ? null
                                              : Icon(
                                                  Icons.support_agent,
                                                  color: AppColors.primary,
                                                  size: 44,
                                                ),
                                        ),
                                      );
                                    },
                                  ),
                                  // Verified badge
                                  FutureBuilder<bool>(
                                    future: _agentVerifiedFuture,
                                    builder: (context, snapshot) {
                                      if (snapshot.data == true) {
                                        return Positioned(
                                          bottom: 0,
                                          right: 0,
                                          child: Container(
                                            padding:
                                                const EdgeInsets.all(6),
                                            decoration: BoxDecoration(
                                              color: Colors.white,
                                              shape: BoxShape.circle,
                                              border: Border.all(
                                                color: AppColors.primary,
                                                width: 2,
                                              ),
                                              boxShadow: [
                                                BoxShadow(
                                                  color: Colors.black
                                                      .withOpacity(0.15),
                                                  blurRadius: 8,
                                                )
                                              ],
                                            ),
                                            child: Icon(
                                              Icons.verified,
                                              color: AppColors.primary,
                                              size: 18,
                                            ),
                                          ),
                                        );
                                      }
                                      return const SizedBox.shrink();
                                    },
                                  ),
                                ],
                              ),
                              const SizedBox(height: 16),
                              // Agent Info Section
                              Column(
                                children: [
                                  // Agent Name with Role Badge
                                  Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.center,
                                    children: [
                                      Flexible(
                                        child: Text(
                                          widget.property.agentName
                                                  .trim()
                                                  .isNotEmpty
                                              ? widget.property.agentName
                                              : 'Property Agent',
                                          style:
                                              textTheme.titleLarge?.copyWith(
                                                fontWeight: FontWeight.w800,
                                                color: AppColors.textPrimary,
                                              ),
                                          textAlign: TextAlign.center,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 6),
                                  // Company Name
                                  Text(
                                    widget.property.companyName
                                            .trim()
                                            .isNotEmpty
                                        ? widget.property.companyName
                                        : 'Professional Agent',
                                    style: textTheme.bodyMedium?.copyWith(
                                      color: AppColors.textSecondary,
                                      fontWeight: FontWeight.w500,
                                    ),
                                    textAlign: TextAlign.center,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ],
                              ),
                              const SizedBox(height: 18),
                              // Divider
                              Container(
                                height: 1,
                                color: AppColors.primary.withOpacity(0.1),
                              ),
                              const SizedBox(height: 18),
                              // CTA Section
                              Container(
                                width: double.infinity,
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 10,
                                ),
                                decoration: BoxDecoration(
                                  color: AppColors.primary.withOpacity(0.08),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.center,
                                  children: [
                                    Icon(
                                      Icons.info_outlined,
                                      color: AppColors.primary,
                                      size: 18,
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        'View full profile & rating',
                                        style: textTheme.bodySmall
                                            ?.copyWith(
                                              color: AppColors.primary,
                                              fontWeight: FontWeight.w600,
                                            ),
                                        textAlign: TextAlign.center,
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Icon(
                                      Icons.arrow_forward_ios,
                                      color: AppColors.primary,
                                      size: 14,
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 12),
                              // Email Contact (if available)
                              if (widget.property.contactEmail
                                  .trim()
                                  .isNotEmpty) ...[
                                Container(
                                  width: double.infinity,
                                  padding:
                                      const EdgeInsets.symmetric(vertical: 12),
                                  child: InkWell(
                                    onTap: () =>
                                        _sendEmail(widget.property.contactEmail),
                                    borderRadius: BorderRadius.circular(10),
                                    child: Padding(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 12),
                                      child: Row(
                                        children: [
                                          Container(
                                            width: 40,
                                            height: 40,
                                            decoration: BoxDecoration(
                                              color: Colors.white,
                                              shape: BoxShape.circle,
                                              border: Border.all(
                                                color: AppColors.primary
                                                    .withOpacity(0.2),
                                              ),
                                            ),
                                            child: Icon(
                                              Icons.email_outlined,
                                              color: AppColors.primary,
                                              size: 20,
                                            ),
                                          ),
                                          const SizedBox(width: 12),
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              children: [
                                                Text(
                                                  'Email',
                                                  style: textTheme.bodySmall
                                                      ?.copyWith(
                                                    color: AppColors
                                                        .textSecondary,
                                                    fontSize: 12,
                                                  ),
                                                ),
                                                const SizedBox(height: 2),
                                                Text(
                                                  widget.property.contactEmail,
                                                  style: textTheme.bodyMedium
                                                      ?.copyWith(
                                                    fontWeight: FontWeight.w600,
                                                    color:
                                                        AppColors.textPrimary,
                                                  ),
                                                  maxLines: 1,
                                                  overflow:
                                                      TextOverflow.ellipsis,
                                                ),
                                              ],
                                            ),
                                          ),
                                          Icon(
                                            Icons.chevron_right,
                                            color: AppColors.primary
                                                .withOpacity(0.5),
                                            size: 20,
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                  ],

                  // Inspection Fee Section
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
                                        borderRadius:
                                            BorderRadius.circular(20),
                                      ),
                                      child: Text(
                                        '${widget.property.currency} ${CurrencyFormatter.format(widget.property.inspectionFee ?? 30000)}',
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
                              border:
                                  Border.all(color: Colors.orange.shade200),
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
                                    'IMPORTANT: Pay ${widget.property.currency} ${CurrencyFormatter.format(widget.property.inspectionFee ?? 30000)} after confirming property availability.',
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
                ],
              ),
            ),

            // More Properties from this Agent
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
                        .where('ownerId',
                            isEqualTo: widget.property.ownerId)
                        .where('status', isEqualTo: 'approved')
                        .limit(10)
                        .snapshots(),
                    builder: (context, snapshot) {
                      if (snapshot.connectionState ==
                          ConnectionState.waiting) {
                        return const Center(
                          child: Padding(
                            padding: EdgeInsets.all(20.0),
                            child: CircularProgressIndicator(),
                          ),
                        );
                      }

                      if (snapshot.hasError) {
                        return Center(
                            child: Text('Error: ${snapshot.error}'));
                      }

                      if (!snapshot.hasData ||
                          snapshot.data!.docs.isEmpty) {
                        return const Center(
                          child: Padding(
                            padding: EdgeInsets.all(20.0),
                            child:
                                Text('No other properties from this agent'),
                          ),
                        );
                      }

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
                            child:
                                Text('No other properties from this agent'),
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
                                    builder: (context) =>
                                        PropertyDetailsScreen(
                                      property: property,
                                    ),
                                  ),
                                );
                              },
                              child: Container(
                                width: 250,
                                margin:
                                    const EdgeInsets.only(right: 16),
                                decoration: BoxDecoration(
                                  borderRadius:
                                      BorderRadius.circular(12),
                                  color: Colors.white,
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black
                                          .withOpacity(0.1),
                                      blurRadius: 8,
                                      offset: const Offset(0, 4),
                                    ),
                                  ],
                                ),
                                child: Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.start,
                                  children: [
                                    ClipRRect(
                                      borderRadius:
                                          const BorderRadius.vertical(
                                        top: Radius.circular(12),
                                      ),
                                      child: property
                                              .imageUrls.isNotEmpty
                                          ? CachedNetworkImage(
                                              imageUrl: property
                                                  .imageUrls.first,
                                              height: 150,
                                              width: double.infinity,
                                              fit: BoxFit.cover,
                                              filterQuality:
                                                  FilterQuality.high,
                                              placeholder: (context,
                                                      url) =>
                                                  Container(
                                                color: Colors.grey[300],
                                                child: const Center(
                                                  child:
                                                      CircularProgressIndicator(),
                                                ),
                                              ),
                                              errorWidget: (context,
                                                      url, error) =>
                                                  Container(
                                                color: Colors.grey[300],
                                                child: const Icon(
                                                  Icons
                                                      .image_not_supported,
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
                                    Padding(
                                      padding:
                                          const EdgeInsets.all(12.0),
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            property.title,
                                            style: const TextStyle(
                                              fontSize: 16,
                                              fontWeight:
                                                  FontWeight.bold,
                                            ),
                                            maxLines: 1,
                                            overflow:
                                                TextOverflow.ellipsis,
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
                                                    color:
                                                        Colors.grey[600],
                                                  ),
                                                  maxLines: 1,
                                                  overflow: TextOverflow
                                                      .ellipsis,
                                                ),
                                              ),
                                            ],
                                          ),
                                          const SizedBox(height: 8),
                                          Text(
                                            property.type ==
                                                        PropertyType
                                                            .hostel &&
                                                    !property
                                                        .showPriceToCustomers
                                                ? 'Price on request'
                                                : '${property.currency} ${CurrencyFormatter.format(property.price)}${property.type == PropertyType.rent ? '/month' : ''}',
                                            style: const TextStyle(
                                              fontSize: 16,
                                              fontWeight:
                                                  FontWeight.bold,
                                              color: AppColors.primary,
                                            ),
                                          ),
                                          const SizedBox(height: 4),
                                          if (property.type !=
                                                  PropertyType
                                                      .commercial &&
                                              (property.bedrooms > 0 ||
                                                  property.bathrooms >
                                                      0))
                                            Row(
                                              children: [
                                                if (property.bedrooms >
                                                    0) ...[
                                                  Icon(
                                                    Icons.bed,
                                                    size: 14,
                                                    color:
                                                        Colors.grey[600],
                                                  ),
                                                  const SizedBox(
                                                      width: 4),
                                                  Text(
                                                    '${property.bedrooms} beds',
                                                    style: TextStyle(
                                                      fontSize: 12,
                                                      color: Colors
                                                          .grey[600],
                                                    ),
                                                  ),
                                                  const SizedBox(
                                                      width: 12),
                                                ],
                                                if (property.bathrooms >
                                                    0) ...[
                                                  Icon(
                                                    Icons.bathroom,
                                                    size: 14,
                                                    color:
                                                        Colors.grey[600],
                                                  ),
                                                  const SizedBox(
                                                      width: 4),
                                                  Text(
                                                    '${property.bathrooms} baths',
                                                    style: TextStyle(
                                                      fontSize: 12,
                                                      color: Colors
                                                          .grey[600],
                                                    ),
                                                  ),
                                                ],
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
                            content: Text('No contact phone available')),
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
                            content:
                                Text('No WhatsApp contact available')),
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

  // ── Helper widgets ────────────────────────────────────────────────────────

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

  Widget _buildContactRow({
    required IconData icon,
    required String label,
    required String value,
    required VoidCallback onTap,
  }) {
    final textTheme = Theme.of(context).textTheme;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: AppColors.primary.withOpacity(0.06),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.primary.withOpacity(0.12)),
        ),
        child: Row(
          children: [
            Icon(icon, color: AppColors.primary, size: 22),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: textTheme.bodySmall?.copyWith(
                      color: Colors.grey[600],
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    value,
                    style: textTheme.bodyLarge?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right, color: AppColors.primary),
          ],
        ),
      ),
    );
  }

  // ── Business logic helpers ────────────────────────────────────────────────

  bool _canShowHostelPriceToCustomers(PropertyModel property) {
    return property.type != PropertyType.hostel ||
        property.showPriceToCustomers;
  }

  bool get _shouldShowContactCard {
    if (widget.property.type == PropertyType.hostel) return false;

    return true;
  }

  Future<void> _makePhoneCall(String phoneNumber) async {
    final Uri phoneUri = Uri(scheme: 'tel', path: phoneNumber);
    if (await canLaunchUrl(phoneUri)) {
      await launchUrl(phoneUri);
    } else if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not launch phone call')),
      );
    }
  }

  Future<void> _sendEmail(String email) async {
    final Uri emailUri = Uri(scheme: 'mailto', path: email);
    if (await canLaunchUrl(emailUri)) {
      await launchUrl(emailUri);
    } else if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not open email client')),
      );
    }
  }

  String _normalizeWhatsAppNumber(String phoneNumber) {
    String cleanNumber = phoneNumber.replaceAll(RegExp(r'[^\d]'), '');

    if (cleanNumber.startsWith('0') && cleanNumber.length > 1) {
      return '256${cleanNumber.substring(1)}';
    }

    if (cleanNumber.length == 9) {
      return '256$cleanNumber';
    }

    return cleanNumber;
  }

  Uri _publicSiteBaseUri() {
    final baseUri = Uri.base;
    final isHttpBase = baseUri.scheme == 'http' || baseUri.scheme == 'https';
    final isLocalHost =
        baseUri.host == 'localhost' || baseUri.host == '127.0.0.1';

    if (isHttpBase && baseUri.host.isNotEmpty && !isLocalHost) {
      return Uri(
        scheme: baseUri.scheme,
        host: baseUri.host,
        port: baseUri.hasPort &&
                baseUri.port != 80 &&
                baseUri.port != 443
            ? baseUri.port
            : null,
      );
    }

    return Uri.parse(_publicWebAppBaseUrl);
  }

  String _buildPropertyShareUrl() {
    return _publicSiteBaseUri()
        .replace(pathSegments: ['property', widget.property.id]).toString();
  }

  String _buildPropertyReference() {
    final normalizedId = widget.property.id
        .replaceAll(RegExp(r'[^A-Za-z0-9]'), '')
        .toUpperCase();

    if (normalizedId.isEmpty) {
      return widget.property.id;
    }

    final shortId =
        normalizedId.length > 10 ? normalizedId.substring(0, 10) : normalizedId;
    return 'TH-$shortId';
  }

  String _buildWhatsAppMessage() {
    final propertyUrl = _buildPropertyShareUrl();
    final propertyRef = _buildPropertyReference();
    final priceText = _canShowHostelPriceToCustomers(widget.property) &&
            widget.property.price > 0
        ? '${widget.property.currency} ${CurrencyFormatter.format(widget.property.price)}'
        : 'Price on request';

    final lines = <String>[
      propertyUrl,
      '',
      '📍 Property on True Home',
      'Title: ${widget.property.title}',
      'Location: ${widget.property.location}',
      'Price: $priceText',
      'Ref: $propertyRef',
    ];

    return lines.join('\n');
  }

  Future<void> _openWhatsApp(String phoneNumber) async {
    final cleanNumber = _normalizeWhatsAppNumber(phoneNumber);
    final message = _buildWhatsAppMessage();
    final Uri whatsappUri = Uri.parse(
      'https://wa.me/$cleanNumber?text=${Uri.encodeComponent(message)}',
    );

    if (await canLaunchUrl(whatsappUri)) {
      await launchUrl(whatsappUri, mode: LaunchMode.externalApplication);
    } else if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not open WhatsApp')),
      );
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
    if (roomType.toLowerCase().contains('single')) return Icons.person;
    if (roomType.toLowerCase().contains('double')) return Icons.people;
    if (roomType.toLowerCase().contains('triple')) return Icons.group;
    if (roomType.toLowerCase().contains('shared')) return Icons.groups;
    return Icons.hotel;
  }
}