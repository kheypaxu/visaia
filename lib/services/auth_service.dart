import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:visaia/services/auth_cache_service.dart';
import 'package:visaia/services/connectivity_service.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final AuthCacheService _cacheService = AuthCacheService();
  final ConnectivityService _connectivityService = ConnectivityService();

  // Sign in – returns UserCredential if online, or null if offline fallback
  Future<UserCredential?> signInWithEmailAndPassword(
      String email, String password) async {
    final isOnline = _connectivityService.isOnline;

    if (!isOnline) {
      final isValid = await _cacheService.verifyOfflineCredentials(email, password);
      if (isValid) {
        debugPrint('🔓 Offline login successful using cached credentials.');
        return null;
      }

      final cachedEmail = _cacheService.cachedEmail;
      if (cachedEmail != null &&
          cachedEmail == email.trim().toLowerCase()) {
        throw Exception('Incorrect password for cached offline account.');
      } else {
        throw Exception(
            'You are currently offline. Please connect to Wi-Fi or mobile data to sign in for the first time.');
      }
    }

    try {
      return await _auth.signInWithEmailAndPassword(
        email: email.trim(),
        password: password.trim(),
      );
    } on FirebaseAuthException catch (e) {
      // If network error during Firebase auth, try offline fallback
      if (e.code == 'network-request-failed') {
        final isValid =
            await _cacheService.verifyOfflineCredentials(email, password);
        if (isValid) {
          debugPrint('🔓 Network failed: Fallen back to offline cached credentials.');
          return null;
        }
      }
      throw _handleAuthException(e);
    } catch (e) {
      throw Exception(e.toString());
    }
  }

  // Sign up
  Future<UserCredential> signUpWithEmailAndPassword(
      String email, String password) async {
    try {
      return await _auth.createUserWithEmailAndPassword(
        email: email.trim(),
        password: password.trim(),
      );
    } on FirebaseAuthException catch (e) {
      throw _handleAuthException(e);
    }
  }

  // Sign out
  Future<void> signOut() async {
    try {
      await _auth.signOut();
    } catch (e) {
      debugPrint('Firebase signout error: $e');
    }
    await _cacheService.clearActiveSession();
  }

  // Get verification status from Firestore (farmers collection) with offline fallback
  Future<String?> getUserVerificationStatus(String uid) async {
    try {
      DocumentSnapshot doc =
          await _firestore.collection('farmers').doc(uid).get();
      if (doc.exists) {
        final status = doc.get('status') as String?;
        if (status != null) {
          await _cacheService.updateProfile(verificationStatus: status);
        }
        return status;
      }
      return null;
    } catch (e) {
      debugPrint('Firestore fetch verification status error: $e. Using cache.');
      return _cacheService.cachedVerificationStatus;
    }
  }

  // Combine sign-in + verification check + session caching
  Future<void> signInAndVerify(String email, String password) async {
    final isOnline = _connectivityService.isOnline;

    if (!isOnline) {
      // Offline verification flow
      final isValid =
          await _cacheService.verifyOfflineCredentials(email, password);
      if (!isValid) {
        final cachedEmail = _cacheService.cachedEmail;
        if (cachedEmail != null &&
            cachedEmail == email.trim().toLowerCase()) {
          throw Exception('Incorrect password for cached offline account.');
        } else {
          throw Exception(
              'No cached credentials found for this account. Please connect to internet to sign in.');
        }
      }

      final status = _cacheService.cachedVerificationStatus;
      if (status != 'verified') {
        throw Exception(
            'Your account has not been verified by an admin yet.');
      }

      _cacheService.isOfflineSessionActive = true;
      return;
    }

    // Online verification flow
    UserCredential? cred;
    try {
      cred = await signInWithEmailAndPassword(email, password);
    } catch (e) {
      rethrow;
    }

    if (cred?.user == null) {
      // Handled by offline fallback inside signInWithEmailAndPassword
      return;
    }

    final uid = cred!.user!.uid;
    final status = await getUserVerificationStatus(uid);

    if (status != 'verified') {
      await signOut(); // kick out unverified users
      throw Exception('Your account has not been verified by an admin yet.');
    }

    // Fetch farmer details to populate offline cache
    String? farmerName;
    String? profileImage;
    bool hasFarm = false;
    bool hasFields = false;
    String? activeFarmId;
    String? activeFarmName;

    try {
      final farmerDoc = await _firestore.collection('farmers').doc(uid).get();
      if (farmerDoc.exists) {
        farmerName = farmerDoc.data()?['name'] ?? farmerDoc.data()?['fullName'];
        profileImage = farmerDoc.data()?['profileImage'];
      }

      final userDoc = await _firestore.collection('users').doc(uid).get();
      if (userDoc.exists) {
        hasFarm = userDoc.data()?['hasFarm'] as bool? ?? false;
        hasFields = userDoc.data()?['hasFields'] as bool? ?? false;
      }

      final farmSnapshot = await _firestore
          .collection('users')
          .doc(uid)
          .collection('farms')
          .orderBy('createdAt', descending: true)
          .limit(1)
          .get();

      if (farmSnapshot.docs.isNotEmpty) {
        activeFarmId = farmSnapshot.docs.first.id;
        activeFarmName = farmSnapshot.docs.first.data()['name'];
      }
    } catch (e) {
      debugPrint('Note: Pre-caching farmer profile had non-fatal error: $e');
    }

    // Save full user credentials & profile to local offline cache
    await _cacheService.cacheUserSession(
      uid: uid,
      email: email,
      password: password,
      name: farmerName ?? cred.user?.displayName,
      verificationStatus: status,
      profileImage: profileImage,
      hasFarm: hasFarm,
      hasFields: hasFields,
      activeFarmId: activeFarmId,
      activeFarmName: activeFarmName,
    );
  }

  // Error handling
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
    } else if (e.code == 'network-request-failed') {
      return Exception('Network error. Check your connection or use offline login.');
    } else {
      return Exception(e.message ?? 'An unknown error occurred.');
    }
  }
}