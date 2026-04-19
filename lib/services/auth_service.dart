import 'package:firebase_auth/firebase_auth.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // Sign in
  Future<UserCredential> signInWithEmailAndPassword(String email, String password) async {
    try {
      return await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
    } on FirebaseAuthException catch (e) {
      throw _handleAuthException(e);
    }
  }

  // Sign up
  Future<UserCredential> signUpWithEmailAndPassword(String email, String password) async {
    try {
      return await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );
    } on FirebaseAuthException catch (e) {
      throw _handleAuthException(e);
    }
  }

  // Sign out
  Future<void> signOut() async {
    await _auth.signOut();
  }

  // Centralized Error Handling
  Exception _handleAuthException(FirebaseAuthException e) {
    if (e.code == 'user-not-found') {
      return Exception('No user found for that email.');
    } else if (e.code == 'wrong-password') {
      return Exception('Wrong password provided for that user.');
    } else if (e.code == 'invalid-credential') {
      return Exception('Invalid email or password.');
    } else if (e.code == 'email-already-in-use') {
      return Exception('The account already exists for that email.');
    } else if (e.code == 'weak-password') {
      return Exception('The password provided is too weak.');
    } else if (e.code == 'invalid-email') {
      return Exception('The email address is invalid.');
    } else {
      return Exception(e.message ?? 'An unknown error occurred.');
    }
  }
}
