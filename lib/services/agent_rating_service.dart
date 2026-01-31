import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/agent_rating_model.dart';


class AgentRatingService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // Submit or update a rating for an agent
  Future<void> rateAgent({
    required String agentId,
    required double rating,
    String? reviewText,
  }) async {
    try {
      final currentUser = _auth.currentUser;
      if (currentUser == null) {
        throw Exception('You must be logged in to rate an agent');
      }

      // Get customer info
      final customerDoc = await _firestore.collection('users').doc(currentUser.uid).get();
      final customerName = customerDoc.data()?['name'] ?? 'Anonymous';

      // Check if customer already rated this agent
      final existingRating = await _firestore
          .collection('agent_ratings')
          .where('agentId', isEqualTo: agentId)
          .where('customerId', isEqualTo: currentUser.uid)
          .limit(1)
          .get();

      final now = DateTime.now();
      final ratingData = {
        'agentId': agentId,
        'customerId': currentUser.uid,
        'customerName': customerName,
        'rating': rating,
        'reviewText': reviewText,
        'updatedAt': now.toIso8601String(),
      };

      if (existingRating.docs.isNotEmpty) {
        // Update existing rating
        await _firestore
            .collection('agent_ratings')
            .doc(existingRating.docs.first.id)
            .update(ratingData);
      } else {
        // Create new rating
        ratingData['id'] = '';
        ratingData['createdAt'] = now.toIso8601String();
        
        final docRef = await _firestore.collection('agent_ratings').add(ratingData);
        await docRef.update({'id': docRef.id});
      }

      // Recalculate agent's average rating
      await _updateAgentRatingStats(agentId);
    } catch (e) {
      throw Exception('Failed to submit rating: $e');
    }
  }

  // Get all ratings for a specific agent
  Stream<List<AgentRatingModel>> getAgentRatings(String agentId) {
    return _firestore
        .collection('agent_ratings')
        .where('agentId', isEqualTo: agentId)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => AgentRatingModel.fromJson(doc.data(), doc.id))
            .toList());
  }

  // Get customer's rating for a specific agent (to check if already rated)
  Future<AgentRatingModel?> getCustomerRatingForAgent(String agentId) async {
    try {
      final currentUser = _auth.currentUser;
      if (currentUser == null) return null;

      final snapshot = await _firestore
          .collection('agent_ratings')
          .where('agentId', isEqualTo: agentId)
          .where('customerId', isEqualTo: currentUser.uid)
          .limit(1)
          .get();

      if (snapshot.docs.isEmpty) return null;

      return AgentRatingModel.fromJson(
        snapshot.docs.first.data(),
        snapshot.docs.first.id,
      );
    } catch (e) {
      print('Error getting customer rating: $e');
      return null;
    }
  }

  // Update agent's rating statistics
  Future<void> _updateAgentRatingStats(String agentId) async {
    try {
      final ratingsSnapshot = await _firestore
          .collection('agent_ratings')
          .where('agentId', isEqualTo: agentId)
          .get();

      if (ratingsSnapshot.docs.isEmpty) {
        // No ratings yet
        await _firestore.collection('users').doc(agentId).update({
          'averageRating': null,
          'totalRatings': 0,
          'totalReviews': 0,
        });
        return;
      }

      double totalRating = 0;
      int reviewCount = 0;

      for (var doc in ratingsSnapshot.docs) {
        final data = doc.data();
        totalRating += (data['rating'] ?? 0).toDouble();
        if (data['reviewText'] != null && data['reviewText'].toString().isNotEmpty) {
          reviewCount++;
        }
      }

      final averageRating = totalRating / ratingsSnapshot.docs.length;

      await _firestore.collection('users').doc(agentId).update({
        'averageRating': averageRating,
        'totalRatings': ratingsSnapshot.docs.length,
        'totalReviews': reviewCount,
      });
    } catch (e) {
      print('Error updating agent rating stats: $e');
    }
  }

  // Delete a rating (only the customer who created it)
  Future<void> deleteRating(String ratingId) async {
    try {
      final currentUser = _auth.currentUser;
      if (currentUser == null) {
        throw Exception('You must be logged in to delete a rating');
      }

      final ratingDoc = await _firestore.collection('agent_ratings').doc(ratingId).get();
      
      if (!ratingDoc.exists) {
        throw Exception('Rating not found');
      }

      final ratingData = ratingDoc.data();
      if (ratingData?['customerId'] != currentUser.uid) {
        throw Exception('You can only delete your own ratings');
      }

      final agentId = ratingData?['agentId'];
      
      await _firestore.collection('agent_ratings').doc(ratingId).delete();

      // Recalculate agent's rating stats
      if (agentId != null) {
        await _updateAgentRatingStats(agentId);
      }
    } catch (e) {
      throw Exception('Failed to delete rating: $e');
    }
  }

  // Get agent rating statistics
  Future<Map<String, dynamic>> getAgentRatingStats(String agentId) async {
    try {
      final ratingsSnapshot = await _firestore
          .collection('agent_ratings')
          .where('agentId', isEqualTo: agentId)
          .get();

      if (ratingsSnapshot.docs.isEmpty) {
        return {
          'averageRating': 0.0,
          'totalRatings': 0,
          'totalReviews': 0,
          'ratingDistribution': {5: 0, 4: 0, 3: 0, 2: 0, 1: 0},
        };
      }

      double totalRating = 0;
      int reviewCount = 0;
      Map<int, int> distribution = {5: 0, 4: 0, 3: 0, 2: 0, 1: 0};

      for (var doc in ratingsSnapshot.docs) {
        final data = doc.data();
        final rating = (data['rating'] ?? 0).toDouble();
        totalRating += rating;
        
        if (data['reviewText'] != null && data['reviewText'].toString().isNotEmpty) {
          reviewCount++;
        }

        // Count rating distribution
        final ratingInt = rating.round();
        if (ratingInt >= 1 && ratingInt <= 5) {
          distribution[ratingInt] = (distribution[ratingInt] ?? 0) + 1;
        }
      }

      return {
        'averageRating': totalRating / ratingsSnapshot.docs.length,
        'totalRatings': ratingsSnapshot.docs.length,
        'totalReviews': reviewCount,
        'ratingDistribution': distribution,
      };
    } catch (e) {
      print('Error getting agent rating stats: $e');
      return {
        'averageRating': 0.0,
        'totalRatings': 0,
        'totalReviews': 0,
        'ratingDistribution': {5: 0, 4: 0, 3: 0, 2: 0, 1: 0},
      };
    }
  }
}
