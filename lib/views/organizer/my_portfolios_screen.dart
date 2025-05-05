import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../models/portfolio_model.dart';
import '../../services/portfolio_service.dart';
import '../../widgets/firestore_image.dart' as fw;
import 'portfolio_edit_screen.dart';
import '../../constants/app_colors.dart';
import 'portfolio_creation_screen.dart';

class MyPortfoliosScreen extends StatefulWidget {
  final String organizerId;

  const MyPortfoliosScreen({Key? key, required this.organizerId})
    : super(key: key);

  @override
  _MyPortfoliosScreenState createState() => _MyPortfoliosScreenState();
}

class _MyPortfoliosScreenState extends State<MyPortfoliosScreen> {
  final _portfolioService = PortfolioService();
  bool _isLoading = true;
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  // Cache for ratings and event counts
  final Map<String, double> _portfolioRatings = {};
  final Map<String, int> _portfolioEventCounts = {};

  @override
  void initState() {
    super.initState();
  }

  // Get portfolio rating with caching
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

  // Get portfolio event count with caching
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

  // Delete portfolio
  Future<void> _deletePortfolio(PortfolioModel portfolio) async {
    try {
      // Show confirmation dialog
      final shouldDelete = await showDialog<bool>(
        context: context,
        builder:
            (context) => Dialog(
              backgroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Close button at top-right
                    Align(
                      alignment: Alignment.topRight,
                      child: GestureDetector(
                        onTap: () => Navigator.pop(context, false),
                        child: const Icon(Icons.close, color: Colors.grey),
                      ),
                    ),

                    // Red circle with X icon (filled red with white X)
                    Container(
                      width: 60,
                      height: 60,
                      decoration: const BoxDecoration(
                        color: Colors.red,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.close,
                        color: Colors.white,
                        size: 30,
                      ),
                    ),

                    const SizedBox(height: 24),

                    // Title
                    const Text(
                      'Are you sure?',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87,
                      ),
                    ),

                    const SizedBox(height: 12),

                    // Description with actual portfolio name
                    Text(
                      'Do you really want to delete "${portfolio.title}"? This process cannot be undone.',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 14, color: Colors.grey[600]),
                    ),

                    const SizedBox(height: 24),

                    // Buttons
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        // Cancel Button
                        Expanded(
                          child: ElevatedButton(
                            onPressed: () => Navigator.pop(context, false),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.grey[300],
                              foregroundColor: Colors.black,
                              elevation: 0,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                              padding: const EdgeInsets.symmetric(vertical: 12),
                            ),
                            child: const Text('Cancel'),
                          ),
                        ),

                        const SizedBox(width: 12),

                        // Delete Button (red with black text)
                        Expanded(
                          child: ElevatedButton(
                            onPressed: () => Navigator.pop(context, true),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.red,
                              foregroundColor: Colors.black,
                              elevation: 0,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                              padding: const EdgeInsets.symmetric(vertical: 12),
                            ),
                            child: const Text('Delete'),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
      );

      if (shouldDelete != true) return;

      // Delete portfolio document
      await _portfolioService.deletePortfolio(portfolio.id);

      // Show success message
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Portfolio deleted successfully'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      print('Error deleting portfolio: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error deleting portfolio: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: AppColors.creamBackground,
      body: SafeArea(
        child: Column(
          children: [
            _buildAppBar(context),
            Expanded(
              child: StreamBuilder<List<PortfolioModel>>(
                stream: _portfolioService.getPortfoliosByOrganizer(
                  widget.organizerId,
                ),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting &&
                      !snapshot.hasData) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  if (snapshot.hasError) {
                    return Center(child: Text('Error: ${snapshot.error}'));
                  }

                  final portfolios = snapshot.data ?? [];

                  if (portfolios.isEmpty) {
                    return Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(
                            Icons.folder_outlined,
                            size: 80,
                            color: Colors.grey,
                          ),
                          const SizedBox(height: 16),
                          const Text(
                            'No portfolios found',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Colors.grey,
                            ),
                          ),
                          const SizedBox(height: 8),
                          const Text(
                            'Create your first portfolio to get started',
                            style: TextStyle(fontSize: 14, color: Colors.grey),
                          ),
                          const SizedBox(height: 24),
                          ElevatedButton.icon(
                            onPressed: () {
                              Navigator.pop(context);
                              // Navigate to the portfolio creation screen
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder:
                                      (context) => PortfolioCreationScreen(
                                        organizerId: widget.organizerId,
                                      ),
                                ),
                              );
                            },
                            icon: const Icon(Icons.add),
                            label: const Text('Create Portfolio'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.primaryPurple,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 24,
                                vertical: 12,
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  }

                  // Preload ratings and event counts
                  for (var portfolio in portfolios) {
                    if (!_portfolioRatings.containsKey(portfolio.id)) {
                      _getPortfolioRating(portfolio.id).then((_) {
                        if (mounted) setState(() {});
                      });
                    }
                    if (!_portfolioEventCounts.containsKey(portfolio.id)) {
                      _getPortfolioEventCount(portfolio.id).then((_) {
                        if (mounted) setState(() {});
                      });
                    }
                  }

                  return ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: portfolios.length,
                    itemBuilder: (context, index) {
                      return _buildPortfolioCard(context, portfolios[index]);
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAppBar(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: const BoxDecoration(
        color: Color(0xFF9D9DCC),
        boxShadow: [
          BoxShadow(color: Colors.black12, offset: Offset(0, 2), blurRadius: 4),
        ],
      ),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.arrow_back, color: Colors.white),
            onPressed: () => Navigator.pop(context),
          ),
          const Text(
            'My Portfolios',
            style: TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          const Spacer(),
          Container(
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              borderRadius: BorderRadius.circular(25),
            ),
            child: IconButton(
              icon: const Icon(Icons.add, color: Colors.white),
              tooltip: 'Create Portfolio',
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder:
                        (context) => PortfolioCreationScreen(
                          organizerId: widget.organizerId,
                        ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPortfolioCard(BuildContext context, PortfolioModel portfolio) {
    final currencyFormat = NumberFormat.currency(
      symbol: 'PKR ',
      decimalDigits: 0,
    );

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      elevation: 4,
      color: Colors.white,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (portfolio.imageUrls.isNotEmpty)
            Stack(
              children: [
                ClipRRect(
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(12),
                    topRight: Radius.circular(12),
                  ),
                  child: Container(
                    height: 140,
                    width: double.infinity,
                    child: fw.FirestoreImage(
                      imageUrl: portfolio.imageUrls[0],
                      fit: BoxFit.cover,
                    ),
                  ),
                ),
                // Action buttons overlay
                Positioned(
                  top: 8,
                  right: 8,
                  child: Row(
                    children: [
                      // Edit button
                      Container(
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.9),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: IconButton(
                          icon: const Icon(Icons.edit, color: Colors.blue),
                          tooltip: 'Edit',
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder:
                                    (context) => PortfolioEditScreen(
                                      portfolio: portfolio,
                                    ),
                              ),
                            ).then((_) {
                              setState(() {
                                // This will refresh the screen data after editing
                              });
                            });
                          },
                        ),
                      ),
                      const SizedBox(width: 8),
                      // Delete button
                      Container(
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.9),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: IconButton(
                          icon: const Icon(Icons.delete, color: Colors.red),
                          tooltip: 'Delete',
                          onPressed: () => _deletePortfolio(portfolio),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  portfolio.title,
                  style: const TextStyle(
                    color: Colors.black87,
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  portfolio.description.length > 100
                      ? '${portfolio.description.substring(0, 100)}...'
                      : portfolio.description,
                  style: TextStyle(color: Colors.grey[700], fontSize: 14),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Icon(Icons.event, size: 16, color: Colors.grey[600]),
                    const SizedBox(width: 4),
                    Text(
                      portfolio.eventTypes.join(', '),
                      style: TextStyle(color: Colors.grey[600], fontSize: 14),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Icon(
                      Icons.monetization_on,
                      size: 16,
                      color: Colors.grey[600],
                    ),
                    const SizedBox(width: 4),
                    Text(
                      '${currencyFormat.format(portfolio.minBudget)} - ${currencyFormat.format(portfolio.maxBudget)}',
                      style: TextStyle(color: Colors.grey[600], fontSize: 14),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    const Icon(Icons.star, color: Colors.amber, size: 16),
                    const SizedBox(width: 4),
                    Text(
                      _portfolioRatings.containsKey(portfolio.id)
                          ? (_portfolioRatings[portfolio.id]! > 0
                              ? _portfolioRatings[portfolio.id]!
                                  .toStringAsFixed(1)
                              : 'N/A')
                          : portfolio.rating.toStringAsFixed(1),
                      style: const TextStyle(
                        color: Colors.black87,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      '${_portfolioEventCounts.containsKey(portfolio.id) ? _portfolioEventCounts[portfolio.id] : portfolio.totalEvents} events',
                      style: TextStyle(color: Colors.grey[600], fontSize: 14),
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
}
