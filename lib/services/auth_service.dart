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

      // Store user data in Firestore
      if (role == 'client') {
        await _firestore
            .collection('clients')
            .doc(userCredential.user!.uid)
            .set({'email': email, 'role': role});
      } else {
        await _firestore
            .collection('organizers')
            .doc(userCredential.user!.uid)
            .set({'email': email, 'role': role});
      }

      return {'success': true};
    } on FirebaseAuthException catch (e) {
      if (e.code == 'email-already-in-use') {
        return {
          'success': false,
          'message': 'This email is already registered.',
        };
      }
      return {'success': false, 'message': 'An error occurred during signup.'};
    }
  }

  Future<Map<String, dynamic>?> login(String email, String password) async {
    try {
      print('Attempting login for email: $email');
      final UserCredential userCredential = await _auth
          .signInWithEmailAndPassword(email: email, password: password);

      // Check in clients collection
      var clientDoc =
          await _firestore
              .collection('clients')
              .doc(userCredential.user!.uid)
              .get();

      if (clientDoc.exists) {
        return {
          'success': true,
          'role': 'client',
          'userData': clientDoc.data(),
        };
      }

      // Check in organizers collection
      var organizerDoc =
          await _firestore
              .collection('organizers')
              .doc(userCredential.user!.uid)
              .get();

      if (organizerDoc.exists) {
        return {
          'success': true,
          'role': 'organizer',
          'userData': organizerDoc.data(),
        };
      }

      return {'success': false};
    } catch (e) {
      print('Login error: $e');
      return {'success': false};
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
}
