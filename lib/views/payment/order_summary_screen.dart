import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import '../../models/portfolio_model.dart';
import '../../views/organizer_search_screen.dart';
import 'payment_screen.dart';

class OrderSummaryScreen extends StatelessWidget {
  final PortfolioModel portfolio;
  final String eventName;
  final String eventType;
  final DateTime eventDate;
  final double budget;
  final double photographerFee;
  final double totalAmount;
  final Color primaryColor;
  final Color secondaryColor;
  final bool needsPhotographer;
  final String clientResponse;
  final String additionalNotes;
  final String clientId;
  final String clientName;

  const OrderSummaryScreen({
    Key? key,
    required this.portfolio,
    required this.eventName,
    required this.eventType,
    required this.eventDate,
    required this.budget,
    required this.photographerFee,
    required this.totalAmount,
    required this.primaryColor,
    required this.secondaryColor,
    required this.needsPhotographer,
    required this.clientResponse,
    required this.additionalNotes,
    required this.clientId,
    required this.clientName,
  }) : super(key: key);

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
        backgroundColor: const Color(0xFFFFFDE5),
        appBar: AppBar(
          backgroundColor: const Color(0xFF9D9DCC),
          elevation: 0,
          title: const Text(
            'Order Summary',
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 20,
            ),
          ),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back, color: Colors.white),
            onPressed: () => Navigator.pop(context),
          ),
        ),
        body: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Service Provider Card
                    _buildServiceCard(),

                    const SizedBox(height: 16),

                    // Details Section
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildSectionTitle('Event Details'),
                          _buildSimpleDetailRow('Event', eventName),
                          _buildSimpleDetailRow('Event Type', eventType),
                          _buildSimpleDetailRow(
                            'Event Date',
                            DateFormat('MMMM dd, yyyy').format(eventDate),
                          ),
                          _buildSimpleDetailRow('Client Name', clientName),
                          if (clientResponse.isNotEmpty)
                            _buildSimpleDetailRow(
                              'Message to Organizer',
                              clientResponse,
                            ),

                          const SizedBox(height: 16),
                          _buildSectionTitle('Color Scheme'),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              Expanded(
                                child: Container(
                                  height: 40,
                                  decoration: BoxDecoration(
                                    color: primaryColor,
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: const Center(
                                    child: Text(
                                      'Primary',
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: Container(
                                  height: 40,
                                  decoration: BoxDecoration(
                                    color: secondaryColor,
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: const Center(
                                    child: Text(
                                      'Secondary',
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),

                          const SizedBox(height: 16),
                          _buildSectionTitle('Payment Summary'),
                          _buildPaymentRow(
                            'Base Budget',
                            'PKR ${budget.toStringAsFixed(0)}',
                          ),
                          if (needsPhotographer)
                            _buildPaymentRow(
                              'Photographer',
                              'PKR ${photographerFee.toStringAsFixed(0)}',
                            ),
                          const Divider(),
                          _buildPaymentRow(
                            'Total Amount',
                            'PKR ${totalAmount.toStringAsFixed(0)}',
                            isBold: true,
                          ),

                          if (additionalNotes.isNotEmpty) ...[
                            const SizedBox(height: 16),
                            _buildSectionTitle('Additional Notes'),
                            const SizedBox(height: 8),
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                  color: const Color(
                                    0xFF9D9DCC,
                                  ).withOpacity(0.3),
                                ),
                              ),
                              child: Text(
                                additionalNotes,
                                style: const TextStyle(
                                  color: Color(0xFF6B6B8D),
                                  fontSize: 15,
                                ),
                              ),
                            ),
                          ],
                          const SizedBox(
                            height: 100,
                          ), // Space at bottom for fixed payment button
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            // Fixed bottom payment button
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 10,
                    offset: const Offset(0, -4),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text(
                        'Total Amount',
                        style: TextStyle(
                          color: Color(0xFF9D9DCC),
                          fontSize: 14,
                        ),
                      ),
                      Text(
                        'PKR ${totalAmount.toStringAsFixed(0)}',
                        style: const TextStyle(
                          color: Color(0xFF6B6B8D),
                          fontWeight: FontWeight.bold,
                          fontSize: 18,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: SizedBox(
                      height: 50,
                      child: ElevatedButton(
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder:
                                  (context) => PaymentScreen(
                                    portfolio: portfolio,
                                    eventName: eventName,
                                    eventType: eventType,
                                    eventDate: eventDate,
                                    budget: budget,
                                    photographerFee: photographerFee,
                                    totalAmount: totalAmount,
                                    primaryColor: primaryColor,
                                    secondaryColor: secondaryColor,
                                    needsPhotographer: needsPhotographer,
                                    clientResponse: clientResponse,
                                    additionalNotes: additionalNotes,
                                    clientId: clientId,
                                    clientName: clientName,
                                  ),
                            ),
                          );
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF9D9DCC),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(25),
                          ),
                        ),
                        child: const Text(
                          'Pay Now',
                          style: TextStyle(
                            fontSize: 16,
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildServiceCard() {
    return Container(
      margin: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: const Color(0xFF9D9DCC).withOpacity(0.2),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.event, color: Color(0xFF9D9DCC)),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        portfolio.title,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF6B6B8D),
                        ),
                      ),
                      Text(
                        'Event Organizer',
                        style: TextStyle(
                          fontSize: 14,
                          color: const Color(0xFF6B6B8D).withOpacity(0.7),
                        ),
                      ),
                    ],
                  ),
                ),
                Builder(
                  builder: (BuildContext context) {
                    return TextButton(
                      onPressed: () {
                        // Navigate to organizer search screen
                        Navigator.pushAndRemoveUntil(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const OrganizerSearchScreen(),
                          ),
                          (route) =>
                              route
                                  .isFirst, // Keep only the first route in stack
                        );
                      },
                      style: TextButton.styleFrom(
                        foregroundColor: const Color(0xFF9D9DCC),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(20),
                          side: const BorderSide(color: Color(0xFF9D9DCC)),
                        ),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                        minimumSize: Size.zero,
                      ),
                      child: const Text(
                        'Change',
                        style: TextStyle(fontSize: 12),
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.bold,
          color: Color(0xFF6B6B8D),
        ),
      ),
    );
  }

  Widget _buildSimpleDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: 2,
            child: Text(
              label,
              style: TextStyle(
                color: const Color(0xFF6B6B8D).withOpacity(0.7),
                fontSize: 14,
              ),
            ),
          ),
          Expanded(
            flex: 3,
            child: Text(
              value,
              style: const TextStyle(
                color: Color(0xFF6B6B8D),
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPaymentRow(String label, String amount, {bool isBold = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: isBold ? 16 : 14,
              fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
              color:
                  isBold
                      ? const Color(0xFF6B6B8D)
                      : const Color(0xFF6B6B8D).withOpacity(0.7),
            ),
          ),
          Text(
            amount,
            style: TextStyle(
              fontSize: isBold ? 16 : 14,
              fontWeight: isBold ? FontWeight.bold : FontWeight.w500,
              color: const Color(0xFF6B6B8D),
            ),
          ),
        ],
      ),
    );
  }
}
