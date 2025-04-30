import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:flutter_colorpicker/flutter_colorpicker.dart';
import '../controllers/organizer_search_controller.dart';
import '../models/organizer_model.dart';
import 'package:intl/intl.dart';
import '../models/portfolio_model.dart';
import '../widgets/firestore_image.dart' as fw;
import 'client/portfolio_response_screen.dart';
import '../constants/app_colors.dart';

class OrganizerSearchScreen extends StatelessWidget {
  final String clientId;
  final String clientName;

  const OrganizerSearchScreen({
    super.key,
    this.clientId = '',
    this.clientName = 'Client',
  });

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => OrganizerSearchController(),
      child: OrganizerSearchView(clientId: clientId, clientName: clientName),
    );
  }
}

class OrganizerSearchView extends StatelessWidget {
  final String clientId;
  final String clientName;

  const OrganizerSearchView({
    super.key,
    required this.clientId,
    required this.clientName,
  });

  @override
  Widget build(BuildContext context) {
    // Set status bar color to match background
    SystemChrome.setSystemUIOverlayStyle(
      const SystemUiOverlayStyle(
        statusBarColor: Color(0xFFFFFDE5),
        statusBarIconBrightness: Brightness.dark,
      ),
    );

    return Scaffold(
      backgroundColor: AppColors.creamBackground,
      body: SafeArea(
        child: Column(
          children: [
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
                    'Search',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 20,
                    ),
                  ),
                  const Spacer(),
                ],
              ),
            ),
            _buildSearchBar(context),
            Consumer<OrganizerSearchController>(
              builder: (context, controller, child) {
                if (controller.isLoading) {
                  return const Expanded(
                    child: Center(
                      child: CircularProgressIndicator(
                        color: Color(0xFF9D9DCC),
                      ),
                    ),
                  );
                }

                final hasPortfolios = controller.portfolios.isNotEmpty;
                final hasOrganizers = controller.organizers.isNotEmpty;
                final hasResults = hasPortfolios || hasOrganizers;
                final hasSearchQuery = controller.hasSearchQuery;

                if (!hasResults && hasSearchQuery) {
                  return Expanded(
                    child: Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(
                            Icons.search_off,
                            size: 64,
                            color: Color(0xFF9D9DCC),
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'No results found for "${controller.searchQuery}"',
                            style: const TextStyle(
                              fontSize: 16,
                              color: Colors.grey,
                            ),
                          ),
                          const SizedBox(height: 8),
                          const Text(
                            'Try different keywords or filters',
                            style: TextStyle(color: Colors.grey),
                          ),
                        ],
                      ),
                    ),
                  );
                }

                return Expanded(
                  child: ListView(
                    padding: const EdgeInsets.all(16),
                    children: [
                      if (hasPortfolios) ...[
                        const Padding(
                          padding: EdgeInsets.only(bottom: 8.0),
                          child: Text(
                            'Portfolios',
                            style: TextStyle(
                              color: Color(0xFF9D9DCC),
                              fontWeight: FontWeight.bold,
                              fontSize: 18,
                            ),
                          ),
                        ),
                        ...controller.portfolios.map(
                          (portfolio) =>
                              _buildPortfolioCard(context, portfolio),
                        ),
                        const SizedBox(height: 24),
                      ],

                      if (hasOrganizers) ...[
                        const Padding(
                          padding: EdgeInsets.only(bottom: 8.0),
                          child: Text(
                            'Organizers',
                            style: TextStyle(
                              color: Color(0xFF9D9DCC),
                              fontWeight: FontWeight.bold,
                              fontSize: 18,
                            ),
                          ),
                        ),
                        ...controller.organizers.map(
                          (organizer) =>
                              _buildOrganizerCard(context, organizer),
                        ),
                      ],

                      if (!hasResults && !hasSearchQuery)
                        const Center(
                          child: Padding(
                            padding: EdgeInsets.only(top: 32.0),
                            child: Text(
                              'Search for organizers and portfolios',
                              style: TextStyle(
                                color: Colors.grey,
                                fontSize: 16,
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSearchBar(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: TextField(
        style: const TextStyle(color: Color(0xFF9D9DCC), fontSize: 16),
        decoration: InputDecoration(
          hintText: 'Search organizers...',
          hintStyle: TextStyle(
            color: const Color(0xFF9D9DCC).withOpacity(0.6),
            fontSize: 16,
          ),
          prefixIcon: const Icon(Icons.search, color: Color(0xFF9D9DCC)),
          suffixIcon: TextButton.icon(
            onPressed: () => _showFilterDialog(context),
            icon: const Icon(Icons.filter_list, color: Color(0xFF9D9DCC)),
            label: const Text(
              'Filter',
              style: TextStyle(
                color: Color(0xFF9D9DCC),
                fontWeight: FontWeight.bold,
                fontSize: 14,
              ),
            ),
          ),
          filled: true,
          fillColor: Colors.white,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Color(0xFF9D9DCC)),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Color(0xFF9D9DCC)),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Color(0xFF9D9DCC), width: 2),
          ),
        ),
        onChanged: (value) {
          context.read<OrganizerSearchController>().updateSearchQuery(value);
        },
      ),
    );
  }

  Widget _buildOrganizerCard(BuildContext context, OrganizerModel organizer) {
    final currencyFormat = NumberFormat.currency(
      symbol: 'PKR ',
      decimalDigits: 0,
    );

    return Card(
      color: Colors.white,
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ListTile(
        contentPadding: const EdgeInsets.all(16),
        title: Text(
          organizer.name,
          style: const TextStyle(
            color: Color(0xFF9D9DCC),
            fontWeight: FontWeight.bold,
            fontSize: 18,
          ),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 8),
            Text(
              organizer.eventType,
              style: const TextStyle(color: Color(0xFF9D9DCC), fontSize: 14),
            ),
            Text(
              'Budget: ${currencyFormat.format(organizer.minBudget)} - ${currencyFormat.format(organizer.maxBudget)}',
              style: const TextStyle(color: Color(0xFF9D9DCC), fontSize: 14),
            ),
          ],
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              '${organizer.rating}/5',
              style: const TextStyle(
                color: Color(0xFF9D9DCC),
                fontWeight: FontWeight.bold,
              ),
            ),
            const Icon(Icons.star, color: Colors.amber, size: 20),
          ],
        ),
      ),
    );
  }

  void _showFilterDialog(BuildContext context) {
    double? minBudget = 0;
    double? maxBudget = 100000;
    String? selectedEventType;

    // Store the controller outside of the dialog to use later
    final controller = context.read<OrganizerSearchController>();

    // Controllers for text fields
    final minBudgetController = TextEditingController(text: '0');
    final maxBudgetController = TextEditingController(text: '100000');

    final currencyFormat = NumberFormat.currency(
      symbol: 'PKR ',
      decimalDigits: 0,
    );

    showDialog(
      context: context,
      builder: (BuildContext dialogContext) {
        return StatefulBuilder(
          builder: (dialogContext, setState) {
            return Dialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
              elevation: 0,
              backgroundColor: Colors.transparent,
              child: Container(
                width: MediaQuery.of(context).size.width * 0.9,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF9D9DCC).withOpacity(0.2),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Filter Options',
                          style: TextStyle(
                            color: Color(0xFF9D9DCC),
                            fontWeight: FontWeight.bold,
                            fontSize: 22,
                          ),
                        ),
                        IconButton(
                          icon: const Icon(
                            Icons.close,
                            color: Color(0xFF9D9DCC),
                          ),
                          onPressed: () => Navigator.pop(dialogContext),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: const Color(0xFF9D9DCC).withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Budget Range',
                            style: TextStyle(
                              color: Color(0xFF9D9DCC),
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                          const SizedBox(height: 16),
                          Row(
                            children: [
                              Expanded(
                                child: Container(
                                  width: 300,
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      const Text(
                                        'Min Budget',
                                        style: TextStyle(
                                          color: Color(0xFF9D9DCC),
                                          fontSize: 14,
                                        ),
                                      ),
                                      const SizedBox(height: 8),
                                      TextField(
                                        controller: minBudgetController,
                                        keyboardType: TextInputType.number,
                                        decoration: InputDecoration(
                                          prefixText: 'PKR ',
                                          prefixStyle: TextStyle(
                                            color: const Color(
                                              0xFF9D9DCC,
                                            ).withOpacity(0.5),
                                          ),
                                          filled: true,
                                          fillColor: Colors.white,
                                          contentPadding:
                                              const EdgeInsets.symmetric(
                                                horizontal: 20,
                                                vertical: 16,
                                              ),
                                          border: OutlineInputBorder(
                                            borderRadius: BorderRadius.circular(
                                              8,
                                            ),
                                            borderSide: BorderSide.none,
                                          ),
                                          enabledBorder: OutlineInputBorder(
                                            borderRadius: BorderRadius.circular(
                                              8,
                                            ),
                                            borderSide: BorderSide.none,
                                          ),
                                          focusedBorder: OutlineInputBorder(
                                            borderRadius: BorderRadius.circular(
                                              8,
                                            ),
                                            borderSide: const BorderSide(
                                              color: Color(0xFF9D9DCC),
                                              width: 2,
                                            ),
                                          ),
                                        ),
                                        onChanged: (value) {
                                          setState(() {
                                            minBudget =
                                                double.tryParse(value) ?? 0;
                                          });
                                        },
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: Container(
                                  width: 300,
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      const Text(
                                        'Max Budget',
                                        style: TextStyle(
                                          color: Color(0xFF9D9DCC),
                                          fontSize: 14,
                                        ),
                                      ),
                                      const SizedBox(height: 8),
                                      TextField(
                                        controller: maxBudgetController,
                                        keyboardType: TextInputType.number,
                                        decoration: InputDecoration(
                                          prefixText: 'PKR ',
                                          prefixStyle: TextStyle(
                                            color: const Color(
                                              0xFF9D9DCC,
                                            ).withOpacity(0.5),
                                          ),
                                          filled: true,
                                          fillColor: Colors.white,
                                          contentPadding:
                                              const EdgeInsets.symmetric(
                                                horizontal: 20,
                                                vertical: 16,
                                              ),
                                          border: OutlineInputBorder(
                                            borderRadius: BorderRadius.circular(
                                              8,
                                            ),
                                            borderSide: BorderSide.none,
                                          ),
                                          enabledBorder: OutlineInputBorder(
                                            borderRadius: BorderRadius.circular(
                                              8,
                                            ),
                                            borderSide: BorderSide.none,
                                          ),
                                          focusedBorder: OutlineInputBorder(
                                            borderRadius: BorderRadius.circular(
                                              8,
                                            ),
                                            borderSide: const BorderSide(
                                              color: Color(0xFF9D9DCC),
                                              width: 2,
                                            ),
                                          ),
                                        ),
                                        onChanged: (value) {
                                          setState(() {
                                            if (value.isEmpty) {
                                              maxBudget = null;
                                            } else {
                                              final parsed = double.tryParse(
                                                value,
                                              );
                                              if (parsed != null) {
                                                maxBudget =
                                                    parsed <= 100000
                                                        ? parsed
                                                        : 100000;
                                                if (parsed > 100000) {
                                                  maxBudgetController.text =
                                                      '100000';
                                                  maxBudgetController
                                                          .selection =
                                                      TextSelection.fromPosition(
                                                        TextPosition(
                                                          offset:
                                                              '100000'.length,
                                                        ),
                                                      );
                                                }
                                              }
                                            }
                                          });
                                        },
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: const Color(0xFF9D9DCC).withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Event Type',
                            style: TextStyle(
                              color: Color(0xFF9D9DCC),
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                          const SizedBox(height: 12),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: DropdownButton<String>(
                              value: selectedEventType,
                              isExpanded: true,
                              underline: const SizedBox(),
                              hint: const Text(
                                'Select Event Type',
                                style: TextStyle(
                                  color: Color(0xFF9D9DCC),
                                  fontSize: 14,
                                ),
                              ),
                              items:
                                  [
                                    'Wedding',
                                    'Birthday',
                                    'Corporate',
                                    'Other',
                                  ].map((String value) {
                                    return DropdownMenuItem<String>(
                                      value: value,
                                      child: Text(
                                        value,
                                        style: const TextStyle(
                                          color: Color(0xFF9D9DCC),
                                          fontSize: 14,
                                        ),
                                      ),
                                    );
                                  }).toList(),
                              onChanged: (String? newValue) {
                                setState(() {
                                  selectedEventType = newValue;
                                });
                              },
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: () {
                          controller.updateFilters({
                            'minBudget': minBudget,
                            'maxBudget': maxBudget,
                            'eventType': selectedEventType,
                            'primaryColor': null,
                            'secondaryColor': null,
                          });
                          Navigator.pop(dialogContext);
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF9D9DCC),
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: const Text(
                          'Apply Filters',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
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
      child: InkWell(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder:
                  (context) => PortfolioResponseScreen(
                    portfolio: portfolio,
                    clientId: clientId,
                    clientName: clientName,
                  ),
            ),
          );
        },
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (portfolio.imageUrls.isNotEmpty)
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
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    portfolio.title,
                    style: const TextStyle(
                      color: Color(0xFF9D9DCC),
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
                        portfolio.rating.toStringAsFixed(1),
                        style: const TextStyle(
                          color: Color(0xFF9D9DCC),
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Text(
                        '${portfolio.totalEvents} events',
                        style: TextStyle(color: Colors.grey[600], fontSize: 14),
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
  }
}
