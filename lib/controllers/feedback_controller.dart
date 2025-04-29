import 'package:flutter/foundation.dart';
import '../models/order_model.dart';

class FeedbackController extends ChangeNotifier {
  final List<OrderModel> _completedOrders = [];
  final List<OrderModel> _ratedOrders = [];
  bool _isLoading = false;

  List<OrderModel> get completedOrders => _completedOrders;
  List<OrderModel> get ratedOrders => _ratedOrders;
  bool get isLoading => _isLoading;

  // Will be implemented with Firebase later
  Future<void> fetchOrders(String clientId) async {
    _isLoading = true;
    notifyListeners();

    // Dummy data for now
    _completedOrders.addAll([
      OrderModel(
        id: '1',
        clientId: clientId,
        organizerId: 'org1',
        organizerName: 'Event Master',
        eventType: 'Wedding',
        eventDate: DateTime.now().subtract(const Duration(days: 5)),
        isCompleted: true,
      ),
    ]);

    _isLoading = false;
    notifyListeners();
  }

  Future<void> submitFeedback(
    String orderId,
    double rating,
    String feedback,
  ) async {
    // Will implement Firebase update later
  }
}
