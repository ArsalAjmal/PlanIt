import 'package:flutter/material.dart';
import '../../models/portfolio_model.dart';
import '../../services/portfolio_service.dart';
import '../../widgets/firestore_image.dart';
import 'portfolio_response_screen.dart';

class PortfolioBrowseScreen extends StatefulWidget {
  final String clientId;
  final String clientName;

  const PortfolioBrowseScreen({
    Key? key,
    required this.clientId,
    required this.clientName,
  }) : super(key: key);

  @override
  _PortfolioBrowseScreenState createState() => _PortfolioBrowseScreenState();
}

class _PortfolioBrowseScreenState extends State<PortfolioBrowseScreen> {
  final _portfolioService = PortfolioService();
  String? _selectedEventType;
  double? _minBudget;
  double? _maxBudget;
  final _minBudgetController = TextEditingController();
  final _maxBudgetController = TextEditingController();
  bool _showFilters = false;
  final _searchController = TextEditingController();
  String _searchQuery = '';

  final List<String> _availableEventTypes = [
    'Wedding',
    'Birthday',
    'Corporate',
    'Other',
  ];

  @override
  void dispose() {
    _minBudgetController.dispose();
    _maxBudgetController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  void _applyFilters() {
    setState(() {
      _minBudget =
          _minBudgetController.text.isNotEmpty
              ? double.parse(_minBudgetController.text)
              : null;
      _maxBudget =
          _maxBudgetController.text.isNotEmpty
              ? double.parse(_maxBudgetController.text)
              : null;
      _showFilters = false;
    });
  }

  void _resetFilters() {
    setState(() {
      _selectedEventType = null;
      _minBudget = null;
      _maxBudget = null;
      _minBudgetController.clear();
      _maxBudgetController.clear();
      _showFilters = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Browse Portfolios'),
        backgroundColor: const Color(0xFF9D9DCC),
        actions: [
          IconButton(
            icon: const Icon(Icons.bug_report),
            tooltip: 'Debug Portfolio Search',
            onPressed: () {
              Navigator.pushNamed(context, '/debug_portfolios');
            },
          ),
          IconButton(
            icon: const Icon(Icons.filter_list),
            onPressed: () {
              setState(() {
                _showFilters = !_showFilters;
              });
            },
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Search portfolios by title...',
                prefixIcon: Icon(Icons.search),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8.0),
                ),
                contentPadding: EdgeInsets.symmetric(vertical: 0.0),
              ),
              onChanged: (value) {
                print('Search text changed to: "$value"');
                setState(() {
                  _searchQuery = value;
                });
              },
            ),
          ),
          if (_showFilters)
            Card(
              margin: const EdgeInsets.all(8),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Filters',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 16),
                    DropdownButtonFormField<String>(
                      value: _selectedEventType,
                      decoration: const InputDecoration(
                        labelText: 'Event Type',
                        border: OutlineInputBorder(),
                      ),
                      items:
                          _availableEventTypes.map((type) {
                            return DropdownMenuItem(
                              value: type,
                              child: Text(type),
                            );
                          }).toList(),
                      onChanged: (value) {
                        setState(() {
                          _selectedEventType = value;
                        });
                      },
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            controller: _minBudgetController,
                            decoration: const InputDecoration(
                              labelText: 'Min Budget',
                              prefixText: 'PKR ',
                              border: OutlineInputBorder(),
                            ),
                            keyboardType: TextInputType.number,
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: TextFormField(
                            controller: _maxBudgetController,
                            decoration: const InputDecoration(
                              labelText: 'Max Budget',
                              prefixText: 'PKR ',
                              border: OutlineInputBorder(),
                            ),
                            keyboardType: TextInputType.number,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        TextButton(
                          onPressed: _resetFilters,
                          child: const Text('Reset'),
                        ),
                        const SizedBox(width: 8),
                        ElevatedButton(
                          onPressed: _applyFilters,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF9D9DCC),
                          ),
                          child: const Text('Apply'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          Expanded(
            child: StreamBuilder<List<PortfolioModel>>(
              stream: _portfolioService.searchPortfolios(
                eventType: _selectedEventType,
                minBudget: _minBudget,
                maxBudget: _maxBudget,
                titleQuery: _searchQuery,
              ),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (snapshot.hasError) {
                  print('Error in StreamBuilder: ${snapshot.error}');
                  return Center(child: Text('Error: ${snapshot.error}'));
                }

                final portfolios = snapshot.data ?? [];
                print('StreamBuilder received ${portfolios.length} portfolios');

                if (portfolios.isNotEmpty) {
                  print('First portfolio title: "${portfolios.first.title}"');
                }

                if (portfolios.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Text(
                          'No portfolios found',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 8),
                        if (_searchQuery.isNotEmpty)
                          Text(
                            'No results found for "${_searchQuery}"',
                            style: TextStyle(color: Colors.grey[600]),
                          ),
                        const SizedBox(height: 16),
                        ElevatedButton(
                          onPressed: () {
                            setState(() {
                              _searchController.clear();
                              _searchQuery = '';
                              _selectedEventType = null;
                              _minBudget = null;
                              _maxBudget = null;
                              _minBudgetController.clear();
                              _maxBudgetController.clear();
                            });
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF9D9DCC),
                          ),
                          child: const Text('Clear all filters'),
                        ),
                      ],
                    ),
                  );
                }

                return GridView.builder(
                  padding: const EdgeInsets.all(8),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    childAspectRatio: 0.75,
                    crossAxisSpacing: 8,
                    mainAxisSpacing: 8,
                  ),
                  itemCount: portfolios.length,
                  itemBuilder: (context, index) {
                    final portfolio = portfolios[index];
                    return Card(
                      child: InkWell(
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder:
                                  (context) => PortfolioResponseScreen(
                                    portfolio: portfolio,
                                    clientId: widget.clientId,
                                    clientName: widget.clientName,
                                  ),
                            ),
                          );
                        },
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child:
                                  portfolio.imageUrls.isNotEmpty
                                      ? FirestoreImage(
                                        imageUrl: portfolio.imageUrls[0],
                                        fit: BoxFit.cover,
                                        width: double.infinity,
                                      )
                                      : Container(
                                        color: Colors.grey[200],
                                        child: const Center(
                                          child: Icon(
                                            Icons.image_not_supported,
                                            size: 48,
                                            color: Colors.grey,
                                          ),
                                        ),
                                      ),
                            ),
                            Padding(
                              padding: const EdgeInsets.all(8),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    portfolio.title,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 16,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    'PKR ${portfolio.minBudget} - PKR ${portfolio.maxBudget}',
                                    style: TextStyle(
                                      color: Colors.grey[600],
                                      fontSize: 14,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Row(
                                    children: [
                                      const Icon(
                                        Icons.star,
                                        color: Colors.amber,
                                        size: 16,
                                      ),
                                      const SizedBox(width: 4),
                                      Text(
                                        portfolio.rating.toStringAsFixed(1),
                                        style: const TextStyle(fontSize: 14),
                                      ),
                                      const SizedBox(width: 8),
                                      const Icon(
                                        Icons.event,
                                        color: Colors.grey,
                                        size: 16,
                                      ),
                                      const SizedBox(width: 4),
                                      Text(
                                        '${portfolio.totalEvents}',
                                        style: const TextStyle(fontSize: 14),
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
          ),
        ],
      ),
    );
  }
}
