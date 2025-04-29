import 'package:flutter/foundation.dart';

class CityProvider extends ChangeNotifier {
  String _currentCity = 'Islamabad';

  String get currentCity => _currentCity;

  void updateCity(String newCity) {
    _currentCity = newCity;
    notifyListeners();
  }
}
