import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_colorpicker/flutter_colorpicker.dart';
import '../../models/portfolio_model.dart';
import '../../models/response_model.dart';
import '../../services/portfolio_service.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';
import '../payment/order_summary_screen.dart';
import '../../constants/app_colors.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../widgets/firestore_image.dart' as fw;

class PortfolioResponseScreen extends StatefulWidget {
  final PortfolioModel portfolio;
  final String clientId;
  final String clientName;

  const PortfolioResponseScreen({
    Key? key,
    required this.portfolio,
    required this.clientId,
    required this.clientName,
  }) : super(key: key);

  @override
  _PortfolioResponseScreenState createState() =>
      _PortfolioResponseScreenState();
}

class _PortfolioResponseScreenState extends State<PortfolioResponseScreen> {
  final _formKey = GlobalKey<FormState>();
  final _clientNameController = TextEditingController();
  final _eventNameController = TextEditingController();
  final _budgetController = TextEditingController();
  final _notesController = TextEditingController();
  final _addressController = TextEditingController();
  final _apartmentController = TextEditingController();
  final _cityController = TextEditingController();
  final _phoneController = TextEditingController();
  final _portfolioService = PortfolioService();
  DateTime? _selectedDate;
  String _selectedEventType = '';
  Color _primaryColor = Colors.blue;
  Color _secondaryColor = Colors.green;
  bool _needsPhotographer = false;
  bool _isLoading = false;
  final double _photographerFee = 25000.0; // PKR 25,000 for photographer
  String _selectedCountryCode = '+92'; // Default to Pakistan
  String? _phoneErrorText; // Track phone validation error

  // Country codes list
  final List<Map<String, dynamic>> _countryCodes = [
    {
      'code': '+92',
      'name': 'Pakistan',
      'flag': '🇵🇰',
      'digits': 10,
      'pattern': 'Starting with 3',
    },
    {
      'code': '+91',
      'name': 'India',
      'flag': '🇮🇳',
      'digits': 10,
      'pattern': 'Starting with 6, 7, 8, or 9',
    },
    {
      'code': '+1',
      'name': 'USA',
      'flag': '🇺🇸',
      'digits': 10,
      'pattern': 'Area code + 7 digits',
    },
    {
      'code': '+44',
      'name': 'UK',
      'flag': '🇬🇧',
      'digits': 10,
      'pattern': 'Without leading 0',
    },
    {
      'code': '+971',
      'name': 'UAE',
      'flag': '🇦🇪',
      'digits': 9,
      'pattern': 'Starting with 2, 4, or 5',
    },
    {
      'code': '+966',
      'name': 'Saudi Arabia',
      'flag': '🇸🇦',
      'digits': 9,
      'pattern': 'Starting with 5 for mobile',
    },
  ];

  // Get expected phone digit length based on country code
  int get _expectedPhoneDigits {
    final country = _countryCodes.firstWhere(
      (country) => country['code'] == _selectedCountryCode,
      orElse: () => {'digits': 10},
    );
    return country['digits'] as int;
  }

  // For rating and event count caching
  double _portfolioRating = 0.0;
  int _eventCount = 0;
  bool _loadingRating = true;

  @override
  void initState() {
    super.initState();
    _clientNameController.text = widget.clientName; // Pre-fill with user's name
    _portfolioRating = widget.portfolio.rating;
    _eventCount = widget.portfolio.totalEvents;
    _loadPortfolioRating();

    // Add listener for phone validation
    _phoneController.addListener(_validatePhoneOnChange);
  }

  Future<void> _loadPortfolioRating() async {
    setState(() {
      _loadingRating = true;
    });

    try {
      // Get portfolio rating
      final ratingSnapshot =
          await FirebaseFirestore.instance
              .collection('reviews')
              .where('portfolioId', isEqualTo: widget.portfolio.id)
              .get();

      double totalRating = 0;
      if (ratingSnapshot.docs.isNotEmpty) {
        for (var doc in ratingSnapshot.docs) {
          totalRating += (doc.data()['rating'] as num).toDouble();
        }
        _portfolioRating = totalRating / ratingSnapshot.docs.length;
      }

      // Get event count
      final eventSnapshot =
          await FirebaseFirestore.instance
              .collection('responses')
              .where('portfolioId', isEqualTo: widget.portfolio.id)
              .where('status', isEqualTo: 'completed')
              .get();

      _eventCount = eventSnapshot.docs.length;

      if (mounted) {
        setState(() {
          _loadingRating = false;
        });
      }
    } catch (e) {
      print('Error loading portfolio rating: $e');
      if (mounted) {
        setState(() {
          _loadingRating = false;
        });
      }
    }
  }

  @override
  void dispose() {
    _clientNameController.dispose();
    _eventNameController.dispose();
    _budgetController.dispose();
    _notesController.dispose();
    _addressController.dispose();
    _apartmentController.dispose();
    _cityController.dispose();
    _phoneController.removeListener(_validatePhoneOnChange);
    _phoneController.dispose();
    super.dispose();
  }

  Future<void> _selectDate() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      builder: (BuildContext context, Widget? child) {
        return Theme(
          data: ThemeData.light().copyWith(
            colorScheme: const ColorScheme.light(
              primary: Color(0xFF9D9DCC),
              onPrimary: Colors.white,
              surface: Colors.white,
              onSurface: Colors.black87, // Ensures calendar date text is black
            ),
            dialogBackgroundColor: Colors.white,
            textTheme: Theme.of(context).textTheme.copyWith(
              bodyMedium: const TextStyle(color: Colors.black87),
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null) {
      setState(() {
        _selectedDate = picked;
      });
    }
  }

  double _calculateTotalAmount() {
    double total = double.parse(_budgetController.text);
    if (_needsPhotographer) {
      total += _photographerFee;
    }
    return total;
  }

  Future<void> _submitResponse() async {
    if (_formKey.currentState!.validate() && _selectedDate != null) {
      final totalAmount = _calculateTotalAmount();

      // Clean up phone number and format with country code
      final cleanedPhone = _phoneController.text;
      final formattedPhone = '$_selectedCountryCode$cleanedPhone';

      Navigator.push(
        context,
        MaterialPageRoute(
          builder:
              (context) => OrderSummaryScreen(
                portfolio: widget.portfolio,
                eventName: _eventNameController.text,
                eventType: _selectedEventType,
                eventDate: _selectedDate!,
                budget: double.parse(_budgetController.text),
                photographerFee: _needsPhotographer ? _photographerFee : 0,
                totalAmount: totalAmount,
                primaryColor: _primaryColor,
                secondaryColor: _secondaryColor,
                needsPhotographer: _needsPhotographer,
                clientResponse: '',
                additionalNotes: _notesController.text,
                clientId: widget.clientId,
                clientName: _clientNameController.text,
                address: _addressController.text,
                apartment: _apartmentController.text,
                city: _cityController.text,
                phoneNumber: formattedPhone,
              ),
        ),
      );
    }
  }

  void _showColorPicker(bool isPrimary) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('Pick ${isPrimary ? 'Primary' : 'Secondary'} Color'),
          content: SingleChildScrollView(
            child: ColorPicker(
              pickerColor: isPrimary ? _primaryColor : _secondaryColor,
              onColorChanged: (color) {
                setState(() {
                  if (isPrimary) {
                    _primaryColor = color;
                  } else {
                    _secondaryColor = color;
                  }
                });
              },
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Done'),
            ),
          ],
        );
      },
    );
  }

  String _getPhoneHint() {
    final country = _countryCodes.firstWhere(
      (country) => country['code'] == _selectedCountryCode,
      orElse: () => {'pattern': 'Unknown'},
    );
    return country['pattern'] as String;
  }

  // Validates phone number on change and updates error text
  void _validatePhoneOnChange() {
    if (_phoneController.text.isEmpty) {
      setState(() {
        _phoneErrorText = null;
      });
      return;
    }

    // Get digits only (should be the same as text now that we removed spacing)
    final digitsOnly = _phoneController.text;

    // Get country-specific validation rules
    final country = _countryCodes.firstWhere(
      (c) => c['code'] == _selectedCountryCode,
      orElse: () => {'digits': 10, 'name': 'Unknown'},
    );

    final expectedDigits = country['digits'] as int;
    bool isValid = true;

    // Check for invalid starting digits early on
    if (digitsOnly.isNotEmpty) {
      // Pakistan mobile validation
      if (_selectedCountryCode == '+92' && !digitsOnly.startsWith('3')) {
        isValid = false;
      }
      // India mobile validation
      else if (_selectedCountryCode == '+91' &&
          digitsOnly.isNotEmpty &&
          !digitsOnly.startsWith('9') &&
          !digitsOnly.startsWith('8') &&
          !digitsOnly.startsWith('7') &&
          !digitsOnly.startsWith('6')) {
        isValid = false;
      }
      // UAE number validation
      else if (_selectedCountryCode == '+971' &&
          digitsOnly.isNotEmpty &&
          !digitsOnly.startsWith('5') &&
          !digitsOnly.startsWith('4') &&
          !digitsOnly.startsWith('2')) {
        isValid = false;
      }
      // Saudi Arabia validation
      else if (_selectedCountryCode == '+966' &&
          digitsOnly.isNotEmpty &&
          !digitsOnly.startsWith('5')) {
        isValid = false;
      }
    }

    // Handle length validation
    if (isValid) {
      if (digitsOnly.length < expectedDigits) {
        // No error yet, still typing
        isValid = false; // Not valid until we have enough digits
      } else if (digitsOnly.length > expectedDigits) {
        isValid = false;
      }
    }

    // Set a simple, consistent error message
    String? error = isValid ? null : "Invalid phone number";

    setState(() {
      _phoneErrorText = error;
    });
  }

  bool _isPhoneValid() {
    if (_phoneController.text.isEmpty) {
      return false;
    }

    // Check if there are no validation errors and the phone number is complete
    final digitsOnly = _phoneController.text;
    final country = _countryCodes.firstWhere(
      (c) => c['code'] == _selectedCountryCode,
      orElse: () => {'digits': 10, 'name': 'Unknown'},
    );
    final expectedDigits = country['digits'] as int;

    // Must have right number of digits and no error text
    return digitsOnly.length == expectedDigits && _phoneErrorText == null;
  }

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
                    'Placing Order',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.refresh, color: Colors.white),
                    onPressed: _loadPortfolioRating,
                  ),
                ],
              ),
            ),

            // Main content with everything scrollable
            Expanded(
              child:
                  _isLoading
                      ? const Center(
                        child: CircularProgressIndicator(
                          color: Color(0xFF9D9DCC),
                        ),
                      )
                      : SingleChildScrollView(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Food delivery style header
                            Column(
                              children: [
                                // Central portfolio image
                                Container(
                                  width:
                                      double.infinity, // Full width with margin
                                  height: 140, // Slightly increased height
                                  margin: const EdgeInsets.fromLTRB(
                                    16,
                                    16,
                                    16,
                                    0,
                                  ), // Added horizontal margins
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(16),
                                    border: Border.all(
                                      color: Colors.white,
                                      width: 3,
                                    ),
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.black.withOpacity(0.1),
                                        blurRadius: 8,
                                        offset: const Offset(0, 2),
                                      ),
                                    ],
                                  ),
                                  child: ClipRRect(
                                    borderRadius: BorderRadius.circular(14),
                                    child:
                                        widget.portfolio.imageUrls.isNotEmpty
                                            ? fw.FirestoreImage(
                                              imageUrl:
                                                  widget.portfolio.imageUrls[0],
                                              fit: BoxFit.cover,
                                            )
                                            : Container(
                                              color: const Color(
                                                0xFF9D9DCC,
                                              ).withOpacity(0.2),
                                              child: const Center(
                                                child: Icon(
                                                  Icons
                                                      .image_not_supported_outlined,
                                                  color: Color(0xFF9D9DCC),
                                                  size: 36,
                                                ),
                                              ),
                                            ),
                                  ),
                                ),

                                const SizedBox(height: 12),

                                // Portfolio title (like restaurant name)
                                Text(
                                  widget.portfolio.title,
                                  style: const TextStyle(
                                    fontSize: 22,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.black87,
                                  ),
                                  textAlign: TextAlign.center,
                                ),

                                const SizedBox(height: 6),

                                // Rating display
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children:
                                      _loadingRating
                                          ? [
                                            SizedBox(
                                              width: 16,
                                              height: 16,
                                              child: CircularProgressIndicator(
                                                strokeWidth: 2,
                                                color: Colors.amber,
                                              ),
                                            ),
                                            const SizedBox(width: 6),
                                            Text(
                                              "Loading...",
                                              style: const TextStyle(
                                                fontSize: 14,
                                                fontWeight: FontWeight.w500,
                                                color: Colors.black54,
                                              ),
                                            ),
                                          ]
                                          : [
                                            ...List.generate(5, (index) {
                                              return Icon(
                                                index < _portfolioRating.floor()
                                                    ? Icons.star
                                                    : index < _portfolioRating
                                                    ? Icons.star_half
                                                    : Icons.star_border,
                                                color: Colors.amber,
                                                size: 18,
                                              );
                                            }),
                                            const SizedBox(width: 6),
                                            Text(
                                              "${_portfolioRating.toStringAsFixed(1)} (${_eventCount}${_eventCount > 0 ? '+' : ''} ratings)",
                                              style: const TextStyle(
                                                fontSize: 14,
                                                fontWeight: FontWeight.w500,
                                                color: Colors.black54,
                                              ),
                                            ),
                                          ],
                                ),

                                const SizedBox(height: 16),

                                // Fast Delivery list tile with green background
                                Padding(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 16,
                                  ),
                                  child: Container(
                                    decoration: BoxDecoration(
                                      color: Colors.green.withOpacity(0.1),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: ListTile(
                                      leading: Container(
                                        padding: const EdgeInsets.all(8),
                                        decoration: BoxDecoration(
                                          color: Colors.white,
                                          borderRadius: BorderRadius.circular(
                                            8,
                                          ),
                                        ),
                                        child: const Icon(
                                          Icons.delivery_dining,
                                          color: Colors.green,
                                          size: 20,
                                        ),
                                      ),
                                      title: const Text(
                                        "Fast Delivery",
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          color: Colors.black87,
                                        ),
                                      ),
                                      subtitle: const Text(
                                        "Planning completed in 7 days",
                                        style: TextStyle(color: Colors.black54),
                                      ),
                                      dense: true,
                                      contentPadding:
                                          const EdgeInsets.symmetric(
                                            horizontal: 16,
                                            vertical: 4,
                                          ),
                                    ),
                                  ),
                                ),

                                const SizedBox(height: 8),

                                // Promotions in same row as separate list tiles
                                Padding(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 16,
                                  ),
                                  child: Row(
                                    children: [
                                      // PlanIt Pro discount with orange background
                                      Expanded(
                                        child: Container(
                                          decoration: BoxDecoration(
                                            color: Colors.orange.withOpacity(
                                              0.1,
                                            ),
                                            borderRadius: BorderRadius.circular(
                                              8,
                                            ),
                                          ),
                                          child: ListTile(
                                            leading: Container(
                                              padding: const EdgeInsets.all(6),
                                              decoration: BoxDecoration(
                                                color: Colors.white,
                                                borderRadius:
                                                    BorderRadius.circular(6),
                                              ),
                                              child: const Icon(
                                                Icons.workspace_premium,
                                                color: Colors.orange,
                                                size: 18,
                                              ),
                                            ),
                                            title: const Text(
                                              "30% OFF",
                                              style: TextStyle(
                                                fontWeight: FontWeight.bold,
                                                fontSize: 13,
                                                color: Colors.black87,
                                              ),
                                            ),
                                            subtitle: const Text(
                                              "PlanIt Pro",
                                              style: TextStyle(
                                                fontSize: 12,
                                                color: Colors.black54,
                                              ),
                                            ),
                                            dense: true,
                                            contentPadding:
                                                const EdgeInsets.symmetric(
                                                  horizontal: 8,
                                                  vertical: 4,
                                                ),
                                          ),
                                        ),
                                      ),

                                      const SizedBox(width: 8),

                                      // Minimum order discount with purple background
                                      Expanded(
                                        child: Container(
                                          decoration: BoxDecoration(
                                            color: Colors.purple.withOpacity(
                                              0.1,
                                            ),
                                            borderRadius: BorderRadius.circular(
                                              8,
                                            ),
                                          ),
                                          child: ListTile(
                                            leading: Container(
                                              padding: const EdgeInsets.all(6),
                                              decoration: BoxDecoration(
                                                color: Colors.white,
                                                borderRadius:
                                                    BorderRadius.circular(6),
                                              ),
                                              child: const Icon(
                                                Icons.local_offer,
                                                color: Colors.purple,
                                                size: 18,
                                              ),
                                            ),
                                            title: const Text(
                                              "35% OFF",
                                              style: TextStyle(
                                                fontWeight: FontWeight.bold,
                                                fontSize: 13,
                                                color: Colors.black87,
                                              ),
                                            ),
                                            subtitle: const Text(
                                              "Min. 50,000",
                                              style: TextStyle(
                                                fontSize: 12,
                                                color: Colors.black54,
                                              ),
                                            ),
                                            dense: true,
                                            contentPadding:
                                                const EdgeInsets.symmetric(
                                                  horizontal: 8,
                                                  vertical: 4,
                                                ),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),

                                const SizedBox(height: 16),
                              ],
                            ),

                            // Form content - add it back
                            Padding(
                              padding: const EdgeInsets.all(16),
                              child: Form(
                                key: _formKey,
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    // Personal Details Section
                                    Padding(
                                      padding: const EdgeInsets.only(
                                        bottom: 12,
                                        top: 8,
                                      ),
                                      child: Row(
                                        children: [
                                          Container(
                                            width: 3,
                                            height: 20,
                                            decoration: BoxDecoration(
                                              color: Colors.black87,
                                              borderRadius:
                                                  BorderRadius.circular(1.5),
                                            ),
                                          ),
                                          const SizedBox(width: 8),
                                          const Text(
                                            "Personal Details",
                                            style: TextStyle(
                                              fontSize: 16,
                                              fontWeight: FontWeight.bold,
                                              color: Colors.black87,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),

                                    TextFormField(
                                      controller: _clientNameController,
                                      decoration: InputDecoration(
                                        labelText: 'Your Name',
                                        hintText: 'Enter your name',
                                        hintStyle: TextStyle(
                                          color: Colors.grey[600],
                                          fontSize: 16,
                                        ),
                                        filled: true,
                                        fillColor: Colors.grey.withOpacity(0.1),
                                        labelStyle: TextStyle(
                                          color: Colors.grey[600],
                                          fontSize: 16,
                                        ),
                                        prefixIcon: const Icon(
                                          Icons.person_outline,
                                          color: Color(0xFF9D9DCC),
                                          size: 20,
                                        ),
                                        contentPadding:
                                            const EdgeInsets.symmetric(
                                              vertical: 10.0,
                                              horizontal: 12.0,
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
                                      style: const TextStyle(
                                        color: Colors.black87,
                                        fontSize: 16,
                                      ),
                                      validator: (value) {
                                        if (value == null || value.isEmpty) {
                                          return 'Please enter your name';
                                        }
                                        return null;
                                      },
                                    ),

                                    const SizedBox(height: 16),

                                    // Phone Number Field with Country Code
                                    Row(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        // Country code dropdown
                                        Container(
                                          decoration: BoxDecoration(
                                            color: Colors.grey.withOpacity(0.1),
                                            borderRadius: BorderRadius.circular(
                                              12,
                                            ),
                                          ),
                                          width: 120,
                                          child: DropdownButtonFormField<
                                            String
                                          >(
                                            decoration: InputDecoration(
                                              contentPadding:
                                                  const EdgeInsets.symmetric(
                                                    horizontal: 10,
                                                    vertical: 10,
                                                  ),
                                              border: OutlineInputBorder(
                                                borderRadius:
                                                    BorderRadius.circular(12),
                                                borderSide: BorderSide.none,
                                              ),
                                              enabledBorder: OutlineInputBorder(
                                                borderRadius:
                                                    BorderRadius.circular(12),
                                                borderSide: BorderSide.none,
                                              ),
                                              focusedBorder: OutlineInputBorder(
                                                borderRadius:
                                                    BorderRadius.circular(12),
                                                borderSide: const BorderSide(
                                                  color: Color(0xFF9D9DCC),
                                                  width: 1,
                                                ),
                                              ),
                                            ),
                                            value: _selectedCountryCode,
                                            items:
                                                _countryCodes.map((country) {
                                                  return DropdownMenuItem<
                                                    String
                                                  >(
                                                    value: country['code'],
                                                    child: Row(
                                                      mainAxisSize:
                                                          MainAxisSize.min,
                                                      children: [
                                                        Text(country['flag']),
                                                        const SizedBox(
                                                          width: 4,
                                                        ),
                                                        Text(country['code']),
                                                      ],
                                                    ),
                                                  );
                                                }).toList(),
                                            onChanged: (value) {
                                              if (value != null) {
                                                setState(() {
                                                  _selectedCountryCode = value;
                                                  // Clear phone field when country changes
                                                  _phoneController.clear();
                                                  // Clear error text
                                                  _phoneErrorText = null;
                                                });
                                              }
                                            },
                                            dropdownColor: Colors.white,
                                          ),
                                        ),

                                        const SizedBox(width: 8),

                                        // Phone number field
                                        Expanded(
                                          child: TextFormField(
                                            controller: _phoneController,
                                            decoration: InputDecoration(
                                              labelText: 'Phone Number',
                                              hintText: _getPhoneHint(),
                                              hintStyle: TextStyle(
                                                color: Colors.grey[600],
                                                fontSize: 16,
                                              ),
                                              filled: true,
                                              fillColor: Colors.grey
                                                  .withOpacity(0.1),
                                              labelStyle: TextStyle(
                                                color: Colors.grey[600],
                                                fontSize: 16,
                                              ),
                                              prefixIcon: const Icon(
                                                Icons.phone,
                                                color: Color(0xFF9D9DCC),
                                                size: 20,
                                              ),
                                              suffixIcon:
                                                  _isPhoneValid()
                                                      ? const Icon(
                                                        Icons.check_circle,
                                                        color: Colors.green,
                                                        size: 20,
                                                      )
                                                      : null,
                                              contentPadding:
                                                  const EdgeInsets.symmetric(
                                                    vertical: 10.0,
                                                    horizontal: 12.0,
                                                  ),
                                              border: OutlineInputBorder(
                                                borderRadius:
                                                    BorderRadius.circular(12),
                                                borderSide: BorderSide.none,
                                              ),
                                              enabledBorder: OutlineInputBorder(
                                                borderRadius:
                                                    BorderRadius.circular(12),
                                                borderSide: BorderSide.none,
                                              ),
                                              focusedBorder: OutlineInputBorder(
                                                borderRadius:
                                                    BorderRadius.circular(12),
                                                borderSide: const BorderSide(
                                                  color: Color(0xFF9D9DCC),
                                                  width: 1,
                                                ),
                                              ),
                                              errorText: _phoneErrorText,
                                              isDense: true,
                                            ),
                                            keyboardType: TextInputType.phone,
                                            style: const TextStyle(
                                              color: Colors.black87,
                                              fontSize: 16,
                                            ),
                                            inputFormatters: [
                                              PhoneNumberInputFormatter(
                                                _expectedPhoneDigits,
                                              ),
                                            ],
                                            validator: (value) {
                                              if (value == null ||
                                                  value.isEmpty) {
                                                return 'Please enter your phone number';
                                              }

                                              // Simply validate the phone number according to our real-time validation
                                              final digitsOnly = value
                                                  .replaceAll(
                                                    RegExp(r'\D'),
                                                    '',
                                                  );

                                              // Get expected digits for this country
                                              final expectedDigits =
                                                  _countryCodes.firstWhere(
                                                        (c) =>
                                                            c['code'] ==
                                                            _selectedCountryCode,
                                                        orElse:
                                                            () => {
                                                              'digits': 10,
                                                            },
                                                      )['digits']
                                                      as int;

                                              // Check if the length matches
                                              if (digitsOnly.length !=
                                                  expectedDigits) {
                                                return 'Invalid phone number';
                                              }

                                              // Return the current error text if there is one
                                              return _phoneErrorText;
                                            },
                                          ),
                                        ),
                                      ],
                                    ),

                                    const SizedBox(height: 16),

                                    // Event Details Section
                                    Padding(
                                      padding: const EdgeInsets.only(
                                        bottom: 12,
                                        top: 8,
                                      ),
                                      child: Row(
                                        children: [
                                          Container(
                                            width: 3,
                                            height: 20,
                                            decoration: BoxDecoration(
                                              color: Colors.black87,
                                              borderRadius:
                                                  BorderRadius.circular(1.5),
                                            ),
                                          ),
                                          const SizedBox(width: 8),
                                          const Text(
                                            "Event Details",
                                            style: TextStyle(
                                              fontSize: 16,
                                              fontWeight: FontWeight.bold,
                                              color: Colors.black87,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),

                                    TextFormField(
                                      controller: _eventNameController,
                                      decoration: InputDecoration(
                                        labelText: 'Event Name',
                                        hintText: 'Enter event name',
                                        hintStyle: TextStyle(
                                          color: Colors.grey[600],
                                          fontSize: 16,
                                        ),
                                        filled: true,
                                        fillColor: Colors.grey.withOpacity(0.1),
                                        labelStyle: TextStyle(
                                          color: Colors.grey[600],
                                          fontSize: 16,
                                        ),
                                        prefixIcon: const Icon(
                                          Icons.event_outlined,
                                          color: Color(0xFF9D9DCC),
                                          size: 20,
                                        ),
                                        contentPadding:
                                            const EdgeInsets.symmetric(
                                              vertical: 10.0,
                                              horizontal: 12.0,
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
                                      style: const TextStyle(
                                        color: Colors.black87,
                                        fontSize: 16,
                                      ),
                                      validator: (value) {
                                        if (value == null || value.isEmpty) {
                                          return 'Please enter event name';
                                        }
                                        return null;
                                      },
                                    ),
                                    const SizedBox(height: 16),
                                    DropdownButtonFormField<String>(
                                      value:
                                          _selectedEventType.isEmpty
                                              ? null
                                              : _selectedEventType,
                                      decoration: InputDecoration(
                                        labelText: 'Event Type',
                                        hintText: 'Select event type',
                                        hintStyle: TextStyle(
                                          color: Colors.grey[600],
                                          fontSize: 16,
                                        ),
                                        filled: true,
                                        fillColor: Colors.grey.withOpacity(0.1),
                                        labelStyle: TextStyle(
                                          color: Colors.grey[600],
                                          fontSize: 16,
                                        ),
                                        prefixIcon: const Icon(
                                          Icons.category_outlined,
                                          color: Color(0xFF9D9DCC),
                                          size: 20,
                                        ),
                                        contentPadding:
                                            const EdgeInsets.symmetric(
                                              vertical: 10.0,
                                              horizontal: 12.0,
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
                                      style: const TextStyle(
                                        color: Colors.black87,
                                        fontSize: 16,
                                      ),
                                      items:
                                          widget.portfolio.eventTypes.map((
                                            type,
                                          ) {
                                            return DropdownMenuItem(
                                              value: type,
                                              child: Text(
                                                type,
                                                style: const TextStyle(
                                                  color: Colors.black87,
                                                  fontSize: 16,
                                                ),
                                              ),
                                            );
                                          }).toList(),
                                      onChanged: (value) {
                                        setState(() {
                                          if (value != null) {
                                            _selectedEventType = value;
                                          }
                                        });
                                      },
                                      validator: (value) {
                                        if (value == null || value.isEmpty) {
                                          return 'Please select an event type';
                                        }
                                        return null;
                                      },
                                      dropdownColor: Colors.white,
                                    ),
                                    const SizedBox(height: 16),
                                    TextFormField(
                                      readOnly: true,
                                      onTap: _selectDate,
                                      decoration: InputDecoration(
                                        labelText: 'Event Date',
                                        hintText: 'Select date',
                                        hintStyle: TextStyle(
                                          color: Colors.grey[600],
                                          fontSize: 16,
                                        ),
                                        filled: true,
                                        fillColor: Colors.grey.withOpacity(0.1),
                                        labelStyle: TextStyle(
                                          color: Colors.grey[600],
                                          fontSize: 16,
                                        ),
                                        prefixIcon: const Icon(
                                          Icons.calendar_today,
                                          color: Color(0xFF9D9DCC),
                                          size: 20,
                                        ),
                                        contentPadding:
                                            const EdgeInsets.symmetric(
                                              vertical: 10.0,
                                              horizontal: 12.0,
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
                                        suffixIcon:
                                            _selectedDate != null
                                                ? IconButton(
                                                  icon: const Icon(
                                                    Icons.clear,
                                                    size: 20,
                                                  ),
                                                  onPressed: () {
                                                    setState(() {
                                                      _selectedDate = null;
                                                    });
                                                  },
                                                )
                                                : null,
                                      ),
                                      style: TextStyle(
                                        color:
                                            _selectedDate == null
                                                ? Colors
                                                    .grey[600] // Lighter shade for placeholder
                                                : Colors
                                                    .black87, // Dark shade for selected date
                                        fontSize: 16,
                                      ),
                                      controller: TextEditingController(
                                        text:
                                            _selectedDate == null
                                                ? 'Select Date'
                                                : DateFormat(
                                                  'MMMM dd, yyyy',
                                                ).format(_selectedDate!),
                                      ),
                                    ),
                                    if (_selectedDate == null)
                                      const Padding(
                                        padding: EdgeInsets.only(
                                          top: 8,
                                          left: 12,
                                        ),
                                        child: Text(
                                          'Please select a date',
                                          style: TextStyle(
                                            color: Colors.red,
                                            fontSize: 12,
                                          ),
                                        ),
                                      ),
                                    const SizedBox(height: 16),

                                    // Add Venue Section after Event Details or before Budget
                                    Padding(
                                      padding: const EdgeInsets.only(
                                        bottom: 12,
                                        top: 8,
                                      ),
                                      child: Row(
                                        children: [
                                          Container(
                                            width: 3,
                                            height: 20,
                                            decoration: BoxDecoration(
                                              color: Colors.black87,
                                              borderRadius:
                                                  BorderRadius.circular(1.5),
                                            ),
                                          ),
                                          const SizedBox(width: 8),
                                          const Text(
                                            "Venue Details",
                                            style: TextStyle(
                                              fontSize: 16,
                                              fontWeight: FontWeight.bold,
                                              color: Colors.black87,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),

                                    // Address field
                                    TextFormField(
                                      controller: _addressController,
                                      maxLength: 100,
                                      decoration: InputDecoration(
                                        labelText: 'Address',
                                        hintText: 'Enter venue address',
                                        counterText: '',
                                        hintStyle: TextStyle(
                                          color: Colors.grey[600],
                                          fontSize: 16,
                                        ),
                                        filled: true,
                                        fillColor: Colors.grey.withOpacity(0.1),
                                        labelStyle: TextStyle(
                                          color: Colors.grey[600],
                                          fontSize: 16,
                                        ),
                                        prefixIcon: const Icon(
                                          Icons.location_on_outlined,
                                          color: Color(0xFF9D9DCC),
                                          size: 20,
                                        ),
                                        contentPadding:
                                            const EdgeInsets.symmetric(
                                              vertical: 10.0,
                                              horizontal: 12.0,
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
                                      style: const TextStyle(
                                        color: Colors.black87,
                                        fontSize: 16,
                                      ),
                                      validator: (value) {
                                        if (value == null || value.isEmpty) {
                                          return 'Please enter venue address';
                                        }
                                        return null;
                                      },
                                    ),

                                    const SizedBox(height: 16),

                                    // Apartment/Suite field (optional)
                                    TextFormField(
                                      controller: _apartmentController,
                                      decoration: InputDecoration(
                                        labelText:
                                            'Apartment, Suite, etc. (Optional)',
                                        hintText:
                                            'Enter additional address details',
                                        hintStyle: TextStyle(
                                          color: Colors.grey[600],
                                          fontSize: 16,
                                        ),
                                        filled: true,
                                        fillColor: Colors.grey.withOpacity(0.1),
                                        labelStyle: TextStyle(
                                          color: Colors.grey[600],
                                          fontSize: 16,
                                        ),
                                        prefixIcon: const Icon(
                                          Icons.apartment,
                                          color: Color(0xFF9D9DCC),
                                          size: 20,
                                        ),
                                        contentPadding:
                                            const EdgeInsets.symmetric(
                                              vertical: 10.0,
                                              horizontal: 12.0,
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
                                      style: const TextStyle(
                                        color: Colors.black87,
                                        fontSize: 16,
                                      ),
                                      // No validator since it's optional
                                    ),

                                    const SizedBox(height: 16),

                                    // City field
                                    TextFormField(
                                      controller: _cityController,
                                      decoration: InputDecoration(
                                        labelText: 'City',
                                        hintText: 'Enter city name',
                                        hintStyle: TextStyle(
                                          color: Colors.grey[600],
                                          fontSize: 16,
                                        ),
                                        filled: true,
                                        fillColor: Colors.grey.withOpacity(0.1),
                                        labelStyle: TextStyle(
                                          color: Colors.grey[600],
                                          fontSize: 16,
                                        ),
                                        prefixIcon: const Icon(
                                          Icons.location_city,
                                          color: Color(0xFF9D9DCC),
                                          size: 20,
                                        ),
                                        contentPadding:
                                            const EdgeInsets.symmetric(
                                              vertical: 10.0,
                                              horizontal: 12.0,
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
                                      style: const TextStyle(
                                        color: Colors.black87,
                                        fontSize: 16,
                                      ),
                                      validator: (value) {
                                        if (value == null || value.isEmpty) {
                                          return 'Please enter city name';
                                        }
                                        return null;
                                      },
                                    ),

                                    const SizedBox(height: 16),

                                    // Budget heading with vertical line
                                    Padding(
                                      padding: const EdgeInsets.only(
                                        bottom: 12,
                                        top: 8,
                                      ),
                                      child: Row(
                                        children: [
                                          Container(
                                            width: 3,
                                            height: 20,
                                            decoration: BoxDecoration(
                                              color: Colors.black87,
                                              borderRadius:
                                                  BorderRadius.circular(1.5),
                                            ),
                                          ),
                                          const SizedBox(width: 8),
                                          const Text(
                                            "Budget",
                                            style: TextStyle(
                                              fontSize: 16,
                                              fontWeight: FontWeight.bold,
                                              color: Colors.black87,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),

                                    TextFormField(
                                      controller: _budgetController,
                                      decoration: InputDecoration(
                                        labelText: 'Budget (PKR)',
                                        hintText: 'Enter your budget',
                                        hintStyle: TextStyle(
                                          color: Colors.grey[600],
                                          fontSize: 16,
                                        ),
                                        filled: true,
                                        fillColor: Colors.grey.withOpacity(0.1),
                                        labelStyle: TextStyle(
                                          color: Colors.grey[600],
                                          fontSize: 16,
                                        ),
                                        prefixIcon: const Icon(
                                          Icons.currency_rupee,
                                          color: Color(0xFF9D9DCC),
                                          size: 20,
                                        ),
                                        contentPadding:
                                            const EdgeInsets.symmetric(
                                              vertical: 10.0,
                                              horizontal: 12.0,
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
                                      style: const TextStyle(
                                        color: Colors.black87,
                                        fontSize: 16,
                                      ),
                                      keyboardType: TextInputType.number,
                                      validator: (value) {
                                        if (value == null || value.isEmpty) {
                                          return 'Please enter your budget';
                                        }
                                        if (double.tryParse(value) == null) {
                                          return 'Please enter a valid number';
                                        }
                                        final budget = double.parse(value);
                                        if (budget <
                                            widget.portfolio.minBudget) {
                                          return 'Budget must be at least PKR ${widget.portfolio.minBudget.toStringAsFixed(0)}';
                                        }
                                        return null;
                                      },
                                    ),
                                    const SizedBox(height: 20),
                                    Container(
                                      decoration: BoxDecoration(
                                        color: Colors.white,
                                        borderRadius: BorderRadius.circular(12),
                                        border: Border.all(
                                          color: const Color(0xFF9D9DCC),
                                          width: 1,
                                        ),
                                      ),
                                      child: SwitchListTile(
                                        title: const Text(
                                          'Need a Photographer?',
                                          style: TextStyle(
                                            color: Colors.black87,
                                            fontSize: 16,
                                          ),
                                        ),
                                        subtitle: const Text(
                                          'Additional PKR 25,000 if selected',
                                          style: TextStyle(
                                            color: Colors.black87,
                                            fontSize: 14,
                                          ),
                                        ),
                                        value: _needsPhotographer,
                                        activeColor: const Color(0xFF9D9DCC),
                                        onChanged: (value) {
                                          setState(() {
                                            _needsPhotographer = value;
                                          });
                                        },
                                      ),
                                    ),
                                    const SizedBox(height: 16),

                                    // Color Scheme Section with vertical line
                                    Padding(
                                      padding: const EdgeInsets.only(
                                        bottom: 12,
                                        top: 8,
                                      ),
                                      child: Row(
                                        children: [
                                          Container(
                                            width: 3,
                                            height: 20,
                                            decoration: BoxDecoration(
                                              color: Colors.black87,
                                              borderRadius:
                                                  BorderRadius.circular(1.5),
                                            ),
                                          ),
                                          const SizedBox(width: 8),
                                          const Text(
                                            'Color Scheme',
                                            style: TextStyle(
                                              fontSize: 16,
                                              fontWeight: FontWeight.bold,
                                              color: Colors.black87,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),

                                    Row(
                                      children: [
                                        Expanded(
                                          child: InkWell(
                                            onTap: () => _showColorPicker(true),
                                            child: Container(
                                              height: 50,
                                              decoration: BoxDecoration(
                                                color: _primaryColor,
                                                borderRadius:
                                                    BorderRadius.circular(12),
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
                                        ),
                                        const SizedBox(width: 16),
                                        Expanded(
                                          child: InkWell(
                                            onTap:
                                                () => _showColorPicker(false),
                                            child: Container(
                                              height: 50,
                                              decoration: BoxDecoration(
                                                color: _secondaryColor,
                                                borderRadius:
                                                    BorderRadius.circular(12),
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
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 16),

                                    // Notes Sub-section
                                    Padding(
                                      padding: const EdgeInsets.only(
                                        bottom: 12,
                                        top: 8,
                                      ),
                                      child: Row(
                                        children: [
                                          Container(
                                            width: 3,
                                            height: 20,
                                            decoration: BoxDecoration(
                                              color: Colors.black87,
                                              borderRadius:
                                                  BorderRadius.circular(1.5),
                                            ),
                                          ),
                                          const SizedBox(width: 8),
                                          const Text(
                                            'Additional Notes',
                                            style: TextStyle(
                                              fontSize: 16,
                                              fontWeight: FontWeight.bold,
                                              color: Colors.black87,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),

                                    TextFormField(
                                      controller: _notesController,
                                      decoration: InputDecoration(
                                        labelText: 'Notes (Optional)',
                                        hintText: 'Add additional notes',
                                        hintStyle: TextStyle(
                                          color: Colors.grey[600],
                                          fontSize: 16,
                                        ),
                                        filled: true,
                                        fillColor: Colors.grey.withOpacity(0.1),
                                        alignLabelWithHint: true,
                                        labelStyle: TextStyle(
                                          color: Colors.grey[600],
                                          fontSize: 16,
                                        ),
                                        contentPadding:
                                            const EdgeInsets.symmetric(
                                              vertical: 10.0,
                                              horizontal: 12.0,
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
                                      style: const TextStyle(
                                        color: Colors.black87,
                                        fontSize: 16,
                                      ),
                                      maxLines: 3,
                                      textAlignVertical: TextAlignVertical.top,
                                    ),
                                    const SizedBox(height: 32),
                                    SizedBox(
                                      width: double.infinity,
                                      child: ElevatedButton(
                                        onPressed: _submitResponse,
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: const Color(
                                            0xFF9D9DCC,
                                          ),
                                          padding: const EdgeInsets.symmetric(
                                            vertical: 16,
                                          ),
                                          shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(
                                              12,
                                            ),
                                          ),
                                        ),
                                        child: const Text(
                                          'Submit Order',
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
                          ],
                        ),
                      ),
            ),
          ],
        ),
      ),
    );
  }
}

// Custom formatter for phone numbers
class PhoneNumberInputFormatter extends TextInputFormatter {
  final int digitsLimit;

  PhoneNumberInputFormatter(this.digitsLimit);

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    if (newValue.text.isEmpty) {
      return newValue;
    }

    // Strip non-digit characters
    final digitsOnly = newValue.text.replaceAll(RegExp(r'\D'), '');

    // Truncate if longer than limit
    final truncatedDigits =
        digitsOnly.length > digitsLimit
            ? digitsOnly.substring(0, digitsLimit)
            : digitsOnly;

    return TextEditingValue(
      text: truncatedDigits,
      selection: TextSelection.collapsed(offset: truncatedDigits.length),
    );
  }
}
