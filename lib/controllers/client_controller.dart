import 'dart:async';
import 'package:flutter/material.dart';
import '../models/event_model.dart';

class ClientController extends ChangeNotifier {
  EventModel? _currentEvent;
  Timer? _timer;
  Map<String, int> _countdown = {
    'days': 0,
    'hours': 1,
    'minutes': 32,
    'seconds': 6,
  };

  Map<String, int> get countdown => _countdown;

  void startCountdown() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_currentEvent != null) {
        _countdown = _currentEvent!.getCountdown();
        notifyListeners();
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }
}
