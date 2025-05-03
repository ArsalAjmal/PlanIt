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
import 'dart:async';

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

class OrganizerSearchView extends StatefulWidget {
  final String clientId;
  final String clientName;

  const OrganizerSearchView({
    super.key,
    required this.clientId,
    required this.clientName,
  });

  @override
  State<OrganizerSearchView> createState() => _OrganizerSearchViewState();
}

class _OrganizerSearchViewState extends State<OrganizerSearchView> {
  // Timer for promotional offers
  Timer? _promotionalTimer;
  int _remainingSeconds = 15 * 60; // 15 minutes in seconds

  @override
  void initState() {
    super.initState();
    // Start the promotional timer
    _startPromoTimer();
  }

  @override
  void dispose() {
    _promotionalTimer?.cancel();
    super.dispose();
  }

  void _startPromoTimer() {
    _promotionalTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      setState(() {
        if (_remainingSeconds > 0) {
          _remainingSeconds--;
        } else {
          timer.cancel();
        }
      });
    });
  }

  String _formatTime(int seconds) {
    int minutes = seconds ~/ 60;
    int remainingSeconds = seconds % 60;
    return '$minutes:${remainingSeconds.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    // Set status bar color to match background
    SystemChrome.setSystemUIOverlayStyle(
      const SystemUiOverlayStyle(
        statusBarColor: Colors.white,
        statusBarIconBrightness: Brightness.dark,
      ),
    );

    return Scaffold(
      backgroundColor: AppColors.creamBackground,
      body: SafeArea(
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
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
                    icon: const Icon(Icons.arrow_back, color: Colors.white),
                    onPressed: () => Navigator.pop(context),
                  ),
                  const Text(
                    'Search',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const Spacer(),
                ],
              ),
            ),
            _buildSearchBar(context),
            _buildPromotionalOffers(),
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
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 24.0),
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
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                fontSize: 16,
                                color: Colors.black87,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            const SizedBox(height: 8),
                            const Text(
                              'Try different keywords or filters',
                              style: TextStyle(
                                color: Colors.black87,
                                fontSize: 14,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                }

                // Use a builder for better performance with lists
                return Expanded(
                  child: ListView.builder(
                    padding: const EdgeInsets.all(16),
                    // Calculate the total item count with headers
                    itemCount:
                        (hasPortfolios ? 1 + controller.portfolios.length : 0) +
                        (hasOrganizers ? 1 + controller.organizers.length : 0) +
                        (!hasResults && !hasSearchQuery ? 1 : 0),
                    itemBuilder: (context, index) {
                      // Portfolio section
                      if (hasPortfolios) {
                        if (index == 0) {
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 8.0),
                            child: Row(
                              children: [
                                Container(
                                  width: 3,
                                  height: 24,
                                  decoration: BoxDecoration(
                                    color: Colors.black87,
                                    borderRadius: BorderRadius.circular(1.5),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                const Text(
                                  'Portfolios',
                                  style: TextStyle(
                                    color: Colors.black87,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 18,
                                  ),
                                ),
                              ],
                            ),
                          );
                        }

                        if (index < 1 + controller.portfolios.length) {
                          return _buildPortfolioCard(
                            context,
                            controller.portfolios[index - 1],
                          );
                        }

                        // If we have both sections, add spacing after portfolios
                        if (hasOrganizers &&
                            index == 1 + controller.portfolios.length) {
                          return const SizedBox(height: 24);
                        }
                      }

                      // Organizer section - adjust index based on portfolio section
                      final organizerStartIndex =
                          hasPortfolios
                              ? 1 +
                                  controller.portfolios.length +
                                  (hasOrganizers ? 1 : 0)
                              : 0;

                      if (hasOrganizers) {
                        if (index == organizerStartIndex) {
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 8.0),
                            child: Row(
                              children: [
                                Container(
                                  width: 3,
                                  height: 24,
                                  decoration: BoxDecoration(
                                    color: Colors.black87,
                                    borderRadius: BorderRadius.circular(1.5),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                const Text(
                                  'Organizers',
                                  style: TextStyle(
                                    color: Colors.black87,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 18,
                                  ),
                                ),
                              ],
                            ),
                          );
                        }

                        if (index > organizerStartIndex &&
                            index <
                                organizerStartIndex +
                                    1 +
                                    controller.organizers.length) {
                          return _buildOrganizerCard(
                            context,
                            controller.organizers[index -
                                organizerStartIndex -
                                1],
                          );
                        }
                      }

                      // Empty results message
                      if (!hasResults && !hasSearchQuery) {
                        return const Center(
                          child: Padding(
                            padding: EdgeInsets.symmetric(
                              vertical: 32.0,
                              horizontal: 24.0,
                            ),
                            child: Text(
                              'Search for organizers and portfolios',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: Colors.black87,
                                fontSize: 16,
                              ),
                            ),
                          ),
                        );
                      }

                      return const SizedBox.shrink();
                    },
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
        style: const TextStyle(color: Colors.black87, fontSize: 16),
        decoration: InputDecoration(
          hintText: 'Search organizers...',
          hintStyle: TextStyle(color: Colors.grey[600], fontSize: 16),
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
          fillColor: Colors.grey.withOpacity(0.1),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(30),
            borderSide: BorderSide.none,
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(30),
            borderSide: BorderSide.none,
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(30),
            borderSide: const BorderSide(color: Color(0xFF9D9DCC), width: 1),
          ),
          contentPadding: const EdgeInsets.symmetric(
            vertical: 4,
            horizontal: 20,
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
              style: const TextStyle(color: Colors.black87, fontSize: 14),
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
                color: Colors.black87,
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
                            color: Colors.black87,
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
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                width: 3,
                                height: 20,
                                decoration: BoxDecoration(
                                  color: Colors.black87,
                                  borderRadius: BorderRadius.circular(1.5),
                                ),
                              ),
                              const SizedBox(width: 8),
                              const Text(
                                'Budget Range',
                                style: TextStyle(
                                  color: Colors.black87,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                ),
                              ),
                            ],
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
                                          color: Color(0xFF757575),
                                          fontSize: 14,
                                        ),
                                      ),
                                      const SizedBox(height: 8),
                                      TextField(
                                        controller: minBudgetController,
                                        keyboardType: TextInputType.number,
                                        style: const TextStyle(
                                          color: Color(0xFF757575),
                                        ),
                                        decoration: InputDecoration(
                                          prefixText: 'PKR ',
                                          prefixStyle: const TextStyle(
                                            color: Colors.black87,
                                            fontWeight: FontWeight.w500,
                                          ),
                                          filled: true,
                                          fillColor: Colors.grey.withOpacity(
                                            0.1,
                                          ),
                                          contentPadding:
                                              const EdgeInsets.symmetric(
                                                horizontal: 12,
                                                vertical: 10,
                                              ),
                                          border: OutlineInputBorder(
                                            borderRadius: BorderRadius.circular(
                                              12,
                                            ),
                                            borderSide: BorderSide.none,
                                          ),
                                          enabledBorder: OutlineInputBorder(
                                            borderRadius: BorderRadius.circular(
                                              12,
                                            ),
                                            borderSide: BorderSide.none,
                                          ),
                                          focusedBorder: OutlineInputBorder(
                                            borderRadius: BorderRadius.circular(
                                              12,
                                            ),
                                            borderSide: const BorderSide(
                                              color: Color(0xFF9D9DCC),
                                              width: 1,
                                            ),
                                          ),
                                          isDense: true,
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
                                          color: Color(0xFF757575),
                                          fontSize: 14,
                                        ),
                                      ),
                                      const SizedBox(height: 8),
                                      TextField(
                                        controller: maxBudgetController,
                                        keyboardType: TextInputType.number,
                                        style: const TextStyle(
                                          color: Color(0xFF757575),
                                        ),
                                        decoration: InputDecoration(
                                          prefixText: 'PKR ',
                                          prefixStyle: const TextStyle(
                                            color: Colors.black87,
                                            fontWeight: FontWeight.w500,
                                          ),
                                          filled: true,
                                          fillColor: Colors.grey.withOpacity(
                                            0.1,
                                          ),
                                          contentPadding:
                                              const EdgeInsets.symmetric(
                                                horizontal: 12,
                                                vertical: 10,
                                              ),
                                          border: OutlineInputBorder(
                                            borderRadius: BorderRadius.circular(
                                              12,
                                            ),
                                            borderSide: BorderSide.none,
                                          ),
                                          enabledBorder: OutlineInputBorder(
                                            borderRadius: BorderRadius.circular(
                                              12,
                                            ),
                                            borderSide: BorderSide.none,
                                          ),
                                          focusedBorder: OutlineInputBorder(
                                            borderRadius: BorderRadius.circular(
                                              12,
                                            ),
                                            borderSide: const BorderSide(
                                              color: Color(0xFF9D9DCC),
                                              width: 1,
                                            ),
                                          ),
                                          isDense: true,
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
                    const Divider(
                      height: 1,
                      thickness: 1,
                      color: Color(0xFFEEEEEE),
                    ),
                    const SizedBox(height: 20),
                    Container(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                width: 3,
                                height: 20,
                                decoration: BoxDecoration(
                                  color: Colors.black87,
                                  borderRadius: BorderRadius.circular(1.5),
                                ),
                              ),
                              const SizedBox(width: 8),
                              const Text(
                                'Event Type',
                                style: TextStyle(
                                  color: Colors.black87,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12),
                            decoration: BoxDecoration(
                              color: Colors.grey.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: DropdownButton<String>(
                              value: selectedEventType,
                              isExpanded: true,
                              underline: const SizedBox(),
                              dropdownColor: Colors.white,
                              hint: const Text(
                                'Select Event Type',
                                style: TextStyle(
                                  color: Color(0xFF757575),
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
                                          color: Colors.black87,
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

  Widget _buildPromotionalOffers() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Promotional timer banner
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
          decoration: BoxDecoration(
            color: const Color(0xFFFFF1F1), // Light pink background
            boxShadow: [
              BoxShadow(
                color: Colors.grey.withOpacity(0.1),
                spreadRadius: 1,
                blurRadius: 2,
                offset: const Offset(0, 1),
              ),
            ],
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Clock icon
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.grey.withOpacity(0.2),
                      spreadRadius: 1,
                      blurRadius: 2,
                      offset: const Offset(0, 1),
                    ),
                  ],
                ),
                child: Image.asset(
                  'assets/images/clock_icon.png',
                  width: 24,
                  height: 24,
                  errorBuilder:
                      (context, error, stackTrace) =>
                          const Icon(Icons.timer, color: Colors.pink, size: 24),
                ),
              ),

              // Text content
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text(
                      'Save 25%',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.pink,
                      ),
                    ),
                    Text(
                      'Hurry! Limited time offers',
                      style: TextStyle(fontSize: 12, color: Colors.grey[700]),
                    ),
                  ],
                ),
              ),

              // Timer display
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: Colors.pink,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  _formatTime(_remainingSeconds),
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                    fontSize: 16,
                  ),
                ),
              ),
            ],
          ),
        ),

        // Horizontal promotional cards
        SizedBox(
          height: 180,
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            children: [
              _buildPromotionalCard(
                'Up to 30% off',
                'assets/images/promo1.jpg',
                Colors.purple.shade800,
                subtitle: 'on all events',
              ),
              _buildPromotionalCard(
                'New Services',
                'assets/images/promo2.jpg',
                Colors.pink,
                subtitle: 'Birthday Events',
              ),
              _buildPromotionalCard(
                'Special Offer',
                'assets/images/promo3.jpg',
                Colors.pink.shade700,
                subtitle: '20% Off Photographers',
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildPromotionalCard(
    String title,
    String imagePath,
    Color color, {
    String? subtitle,
  }) {
    return Container(
      width: 280,
      margin: const EdgeInsets.only(right: 16),
      key: ValueKey(imagePath),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [color, color.withOpacity(0.8)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(0.3),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        children: [
          // Background image with fallback
          Positioned.fill(
            child: Image.asset(
              imagePath,
              fit: BoxFit.cover,
              // Use a cacheWidth to optimize memory usage
              cacheWidth: 560,
              errorBuilder:
                  (context, error, stackTrace) =>
                      Container(color: color.withOpacity(0.2)),
            ),
          ),

          // Text overlay
          Positioned(
            top: 20,
            left: 20,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 28,
                  ),
                ),
                if (subtitle != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(
                      subtitle,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                        fontSize: 22,
                      ),
                    ),
                  ),
              ],
            ),
          ),

          // T&Cs text at bottom
          const Positioned(
            bottom: 10,
            left: 20,
            child: Text(
              'T&Cs apply.',
              style: TextStyle(color: Colors.white, fontSize: 12),
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
      key: ValueKey('portfolio_${portfolio.id}'),
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
            if (portfolio.imageUrls.isNotEmpty)
              ClipRRect(
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(12),
                  topRight: Radius.circular(12),
                ),
                child: Container(
                  key: ValueKey('img_${portfolio.id}'),
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
                        portfolio.rating.toStringAsFixed(1),
                        style: const TextStyle(
                          color: Colors.black87,
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
