import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/portfolio_model.dart';
import '../models/response_model.dart';
import '../models/review_model.dart';

class PortfolioService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Portfolio Collection
  final String _portfolioCollection = 'portfolios';
  final String _responseCollection = 'responses';
  final String _reviewCollection = 'reviews';

  // Create a new portfolio
  Future<void> createPortfolio(PortfolioModel portfolio) async {
    try {
      print('Creating portfolio with ID: ${portfolio.id}');
      print('OrganizerId: ${portfolio.organizerId}');
      print('ImageUrls: ${portfolio.imageUrls.length} images');

      await _firestore
          .collection(_portfolioCollection)
          .doc(portfolio.id)
          .set(portfolio.toMap());

      print('Portfolio created successfully with ID: ${portfolio.id}');
    } catch (e) {
      print('Error creating portfolio: $e');
      throw Exception('Failed to create portfolio: $e');
    }
  }

  // Update an existing portfolio
  Future<void> updatePortfolio(PortfolioModel portfolio) async {
    await _firestore
        .collection(_portfolioCollection)
        .doc(portfolio.id)
        .update(portfolio.toMap());
  }

  // Get all portfolios
  Stream<List<PortfolioModel>> getPortfolios() {
    return _firestore
        .collection(_portfolioCollection)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) {
          return snapshot.docs
              .map(
                (doc) =>
                    PortfolioModel.fromMap(doc.data() as Map<String, dynamic>),
              )
              .toList();
        });
  }

  // Get portfolios by organizer
  Stream<List<PortfolioModel>> getPortfoliosByOrganizer(String organizerId) {
    return _firestore
        .collection(_portfolioCollection)
        .where('organizerId', isEqualTo: organizerId)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) {
          return snapshot.docs
              .map(
                (doc) =>
                    PortfolioModel.fromMap(doc.data() as Map<String, dynamic>),
              )
              .toList();
        });
  }

  // Get portfolio by ID
  Future<PortfolioModel?> getPortfolioById(String portfolioId) async {
    final doc =
        await _firestore
            .collection(_portfolioCollection)
            .doc(portfolioId)
            .get();
    if (doc.exists) {
      return PortfolioModel.fromMap(doc.data() as Map<String, dynamic>);
    }
    return null;
  }

  // Delete portfolio
  Future<void> deletePortfolio(String portfolioId) async {
    await _firestore.collection(_portfolioCollection).doc(portfolioId).delete();
  }

  // Create a new response
  Future<void> createResponse(ResponseModel response) async {
    try {
      print('Starting to create response with ID: ${response.id}');
      print('Response organizer ID: ${response.organizerId}');
      print('Response status: ${response.status}');

      await _firestore
          .collection(_responseCollection)
          .doc(response.id)
          .set(response.toMap());

      print('Response created successfully in Firestore');

      // Double-check that the document was created by reading it back
      final docSnapshot =
          await _firestore
              .collection(_responseCollection)
              .doc(response.id)
              .get();

      if (docSnapshot.exists) {
        final savedData = docSnapshot.data();
        print('Verified response in Firestore:');
        print('- Status: ${savedData?['status']}');
        print('- Organizer ID: ${savedData?['organizerId']}');
        print('- Client ID: ${savedData?['clientId']}');
      } else {
        print('WARNING: Document was not found after creation!');
      }
    } catch (e) {
      print('ERROR creating response: $e');
      rethrow;
    }
  }

  // Get responses for an organizer
  Stream<List<ResponseModel>> getResponsesForOrganizer(String organizerId) {
    return _firestore
        .collection(_responseCollection)
        .where('organizerId', isEqualTo: organizerId)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) {
          return snapshot.docs
              .map(
                (doc) =>
                    ResponseModel.fromMap(doc.data() as Map<String, dynamic>),
              )
              .toList();
        });
  }

  // Get responses for an organizer as a Future<List> instead of a Stream
  Future<List<ResponseModel>> getResponsesForOrganizerAsList(
    String organizerId,
  ) async {
    final snapshot =
        await _firestore
            .collection(_responseCollection)
            .where('organizerId', isEqualTo: organizerId)
            .orderBy('createdAt', descending: true)
            .get();

    return snapshot.docs
        .map((doc) => ResponseModel.fromMap(doc.data() as Map<String, dynamic>))
        .toList();
  }

  // Update response status
  Future<void> updateResponseStatus(String responseId, String status) async {
    await _firestore.collection(_responseCollection).doc(responseId).update({
      'status': status,
    });
  }

  // Search portfolios by filters
  Stream<List<PortfolioModel>> searchPortfolios({
    String? eventType,
    double? minBudget,
    double? maxBudget,
    String? titleQuery,
  }) {
    Query query = _firestore.collection(_portfolioCollection);

    print('==================== SEARCH PORTFOLIOS ====================');
    print('Searching portfolios with filters:');
    print('Event type: $eventType');
    print('Min budget: $minBudget');
    print('Max budget: $maxBudget');
    print('Title query: $titleQuery');

    try {
      if (eventType != null) {
        query = query.where('eventTypes', arrayContains: eventType);
      }

      if (minBudget != null) {
        query = query.where('minBudget', isGreaterThanOrEqualTo: minBudget);
      }

      if (maxBudget != null) {
        query = query.where('maxBudget', isLessThanOrEqualTo: maxBudget);
      }

      return query.orderBy('createdAt', descending: true).snapshots().map((
        snapshot,
      ) {
        try {
          var portfolios =
              snapshot.docs
                  .map(
                    (doc) => PortfolioModel.fromMap(
                      doc.data() as Map<String, dynamic>,
                    ),
                  )
                  .toList();

          print('Before title filter: ${portfolios.length} portfolios');
          for (var portfolio in portfolios) {
            print(
              'Portfolio: ${portfolio.id}, title: "${portfolio.title}", organizerId: ${portfolio.organizerId}',
            );
          }

          // Filter by title if titleQuery is provided
          if (titleQuery != null && titleQuery.isNotEmpty) {
            final searchTerm = titleQuery.toLowerCase();
            print('Filtering by title using searchTerm: "$searchTerm"');
            portfolios =
                portfolios.where((portfolio) {
                  final matches = portfolio.title.toLowerCase().contains(
                    searchTerm,
                  );
                  print(
                    'Checking portfolio "${portfolio.title}": ${matches ? "MATCH" : "NO MATCH"}',
                  );
                  return matches;
                }).toList();
          }

          print('After filtering: Found ${portfolios.length} portfolios');
          for (var portfolio in portfolios) {
            print(
              'Portfolio: ${portfolio.id}, title: "${portfolio.title}", organizerId: ${portfolio.organizerId}',
            );
          }
          print('==================== END SEARCH ====================');

          return portfolios;
        } catch (e) {
          print('Error processing portfolios: $e');
          return <PortfolioModel>[];
        }
      });
    } catch (e) {
      print('Error searching portfolios: $e');
      // Return an empty stream in case of error
      return Stream.value(<PortfolioModel>[]);
    }
  }

  // Mark response as completed
  Future<void> markResponseAsCompleted(String responseId) async {
    await _firestore.collection(_responseCollection).doc(responseId).update({
      'status': 'completed',
    });
  }

  // Create a review
  Future<void> createReview(ReviewModel review) async {
    final batch = _firestore.batch();

    // Add the review
    final reviewRef = _firestore.collection(_reviewCollection).doc(review.id);
    batch.set(reviewRef, review.toMap());

    // Update portfolio rating
    final portfolioRef = _firestore
        .collection(_portfolioCollection)
        .doc(review.portfolioId);
    final portfolioDoc = await portfolioRef.get();

    if (portfolioDoc.exists) {
      final portfolio = PortfolioModel.fromMap(
        portfolioDoc.data() as Map<String, dynamic>,
      );

      // Calculate new rating
      final reviews =
          await _firestore
              .collection(_reviewCollection)
              .where('portfolioId', isEqualTo: review.portfolioId)
              .get();

      double totalRating = reviews.docs.fold(
        0.0,
        (sum, doc) => sum + (doc.data()['rating'] as num),
      );
      totalRating += review.rating;
      final newRating = totalRating / (reviews.docs.length + 1);

      batch.update(portfolioRef, {
        'rating': newRating,
        'totalEvents': portfolio.totalEvents + 1,
      });
    }

    // Execute batch
    await batch.commit();
  }

  // Get reviews for a portfolio
  Stream<List<ReviewModel>> getReviewsForPortfolio(String portfolioId) {
    return _firestore
        .collection(_reviewCollection)
        .where('portfolioId', isEqualTo: portfolioId)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) {
          return snapshot.docs
              .map(
                (doc) =>
                    ReviewModel.fromMap(doc.data() as Map<String, dynamic>),
              )
              .toList();
        });
  }

  // Get all responses for client (both pending and completed)
  Stream<List<ResponseModel>> getAllResponsesForClient(String clientId) {
    return _firestore
        .collection(_responseCollection)
        .where('clientId', isEqualTo: clientId)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) {
          return snapshot.docs
              .map(
                (doc) =>
                    ResponseModel.fromMap(doc.data() as Map<String, dynamic>),
              )
              .toList();
        });
  }

  // Get completed responses for client
  Stream<List<ResponseModel>> getCompletedResponsesForClient(String clientId) {
    return _firestore
        .collection(_responseCollection)
        .where('clientId', isEqualTo: clientId)
        .where('status', isEqualTo: 'completed')
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) {
          return snapshot.docs
              .map(
                (doc) =>
                    ResponseModel.fromMap(doc.data() as Map<String, dynamic>),
              )
              .toList();
        });
  }

  // Check if response has been reviewed
  Future<bool> hasResponseBeenReviewed(String responseId) async {
    final review =
        await _firestore
            .collection(_reviewCollection)
            .where('responseId', isEqualTo: responseId)
            .get();
    return review.docs.isNotEmpty;
  }

  // Get reviews by client
  Stream<List<ReviewModel>> getReviewsByClient(String clientId) {
    return _firestore
        .collection(_reviewCollection)
        .where('clientId', isEqualTo: clientId)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) {
          return snapshot.docs
              .map(
                (doc) =>
                    ReviewModel.fromMap(doc.data() as Map<String, dynamic>),
              )
              .toList();
        });
  }

  // Debug method to check all responses
  Future<void> debugCheckAllResponses() async {
    try {
      print('======= CHECKING ALL RESPONSES IN DATABASE =======');

      final allResponses =
          await _firestore.collection(_responseCollection).get();

      print('Total responses in database: ${allResponses.docs.length}');

      for (var doc in allResponses.docs) {
        final data = doc.data();
        print('Response: ${doc.id}');
        print('- Status: ${data['status']}');
        print('- Organizer ID: ${data['organizerId']}');
        print('- Client ID: ${data['clientId']}');
        print('- Event Name: ${data['eventName']}');
        print('- Created At: ${data['createdAt']}');
        print('-----------------------------------');
      }

      print('======= END RESPONSE CHECK =======');
    } catch (e) {
      print('Error checking responses: $e');
    }
  }
}
