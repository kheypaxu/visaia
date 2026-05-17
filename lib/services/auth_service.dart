import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Sign in – returns only UserCredential, verification check happens after
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

  // Get verification status from Firestore (farmers collection)
  Future<String?> getUserVerificationStatus(String uid) async {
    try {
      DocumentSnapshot doc = await _firestore.collection('farmers').doc(uid).get();
      if (doc.exists) {
        return doc.get('status') as String?;
      }
      return null; // document doesn't exist → treat as unverified
    } catch (e) {
      return null;
    }
  }

  // Optional: Combine sign-in + verification in one call
  Future<void> signInAndVerify(String email, String password) async {
    UserCredential cred = await signInWithEmailAndPassword(email, password);
    final status = await getUserVerificationStatus(cred.user!.uid);
    if (status != 'verified') {
      await signOut(); // kick out unverified users
      throw Exception('Your account has not been verified by an admin yet.');
    }
  }

  // Error handling (unchanged)
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