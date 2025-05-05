import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import '../models/review_model.dart';
import '../models/response_model.dart';
import '../constants/app_colors.dart';

class OrganizerReviewsScreen extends StatefulWidget {
  const OrganizerReviewsScreen({super.key});

  @override
  State<OrganizerReviewsScreen> createState() => _OrganizerReviewsScreenState();
}

class _OrganizerReviewsScreenState extends State<OrganizerReviewsScreen> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  bool _isLoading = true;
  List<ReviewModel> _reviews = [];
  Map<String, ResponseModel> _responseMap = {};

  @override
  void initState() {
    super.initState();
    _loadReviews();
  }

  Future<void> _loadReviews() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final user = _auth.currentUser;
      if (user == null) {
        print('User not logged in');
        setState(() {
          _isLoading = false;
        });
        return;
      }

      // Fetch reviews for this organizer
      final reviewsSnapshot =
          await _firestore
              .collection('reviews')
              .where('organizerId', isEqualTo: user.uid)
              .orderBy('createdAt', descending: true)
              .get();

      final reviews =
          reviewsSnapshot.docs
              .map((doc) => ReviewModel.fromMap(doc.data()))
              .toList();

      // Get all associated responses
      Map<String, ResponseModel> responseMap = {};
      for (var review in reviews) {
        try {
          final responseDoc =
              await _firestore
                  .collection('responses')
                  .doc(review.responseId)
                  .get();
          if (responseDoc.exists) {
            responseMap[review.responseId] = ResponseModel.fromMap(
              responseDoc.data()!,
            );
          }
        } catch (e) {
          print('Error loading response for review ${review.id}: $e');
        }
      }

      setState(() {
        _reviews = reviews;
        _responseMap = responseMap;
        _isLoading = false;
      });

      print('Loaded ${reviews.length} reviews for organizer');
    } catch (e) {
      print('Error loading reviews: $e');
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    // Set status bar color to match background
    SystemChrome.setSystemUIOverlayStyle(
      const SystemUiOverlayStyle(
        statusBarColor: Color(0xFFFFFDE5),
        statusBarIconBrightness: Brightness.dark,
      ),
    );

    return SafeArea(
      child: Scaffold(
        backgroundColor: AppColors.creamBackground,
        appBar: null, // Remove the standard AppBar
        body:
            _isLoading
                ? const Center(child: CircularProgressIndicator())
                : Column(
                  children: [
                    // Custom app bar that matches other screens
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                      decoration: const BoxDecoration(
                        color: Color(0xFF9D9DCC),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black12,
                            offset: Offset(0, 2),
                            blurRadius: 4,
                          ),
                        ],
                      ),
                      child: Row(
                        children: [
                          IconButton(
                            icon: const Icon(
                              Icons.arrow_back,
                              color: Colors.white,
                            ),
                            onPressed: () => Navigator.pop(context),
                          ),
                          const Text(
                            'My Reviews',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const Spacer(),
                          IconButton(
                            icon: const Icon(
                              Icons.refresh,
                              color: Colors.white,
                            ),
                            onPressed: _loadReviews,
                            tooltip: 'Refresh',
                          ),
                        ],
                      ),
                    ),

                    Expanded(
                      child:
                          _reviews.isEmpty
                              ? Center(
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    const Icon(
                                      Icons.star_border,
                                      size: 64,
                                      color: Colors.grey,
                                    ),
                                    const SizedBox(height: 16),
                                    const Text(
                                      'No reviews yet',
                                      style: TextStyle(
                                        fontSize: 18,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    const Text(
                                      'Reviews from clients will appear here',
                                      style: TextStyle(
                                        fontSize: 14,
                                        color: Colors.grey,
                                      ),
                                    ),
                                  ],
                                ),
                              )
                              : ListView.builder(
                                padding: const EdgeInsets.all(16),
                                itemCount: _reviews.length,
                                itemBuilder: (context, index) {
                                  final review = _reviews[index];
                                  final order = _responseMap[review.responseId];
                                  return _buildRatedOrderCard(
                                    context,
                                    order,
                                    review,
                                  );
                                },
                              ),
                    ),
                  ],
                ),
      ),
    );
  }

  Widget _buildRatedOrderCard(
    BuildContext context,
    ResponseModel? order,
    ReviewModel review,
  ) {
    return Card(
      color: Colors.white,
      margin: const EdgeInsets.only(bottom: 16),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Image placeholder at top, full width
          ClipRRect(
            borderRadius: BorderRadius.only(
              topLeft: Radius.circular(12),
              topRight: Radius.circular(12),
            ),
            child: Container(
              width: double.infinity,
              height: 150,
              color: Colors.grey[200],
              child: Center(
                child: Icon(Icons.image, color: Colors.grey[400], size: 50),
              ),
            ),
          ),
          // Order details
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: FutureBuilder<DocumentSnapshot>(
                        future:
                            FirebaseFirestore.instance
                                .collection('portfolios')
                                .doc(review.portfolioId)
                                .get(),
                        builder: (context, snapshot) {
                          if (snapshot.connectionState ==
                              ConnectionState.waiting) {
                            return const Text("Loading...");
                          }

                          if (snapshot.hasError ||
                              !snapshot.hasData ||
                              !snapshot.data!.exists) {
                            return Text(
                              order?.eventName ?? "Unknown Event",
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: Colors.black,
                              ),
                              overflow: TextOverflow.ellipsis,
                              maxLines: 1,
                            );
                          }

                          final data =
                              snapshot.data!.data() as Map<String, dynamic>;
                          return Text(
                            data['title'] ??
                                order?.eventName ??
                                "Unknown Event",
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Colors.black,
                            ),
                            overflow: TextOverflow.ellipsis,
                            maxLines: 1,
                          );
                        },
                      ),
                    ),
                    InkWell(
                      onTap: () => _showReportDialog(context, review),
                      borderRadius: BorderRadius.circular(12),
                      child: Column(
                        children: [
                          Padding(
                            padding: const EdgeInsets.all(4.0),
                            child: Icon(
                              Icons.flag_outlined,
                              size: 20,
                              color: Colors.grey[600],
                            ),
                          ),
                          Text(
                            'Report',
                            style: TextStyle(
                              color: Colors.red,
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                _buildDetailRow('Client:', review.clientName),
                const SizedBox(height: 8),
                // Rating information with simplified styling
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Text(
                          'Rating: ',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            color: Colors.black87,
                          ),
                        ),
                        const SizedBox(width: 4),
                        ...List.generate(5, (index) {
                          return Icon(
                            index < review.rating
                                ? Icons.star
                                : Icons.star_border,
                            color: Colors.amber,
                            size: 16,
                          );
                        }),
                      ],
                    ),
                    if (review.comment.isNotEmpty) ...[
                      const SizedBox(height: 12),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            width: 3,
                            height: 16,
                            margin: const EdgeInsets.only(top: 2),
                            decoration: BoxDecoration(
                              color: Colors.black87,
                              borderRadius: BorderRadius.circular(1.5),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Flexible(
                            child: Text(
                              review.comment,
                              style: const TextStyle(
                                fontSize: 13,
                                color: Colors.black54,
                              ),
                              overflow: TextOverflow.ellipsis,
                              maxLines: 2,
                            ),
                          ),
                        ],
                      ),
                    ],
                    const SizedBox(height: 4),
                    Text(
                      'Reviewed on: ${DateFormat('MMM dd, yyyy').format(review.createdAt)}',
                      style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Row(
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 13,
            color: Colors.black,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(width: 8),
        Flexible(
          child: Text(
            value,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.normal,
              color: Colors.black54,
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }

  void _showReportDialog(BuildContext context, ReviewModel review) {
    final reasonController = TextEditingController();

    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            backgroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            title: const Text(
              'Report Review',
              style: TextStyle(
                color: Colors.black87,
                fontWeight: FontWeight.bold,
                fontSize: 20,
              ),
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Why are you reporting this review?',
                  style: TextStyle(color: Colors.black54, fontSize: 16),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: reasonController,
                  decoration: InputDecoration(
                    hintText: 'Describe the issue with this review',
                    hintStyle: TextStyle(color: Colors.grey[600], fontSize: 16),
                    filled: true,
                    fillColor: Colors.grey.withOpacity(0.1),
                    contentPadding: const EdgeInsets.symmetric(
                      vertical: 10.0,
                      horizontal: 12.0,
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(
                        color: Color(0xFF9D9DCC),
                        width: 1,
                      ),
                    ),
                  ),
                  maxLines: 3,
                  style: const TextStyle(color: Colors.black87, fontSize: 16),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text(
                  'Cancel',
                  style: TextStyle(
                    color: Colors.black54,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              ElevatedButton(
                onPressed: () async {
                  if (reasonController.text.trim().isEmpty) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Please provide a reason for the report'),
                        backgroundColor: Colors.red,
                      ),
                    );
                    return;
                  }

                  try {
                    // Submit the report to Firestore
                    await FirebaseFirestore.instance
                        .collection('review_reports')
                        .add({
                          'reviewId': review.id,
                          'reportedBy': _auth.currentUser?.uid,
                          'reportReason': reasonController.text.trim(),
                          'portfolioId': review.portfolioId,
                          'clientId': review.clientId,
                          'createdAt': FieldValue.serverTimestamp(),
                          'status': 'pending', // For admin to review
                        });

                    Navigator.pop(context);

                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Report submitted successfully'),
                        backgroundColor: Colors.green,
                      ),
                    );
                  } catch (e) {
                    print('Error submitting report: $e');
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Error submitting report'),
                        backgroundColor: Colors.red,
                      ),
                    );
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF9D9DCC),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text(
                  'Submit',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
    );
  }
}
