import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_colorpicker/flutter_colorpicker.dart';
import '../../models/portfolio_model.dart';
import '../../models/response_model.dart';
import '../../services/portfolio_service.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';
import '../payment/order_summary_screen.dart';

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
  final _portfolioService = PortfolioService();
  DateTime? _selectedDate;
  String _selectedEventType = '';
  Color _primaryColor = Colors.blue;
  Color _secondaryColor = Colors.green;
  bool _needsPhotographer = false;
  bool _isLoading = false;
  final double _photographerFee = 25000.0; // PKR 25,000 for photographer

  @override
  void initState() {
    super.initState();
    _clientNameController.text = widget.clientName; // Pre-fill with user's name
  }

  @override
  void dispose() {
    _clientNameController.dispose();
    _eventNameController.dispose();
    _budgetController.dispose();
    _notesController.dispose();
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
              onSurface: Color(0xFF6B6B8D),
            ),
            dialogBackgroundColor: Colors.white,
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
        backgroundColor: const Color(0xFFFFFDD0),
        appBar: AppBar(
          backgroundColor: const Color(0xFF9D9DCC),
          elevation: 0,
          title: const Text(
            'Placing Order',
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
        body:
            _isLoading
                ? const Center(child: CircularProgressIndicator())
                : SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        TextFormField(
                          controller: _clientNameController,
                          decoration: InputDecoration(
                            labelText: 'Your Name',
                            filled: true,
                            fillColor: Colors.white,
                            labelStyle: const TextStyle(
                              color: Color(0xFF9D9DCC),
                            ),
                            prefixIcon: const Icon(
                              Icons.person_outline,
                              color: Color(0xFF9D9DCC),
                            ),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          style: const TextStyle(color: Color(0xFF6B6B8D)),
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return 'Please enter your name';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 16),
                        TextFormField(
                          controller: _eventNameController,
                          decoration: InputDecoration(
                            labelText: 'Event Name',
                            filled: true,
                            fillColor: Colors.white,
                            labelStyle: const TextStyle(
                              color: Color(0xFF9D9DCC),
                            ),
                            prefixIcon: const Icon(
                              Icons.event_outlined,
                              color: Color(0xFF9D9DCC),
                            ),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          style: const TextStyle(color: Color(0xFF6B6B8D)),
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
                            filled: true,
                            fillColor: Colors.white,
                            labelStyle: const TextStyle(
                              color: Color(0xFF9D9DCC),
                            ),
                            prefixIcon: const Icon(
                              Icons.category_outlined,
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
                          items:
                              widget.portfolio.eventTypes.map((type) {
                                return DropdownMenuItem(
                                  value: type,
                                  child: Text(
                                    type,
                                    style: const TextStyle(
                                      color: Color(0xFF6B6B8D),
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
                        InkWell(
                          onTap: _selectDate,
                          child: InputDecorator(
                            decoration: InputDecoration(
                              labelText: 'Event Date',
                              filled: true,
                              fillColor: Colors.white,
                              labelStyle: const TextStyle(
                                color: Color(0xFF9D9DCC),
                              ),
                              prefixIcon: const Icon(
                                Icons.calendar_today,
                                color: Color(0xFF9D9DCC),
                              ),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            child: Text(
                              _selectedDate == null
                                  ? 'Select Date'
                                  : DateFormat(
                                    'MMMM dd, yyyy',
                                  ).format(_selectedDate!),
                              style: TextStyle(
                                color:
                                    _selectedDate == null
                                        ? const Color(0xFF9D9DCC)
                                        : const Color(0xFF6B6B8D),
                                fontSize: 16,
                              ),
                            ),
                          ),
                        ),
                        if (_selectedDate == null)
                          const Padding(
                            padding: EdgeInsets.only(top: 8, left: 12),
                            child: Text(
                              'Please select a date',
                              style: TextStyle(color: Colors.red, fontSize: 12),
                            ),
                          ),
                        const SizedBox(height: 16),
                        TextFormField(
                          controller: _budgetController,
                          decoration: InputDecoration(
                            labelText: 'Budget (PKR)',
                            filled: true,
                            fillColor: Colors.white,
                            labelStyle: const TextStyle(
                              color: Color(0xFF9D9DCC),
                            ),
                            prefixIcon: const Icon(
                              Icons.currency_rupee,
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
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return 'Please enter your budget';
                            }
                            if (double.tryParse(value) == null) {
                              return 'Please enter a valid number';
                            }
                            final budget = double.parse(value);
                            if (budget < widget.portfolio.minBudget) {
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
                                color: Color(0xFF6B6B8D),
                                fontSize: 16,
                              ),
                            ),
                            subtitle: const Text(
                              'Additional PKR 25,000 if selected',
                              style: TextStyle(
                                color: Color(0xFF6B6B8D),
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
                        const Text(
                          'Choose Color Scheme',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w500,
                            color: Color(0xFF6B6B8D),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Expanded(
                              child: InkWell(
                                onTap: () => _showColorPicker(true),
                                child: Container(
                                  height: 50,
                                  decoration: BoxDecoration(
                                    color: _primaryColor,
                                    borderRadius: BorderRadius.circular(12),
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
                                onTap: () => _showColorPicker(false),
                                child: Container(
                                  height: 50,
                                  decoration: BoxDecoration(
                                    color: _secondaryColor,
                                    borderRadius: BorderRadius.circular(12),
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
                        TextFormField(
                          controller: _notesController,
                          decoration: InputDecoration(
                            labelText: 'Additional Notes (Optional)',
                            hintText: 'Add additional notes',
                            hintStyle: TextStyle(
                              color: const Color(0xFF9D9DCC).withOpacity(0.6),
                              fontSize: 16,
                            ),
                            filled: true,
                            fillColor: Colors.white,
                            alignLabelWithHint: true,
                            labelStyle: const TextStyle(
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
                          maxLines: 3,
                          textAlignVertical: TextAlignVertical.top,
                        ),
                        const SizedBox(height: 32),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            onPressed: _submitResponse,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF9D9DCC),
                              padding: const EdgeInsets.symmetric(vertical: 16),
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
      ),
    );
  }
}
