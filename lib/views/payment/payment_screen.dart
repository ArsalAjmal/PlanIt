import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../models/portfolio_model.dart';
import '../../models/response_model.dart';
import '../../services/portfolio_service.dart';
import '../../views/client_home_screen.dart';
import '../../constants/app_colors.dart';
import 'payment_success_screen.dart';
import 'package:uuid/uuid.dart';

class PaymentScreen extends StatefulWidget {
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

  const PaymentScreen({
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
  _PaymentScreenState createState() => _PaymentScreenState();
}

class _PaymentScreenState extends State<PaymentScreen> {
  final _formKey = GlobalKey<FormState>();
  final _cardNumberController = TextEditingController();
  final _expiryController = TextEditingController();
  final _cvvController = TextEditingController();
  final _nameController = TextEditingController();
  final _portfolioService = PortfolioService();
  bool _isLoading = false;

  @override
  void dispose() {
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

  String _formatCardNumber(String value) {
    if (value.isEmpty) return '';
    value = value.replaceAll(' ', '');
    final result = StringBuffer();
    for (int i = 0; i < value.length; i++) {
      if (i > 0 && i % 4 == 0) {
        result.write(' ');
      }
      result.write(value[i]);
    }
    return result.toString();
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

        // Print detailed information about the response we're creating
        print('===== CREATING NEW RESPONSE =====');
        print('Response ID: ${response.id}');
        print('Portfolio ID: ${response.portfolioId}');
        print('Organizer ID: ${response.organizerId}');
        print('Client ID: ${response.clientId}');
        print('Client Name: ${response.clientName}');
        print('Event Name: ${response.eventName}');
        print('Event Type: ${response.eventType}');
        print('Event Date: ${response.eventDate}');
        print('Budget: ${response.budget}');
        print('Status: ${response.status}');
        print('Created At: ${response.createdAt}');
        print('================================');

        await _portfolioService.createResponse(response);
        print('Successfully created response in Firestore');

        // Navigate to success screen with confetti animation
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(
            builder:
                (context) => PaymentSuccessScreen(eventName: widget.eventName),
          ),
          (route) => false,
        );
      } catch (e) {
        print('Error submitting payment: $e');
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Error processing payment'),
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
                    'Payment',
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
              child:
                  _isLoading
                      ? const Center(child: CircularProgressIndicator())
                      : SingleChildScrollView(
                        padding: const EdgeInsets.all(16),
                        child: Form(
                          key: _formKey,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Container(
                                padding: const EdgeInsets.all(16),
                                decoration: BoxDecoration(
                                  color: Colors.grey[100],
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    const Text(
                                      'Total Amount:',
                                      style: TextStyle(
                                        fontSize: 18,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    Text(
                                      'PKR ${widget.totalAmount.toStringAsFixed(0)}',
                                      style: const TextStyle(
                                        fontSize: 18,
                                        fontWeight: FontWeight.bold,
                                        color: Color(0xFF9D9DCC),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 24),
                              const Text(
                                'Credit Card Details',
                                style: TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 16),
                              TextFormField(
                                controller: _cardNumberController,
                                decoration: InputDecoration(
                                  labelText: 'Card Number',
                                  filled: true,
                                  fillColor: Colors.white,
                                  labelStyle: const TextStyle(
                                    color: Color(0xFF9D9DCC),
                                  ),
                                  hintText: '1234 5678 9012 3456',
                                  hintStyle: TextStyle(
                                    color: const Color(
                                      0xFF9D9DCC,
                                    ).withOpacity(0.6),
                                    fontSize: 16,
                                  ),
                                  prefixIcon: const Icon(
                                    Icons.credit_card,
                                    color: Color(0xFF9D9DCC),
                                  ),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                ),
                                style: const TextStyle(
                                  color: Color(0xFF6B6B8D),
                                  fontSize: 16,
                                ),
                                keyboardType: TextInputType.number,
                                inputFormatters: [
                                  FilteringTextInputFormatter.digitsOnly,
                                  LengthLimitingTextInputFormatter(16),
                                  _CardNumberFormatter(),
                                ],
                                validator: _validateCardNumber,
                              ),
                              const SizedBox(height: 16),
                              Row(
                                children: [
                                  Expanded(
                                    child: TextFormField(
                                      controller: _expiryController,
                                      decoration: InputDecoration(
                                        labelText: 'Expiry Date',
                                        filled: true,
                                        fillColor: Colors.white,
                                        labelStyle: const TextStyle(
                                          color: Color(0xFF9D9DCC),
                                        ),
                                        hintText: 'MM/YY',
                                        hintStyle: TextStyle(
                                          color: const Color(
                                            0xFF9D9DCC,
                                          ).withOpacity(0.6),
                                          fontSize: 16,
                                        ),
                                        prefixIcon: const Icon(
                                          Icons.date_range,
                                          color: Color(0xFF9D9DCC),
                                        ),
                                        border: OutlineInputBorder(
                                          borderRadius: BorderRadius.circular(
                                            12,
                                          ),
                                        ),
                                      ),
                                      style: const TextStyle(
                                        color: Color(0xFF6B6B8D),
                                        fontSize: 16,
                                      ),
                                      keyboardType: TextInputType.number,
                                      inputFormatters: [
                                        FilteringTextInputFormatter.digitsOnly,
                                        LengthLimitingTextInputFormatter(4),
                                        _ExpiryDateFormatter(),
                                      ],
                                      validator: _validateExpiry,
                                    ),
                                  ),
                                  const SizedBox(width: 16),
                                  Expanded(
                                    child: TextFormField(
                                      controller: _cvvController,
                                      decoration: InputDecoration(
                                        labelText: 'CVV',
                                        filled: true,
                                        fillColor: Colors.white,
                                        labelStyle: const TextStyle(
                                          color: Color(0xFF9D9DCC),
                                        ),
                                        hintText: '123',
                                        hintStyle: TextStyle(
                                          color: const Color(
                                            0xFF9D9DCC,
                                          ).withOpacity(0.6),
                                          fontSize: 16,
                                        ),
                                        prefixIcon: const Icon(
                                          Icons.security,
                                          color: Color(0xFF9D9DCC),
                                        ),
                                        border: OutlineInputBorder(
                                          borderRadius: BorderRadius.circular(
                                            12,
                                          ),
                                        ),
                                      ),
                                      style: const TextStyle(
                                        color: Color(0xFF6B6B8D),
                                        fontSize: 16,
                                      ),
                                      keyboardType: TextInputType.number,
                                      inputFormatters: [
                                        FilteringTextInputFormatter.digitsOnly,
                                        LengthLimitingTextInputFormatter(3),
                                      ],
                                      validator: _validateCVV,
                                      obscureText: true,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 32),
                              SizedBox(
                                width: double.infinity,
                                child: ElevatedButton(
                                  onPressed: _processPayment,
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: const Color(0xFF9D9DCC),
                                    padding: const EdgeInsets.symmetric(
                                      vertical: 16,
                                    ),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                  ),
                                  child: const Text(
                                    'Confirm Payment',
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
                      ),
            ),
          ],
        ),
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
