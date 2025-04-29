import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/organizer_model.dart';

class OrganizerService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final String _organizersCollection = 'organizers';

  // Get all organizers
  Stream<List<OrganizerModel>> getOrganizers() {
    return _firestore.collection(_organizersCollection).snapshots().map((
      snapshot,
    ) {
      return snapshot.docs
          .map((doc) => OrganizerModel.fromMap(doc.data()))
          .toList();
    });
  }

  // Search organizers with filters
  Stream<List<OrganizerModel>> searchOrganizers({
    String? query,
    String? eventType,
    double? minBudget,
    double? maxBudget,
  }) {
    print('Searching organizers with:');
    print('Query: $query');
    print('Event type: $eventType');
    print('Min budget: $minBudget');
    print('Max budget: $maxBudget');

    Query firestoreQuery = _firestore.collection(_organizersCollection);

    if (eventType != null && eventType.isNotEmpty) {
      firestoreQuery = firestoreQuery.where('eventType', isEqualTo: eventType);
    }

    if (minBudget != null) {
      firestoreQuery = firestoreQuery.where(
        'minBudget',
        isGreaterThanOrEqualTo: minBudget,
      );
    }

    if (maxBudget != null) {
      firestoreQuery = firestoreQuery.where(
        'maxBudget',
        isLessThanOrEqualTo: maxBudget,
      );
    }

    return firestoreQuery.snapshots().map((snapshot) {
      var organizers =
          snapshot.docs
              .map(
                (doc) =>
                    OrganizerModel.fromMap(doc.data() as Map<String, dynamic>),
              )
              .toList();

      // Filter by name if query is provided
      if (query != null && query.isNotEmpty) {
        final searchTerm = query.toLowerCase();
        organizers =
            organizers.where((organizer) {
              return organizer.name.toLowerCase().contains(searchTerm);
            }).toList();
      }

      print('Found ${organizers.length} organizers');
      return organizers;
    });
  }

  // Get organizer by ID
  Future<OrganizerModel?> getOrganizerById(String organizerId) async {
    final doc =
        await _firestore
            .collection(_organizersCollection)
            .doc(organizerId)
            .get();
    if (doc.exists) {
      return OrganizerModel.fromMap(doc.data() as Map<String, dynamic>);
    }
    return null;
  }
}
