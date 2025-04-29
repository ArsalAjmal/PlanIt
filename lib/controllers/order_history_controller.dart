import 'package:flutter/foundation.dart';
import '../models/response_model.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../services/portfolio_service.dart';

class OrderHistoryController extends ChangeNotifier {
  final List<ResponseModel> _orders = [];
  bool _isLoading = false;
  final PortfolioService _portfolioService = PortfolioService();
  Stream<List<ResponseModel>>? _ordersStream;

  List<ResponseModel> get orders => _orders;
  bool get isLoading => _isLoading;
  Stream<List<ResponseModel>>? get ordersStream => _ordersStream;
  List<ResponseModel> get ongoingOrders =>
      _orders.where((order) => order.status != 'completed').toList();
  List<ResponseModel> get completedOrders =>
      _orders.where((order) => order.status == 'completed').toList();

  // Initialize stream for orders
  void initOrdersStream(String clientId) {
    _ordersStream = _portfolioService.getAllResponsesForClient(clientId);
    notifyListeners();
  }

  // Legacy method - keeping for compatibility
  Future<void> fetchOrders(String clientId) async {
    _isLoading = true;
    _orders.clear();
    notifyListeners();

    try {
      // Initialize the stream
      initOrdersStream(clientId);

      // Load initial data using a one-time query to populate _orders list
      final snapshot =
          await FirebaseFirestore.instance
              .collection('responses')
              .where('clientId', isEqualTo: clientId)
              .orderBy('createdAt', descending: true)
              .get();

      final responses =
          snapshot.docs
              .map((doc) => ResponseModel.fromMap(doc.data()))
              .toList();

      _orders.addAll(responses);
      print('Fetched ${_orders.length} orders for client $clientId');

      if (_orders.isEmpty) {
        print('No orders found for client $clientId');
      } else {
        for (var order in _orders) {
          print('Order: ${order.eventName}, Status: ${order.status}');
        }
      }
    } catch (e) {
      print('Error fetching orders: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
}
