import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'dart:async';
import '../../models/response_model.dart';
import '../../services/portfolio_service.dart';
import '../feedback_screen.dart';
import '../../constants/app_colors.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../widgets/firestore_image.dart' as fw;

class PortfolioResponsesScreen extends StatefulWidget {
  final String organizerId;

  const PortfolioResponsesScreen({Key? key, required this.organizerId})
    : super(key: key);

  @override
  _PortfolioResponsesScreenState createState() =>
      _PortfolioResponsesScreenState();
}

class _PortfolioResponsesScreenState extends State<PortfolioResponsesScreen> {
  final _portfolioService = PortfolioService();
  String _selectedStatus = 'All';
  final Map<String, Timer> _eventTimers = {};
  Map<String, List<ResponseModel>> _responsesByStatus = {};

  // Cache for ratings and event counts
  final Map<String, double> _portfolioRatings = {};
  final Map<String, int> _portfolioEventCounts = {};

  bool _isLoading = true;
  bool _hasError = false;
  String _errorMessage = '';

  @override
  void initState() {
    super.initState();
    _loadResponses();

    // Add a delayed refresh to ensure images are loaded
    WidgetsBinding.instance.addPostFrameCallback((_) {
      // Force a rebuild shortly after mounting
      if (mounted) {
        Future.delayed(const Duration(milliseconds: 500), () {
          if (mounted) {
            setState(() {
              // This empty setState will force a rebuild
            });
          }
        });
      }
    });
  }

  @override
  void dispose() {
    _eventTimers.values.forEach((timer) => timer.cancel());
    super.dispose();
  }

  Future<void> _loadResponses() async {
    setState(() {
      _isLoading = true;
      _hasError = false;
      // Clear the ratings cache to ensure we get fresh data
      _portfolioRatings.clear();
      _portfolioEventCounts.clear();
    });

    try {
      final responses = await _portfolioService.getResponsesForOrganizerAsList(
        widget.organizerId,
      );

      // Group responses by status
      final Map<String, List<ResponseModel>> grouped = {};
      for (var response in responses) {
        final status = response.status.toLowerCase();
        if (!grouped.containsKey(status)) {
          grouped[status] = [];
        }
        grouped[status]!.add(response);
      }

      // Sort each group by date (most recent first)
      for (var status in grouped.keys) {
        grouped[status]!.sort((a, b) => b.eventDate.compareTo(a.eventDate));
      }

      // Preload ratings for all portfolio IDs
      final portfolioIds =
          responses
              .map((r) => r.portfolioId)
              .toSet() // Get unique portfolio IDs
              .toList();

      final futures = <Future>[];
      for (var id in portfolioIds) {
        futures.add(_getPortfolioRating(id));
        futures.add(_getPortfolioEventCount(id));
      }

      await Future.wait(futures);

      setState(() {
        _responsesByStatus = grouped;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
        _hasError = true;
        _errorMessage = e.toString();
      });
      print('Error loading responses: $e');
    }
  }

  // Get portfolio rating, with caching
  Future<double> _getPortfolioRating(String portfolioId) async {
    if (_portfolioRatings.containsKey(portfolioId)) {
      return _portfolioRatings[portfolioId]!;
    }

    try {
      final snapshot =
          await FirebaseFirestore.instance
              .collection('reviews')
              .where('portfolioId', isEqualTo: portfolioId)
              .get();

      final reviews = snapshot.docs;
      double averageRating = 0;

      if (reviews.isNotEmpty) {
        double totalRating = 0;
        for (var doc in reviews) {
          final data = doc.data() as Map<String, dynamic>;
          totalRating += (data['rating'] as num).toDouble();
        }
        averageRating = totalRating / reviews.length;
      }

      _portfolioRatings[portfolioId] = averageRating;
      return averageRating;
    } catch (e) {
      print('Error getting portfolio rating: $e');
      return 0.0;
    }
  }

  // Get portfolio event count, with caching
  Future<int> _getPortfolioEventCount(String portfolioId) async {
    if (_portfolioEventCounts.containsKey(portfolioId)) {
      return _portfolioEventCounts[portfolioId]!;
    }

    try {
      final snapshot =
          await FirebaseFirestore.instance
              .collection('responses')
              .where('portfolioId', isEqualTo: portfolioId)
              .where('status', isEqualTo: 'completed')
              .get();

      final eventCount = snapshot.docs.length;
      _portfolioEventCounts[portfolioId] = eventCount;
      return eventCount;
    } catch (e) {
      print('Error getting portfolio event count: $e');
      return 0;
    }
  }

  void _startEventTimer(ResponseModel response) {
    if (_eventTimers.containsKey(response.id)) {
      _eventTimers[response.id]?.cancel();
    }

    final now = DateTime.now();
    final eventDate = response.eventDate;
    final duration = eventDate.difference(now);

    if (duration.isNegative) {
      return;
    }

    final timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      setState(() {
        final remaining = eventDate.difference(DateTime.now());
        if (remaining.isNegative) {
          timer.cancel();
          _eventTimers.remove(response.id);
        }
      });
    });

    _eventTimers[response.id] = timer;
  }

  String _getTimeRemaining(DateTime eventDate) {
    final now = DateTime.now();
    final difference = eventDate.difference(now);

    if (difference.isNegative) {
      return 'Event has passed';
    }

    final days = difference.inDays;
    final hours = difference.inHours % 24;
    final minutes = difference.inMinutes % 60;
    final seconds = difference.inSeconds % 60;

    return '$days days, $hours hours, $minutes minutes, $seconds seconds';
  }

  Future<void> _updateResponseStatus(
    ResponseModel response,
    String status,
  ) async {
    try {
      await _portfolioService.updateResponseStatus(response.id, status);
      if (status == 'accepted') {
        _startEventTimer(response);
      }

      // Update local data without fetching from Firestore again
      setState(() {
        // Remove from old status list
        final oldStatus = response.status.toLowerCase();
        _responsesByStatus[oldStatus]?.removeWhere((r) => r.id == response.id);

        // Create a new response with updated status
        final updatedResponse = ResponseModel(
          id: response.id,
          portfolioId: response.portfolioId,
          organizerId: response.organizerId,
          clientId: response.clientId,
          clientName: response.clientName,
          eventName: response.eventName,
          eventType: response.eventType,
          eventDate: response.eventDate,
          budget: response.budget,
          primaryColor: response.primaryColor,
          secondaryColor: response.secondaryColor,
          needsPhotographer: response.needsPhotographer,
          additionalNotes: response.additionalNotes,
          status: status,
          createdAt: response.createdAt,
        );

        // Add to new status list
        final newStatus = status.toLowerCase();
        if (!_responsesByStatus.containsKey(newStatus)) {
          _responsesByStatus[newStatus] = [];
        }
        _responsesByStatus[newStatus]!.add(updatedResponse);
      });

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Response $status successfully')));
    } catch (e) {
      print('Error updating response status: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Error updating response status')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: AppColors.primaryPurple,
                boxShadow: const [
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
                    icon: const Icon(Icons.arrow_back, color: Colors.white),
                    onPressed: () => Navigator.pop(context),
                  ),
                  const Text(
                    'Portfolio Responses',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.refresh, color: Colors.white),
                    onPressed: _loadResponses,
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: DropdownButtonFormField<String>(
                value: _selectedStatus,
                decoration: InputDecoration(
                  labelText: 'Filter by Status',
                  labelStyle: const TextStyle(color: AppColors.primaryPurple),
                  border: OutlineInputBorder(),
                  enabledBorder: OutlineInputBorder(
                    borderSide: BorderSide(color: Colors.grey.shade300),
                  ),
                  focusedBorder: const OutlineInputBorder(
                    borderSide: BorderSide(color: AppColors.primaryPurple),
                  ),
                ),
                items:
                    ['All', 'Pending', 'Accepted', 'Rejected'].map((status) {
                      return DropdownMenuItem(
                        value: status,
                        child: Text(status),
                      );
                    }).toList(),
                onChanged: (value) {
                  setState(() {
                    _selectedStatus = value!;
                  });
                },
                icon: const Icon(
                  Icons.arrow_drop_down,
                  color: AppColors.primaryPurple,
                ),
                style: const TextStyle(color: Color(0xFF6B6B8D), fontSize: 16),
              ),
            ),
            Expanded(
              child:
                  _isLoading
                      ? const Center(
                        child: CircularProgressIndicator(
                          color: AppColors.primaryPurple,
                        ),
                      )
                      : _hasError
                      ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text('Error: $_errorMessage'),
                            const SizedBox(height: 16),
                            ElevatedButton(
                              onPressed: _loadResponses,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppColors.primaryPurple,
                              ),
                              child: const Text('Try Again'),
                            ),
                          ],
                        ),
                      )
                      : _buildResponsesList(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildResponsesList() {
    final List<ResponseModel> filteredResponses = [];

    if (_selectedStatus == 'All') {
      _responsesByStatus.forEach((_, responses) {
        filteredResponses.addAll(responses);
      });

      // Sort by date (most recent first)
      filteredResponses.sort((a, b) => b.eventDate.compareTo(a.eventDate));
    } else {
      final status = _selectedStatus.toLowerCase();
      filteredResponses.addAll(_responsesByStatus[status] ?? []);
    }

    if (filteredResponses.isEmpty) {
      return const Center(child: Text('No responses found'));
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: filteredResponses.length,
      itemBuilder: (context, index) {
        final response = filteredResponses[index];
        return Card(
          key: Key('response_card_${response.id}'),
          margin: const EdgeInsets.only(bottom: 16),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          clipBehavior: Clip.antiAlias,
          elevation: 2,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                width: double.infinity,
                height: 180,
                child: FutureBuilder<DocumentSnapshot>(
                  future:
                      FirebaseFirestore.instance
                          .collection('portfolios')
                          .doc(response.portfolioId)
                          .get(),
                  builder: (context, snapshot) {
                    if (!snapshot.hasData ||
                        snapshot.hasError ||
                        !snapshot.data!.exists) {
                      // Show a placeholder when no image is available
                      return Container(
                        width: double.infinity,
                        height: double.infinity,
                        color: Colors.grey[200],
                        child: Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.image,
                                color: Colors.grey[400],
                                size: 40,
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'No image available',
                                style: TextStyle(
                                  color: Colors.grey[500],
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    }

                    final data = snapshot.data!.data() as Map<String, dynamic>;
                    final List<dynamic> images = data['imageUrls'] ?? [];

                    if (images.isEmpty) {
                      // Show a placeholder when no images are in the data
                      return Container(
                        width: double.infinity,
                        height: double.infinity,
                        color: Colors.grey[200],
                        child: Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.image,
                                color: Colors.grey[400],
                                size: 40,
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'No image available',
                                style: TextStyle(
                                  color: Colors.grey[500],
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    }

                    // Display the first image with improved styling
                    final imageRef = images[0].toString();
                    print('Loading image reference: $imageRef'); // Debugging

                    return Container(
                      width: double.infinity,
                      height: double.infinity,
                      color: Colors.grey[200],
                      child: fw.FirestoreImage(
                        imageUrl: imageRef,
                        fit: BoxFit.cover,
                      ),
                    );
                  },
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          response.eventName,
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF6B6B8D),
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: _getStatusColor(response.status),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            response.status,
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    _buildDetailRow('Client', response.clientName),
                    const SizedBox(height: 8),
                    _buildDetailRow('Event Type', response.eventType),
                    const SizedBox(height: 8),
                    _buildDetailRow(
                      'Event Date',
                      DateFormat('MMM dd, yyyy').format(response.eventDate),
                    ),
                    if (response.status == 'accepted') ...[
                      const SizedBox(height: 8),
                      _buildDetailRow(
                        'Time Remaining',
                        _getTimeRemaining(response.eventDate),
                        textColor: Colors.blue,
                        isBold: true,
                      ),
                    ],
                    const SizedBox(height: 8),
                    _buildDetailRow(
                      'Budget',
                      'PKR ${NumberFormat('#,###').format(response.budget)}',
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        const Text(
                          'Colors: ',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF6B6B8D),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          width: 24,
                          height: 24,
                          decoration: BoxDecoration(
                            color: Color(int.parse(response.primaryColor)),
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.grey.shade300),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          width: 24,
                          height: 24,
                          decoration: BoxDecoration(
                            color: Color(int.parse(response.secondaryColor)),
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.grey.shade300),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    _buildDetailRow(
                      'Photographer',
                      response.needsPhotographer ? 'Required' : 'Not Required',
                    ),

                    // Portfolio Rating
                    const SizedBox(height: 8),
                    _buildDetailRow(
                      'Portfolio Rating',
                      _portfolioRatings.containsKey(response.portfolioId)
                          ? (_portfolioRatings[response.portfolioId]! > 0
                              ? '${_portfolioRatings[response.portfolioId]!.toStringAsFixed(1)}/5'
                              : 'N/A')
                          : 'Loading...',
                      textColor: Colors.amber.shade800,
                    ),

                    // Event Count
                    const SizedBox(height: 8),
                    _buildDetailRow(
                      'Total Events',
                      _portfolioEventCounts.containsKey(response.portfolioId)
                          ? (_portfolioEventCounts[response.portfolioId]! > 0
                              ? _portfolioEventCounts[response.portfolioId]!
                                  .toString()
                              : 'None')
                          : 'Loading...',
                    ),

                    if (response.additionalNotes.isNotEmpty) ...[
                      const SizedBox(height: 12),
                      const Text(
                        'Notes:',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF6B6B8D),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.grey.shade200,
                          border: Border.all(color: Colors.grey.shade300),
                        ),
                        child: Text(
                          response.additionalNotes,
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey.shade700,
                          ),
                        ),
                      ),
                    ],
                    const SizedBox(height: 16),
                    if (response.status == 'accepted')
                      GestureDetector(
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder:
                                  (context) => const FeedbackScreen(
                                    isInBottomNavBar: false,
                                  ),
                            ),
                          );
                        },
                        child: Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          decoration: BoxDecoration(
                            color: AppColors.primaryPurple,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: const [
                              Icon(Icons.star, color: Colors.white, size: 18),
                              SizedBox(width: 8),
                              Text(
                                'Rate & Review',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    const SizedBox(height: 16),
                    if (response.status == 'pending') ...[
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          OutlinedButton(
                            onPressed:
                                () =>
                                    _updateResponseStatus(response, 'rejected'),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: Colors.red,
                              side: const BorderSide(color: Colors.red),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(4),
                              ),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 10,
                              ),
                            ),
                            child: const Text('Reject'),
                          ),
                          const SizedBox(width: 12),
                          ElevatedButton(
                            onPressed:
                                () =>
                                    _updateResponseStatus(response, 'accepted'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.primaryPurple,
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(4),
                              ),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 10,
                              ),
                            ),
                            child: const Text('Accept'),
                          ),
                        ],
                      ),
                    ],
                    if (response.status == 'accepted') ...[
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          Material(
                            color: Colors.transparent,
                            child: InkWell(
                              onTap: () {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text(
                                      'Chat will be implemented soon',
                                    ),
                                    duration: Duration(seconds: 2),
                                  ),
                                );
                              },
                              borderRadius: BorderRadius.circular(20),
                              child: Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: AppColors.primaryPurple,
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(
                                  Icons.chat,
                                  color: Colors.white,
                                  size: 16,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildDetailRow(
    String label,
    String value, {
    Color? textColor,
    bool isBold = false,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '$label: ',
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: Color(0xFF6B6B8D),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: TextStyle(
              fontSize: 16,
              color: textColor ?? const Color(0xFF6B6B8D),
              fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
            ),
          ),
        ),
      ],
    );
  }

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'pending':
        return Colors.orange;
      case 'accepted':
        return Colors.green;
      case 'rejected':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }
}
