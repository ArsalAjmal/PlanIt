import 'package:cloud_firestore/cloud_firestore.dart';

class PortfolioModel {
  final String id;
  final String organizerId;
  final String title;
  final String description;
  final List<String>
  imageUrls; // These will be Firestore document IDs with 'firestore:' prefix
  final List<String> eventTypes;
  final double minBudget;
  final double maxBudget;
  final double rating;
  final int totalEvents;
  final DateTime createdAt;

  PortfolioModel({
    required this.id,
    required this.organizerId,
    required this.title,
    required this.description,
    required this.imageUrls,
    required this.eventTypes,
    required this.minBudget,
    required this.maxBudget,
    required this.rating,
    required this.totalEvents,
    required this.createdAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'organizerId': organizerId,
      'title': title,
      'description': description,
      'imageUrls': imageUrls,
      'eventTypes': eventTypes,
      'minBudget': minBudget,
      'maxBudget': maxBudget,
      'rating': rating,
      'totalEvents': totalEvents,
      'createdAt': Timestamp.fromDate(createdAt),
    };
  }

  factory PortfolioModel.fromMap(Map<String, dynamic> map) {
    return PortfolioModel(
      id: map['id'] ?? '',
      organizerId: map['organizerId'] ?? '',
      title: map['title'] ?? '',
      description: map['description'] ?? '',
      imageUrls: List<String>.from(map['imageUrls'] ?? []),
      eventTypes: List<String>.from(map['eventTypes'] ?? []),
      minBudget: map['minBudget']?.toDouble() ?? 0.0,
      maxBudget: map['maxBudget']?.toDouble() ?? 0.0,
      rating: map['rating']?.toDouble() ?? 0.0,
      totalEvents: map['totalEvents']?.toInt() ?? 0,
      createdAt:
          map['createdAt'] is Timestamp
              ? (map['createdAt'] as Timestamp).toDate()
              : (map['createdAt'] ?? DateTime.now()),
    );
  }
}
