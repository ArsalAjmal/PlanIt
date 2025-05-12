import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
//import 'package:firebase_core/firebase_core.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Future<Map<String, dynamic>> signUp(
    String email,
    String password,
    String role,
  ) async {
    try {
      print('Attempting signup for email: $email with role: $role');
      final UserCredential userCredential = await _auth
          .createUserWithEmailAndPassword(email: email, password: password);

      // Send email verification
      await userCredential.user!.sendEmailVerification();

      // Store user data in Firestore
      if (role == 'client') {
        await _firestore
            .collection('clients')
            .doc(userCredential.user!.uid)
            .set({'email': email, 'role': role, 'emailVerified': false});
      } else {
        await _firestore
            .collection('organizers')
            .doc(userCredential.user!.uid)
            .set({'email': email, 'role': role, 'emailVerified': false});
      }

      return {
        'success': true,
        'message':
            'Please check your email to verify your account before logging in.',
      };
    } on FirebaseAuthException catch (e) {
      if (e.code == 'email-already-in-use') {
        return {
          'success': false,
          'message': 'This email is already registered.',
        };
      }
      return {
        'success': false,
        'message': 'An error occurred during signup: ${e.message}',
      };
    }
  }

  Future<Map<String, dynamic>?> login(String email, String password) async {
    try {
      print('Attempting login for email: $email');
      final userCredential = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );

      // Get the current user
      User? user = userCredential.user;

      // Reload user to get fresh data from Firebase
      if (user != null) {
        await user.reload();
        // Get the updated user object
        user = _auth.currentUser;
      }

      if (user == null) {
        return {'success': false, 'message': 'Login failed'};
      }

      // Check email verification status
      // Only enforce for new accounts that have the emailVerified field
      var clientDoc =
          await _firestore
              .collection('clients')
              .doc(userCredential.user!.uid)
              .get();

      if (clientDoc.exists) {
        // Update email verification status in Firestore
        if (user.emailVerified) {
          await _firestore.collection('clients').doc(user.uid).update({
            'emailVerified': true,
          });
        }

        // For existing accounts, if emailVerified field doesn't exist, update it
        final userData = clientDoc.data();
        if (userData != null && !userData.containsKey('emailVerified')) {
          await _firestore.collection('clients').doc(user.uid).update({
            'emailVerified': user.emailVerified,
          });
        }

        return {
          'success': true,
          'role': 'client',
          'userData': clientDoc.data(),
          'emailVerified': user.emailVerified,
        };
      }

      // Check in organizers collection
      var organizerDoc =
          await _firestore
              .collection('organizers')
              .doc(userCredential.user!.uid)
              .get();

      if (organizerDoc.exists) {
        // Update email verification status in Firestore
        if (user.emailVerified) {
          await _firestore.collection('organizers').doc(user.uid).update({
            'emailVerified': true,
          });
        }

        // For existing accounts, if emailVerified field doesn't exist, update it
        final userData = organizerDoc.data();
        if (userData != null && !userData.containsKey('emailVerified')) {
          await _firestore.collection('organizers').doc(user.uid).update({
            'emailVerified': user.emailVerified,
          });
        }

        return {
          'success': true,
          'role': 'organizer',
          'userData': organizerDoc.data(),
          'emailVerified': user.emailVerified,
        };
      }

      // If we get here, user exists in Firebase Auth but not in Firestore
      return {'success': false, 'message': 'User profile not found'};
    } on FirebaseAuthException catch (e) {
      return _handleFirebaseAuthError(e);
    } catch (e) {
      print('Login error: $e');
      return {'success': false, 'message': 'An error occurred during login'};
    }
  }

  // Method to resend verification email to current user
  Future<Map<String, dynamic>> resendVerificationEmail() async {
    try {
      User? user = _auth.currentUser;
      if (user != null && !user.emailVerified) {
        await user.sendEmailVerification();
        return {
          'success': true,
          'message':
              'Verification email has been sent. Please check your inbox.',
        };
      }
      return {
        'success': false,
        'message': 'Unable to send verification email. Please try again later.',
      };
    } catch (e) {
      return {
        'success': false,
        'message': 'Error sending verification email: $e',
      };
    }
  }

  Future<void> signOut() async {
    try {
      print('Attempting signout');
      await _auth.signOut();
      print('Signout successful');
    } catch (e) {
      print('Signout error: $e');
      rethrow;
    }
  }

  Stream<User?> get authStateChanges => _auth.authStateChanges();

  // Helper method to handle Firebase Auth errors
  Map<String, dynamic> _handleFirebaseAuthError(FirebaseAuthException e) {
    print('Firebase Auth Error: ${e.code} - ${e.message}');

    switch (e.code) {
      case 'user-not-found':
        return {
          'success': false,
          'message': 'No user found with this email address',
        };
      case 'wrong-password':
        return {'success': false, 'message': 'Incorrect password'};
      case 'invalid-email':
        return {'success': false, 'message': 'Email address is not valid'};
      case 'user-disabled':
        return {
          'success': false,
          'message': 'This user account has been disabled',
        };
      case 'too-many-requests':
        return {
          'success': false,
          'message': 'Too many failed login attempts. Please try again later',
        };
      case 'network-request-failed':
        return {
          'success': false,
          'message': 'Network error. Please check your connection',
        };
      default:
        return {'success': false, 'message': e.message ?? 'Login failed'};
    }
  }
}
