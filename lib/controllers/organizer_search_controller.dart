import 'package:flutter/foundation.dart';
import '../models/organizer_model.dart';
import '../models/portfolio_model.dart';
import '../services/organizer_service.dart';
import '../services/portfolio_service.dart';

class OrganizerSearchController extends ChangeNotifier {
  final List<OrganizerModel> _organizers = [];
  final List<PortfolioModel> _portfolios = [];
  bool _isLoading = false;
  String _searchQuery = '';
  final OrganizerService _organizerService = OrganizerService();
  final PortfolioService _portfolioService = PortfolioService();
  Map<String, dynamic> _filters = {
    'minBudget': 0.0,
    'maxBudget': double.infinity,
    'eventType': null,
    'primaryColor': null,
    'secondaryColor': null,
  };

  List<OrganizerModel> get organizers => _organizers;
  List<PortfolioModel> get portfolios => _portfolios;
  bool get isLoading => _isLoading;
  Map<String, dynamic> get filters => _filters;
  bool get hasSearchQuery => _searchQuery.isNotEmpty;
  String get searchQuery => _searchQuery;

  OrganizerSearchController() {
    _fetchData();
  }

  void updateSearchQuery(String query) {
    _searchQuery = query;
    _fetchData();
  }

  void updateFilters(Map<String, dynamic> newFilters) {
    _filters = newFilters;
    _fetchData();
  }

  void _fetchData() {
    _isLoading = true;
    _portfolios.clear();
    _organizers.clear();
    notifyListeners();

    // First, search portfolios
    _portfolioService
        .searchPortfolios(
          eventType: _filters['eventType'],
          minBudget: _filters['minBudget'],
          maxBudget:
              _filters['maxBudget'] == double.infinity
                  ? null
                  : _filters['maxBudget'],
          titleQuery: _searchQuery,
        )
        .listen((portfolios) {
          _portfolios.clear();
          _portfolios.addAll(portfolios);
          print(
            'Found ${portfolios.length} portfolios for query: $_searchQuery',
          );
          notifyListeners();
        });

    // Then, search organizers
    _organizerService
        .searchOrganizers(
          query: _searchQuery,
          eventType: _filters['eventType'],
          minBudget: _filters['minBudget'],
          maxBudget:
              _filters['maxBudget'] == double.infinity
                  ? null
                  : _filters['maxBudget'],
        )
        .listen((organizers) {
          _organizers.clear();
          _organizers.addAll(organizers);
          print(
            'Found ${organizers.length} organizers for query: $_searchQuery',
          );
          _isLoading = false;
          notifyListeners();
        });
  }
}
