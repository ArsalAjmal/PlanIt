import 'package:flutter/material.dart';
import '../services/auth_service.dart';
// import '../models/user_model.dart';

class LoginController extends ChangeNotifier {
  final AuthService _authService = AuthService();
  bool _isLoading = false;
  String? _errorMessage;
  String? _userRole;

  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  String? get userRole => _userRole;

  Future<bool> login(String email, String password) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final result = await _authService.login(email, password);
      if (result?['success'] == true) {
        _userRole = result?['role'];
        return true;
      }
      _errorMessage = 'Invalid email or password';
      return false;
    } catch (e) {
      _errorMessage = 'An error occurred during login';
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<Map<String, dynamic>> signUp(
    String email,
    String password,
    String role,
  ) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final result = await _authService.signUp(email, password, role);
      if (!result['success']) {
        _errorMessage = result['message'];
      }
      return result;
    } catch (e) {
      _errorMessage = 'An error occurred during signup';
      return {'success': false, 'message': _errorMessage};
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> signOut() async {
    try {
      await _authService.signOut();
    } catch (e) {
      _errorMessage = 'An error occurred during signout: ${e.toString()}';
      notifyListeners();
    }
  }

  void clearError() {
    _errorMessage = null;
    notifyListeners();
  }
}
