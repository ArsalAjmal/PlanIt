import 'package:flutter/material.dart';
import '../../models/portfolio_model.dart';
import '../../services/portfolio_service.dart';
import '../../widgets/firestore_image.dart' as fw;
import 'portfolio_creation_screen.dart';
import 'portfolio_responses_screen.dart';
import 'portfolio_edit_screen.dart';

class MyPortfoliosScreen extends StatefulWidget {
  final String organizerId;

  const MyPortfoliosScreen({Key? key, required this.organizerId})
    : super(key: key);

  @override
  _MyPortfoliosScreenState createState() => _MyPortfoliosScreenState();
}

class _MyPortfoliosScreenState extends State<MyPortfoliosScreen> {
  final _portfolioService = PortfolioService();
  bool _isLoading = false;

  Future<void> _deletePortfolio(String portfolioId) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('Delete Portfolio'),
            content: const Text(
              'Are you sure you want to delete this portfolio? This action cannot be undone.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Cancel'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text(
                  'Delete',
                  style: TextStyle(color: Colors.red),
                ),
              ),
            ],
          ),
    );

    if (confirmed == true) {
      setState(() {
        _isLoading = true;
      });

      try {
        await _portfolioService.deletePortfolio(portfolioId);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Portfolio deleted successfully'),
            backgroundColor: Colors.green,
          ),
        );
      } catch (e) {
        print('Error deleting portfolio: $e');
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Error deleting portfolio'),
            backgroundColor: Colors.red,
          ),
        );
      } finally {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('My Portfolios'),
        backgroundColor: const Color(0xFF9D9DCC),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
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
        ],
      ),
      body:
          _isLoading
              ? const Center(child: CircularProgressIndicator())
              : StreamBuilder<List<PortfolioModel>>(
                stream: _portfolioService.getPortfoliosByOrganizer(
                  widget.organizerId,
                ),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
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
                            Icons.photo_library,
                            size: 64,
                            color: Colors.grey,
                          ),
                          const SizedBox(height: 16),
                          const Text(
                            'No portfolios yet',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 8),
                          const Text(
                            'Create your first portfolio to showcase your work',
                            textAlign: TextAlign.center,
                            style: TextStyle(color: Colors.grey),
                          ),
                          const SizedBox(height: 24),
                          ElevatedButton.icon(
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
                            icon: const Icon(Icons.add),
                            label: const Text('Create Portfolio'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF9D9DCC),
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

                  return ListView.builder(
                    padding: const EdgeInsets.all(8),
                    itemCount: portfolios.length,
                    itemBuilder: (context, index) {
                      final portfolio = portfolios[index];
                      return Card(
                        margin: const EdgeInsets.only(bottom: 8),
                        child: InkWell(
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder:
                                    (context) => PortfolioResponsesScreen(
                                      organizerId: widget.organizerId,
                                    ),
                              ),
                            );
                          },
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Stack(
                                children: [
                                  portfolio.imageUrls.isNotEmpty
                                      ? fw.FirestoreImage(
                                        imageUrl: portfolio.imageUrls[0],
                                        height: 200,
                                        width: double.infinity,
                                        fit: BoxFit.cover,
                                      )
                                      : Container(
                                        height: 200,
                                        color: Colors.grey[200],
                                        child: const Center(
                                          child: Icon(
                                            Icons.image_not_supported,
                                            size: 48,
                                            color: Colors.grey,
                                          ),
                                        ),
                                      ),
                                  Positioned(
                                    top: 8,
                                    right: 8,
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 12,
                                        vertical: 6,
                                      ),
                                      decoration: BoxDecoration(
                                        color: Colors.black54,
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: Row(
                                        children: [
                                          const Icon(
                                            Icons.star,
                                            color: Colors.amber,
                                            size: 16,
                                          ),
                                          const SizedBox(width: 4),
                                          Text(
                                            portfolio.rating.toStringAsFixed(1),
                                            style: const TextStyle(
                                              color: Colors.white,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ],
                                      ),
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
                                        fontWeight: FontWeight.bold,
                                        fontSize: 18,
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    Text(
                                      portfolio.description,
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    const SizedBox(height: 8),
                                    Wrap(
                                      spacing: 8,
                                      children:
                                          portfolio.eventTypes.map((type) {
                                            return Chip(
                                              label: Text(type),
                                              backgroundColor: const Color(
                                                0xFF9D9DCC,
                                              ),
                                              labelStyle: const TextStyle(
                                                color: Colors.white,
                                              ),
                                            );
                                          }).toList(),
                                    ),
                                    const SizedBox(height: 8),
                                    Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.spaceBetween,
                                      children: [
                                        Text(
                                          'PKR ${portfolio.minBudget} - PKR ${portfolio.maxBudget}',
                                          style: const TextStyle(
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                        Row(
                                          children: [
                                            IconButton(
                                              icon: const Icon(Icons.delete),
                                              color: Colors.red,
                                              onPressed:
                                                  () => _deletePortfolio(
                                                    portfolio.id,
                                                  ),
                                            ),
                                            IconButton(
                                              icon: const Icon(Icons.edit),
                                              color: const Color(0xFF9D9DCC),
                                              onPressed: () {
                                                Navigator.push(
                                                  context,
                                                  MaterialPageRoute(
                                                    builder:
                                                        (context) =>
                                                            PortfolioEditScreen(
                                                              portfolio:
                                                                  portfolio,
                                                            ),
                                                  ),
                                                );
                                              },
                                            ),
                                          ],
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
                  );
                },
              ),
    );
  }
}
