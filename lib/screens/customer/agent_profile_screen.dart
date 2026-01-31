import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../../models/user_model.dart';
import '../../models/agent_rating_model.dart';
import '../../services/agent_rating_service.dart';
import '../../services/role_service.dart';
import '../../utils/app_theme.dart';
import '../../config/api_config.dart';
import 'rate_agent_screen.dart';

class AgentProfileScreen extends StatefulWidget {
  final UserModel agent;

  const AgentProfileScreen({
    super.key,
    required this.agent,
  });

  @override
  State<AgentProfileScreen> createState() => _AgentProfileScreenState();
}

class _AgentProfileScreenState extends State<AgentProfileScreen> {
  final AgentRatingService _ratingService = AgentRatingService();
  
  bool _isCustomer = false;
  bool _hasRated = false;

  String? _getImageUrl() {
    if (widget.agent.profileImageUrl == null || widget.agent.profileImageUrl!.isEmpty) {
      return null;
    }
    
    // If it's already a full URL, return it
    if (widget.agent.profileImageUrl!.startsWith('http')) {
      return widget.agent.profileImageUrl;
    }
    
    // Otherwise, it might be stored as an ID in Firestore
    // We need to fetch the actual URL from Firestore storage or reconstruct it
    // For now, return null and fetch from Firestore users collection
    return null;
  }

  Future<String?> _fetchActualImageUrl() async {
    try {
      // First check if it's already a URL
      if (widget.agent.profileImageUrl != null && 
          widget.agent.profileImageUrl!.startsWith('http')) {
        return widget.agent.profileImageUrl;
      }
      
      // If profileImageUrl exists but is not a URL, try to fetch from backend
      if (widget.agent.profileImageUrl != null && 
          widget.agent.profileImageUrl!.isNotEmpty) {
        
        // Try to fetch the actual URL from your backend
        final response = await http.get(
          Uri.parse('${ApiConfig.baseUrl}/api/users/${widget.agent.id}/profile-image'),
        );
        
        if (response.statusCode == 200) {
          final data = json.decode(response.body);
          return data['imageUrl'];
        }
      }
      
      return null;
    } catch (e) {
      print('Error fetching profile image URL: $e');
      return null;
    }
  }

  @override
  void initState() {
    super.initState();
    _checkUserRole();
  }

  Future<void> _checkUserRole() async {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser != null) {
      final roleService = RoleService();
      final userModel = await roleService.getCurrentUser();
      final existingRating = await _ratingService.getCustomerRatingForAgent(widget.agent.id);
      
      if (mounted && userModel != null) {
        setState(() {
          _isCustomer = userModel.activeRole == UserRole.customer;
          _hasRated = existingRating != null;
        });
      }
    }
  }

  void _navigateToRating() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => RateAgentScreen(
          agentId: widget.agent.id,
          agentName: widget.agent.name,
        ),
      ),
    );

    if (result == true) {
      // Rating was submitted/updated, refresh the screen
      setState(() {
        _hasRated = true;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Agent Profile'),
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            // Agent Header
            Container(
              width: double.infinity,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    AppColors.primary,
                    AppColors.primary.withOpacity(0.7),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
              padding: const EdgeInsets.all(24),
              child: Column(
                children: [
                  // Profile Photo
                  Container(
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 4),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.2),
                          blurRadius: 10,
                          offset: const Offset(0, 5),
                        ),
                      ],
                    ),
                    child: CircleAvatar(
                      radius: 60,
                      backgroundColor: Colors.white,
                      child: FutureBuilder<String?>(
                        future: _fetchActualImageUrl(),
                        builder: (context, snapshot) {
                          if (snapshot.connectionState == ConnectionState.waiting) {
                            return const CircularProgressIndicator();
                          }
                          
                          if (snapshot.hasData && snapshot.data != null) {
                            return ClipOval(
                              child: Image.network(
                                snapshot.data!,
                                width: 120,
                                height: 120,
                                fit: BoxFit.cover,
                                errorBuilder: (context, error, stackTrace) {
                                  return const Icon(
                                    Icons.person,
                                    size: 60,
                                    color: Colors.grey,
                                  );
                                },
                              ),
                            );
                          }
                          
                          return const Icon(Icons.person, size: 60, color: Colors.grey);
                        },
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  
                  // Agent Name
                  Text(
                    widget.agent.name,
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  
                  // Company Name
                  if (widget.agent.companyName != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Text(
                        widget.agent.companyName!,
                        style: const TextStyle(
                          fontSize: 16,
                          color: Colors.white70,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),

                  const SizedBox(height: 16),

                  // Rating Display
                  if (widget.agent.averageRating != null) ...[
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.star, color: Colors.amber, size: 24),
                          const SizedBox(width: 8),
                          Text(
                            widget.agent.averageRating!.toStringAsFixed(1),
                            style: const TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(width: 4),
                          Text(
                            '(${widget.agent.totalRatings} ${widget.agent.totalRatings == 1 ? 'rating' : 'ratings'})',
                            style: const TextStyle(
                              fontSize: 14,
                              color: Colors.white70,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ] else ...[
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: const Text(
                        'No ratings yet',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.white70,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),

            // Contact Info Section
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Contact Information',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 16),
                  
                  _buildInfoCard(
                    icon: Icons.email_outlined,
                    label: 'Email',
                    value: widget.agent.email,
                  ),
                  
                  _buildInfoCard(
                    icon: Icons.phone_outlined,
                    label: 'Phone',
                    value: widget.agent.phoneNumber,
                  ),

                  if (widget.agent.whatsappNumber != null)
                    _buildInfoCard(
                      icon: Icons.chat_outlined,
                      label: 'WhatsApp',
                      value: widget.agent.whatsappNumber!,
                    ),

                  if (widget.agent.companyAddress != null)
                    _buildInfoCard(
                      icon: Icons.location_on_outlined,
                      label: 'Office Address',
                      value: widget.agent.companyAddress!,
                    ),
                ],
              ),
            ),

            const Divider(height: 1),

            // Rate Button (only for customers)
            if (_isCustomer) ...[
              Padding(
                padding: const EdgeInsets.all(16),
                child: ElevatedButton.icon(
                  onPressed: _navigateToRating,
                  icon: Icon(_hasRated ? Icons.edit : Icons.star),
                  label: Text(_hasRated ? 'Update Your Rating' : 'Rate This Agent'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 24,
                      vertical: 16,
                    ),
                    minimumSize: const Size(double.infinity, 50),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
              const Divider(height: 1),
            ],

            // Reviews Section
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Customer Reviews',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      if (widget.agent.totalReviews > 0)
                        Text(
                          '${widget.agent.totalReviews} ${widget.agent.totalReviews == 1 ? 'review' : 'reviews'}',
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey[600],
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  
                  // Reviews List
                  StreamBuilder<List<AgentRatingModel>>(
                    stream: _ratingService.getAgentRatings(widget.agent.id),
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return const Center(
                          child: Padding(
                            padding: EdgeInsets.all(20),
                            child: CircularProgressIndicator(),
                          ),
                        );
                      }

                      if (snapshot.hasError) {
                        final errorMessage = snapshot.error.toString();
                        if (errorMessage.contains('FAILED_PRECONDITION') || 
                            errorMessage.contains('index')) {
                          return Center(
                            child: Padding(
                              padding: const EdgeInsets.all(20),
                              child: Column(
                                children: [
                                  Icon(
                                    Icons.hourglass_empty,
                                    size: 48,
                                    color: Colors.grey[400],
                                  ),
                                  const SizedBox(height: 16),
                                  const Text(
                                    'Reviews are being set up...',
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    'This will take a few minutes.\nPlease check back shortly.',
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                      fontSize: 14,
                                      color: Colors.grey[600],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        }
                        return Center(
                          child: Padding(
                            padding: const EdgeInsets.all(20),
                            child: Text(
                              'Error loading reviews: ${snapshot.error}',
                              textAlign: TextAlign.center,
                            ),
                          ),
                        );
                      }

                      final ratings = snapshot.data ?? [];

                      if (ratings.isEmpty) {
                        return Center(
                          child: Padding(
                            padding: const EdgeInsets.all(40),
                            child: Column(
                              children: [
                                Icon(
                                  Icons.rate_review_outlined,
                                  size: 64,
                                  color: Colors.grey[400],
                                ),
                                const SizedBox(height: 16),
                                Text(
                                  'No reviews yet',
                                  style: TextStyle(
                                    fontSize: 16,
                                    color: Colors.grey[600],
                                  ),
                                ),
                                if (_isCustomer && !_hasRated) ...[
                                  const SizedBox(height: 8),
                                  Text(
                                    'Be the first to review this agent!',
                                    style: TextStyle(
                                      fontSize: 14,
                                      color: Colors.grey[500],
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                        );
                      }

                      return Column(
                        children: ratings.map((rating) => _buildReviewCard(rating)).toList(),
                      );
                    },
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoCard({
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        leading: Icon(icon, color: AppColors.primary),
        title: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: Colors.grey[600],
          ),
        ),
        subtitle: Text(
          value,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
    );
  }

  Widget _buildReviewCard(AgentRatingModel rating) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  backgroundColor: AppColors.primary,
                  child: Text(
                    rating.customerName[0].toUpperCase(),
                    style: const TextStyle(color: Colors.white),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        rating.customerName,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      Text(
                        _formatDate(rating.createdAt),
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                ),
                Row(
                  children: List.generate(5, (index) {
                    return Icon(
                      index < rating.rating ? Icons.star : Icons.star_border,
                      color: Colors.amber,
                      size: 20,
                    );
                  }),
                ),
              ],
            ),
            if (rating.reviewText != null && rating.reviewText!.isNotEmpty) ...[
              const SizedBox(height: 12),
              Text(
                rating.reviewText!,
                style: const TextStyle(fontSize: 15),
              ),
            ],
          ],
        ),
      ),
    );
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date);

    if (difference.inDays == 0) {
      if (difference.inHours == 0) {
        return '${difference.inMinutes} minutes ago';
      }
      return '${difference.inHours} hours ago';
    } else if (difference.inDays == 1) {
      return 'Yesterday';
    } else if (difference.inDays < 7) {
      return '${difference.inDays} days ago';
    } else if (difference.inDays < 30) {
      return '${(difference.inDays / 7).floor()} weeks ago';
    } else if (difference.inDays < 365) {
      return '${(difference.inDays / 30).floor()} months ago';
    } else {
      return '${(difference.inDays / 365).floor()} years ago';
    }
  }
}
