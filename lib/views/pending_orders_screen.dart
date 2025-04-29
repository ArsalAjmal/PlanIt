import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/portfolio_service.dart';
import '../models/response_model.dart';
import './login_view.dart';

class PendingOrdersScreen extends StatefulWidget {
  final String orderId;

  const PendingOrdersScreen({super.key, required this.orderId});

  @override
  State<PendingOrdersScreen> createState() => _PendingOrdersScreenState();
}

class _PendingOrdersScreenState extends State<PendingOrdersScreen> {
  final PortfolioService _portfolioService = PortfolioService();
  bool _isLoading = true;
  ResponseModel? _order;

  @override
  void initState() {
    super.initState();
    _loadOrderData();
  }

  Future<void> _loadOrderData() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final doc =
          await FirebaseFirestore.instance
              .collection('responses')
              .doc(widget.orderId)
              .get();

      if (doc.exists) {
        setState(() {
          _order = ResponseModel.fromMap(doc.data()!);
          _isLoading = false;
        });
      } else {
        setState(() {
          _isLoading = false;
        });
        print('Order not found: ${widget.orderId}');
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      print('Error loading order: $e');
    }
  }

  Future<void> _markAsCompleted() async {
    if (_order == null) return;

    setState(() {
      _isLoading = true;
    });

    try {
      await _portfolioService.markResponseAsCompleted(_order!.id);

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Order marked as complete!'),
          backgroundColor: Colors.green,
        ),
      );

      // Pop back to the previous screen with a success result
      Navigator.of(context).pop('ORDER_COMPLETED');
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      print('Error marking order as complete: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Error marking order as complete'),
          backgroundColor: Colors.red,
        ),
      );
    }
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

    if (_isLoading) {
      return const SafeArea(
        child: Scaffold(
          backgroundColor: Color(0xFFFFFDD0),
          body: Center(child: CircularProgressIndicator()),
        ),
      );
    }

    if (_order == null) {
      return SafeArea(
        child: Scaffold(
          backgroundColor: const Color(0xFFFFFDD0),
          appBar: AppBar(
            backgroundColor: const Color(0xFF9D9DCC),
            elevation: 0,
            title: const Text(
              'Order Details',
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
          body: const Center(child: Text('Order not found')),
        ),
      );
    }

    return SafeArea(
      child: Scaffold(
        backgroundColor: const Color(0xFFFFFDD0),
        appBar: AppBar(
          backgroundColor: const Color(0xFF9D9DCC),
          elevation: 0,
          title: Text(
            'Order Details - ${_order!.id.substring(0, 8)}',
            style: const TextStyle(
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
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildDetailCard('Event Information', [
                'Name: ${_order!.eventName}',
                'Type: ${_order!.eventType}',
                'Date: ${_order!.eventDate.toString().substring(0, 10)}',
                'Budget: PKR ${_order!.budget.toStringAsFixed(0)}',
                'Client: ${_order!.clientName}',
              ]),
              const SizedBox(height: 16),
              if (_order!.clientResponse.isNotEmpty) ...[
                _buildMessageCard('Client Message', _order!.clientResponse),
                const SizedBox(height: 16),
              ],
              _buildDetailCard('Additional Information', [
                'Primary Color: ${_order!.primaryColor}',
                'Secondary Color: ${_order!.secondaryColor}',
                'Photographer Needed: ${_order!.needsPhotographer ? 'Yes' : 'No'}',
                'Notes: ${_order!.additionalNotes}',
              ]),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: _markAsCompleted,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF9D9DCC),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text(
                    'Mark as Complete',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMessageCard(String title, String message) {
    return Card(
      elevation: 4,
      color: const Color(0xFFF0F8FF), // Light blue background for message card
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Color(0xFF9D9DCC),
              ),
            ),
            const Divider(),
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(message, style: const TextStyle(fontSize: 16)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailCard(String title, List<String> details) {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Color(0xFF9D9DCC),
              ),
            ),
            const Divider(),
            ...details.map(
              (detail) => Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  children: [
                    const Icon(Icons.circle, size: 8, color: Color(0xFF9D9DCC)),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(detail, style: const TextStyle(fontSize: 16)),
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
