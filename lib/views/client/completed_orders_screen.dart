import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';
import '../../models/response_model.dart';
import '../../models/review_model.dart';
import '../../services/portfolio_service.dart';

class CompletedOrdersScreen extends StatefulWidget {
  final String clientId;
  final String clientName;

  const CompletedOrdersScreen({
    Key? key,
    required this.clientId,
    required this.clientName,
  }) : super(key: key);

  @override
  _CompletedOrdersScreenState createState() => _CompletedOrdersScreenState();
}

class _CompletedOrdersScreenState extends State<CompletedOrdersScreen> {
  final _portfolioService = PortfolioService();

  Future<void> _showReviewDialog(ResponseModel response) async {
    final _ratingController = TextEditingController();
    final _commentController = TextEditingController();
    double _rating = 0;

    return showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('Write a Review'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('Rate your experience'),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(5, (index) {
                      return IconButton(
                        icon: Icon(
                          index < _rating ? Icons.star : Icons.star_border,
                          color: Colors.amber,
                        ),
                        onPressed: () {
                          setState(() {
                            _rating = index + 1.0;
                          });
                        },
                      );
                    }),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _commentController,
                    decoration: const InputDecoration(
                      labelText: 'Comment',
                      border: OutlineInputBorder(),
                    ),
                    maxLines: 3,
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: () async {
                  if (_rating > 0) {
                    final review = ReviewModel(
                      id: const Uuid().v4(),
                      responseId: response.id,
                      portfolioId: response.portfolioId,
                      organizerId: response.organizerId,
                      clientId: widget.clientId,
                      clientName: widget.clientName,
                      rating: _rating,
                      comment: _commentController.text,
                      createdAt: DateTime.now(),
                    );

                    try {
                      await _portfolioService.createReview(review);
                      Navigator.pop(context);
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Review submitted successfully'),
                          backgroundColor: Colors.green,
                        ),
                      );
                    } catch (e) {
                      print('Error submitting review: $e');
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Error submitting review'),
                          backgroundColor: Colors.red,
                        ),
                      );
                    }
                  } else {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Please select a rating'),
                        backgroundColor: Colors.orange,
                      ),
                    );
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF9D9DCC),
                ),
                child: const Text('Submit'),
              ),
            ],
          ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Completed Orders'),
        backgroundColor: const Color(0xFF9D9DCC),
      ),
      body: StreamBuilder<List<ResponseModel>>(
        stream: _portfolioService.getCompletedResponsesForClient(
          widget.clientId,
        ),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }

          final responses = snapshot.data ?? [];

          if (responses.isEmpty) {
            return const Center(child: Text('No completed orders yet'));
          }

          return ListView.builder(
            padding: const EdgeInsets.all(8),
            itemCount: responses.length,
            itemBuilder: (context, index) {
              final response = responses[index];
              return FutureBuilder<bool>(
                future: _portfolioService.hasResponseBeenReviewed(response.id),
                builder: (context, reviewSnapshot) {
                  final hasBeenReviewed = reviewSnapshot.data ?? false;

                  return Card(
                    margin: const EdgeInsets.only(bottom: 8),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            response.eventName,
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Event Type: ${response.eventType}',
                            style: const TextStyle(fontSize: 16),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Event Date: ${DateFormat('MMM dd, yyyy').format(response.eventDate)}',
                            style: const TextStyle(fontSize: 16),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Total Amount: PKR ${response.budget + (response.needsPhotographer ? 25000 : 0)}',
                            style: const TextStyle(fontSize: 16),
                          ),
                          const SizedBox(height: 16),
                          if (!hasBeenReviewed)
                            SizedBox(
                              width: double.infinity,
                              child: ElevatedButton(
                                onPressed: () => _showReviewDialog(response),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFF9D9DCC),
                                ),
                                child: const Text('Write a Review'),
                              ),
                            )
                          else
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: Colors.grey[200],
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: const Text(
                                'Review Submitted',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  color: Colors.grey,
                                  fontStyle: FontStyle.italic,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  );
                },
              );
            },
          );
        },
      ),
    );
  }
}
