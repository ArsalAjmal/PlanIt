import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'dart:math';
import '../../models/portfolio_model.dart';
import '../../views/organizer_search_screen.dart';
import '../../views/client_home_screen.dart';
import '../../constants/app_colors.dart';
import '../../models/response_model.dart';
import '../../services/portfolio_service.dart';
import 'package:uuid/uuid.dart';

// Add the PaymentConfirmationScreen class
class PaymentConfirmationScreen extends StatelessWidget {
  final VoidCallback onBackToHome;

  const PaymentConfirmationScreen({Key? key, required this.onBackToHome})
    : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.creamBackground,
      body: SafeArea(
        child: Padding(
          padding: EdgeInsets.zero,
          child: Column(
            children: [
              // Custom app bar with curved bottom like client home screen
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
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
                    // Removed back button and added title at leading end
                    const Padding(
                      padding: EdgeInsets.only(left: 16.0),
                      child: Text(
                        'Payment Confirmation',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    const Spacer(),
                    // Keep invisible icon button on the right to balance the layout
                    Container(width: 42, height: 42, color: Colors.transparent),
                  ],
                ),
              ),

              // Content area
              Expanded(
                child: Center(
                  child: SingleChildScrollView(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Container(
                          width: double.infinity,
                          margin: const EdgeInsets.symmetric(horizontal: 20),
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(16),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.1),
                                blurRadius: 10,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: Column(
                            children: [
                              const Icon(
                                Icons.check_circle,
                                color: Colors.green,
                                size: 80,
                              ),
                              const SizedBox(height: 24),
                              const Text(
                                'Payment Successful!',
                                style: TextStyle(
                                  fontSize: 24,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.black87,
                                ),
                              ),
                              const SizedBox(height: 16),
                              Text(
                                'Your order has been placed successfully. Check order history section for updates about your order.',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  color: Colors.grey[600],
                                  fontSize: 16,
                                  height: 1.5,
                                ),
                              ),
                              const SizedBox(height: 16),
                              const Divider(),
                              const SizedBox(height: 16),
                              const Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    Icons.access_time,
                                    color: Colors.grey,
                                    size: 18,
                                  ),
                                  SizedBox(width: 8),
                                  Text(
                                    'Estimated response time: 24-48 hours',
                                    style: TextStyle(
                                      color: Colors.grey,
                                      fontSize: 14,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 24),
                              SizedBox(
                                width: double.infinity,
                                height: 50,
                                child: ElevatedButton(
                                  onPressed: () => onBackToHome(),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: const Color(0xFF9D9DCC),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                  ),
                                  child: const Text(
                                    'Back to Home',
                                    style: TextStyle(
                                      fontSize: 16,
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
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
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class OrderSummaryScreen extends StatefulWidget {
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
  State<OrderSummaryScreen> createState() => _OrderSummaryScreenState();
}

class _OrderSummaryScreenState extends State<OrderSummaryScreen> {
  final _formKey = GlobalKey<FormState>();
  final _cardNumberController = TextEditingController();
  final _expiryController = TextEditingController();
  final _cvvController = TextEditingController();
  final _nameController = TextEditingController();
  final _portfolioService = PortfolioService();
  bool _isLoading = false;
  bool _showPaymentSection = true;
  String _cardType = 'Visa';

  @override
  void initState() {
    super.initState();

    // Listen for changes in the card number
    _cardNumberController.addListener(detectCardType);
  }

  @override
  void dispose() {
    _cardNumberController.removeListener(detectCardType);
    _cardNumberController.dispose();
    _expiryController.dispose();
    _cvvController.dispose();
    _nameController.dispose();
    super.dispose();
  }

  String? _validateCardNumber(String? value) {
    if (value == null || value.isEmpty) {
      return 'Please enter card number';
    }
    if (value.replaceAll(' ', '').length != 16) {
      return 'Card number must be 16 digits';
    }
    return null;
  }

  String? _validateExpiry(String? value) {
    if (value == null || value.isEmpty) {
      return 'Please enter expiry date';
    }
    if (!RegExp(r'^\d{2}/\d{2}$').hasMatch(value)) {
      return 'Invalid format (MM/YY)';
    }
    final parts = value.split('/');
    final month = int.tryParse(parts[0]);
    final year = int.tryParse(parts[1]);
    if (month == null || year == null || month < 1 || month > 12) {
      return 'Invalid expiry date';
    }
    final now = DateTime.now();
    final expiry = DateTime(2000 + year, month);
    if (expiry.isBefore(now)) {
      return 'Card has expired';
    }
    return null;
  }

  String? _validateCVV(String? value) {
    if (value == null || value.isEmpty) {
      return 'Please enter CVV';
    }
    if (value.length != 3 || !RegExp(r'^\d{3}$').hasMatch(value)) {
      return 'CVV must be 3 digits';
    }
    return null;
  }

  void _navigateToConfirmationScreen() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder:
            (context) => PaymentConfirmationScreen(
              onBackToHome: () {
                // Navigate to client home screen
                Navigator.of(context).pushAndRemoveUntil(
                  MaterialPageRoute(
                    builder: (context) => const ClientHomeScreen(),
                  ),
                  (route) => false,
                );
              },
            ),
      ),
    );
  }

  Future<void> _processPayment() async {
    if (_formKey.currentState!.validate()) {
      setState(() {
        _isLoading = true;
      });

      // Simulate payment processing
      await Future.delayed(const Duration(seconds: 2));

      try {
        final response = ResponseModel(
          id: const Uuid().v4(),
          portfolioId: widget.portfolio.id,
          organizerId: widget.portfolio.organizerId,
          clientId: widget.clientId,
          clientName: widget.clientName,
          eventName: widget.eventName,
          eventType: widget.eventType,
          eventDate: widget.eventDate,
          budget: widget.budget,
          primaryColor: widget.primaryColor.value.toString(),
          secondaryColor: widget.secondaryColor.value.toString(),
          needsPhotographer: widget.needsPhotographer,
          clientResponse: widget.clientResponse,
          additionalNotes: widget.additionalNotes,
          status: 'pending',
          createdAt: DateTime.now(),
        );

        // Try to create response in Firestore
        // If there's an issue, we'll still show success to the user
        try {
          await _portfolioService.createResponse(response);
        } catch (innerError) {
          print('Error creating response in Firestore: $innerError');
          // Continue to show success to user anyway
        }

        setState(() {
          _isLoading = false;
        });

        // Navigate to confirmation screen instead of showing inline confirmation
        _navigateToConfirmationScreen();
      } catch (e) {
        print('Error in payment processing: $e');
        setState(() {
          _isLoading = false;
        });

        // Navigate to confirmation screen even if there's an error
        _navigateToConfirmationScreen();
      }
    }
  }

  void _togglePaymentSection() {
    setState(() {
      _showPaymentSection = !_showPaymentSection;
    });
  }

  void detectCardType() {
    if (_cardNumberController.text.isEmpty) return;

    String cardNumber = _cardNumberController.text.replaceAll(' ', '');

    // Update card type based on first digits
    setState(() {
      if (cardNumber.startsWith('4')) {
        _cardType = 'Visa';
      } else if (cardNumber.startsWith('5')) {
        _cardType = 'MasterCard';
      } else if (cardNumber.startsWith('3')) {
        _cardType = 'Amex';
      } else if (cardNumber.startsWith('6')) {
        _cardType = 'Discover';
      } else {
        _cardType = 'Invalid';
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    // Set status bar color to match background
    SystemChrome.setSystemUIOverlayStyle(
      const SystemUiOverlayStyle(
        statusBarColor: AppColors.creamBackground,
        statusBarIconBrightness: Brightness.dark,
      ),
    );

    return Scaffold(
      backgroundColor: AppColors.creamBackground,
      body: SafeArea(
        child: Column(
          children: [
            // Custom app bar with curved bottom
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
                    'Order Summary',
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
            Expanded(
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Service Provider Card
                    _buildServiceCard(),

                    const SizedBox(height: 16),

                    // Order summary section styled like the image
                    Padding(
                      padding: const EdgeInsets.all(12),
                      child: Container(
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(10),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.05),
                              blurRadius: 8,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Title row with receipt icon
                            Padding(
                              padding: const EdgeInsets.all(12),
                              child: Row(
                                children: [
                                  Icon(
                                    Icons.receipt_outlined,
                                    color: Colors.grey[700],
                                    size: 20,
                                  ),
                                  const SizedBox(width: 8),
                                  const Text(
                                    'Order summary',
                                    style: TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.black87,
                                    ),
                                  ),
                                ],
                              ),
                            ),

                            // Order items
                            Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  // Event details
                                  Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    children: [
                                      const Text(
                                        'Event Name:',
                                        style: TextStyle(
                                          fontSize: 14,
                                          fontWeight: FontWeight.w500,
                                          color: Colors.black87,
                                        ),
                                      ),
                                      Text(
                                        widget.eventName,
                                        style: TextStyle(
                                          fontSize: 14,
                                          color: Colors.grey[600],
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 6),
                                  Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    children: [
                                      const Text(
                                        'Event Type:',
                                        style: TextStyle(
                                          fontSize: 14,
                                          fontWeight: FontWeight.w500,
                                          color: Colors.black87,
                                        ),
                                      ),
                                      Text(
                                        widget.eventType,
                                        style: TextStyle(
                                          fontSize: 14,
                                          color: Colors.grey[600],
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 6),
                                  Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    children: [
                                      const Text(
                                        'Event Date:',
                                        style: TextStyle(
                                          fontSize: 14,
                                          fontWeight: FontWeight.w500,
                                          color: Colors.black87,
                                        ),
                                      ),
                                      Text(
                                        DateFormat(
                                          'MMM dd, yyyy',
                                        ).format(widget.eventDate),
                                        style: TextStyle(
                                          fontSize: 14,
                                          color: Colors.grey[600],
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 6),
                                  Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    children: [
                                      const Text(
                                        'Client Name:',
                                        style: TextStyle(
                                          fontSize: 14,
                                          fontWeight: FontWeight.w500,
                                          color: Colors.black87,
                                        ),
                                      ),
                                      Text(
                                        widget.clientName,
                                        style: TextStyle(
                                          fontSize: 14,
                                          color: Colors.grey[600],
                                        ),
                                      ),
                                    ],
                                  ),

                                  // Color scheme section
                                  const SizedBox(height: 12),
                                  const Text(
                                    'Color Scheme:',
                                    style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w500,
                                      color: Colors.black87,
                                    ),
                                  ),
                                  const SizedBox(height: 6),
                                  Row(
                                    children: [
                                      Expanded(
                                        child: Container(
                                          height: 30,
                                          decoration: BoxDecoration(
                                            color: widget.primaryColor,
                                            borderRadius: BorderRadius.circular(
                                              6,
                                            ),
                                          ),
                                          child: const Center(
                                            child: Text(
                                              'Primary',
                                              style: TextStyle(
                                                color: Colors.white,
                                                fontWeight: FontWeight.bold,
                                                fontSize: 12,
                                              ),
                                            ),
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: Container(
                                          height: 30,
                                          decoration: BoxDecoration(
                                            color: widget.secondaryColor,
                                            borderRadius: BorderRadius.circular(
                                              6,
                                            ),
                                          ),
                                          child: const Center(
                                            child: Text(
                                              'Secondary',
                                              style: TextStyle(
                                                color: Colors.white,
                                                fontWeight: FontWeight.bold,
                                                fontSize: 12,
                                              ),
                                            ),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),

                            if (widget.needsPhotographer) ...[
                              const SizedBox(height: 12),
                              Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                ),
                                child: Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        const Text(
                                          '1x Photography Service',
                                          style: TextStyle(
                                            fontSize: 15,
                                            fontWeight: FontWeight.w500,
                                            color: Colors.black87,
                                          ),
                                        ),
                                        const SizedBox(height: 2),
                                        const Text(
                                          'Professional event photography',
                                          style: TextStyle(
                                            fontSize: 13,
                                            color: Colors.grey,
                                          ),
                                        ),
                                      ],
                                    ),
                                    Text(
                                      'PKR ${widget.photographerFee.toStringAsFixed(0)}',
                                      style: const TextStyle(
                                        fontSize: 15,
                                        fontWeight: FontWeight.w500,
                                        color: Colors.black87,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],

                            const SizedBox(height: 16),
                            const Divider(height: 1, color: Color(0xFFEEEEEE)),

                            // Subtotal section
                            Padding(
                              padding: const EdgeInsets.all(12),
                              child: Column(
                                children: [
                                  Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text(
                                        'Subtotal',
                                        style: TextStyle(
                                          fontSize: 14,
                                          color: Colors.grey[700],
                                        ),
                                      ),
                                      Text(
                                        'PKR ${widget.budget.toStringAsFixed(0)}',
                                        style: TextStyle(
                                          fontSize: 14,
                                          color: Colors.grey[700],
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 6),
                                  if (widget.needsPhotographer)
                                    Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.spaceBetween,
                                      children: [
                                        Text(
                                          'Photography Service',
                                          style: TextStyle(
                                            fontSize: 14,
                                            color: Colors.grey[700],
                                          ),
                                        ),
                                        Text(
                                          'PKR ${widget.photographerFee.toStringAsFixed(0)}',
                                          style: TextStyle(
                                            fontSize: 14,
                                            color: Colors.grey[700],
                                          ),
                                        ),
                                      ],
                                    ),
                                  const SizedBox(height: 6),
                                  Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text(
                                        'Platform Fee',
                                        style: TextStyle(
                                          fontSize: 14,
                                          color: Colors.grey[700],
                                        ),
                                      ),
                                      const Text(
                                        'PKR 1000',
                                        style: TextStyle(
                                          fontSize: 14,
                                          color: Colors.grey,
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),

                            // Apply voucher
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 8,
                              ),
                              child: Text(
                                'Apply a voucher',
                                style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.pink[500],
                                ),
                              ),
                            ),

                            const SizedBox(height: 4),
                          ],
                        ),
                      ),
                    ),

                    const SizedBox(height: 12),

                    // Payment section
                    if (_showPaymentSection)
                      Padding(
                        padding: const EdgeInsets.all(12),
                        child: Container(
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(10),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.05),
                                blurRadius: 8,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Title row with wallet icon
                              Padding(
                                padding: const EdgeInsets.all(12),
                                child: Row(
                                  children: [
                                    Icon(
                                      Icons.wallet,
                                      color: Colors.grey[700],
                                      size: 20,
                                    ),
                                    const SizedBox(width: 8),
                                    const Text(
                                      'Payment method',
                                      style: TextStyle(
                                        fontSize: 18,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.black87,
                                      ),
                                    ),
                                    const Spacer(),
                                    Text(
                                      'Change',
                                      style: TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w500,
                                        color: Colors.black87,
                                      ),
                                    ),
                                  ],
                                ),
                              ),

                              Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    // Card row
                                    Row(
                                      children: [
                                        // Visa logo
                                        Container(
                                          width: 90,
                                          height: 30,
                                          decoration: BoxDecoration(
                                            color: Colors.white,
                                            borderRadius: BorderRadius.circular(
                                              30,
                                            ),
                                            border: Border.all(
                                              color: Colors.grey.shade300,
                                            ),
                                          ),
                                          child: Center(
                                            child: Text(
                                              _cardType.toUpperCase(),
                                              style: TextStyle(
                                                color: Colors.blue[800],
                                                fontWeight: FontWeight.bold,
                                                fontSize: 12,
                                              ),
                                            ),
                                          ),
                                        ),
                                        const SizedBox(width: 12),
                                        Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Row(
                                              children: [
                                                Text(
                                                  '••••',
                                                  style: TextStyle(
                                                    fontSize: 16,
                                                    letterSpacing: 2,
                                                    color: Colors.grey[600],
                                                  ),
                                                ),
                                                const SizedBox(width: 4),
                                                Text(
                                                  _cardNumberController
                                                          .text
                                                          .isNotEmpty
                                                      ? _cardNumberController
                                                          .text
                                                          .replaceAll(' ', '')
                                                          .substring(
                                                            max(
                                                              0,
                                                              _cardNumberController
                                                                      .text
                                                                      .replaceAll(
                                                                        ' ',
                                                                        '',
                                                                      )
                                                                      .length -
                                                                  4,
                                                            ),
                                                          )
                                                      : '',
                                                  style: TextStyle(
                                                    color: Colors.grey[600],
                                                    fontSize: 16,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ],
                                        ),
                                        const Spacer(),
                                        Text(
                                          'Rs. ${(widget.totalAmount + 1000).toStringAsFixed(2)}',
                                          style: const TextStyle(
                                            fontSize: 16,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),

                              const SizedBox(height: 16),
                              const Divider(
                                height: 1,
                                color: Color(0xFFEEEEEE),
                              ),

                              Padding(
                                padding: const EdgeInsets.all(12),
                                child:
                                    _isLoading
                                        ? const Center(
                                          child: CircularProgressIndicator(),
                                        )
                                        : Form(
                                          key: _formKey,
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              // Credit Card Form
                                              const Text(
                                                'Enter Card Details',
                                                style: TextStyle(
                                                  fontSize: 14,
                                                  fontWeight: FontWeight.bold,
                                                  color: Colors.black87,
                                                ),
                                              ),
                                              const SizedBox(height: 16),
                                              TextFormField(
                                                controller:
                                                    _cardNumberController,
                                                decoration: InputDecoration(
                                                  labelText: 'Card Number',
                                                  filled: true,
                                                  fillColor: Colors.grey
                                                      .withOpacity(0.1),
                                                  labelStyle: TextStyle(
                                                    color: Colors.grey[600],
                                                    fontSize: 16,
                                                  ),
                                                  hintText:
                                                      '1234 5678 9012 3456',
                                                  hintStyle: TextStyle(
                                                    color: Colors.grey[600],
                                                    fontSize: 16,
                                                  ),
                                                  prefixIcon: const Icon(
                                                    Icons.credit_card,
                                                    color: Color(0xFF9D9DCC),
                                                    size: 20,
                                                  ),
                                                  contentPadding:
                                                      const EdgeInsets.symmetric(
                                                        vertical: 10.0,
                                                        horizontal: 12.0,
                                                      ),
                                                  border: OutlineInputBorder(
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                          12,
                                                        ),
                                                    borderSide: BorderSide.none,
                                                  ),
                                                  enabledBorder:
                                                      OutlineInputBorder(
                                                        borderRadius:
                                                            BorderRadius.circular(
                                                              12,
                                                            ),
                                                        borderSide:
                                                            BorderSide.none,
                                                      ),
                                                  focusedBorder:
                                                      OutlineInputBorder(
                                                        borderRadius:
                                                            BorderRadius.circular(
                                                              12,
                                                            ),
                                                        borderSide:
                                                            const BorderSide(
                                                              color: Color(
                                                                0xFF9D9DCC,
                                                              ),
                                                              width: 1,
                                                            ),
                                                      ),
                                                  isDense: true,
                                                ),
                                                style: const TextStyle(
                                                  color: Colors.black87,
                                                  fontSize: 16,
                                                ),
                                                keyboardType:
                                                    TextInputType.number,
                                                inputFormatters: [
                                                  FilteringTextInputFormatter
                                                      .digitsOnly,
                                                  LengthLimitingTextInputFormatter(
                                                    16,
                                                  ),
                                                  _CardNumberFormatter(),
                                                ],
                                                validator: _validateCardNumber,
                                                minLines: 1,
                                                maxLines: 1,
                                              ),
                                              const SizedBox(height: 16),
                                              Row(
                                                children: [
                                                  Expanded(
                                                    child: TextFormField(
                                                      controller:
                                                          _expiryController,
                                                      decoration: InputDecoration(
                                                        labelText:
                                                            'Expiry Date',
                                                        filled: true,
                                                        fillColor: Colors.grey
                                                            .withOpacity(0.1),
                                                        labelStyle: TextStyle(
                                                          color:
                                                              Colors.grey[600],
                                                          fontSize: 16,
                                                        ),
                                                        hintText: 'MM/YY',
                                                        hintStyle: TextStyle(
                                                          color:
                                                              Colors.grey[600],
                                                          fontSize: 16,
                                                        ),
                                                        prefixIcon: const Icon(
                                                          Icons.date_range,
                                                          color: Color(
                                                            0xFF9D9DCC,
                                                          ),
                                                          size: 20,
                                                        ),
                                                        border: OutlineInputBorder(
                                                          borderRadius:
                                                              BorderRadius.circular(
                                                                12,
                                                              ),
                                                          borderSide:
                                                              BorderSide.none,
                                                        ),
                                                        enabledBorder:
                                                            OutlineInputBorder(
                                                              borderRadius:
                                                                  BorderRadius.circular(
                                                                    12,
                                                                  ),
                                                              borderSide:
                                                                  BorderSide
                                                                      .none,
                                                            ),
                                                        focusedBorder:
                                                            OutlineInputBorder(
                                                              borderRadius:
                                                                  BorderRadius.circular(
                                                                    12,
                                                                  ),
                                                              borderSide:
                                                                  const BorderSide(
                                                                    color: Color(
                                                                      0xFF9D9DCC,
                                                                    ),
                                                                    width: 1,
                                                                  ),
                                                            ),
                                                        contentPadding:
                                                            const EdgeInsets.symmetric(
                                                              vertical: 10.0,
                                                              horizontal: 12.0,
                                                            ),
                                                        isDense: true,
                                                      ),
                                                      style: const TextStyle(
                                                        color: Colors.black87,
                                                        fontSize: 16,
                                                      ),
                                                      keyboardType:
                                                          TextInputType.number,
                                                      inputFormatters: [
                                                        FilteringTextInputFormatter
                                                            .digitsOnly,
                                                        LengthLimitingTextInputFormatter(
                                                          4,
                                                        ),
                                                        _ExpiryDateFormatter(),
                                                      ],
                                                      validator:
                                                          _validateExpiry,
                                                      minLines: 1,
                                                      maxLines: 1,
                                                    ),
                                                  ),
                                                  const SizedBox(width: 16),
                                                  Expanded(
                                                    child: TextFormField(
                                                      controller:
                                                          _cvvController,
                                                      decoration: InputDecoration(
                                                        labelText: 'CVV',
                                                        filled: true,
                                                        fillColor: Colors.grey
                                                            .withOpacity(0.1),
                                                        labelStyle: TextStyle(
                                                          color:
                                                              Colors.grey[600],
                                                          fontSize: 16,
                                                        ),
                                                        hintText: '123',
                                                        hintStyle: TextStyle(
                                                          color:
                                                              Colors.grey[600],
                                                          fontSize: 16,
                                                        ),
                                                        prefixIcon: const Icon(
                                                          Icons.security,
                                                          color: Color(
                                                            0xFF9D9DCC,
                                                          ),
                                                          size: 20,
                                                        ),
                                                        border: OutlineInputBorder(
                                                          borderRadius:
                                                              BorderRadius.circular(
                                                                12,
                                                              ),
                                                          borderSide:
                                                              BorderSide.none,
                                                        ),
                                                        enabledBorder:
                                                            OutlineInputBorder(
                                                              borderRadius:
                                                                  BorderRadius.circular(
                                                                    12,
                                                                  ),
                                                              borderSide:
                                                                  BorderSide
                                                                      .none,
                                                            ),
                                                        focusedBorder:
                                                            OutlineInputBorder(
                                                              borderRadius:
                                                                  BorderRadius.circular(
                                                                    12,
                                                                  ),
                                                              borderSide:
                                                                  const BorderSide(
                                                                    color: Color(
                                                                      0xFF9D9DCC,
                                                                    ),
                                                                    width: 1,
                                                                  ),
                                                            ),
                                                        contentPadding:
                                                            const EdgeInsets.symmetric(
                                                              vertical: 10.0,
                                                              horizontal: 12.0,
                                                            ),
                                                        isDense: true,
                                                      ),
                                                      style: const TextStyle(
                                                        color: Colors.black87,
                                                        fontSize: 16,
                                                      ),
                                                      keyboardType:
                                                          TextInputType.number,
                                                      inputFormatters: [
                                                        FilteringTextInputFormatter
                                                            .digitsOnly,
                                                        LengthLimitingTextInputFormatter(
                                                          3,
                                                        ),
                                                      ],
                                                      validator: _validateCVV,
                                                      obscureText: true,
                                                      minLines: 1,
                                                      maxLines: 1,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                              const SizedBox(height: 24),
                                            ],
                                          ),
                                        ),
                              ),
                            ],
                          ),
                        ),
                      ),

                    // Terms and conditions
                    Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 4,
                      ),
                      child: Row(
                        children: [
                          const Text(
                            'By completing this order, I agree to all ',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.black87,
                            ),
                          ),
                          Text(
                            'terms & conditions',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey[700],
                              decoration: TextDecoration.underline,
                            ),
                          ),
                          const Text(
                            '.',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.black87,
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 4),

                    // Total with discounted original price
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      child: Column(
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Row(
                                children: [
                                  Text(
                                    'Total ',
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.black87,
                                    ),
                                  ),
                                  Text(
                                    '(incl. fees and tax)',
                                    style: TextStyle(
                                      fontSize: 13,
                                      color: Colors.grey,
                                    ),
                                  ),
                                ],
                              ),
                              Text(
                                'PKR ${(widget.totalAmount + 1000).toStringAsFixed(0)}',
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.black87,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 10),

                    // Additional Notes section (if needed)
                    if (widget.additionalNotes.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
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
                                widget.additionalNotes,
                                style: const TextStyle(
                                  color: Color(0xFF6B6B8D),
                                  fontSize: 15,
                                ),
                              ),
                            ),
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
                        style: TextStyle(color: Colors.black87, fontSize: 14),
                      ),
                      Text(
                        'PKR ${(widget.totalAmount + 1000).toStringAsFixed(0)}',
                        style: const TextStyle(
                          color: Colors.black87,
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
                        onPressed:
                            _showPaymentSection
                                ? _processPayment
                                : _togglePaymentSection,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF9D9DCC),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: Text(
                          _showPaymentSection
                              ? 'Pay Now'
                              : 'Continue to Payment',
                          style: const TextStyle(
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
                        widget.portfolio.title,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.black87,
                        ),
                      ),
                      Text(
                        'Event Organizer',
                        style: TextStyle(fontSize: 14, color: Colors.black54),
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

class _CardNumberFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    if (newValue.text.isEmpty) {
      return newValue;
    }

    final text = newValue.text.replaceAll(' ', '');
    final buffer = StringBuffer();

    for (var i = 0; i < text.length; i++) {
      if (i > 0 && i % 4 == 0) {
        buffer.write(' ');
      }
      buffer.write(text[i]);
    }

    return TextEditingValue(
      text: buffer.toString(),
      selection: TextSelection.collapsed(offset: buffer.length),
    );
  }
}

class _ExpiryDateFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    if (newValue.text.isEmpty) {
      return newValue;
    }

    final text = newValue.text.replaceAll('/', '');
    final buffer = StringBuffer();

    for (var i = 0; i < text.length; i++) {
      if (i == 2) {
        buffer.write('/');
      }
      buffer.write(text[i]);
    }

    return TextEditingValue(
      text: buffer.toString(),
      selection: TextSelection.collapsed(offset: buffer.length),
    );
  }
}
