import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import '../models/response_model.dart';
import '../models/review_model.dart';
import '../constants/app_colors.dart';

class FeedbackScreen extends StatefulWidget {
  final bool isInBottomNavBar;

  const FeedbackScreen({super.key, this.isInBottomNavBar = true});

  @override
  State<FeedbackScreen> createState() => _FeedbackScreenState();
}

class _FeedbackScreenState extends State<FeedbackScreen> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  bool _isLoading = true;
  List<ResponseModel> _completedOrders = [];
  List<ReviewModel> _myReviews = [];

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
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

      // Fetch completed orders
      final completedOrdersSnapshot =
          await _firestore
              .collection('responses')
              .where('clientId', isEqualTo: user.uid)
              .where('status', isEqualTo: 'completed')
              .get();

      final completedOrders =
          completedOrdersSnapshot.docs
              .map((doc) => ResponseModel.fromMap(doc.data()))
              .toList();

      // Fetch reviews submitted by this client
      final reviewsSnapshot =
          await _firestore
              .collection('reviews')
              .where('clientId', isEqualTo: user.uid)
              .get();

      final reviews =
          reviewsSnapshot.docs
              .map((doc) => ReviewModel.fromMap(doc.data()))
              .toList();

      setState(() {
        _completedOrders = completedOrders;
        _myReviews = reviews;
        _isLoading = false;
      });
    } catch (e) {
      print('Error loading feedback data: $e');
      setState(() {
        _isLoading = false;
      });
    }
  }

  // Determine if an order has been reviewed
  bool _isOrderReviewed(String responseId) {
    return _myReviews.any((review) => review.responseId == responseId);
  }

  // Get orders that need feedback
  List<ResponseModel> get _pendingFeedbackOrders {
    return _completedOrders
        .where((order) => !_isOrderReviewed(order.id))
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    final Widget content = DefaultTabController(
      length: 2,
      child: Column(
        children: [
          // Custom AppBar
          if (!widget.isInBottomNavBar)
            Container(
              color: const Color(0xFF9D9DCC),
              padding: const EdgeInsets.symmetric(
                horizontal: 4.0,
                vertical: 8.0,
              ),
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.arrow_back, color: Colors.white),
                    onPressed: () => Navigator.pop(context),
                  ),
                  const Text(
                    'Feedback',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 20,
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.refresh, color: Colors.white),
                    onPressed: _loadData,
                  ),
                ],
              ),
            ),
          // Tab Bar
          Container(
            color: Colors.white,
            child: TabBar(
              tabs: const [
                Tab(text: 'Pending Feedback'),
                Tab(text: 'My Ratings'),
              ],
              labelColor: Colors.black,
              unselectedLabelColor: Colors.grey,
              indicatorColor: const Color(0xFF9D9DCC),
            ),
          ),
          // Tab Bar View with real data
          Expanded(
            child:
                _isLoading
                    ? const Center(child: CircularProgressIndicator())
                    : TabBarView(
                      children: [
                        // Pending Feedback Tab
                        _pendingFeedbackOrders.isEmpty
                            ? Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: const [
                                  Icon(
                                    Icons.feedback_outlined,
                                    size: 64,
                                    color: Colors.grey,
                                  ),
                                  SizedBox(height: 16),
                                  Text(
                                    'No pending feedback',
                                    style: TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                            )
                            : ListView.builder(
                              padding: const EdgeInsets.all(16),
                              itemCount: _pendingFeedbackOrders.length,
                              itemBuilder: (context, index) {
                                final order = _pendingFeedbackOrders[index];
                                return _buildOrderCard(context, order, true);
                              },
                            ),
                        // My Ratings Tab
                        _myReviews.isEmpty
                            ? Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: const [
                                  Icon(
                                    Icons.star_border,
                                    size: 64,
                                    color: Colors.grey,
                                  ),
                                  SizedBox(height: 16),
                                  Text(
                                    'No ratings submitted yet',
                                    style: TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                            )
                            : ListView.builder(
                              padding: const EdgeInsets.all(16),
                              itemCount: _myReviews.length,
                              itemBuilder: (context, index) {
                                final review = _myReviews[index];
                                // Find the order associated with this review
                                final order = _completedOrders.firstWhere(
                                  (o) => o.id == review.responseId,
                                  orElse:
                                      () => ResponseModel(
                                        id: review.responseId,
                                        portfolioId: review.portfolioId,
                                        organizerId: review.organizerId,
                                        clientId: review.clientId,
                                        clientName: review.clientName,
                                        eventName: "Unknown Event",
                                        eventType: "Unknown",
                                        eventDate: DateTime.now(),
                                        budget: 0,
                                        primaryColor: "",
                                        secondaryColor: "",
                                        needsPhotographer: false,
                                        additionalNotes: "",
                                        status: "completed",
                                        createdAt: review.createdAt,
                                      ),
                                );
                                return _buildRatedOrderCard(
                                  context,
                                  order,
                                  review,
                                );
                              },
                            ),
                      ],
                    ),
          ),
        ],
      ),
    );

    if (widget.isInBottomNavBar) {
      return content;
    } else {
      return Scaffold(
        backgroundColor: AppColors.creamBackground,
        body: SafeArea(child: content),
      );
    }
  }

  Widget _buildOrderCard(
    BuildContext context,
    ResponseModel order,
    bool canRate,
  ) {
    return Card(
      color: Colors.white,
      margin: const EdgeInsets.only(bottom: 16),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Image placeholder with padding
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: Colors.grey[200],
                borderRadius: BorderRadius.circular(12),
              ),
              child: Center(
                child: Icon(Icons.image, color: Colors.grey[400], size: 30),
              ),
            ),
          ),
          // Order details
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  FutureBuilder<DocumentSnapshot>(
                    future:
                        FirebaseFirestore.instance
                            .collection('portfolios')
                            .doc(order.portfolioId)
                            .get(),
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return const Text("Loading...");
                      }

                      if (snapshot.hasError ||
                          !snapshot.hasData ||
                          !snapshot.data!.exists) {
                        return Text(
                          order.eventName,
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
                        data['title'] ?? order.eventName,
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
                  const SizedBox(height: 12),
                  _buildDetailRow('Event Type:', order.eventType),
                  const SizedBox(height: 8),
                  _buildDetailRow(
                    'Event Date:',
                    DateFormat('MMM dd, yyyy').format(order.eventDate),
                  ),
                  const SizedBox(height: 8),
                  _buildDetailRow(
                    'Amount:',
                    'PKR ${NumberFormat('#,###').format(order.budget)}',
                  ),
                  // Rate button
                  if (canRate)
                    Align(
                      alignment: Alignment.centerRight,
                      child: Padding(
                        padding: const EdgeInsets.only(top: 8.0),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              'Rate',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: Colors.black87,
                              ),
                            ),
                            const SizedBox(width: 4),
                            Material(
                              color: Colors.transparent,
                              child: InkWell(
                                onTap: () => _showRatingDialog(context, order),
                                borderRadius: BorderRadius.circular(20),
                                child: Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF9D9DCC),
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
                                    Icons.thumb_up,
                                    color: Colors.white,
                                    size: 14,
                                  ),
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
          ),
        ],
      ),
    );
  }

  Widget _buildRatedOrderCard(
    BuildContext context,
    ResponseModel order,
    ReviewModel review,
  ) {
    return Card(
      color: Colors.white,
      margin: const EdgeInsets.only(bottom: 16),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Image placeholder with padding
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: Colors.grey[200],
                borderRadius: BorderRadius.circular(12),
              ),
              child: Center(
                child: Icon(Icons.image, color: Colors.grey[400], size: 30),
              ),
            ),
          ),
          // Order details
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  FutureBuilder<DocumentSnapshot>(
                    future:
                        FirebaseFirestore.instance
                            .collection('portfolios')
                            .doc(order.portfolioId)
                            .get(),
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return const Text("Loading...");
                      }

                      if (snapshot.hasError ||
                          !snapshot.hasData ||
                          !snapshot.data!.exists) {
                        return Text(
                          order.eventName,
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
                        data['title'] ?? order.eventName,
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
                  const SizedBox(height: 12),
                  _buildDetailRow('Event Type:', order.eventType),
                  const SizedBox(height: 8),
                  _buildDetailRow(
                    'Event Date:',
                    DateFormat('MMM dd, yyyy').format(order.eventDate),
                  ),
                  const SizedBox(height: 8),
                  // Rating information with simplified styling (no container)
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Text(
                            'Your Rating: ',
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
                    ],
                  ),
                ],
              ),
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

  void _showRatingDialog(BuildContext context, ResponseModel order) {
    double selectedRating = 0;
    final feedbackController = TextEditingController();

    showDialog(
      context: context,
      builder:
          (context) => StatefulBuilder(
            builder: (context, setState) {
              return AlertDialog(
                backgroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                title: const Text(
                  'Rate Your Experience',
                  style: TextStyle(
                    color: Colors.black87,
                    fontWeight: FontWeight.bold,
                    fontSize: 20,
                  ),
                ),
                content: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text(
                      'How was your experience?',
                      style: TextStyle(color: Colors.black54, fontSize: 16),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: List.generate(5, (index) {
                        return IconButton(
                          icon: Icon(
                            index < selectedRating
                                ? Icons.star
                                : Icons.star_border,
                            color: Colors.amber,
                            size: 36,
                          ),
                          onPressed: () {
                            setState(() {
                              selectedRating = index + 1;
                            });
                          },
                        );
                      }),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: feedbackController,
                      decoration: InputDecoration(
                        hintText: 'Add your feedback (optional)',
                        hintStyle: TextStyle(
                          color: Colors.grey[600],
                          fontSize: 16,
                        ),
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
                      style: const TextStyle(
                        color: Colors.black87,
                        fontSize: 16,
                      ),
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
                    onPressed:
                        selectedRating > 0
                            ? () async {
                              // Submit the review to Firestore
                              try {
                                final user = _auth.currentUser;
                                if (user == null) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text('User not logged in'),
                                      backgroundColor: Colors.red,
                                    ),
                                  );
                                  Navigator.pop(context);
                                  return;
                                }

                                final reviewId =
                                    FirebaseFirestore.instance
                                        .collection('reviews')
                                        .doc()
                                        .id;
                                final review = ReviewModel(
                                  id: reviewId,
                                  responseId: order.id,
                                  portfolioId: order.portfolioId,
                                  organizerId: order.organizerId,
                                  clientId: user.uid,
                                  clientName: order.clientName,
                                  rating: selectedRating,
                                  comment: feedbackController.text,
                                  createdAt: DateTime.now(),
                                );

                                await FirebaseFirestore.instance
                                    .collection('reviews')
                                    .doc(reviewId)
                                    .set(review.toMap());

                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text(
                                      'Review submitted successfully!',
                                    ),
                                    backgroundColor: Colors.green,
                                  ),
                                );

                                // Refresh data
                                _loadData();
                                Navigator.pop(context);
                              } catch (e) {
                                print('Error submitting review: $e');
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text('Error submitting review'),
                                    backgroundColor: Colors.red,
                                  ),
                                );
                              }
                            }
                            : null,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF9D9DCC),
                      disabledBackgroundColor: const Color(
                        0xFF9D9DCC,
                      ).withOpacity(0.3),
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
              );
            },
          ),
    );
  }
}
