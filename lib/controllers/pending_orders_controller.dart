import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/response_model.dart';
import '../services/portfolio_service.dart';

class PendingOrdersController extends ChangeNotifier {
  final List<ResponseModel> _pendingOrders = [];
  bool _isLoading = false;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final PortfolioService _portfolioService = PortfolioService();
  Stream<List<ResponseModel>>? _pendingOrdersStream;

  List<ResponseModel> get pendingOrders => _pendingOrders;
  bool get isLoading => _isLoading;
  Stream<List<ResponseModel>>? get pendingOrdersStream => _pendingOrdersStream;

  // Initialize stream for real-time pending orders updates
  void initPendingOrdersStream(String organizerId) {
    print('Initializing pending orders stream for organizer: $organizerId');

    // Print organizer ID for debugging
    print('Searching for orders with organizerId: $organizerId');

    // First check if there are any pending orders directly with a one-time query
    _firestore
        .collection('responses')
        .where('organizerId', isEqualTo: organizerId)
        .get()
        .then((snapshot) {
          print(
            'Found ${snapshot.docs.length} total responses for this organizer',
          );

          // Debug: Print all responses for this organizer regardless of status
          for (var doc in snapshot.docs) {
            print(
              'Response: ${doc.id}, status: ${doc.data()['status']}, organizer: ${doc.data()['organizerId']}, client: ${doc.data()['clientId']}, event: ${doc.data()['eventName']}, date: ${doc.data()['eventDate']}',
            );
          }

          // Now specifically check pending orders - case insensitive check
          final pendingDocs =
              snapshot.docs.where((doc) {
                final status = doc.data()['status'] as String? ?? '';
                return status.toLowerCase() == 'pending';
              }).toList();

          print('Found ${pendingDocs.length} pending orders specifically');
        })
        .catchError((error) {
          print('Error in initial orders check: $error');
        });

    _pendingOrdersStream = _firestore
        .collection('responses')
        .where('organizerId', isEqualTo: organizerId)
        // Re-add the status filter but with all possible case variations
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) {
          // Print all responses first
          print('Stream found ${snapshot.docs.length} total responses');
          for (var doc in snapshot.docs) {
            print(
              'Stream response: ${doc.id}, status: ${doc.data()['status']}, organizer: ${doc.data()['organizerId']}, event: ${doc.data()['eventName']}',
            );
          }

          // Filter for pending with case-insensitive check
          final pendingDocs =
              snapshot.docs.where((doc) {
                final status = doc.data()['status'] as String? ?? '';
                return status.toLowerCase() == 'pending';
              }).toList();

          final orders =
              pendingDocs
                  .map((doc) => ResponseModel.fromMap(doc.data()))
                  .toList();

          print(
            'Stream found ${orders.length} pending orders for organizer $organizerId',
          );

          if (orders.isEmpty) {
            print('No orders in stream for organizer $organizerId');
          } else {
            for (var order in orders) {
              print(
                'Stream order: ${order.id}, status: ${order.status}, event: ${order.eventName}',
              );
            }
          }

          return orders;
        });
    notifyListeners();
  }

  // Legacy method - keeping for compatibility
  Future<void> fetchPendingOrders(String organizerId) async {
    _isLoading = true;
    _pendingOrders.clear();
    notifyListeners();

    try {
      // Initialize the stream for real-time updates
      initPendingOrdersStream(organizerId);

      // Get pending responses for this organizer from Firestore
      final snapshot =
          await _firestore
              .collection('responses')
              .where('organizerId', isEqualTo: organizerId)
              // Re-add the status filter but with all possible case variations
              .orderBy('createdAt', descending: true)
              .get();

      print('Fetch query found ${snapshot.docs.length} total responses');
      for (var doc in snapshot.docs) {
        print(
          'Response in fetch: ${doc.id}, status: ${doc.data()['status']}, organizer: ${doc.data()['organizerId']}, event: ${doc.data()['eventName']}',
        );
      }

      // Filter for pending with case-insensitive check
      final pendingDocs =
          snapshot.docs.where((doc) {
            final status = doc.data()['status'] as String? ?? '';
            return status.toLowerCase() == 'pending';
          }).toList();

      print('After filtering, found ${pendingDocs.length} pending responses');

      final responses =
          pendingDocs.map((doc) => ResponseModel.fromMap(doc.data())).toList();

      _pendingOrders.addAll(responses);
      print(
        'Fetched ${_pendingOrders.length} pending orders for organizer $organizerId',
      );

      if (_pendingOrders.isEmpty) {
        print('No pending orders found for organizer $organizerId');
      } else {
        for (var order in _pendingOrders) {
          print(
            'Order: ${order.eventName}, Client: ${order.clientName}, Date: ${order.eventDate}',
          );
        }
      }
    } catch (e) {
      print('Error fetching pending orders: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
}
