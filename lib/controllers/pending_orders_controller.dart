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

    // First check if there are any pending orders directly with a one-time query
    _firestore
        .collection('responses')
        .where('organizerId', isEqualTo: organizerId)
        .where('status', whereIn: ['pending', 'Pending', 'PENDING'])
        .get()
        .then((snapshot) {
          print('Initial check found ${snapshot.docs.length} pending orders');
          for (var doc in snapshot.docs) {
            print(
              'Order: ${doc.id}, status: ${doc.data()['status']}, organizer: ${doc.data()['organizerId']}',
            );
          }
        })
        .catchError((error) {
          print('Error in initial orders check: $error');
        });

    _pendingOrdersStream = _firestore
        .collection('responses')
        .where('organizerId', isEqualTo: organizerId)
        .where('status', whereIn: ['pending', 'Pending', 'PENDING'])
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) {
          final orders =
              snapshot.docs
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
              .where('status', whereIn: ['pending', 'Pending', 'PENDING'])
              .orderBy('createdAt', descending: true)
              .get();

      final responses =
          snapshot.docs
              .map((doc) => ResponseModel.fromMap(doc.data()))
              .toList();

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
