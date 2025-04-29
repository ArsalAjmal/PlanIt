class OrganizerModel {
  final String id;
  final String name;
  final String email;
  final String eventType;
  final double minBudget;
  final double maxBudget;
  final double rating;
  final String role;

  OrganizerModel({
    required this.id,
    required this.name,
    required this.email,
    required this.eventType,
    required this.minBudget,
    required this.maxBudget,
    this.rating = 0.0,
    required this.role,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'email': email,
      'eventType': eventType,
      'minBudget': minBudget,
      'maxBudget': maxBudget,
      'rating': rating,
      'role': role,
    };
  }

  factory OrganizerModel.fromMap(Map<String, dynamic> map) {
    return OrganizerModel(
      id: map['id'] ?? '',
      name: map['name'] ?? map['email'] ?? 'Unknown',
      email: map['email'] ?? '',
      eventType: map['eventType'] ?? 'Other',
      minBudget: (map['minBudget'] ?? 0).toDouble(),
      maxBudget: (map['maxBudget'] ?? 0).toDouble(),
      rating: (map['rating'] ?? 0).toDouble(),
      role: map['role'] ?? 'organizer',
    );
  }

  // Will be used later with Firebase
  factory OrganizerModel.fromFirestore(Map<String, dynamic> data, String id) {
    return OrganizerModel(
      id: id,
      name: data['name'],
      email: data['email'],
      eventType: data['eventType'],
      minBudget: data['minBudget']?.toDouble() ?? 0.0,
      maxBudget: data['maxBudget']?.toDouble() ?? 0.0,
      rating: data['rating']?.toDouble() ?? 0.0,
      role: data['role'] ?? 'organizer',
    );
  }
}
