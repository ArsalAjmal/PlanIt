import 'package:flutter/material.dart';
import '../services/auth_service.dart';
import 'package:firebase_auth/firebase_auth.dart';
// import '../models/user_model.dart';

class LoginController extends ChangeNotifier {
  final AuthService _authService = AuthService();
  bool _isLoading = false;
  String? _errorMessage;
  String? _userRole;
  String? _verificationEmail;

  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  String? get userRole => _userRole;
  String? get verificationEmail => _verificationEmail;

  Future<bool> login(String email, String password) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final result = await _authService.login(email, password);

      if (result?['success'] == true) {
        // For existing accounts that were created before email verification was implemented
        if (result?['userData'] != null &&
            result?['userData']['emailVerified'] == null) {
          // Legacy account, allow login without verification
          _userRole = result?['role'];
          return true;
        }

        // Check email verification status from Firebase Auth directly
        // This is more reliable than Firestore data
        if (result?['emailVerified'] == true) {
          _userRole = result?['role'];
          return true;
        } else {
          _errorMessage = 'Please verify your email before logging in';
          _verificationEmail = email;
          return false;
        }
      }

      _errorMessage = result?['message'] ?? 'Invalid email or password';
      return false;
    } catch (e) {
      _errorMessage = 'Login failed: ${e.toString()}';
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

  // Method to resend verification email
  Future<bool> resendVerificationEmail(String email, String password) async {
    try {
      _isLoading = true;
      notifyListeners();

      // Sign in to get the user
      final result = await _authService.login(email, password);
      if (result?['success'] != true) {
        return false;
      }

      // Get the current user
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        return false;
      }

      // Send verification email
      await user.sendEmailVerification();
      return true;
    } catch (e) {
      print('Error resending verification email: $e');
      return false;
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

  // Method to force reload the user and check verification status
  Future<bool> checkEmailVerificationStatus() async {
    try {
      // Get the current user
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        return false;
      }

      // Reload the user to get fresh data from Firebase
      await user.reload();

      // Get the updated user object
      final updatedUser = FirebaseAuth.instance.currentUser;
      if (updatedUser == null) {
        return false;
      }

      return updatedUser.emailVerified;
    } catch (e) {
      print('Error checking email verification: $e');
      return false;
    }
  }
}
