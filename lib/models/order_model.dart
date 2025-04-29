class OrderModel {
  final String id;
  final String clientId;
  final String organizerId;
  final String organizerName;
  final String eventType;
  final DateTime eventDate;
  final bool isCompleted;
  final double? rating;
  final String? feedback;

  OrderModel({
    required this.id,
    required this.clientId,
    required this.organizerId,
    required this.organizerName,
    required this.eventType,
    required this.eventDate,
    required this.isCompleted,
    this.rating,
    this.feedback,
  });

  // Will be used later with Firebase
  factory OrderModel.fromFirestore(Map<String, dynamic> data, String id) {
    return OrderModel(
      id: id,
      clientId: data['clientId'] ?? '',
      organizerId: data['organizerId'] ?? '',
      organizerName: data['organizerName'] ?? '',
      eventType: data['eventType'] ?? '',
      eventDate: (data['eventDate'] as DateTime?) ?? DateTime.now(),
      isCompleted: data['isCompleted'] ?? false,
      rating: data['rating']?.toDouble(),
      feedback: data['feedback'],
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'clientId': clientId,
      'organizerId': organizerId,
      'organizerName': organizerName,
      'eventType': eventType,
      'eventDate': eventDate,
      'isCompleted': isCompleted,
      'rating': rating,
      'feedback': feedback,
    };
  }
}
