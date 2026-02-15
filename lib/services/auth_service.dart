import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/user_model.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Get current user
  User? get currentUser => _auth.currentUser;

  // Auth state changes
  Stream<User?> get authStateChanges => _auth.authStateChanges();

  // Sign up with email and password
  Future<UserModel?> signUpWithEmail({
    required String email,
    required String password,
    required String name,
  }) async {
    try {
      final UserCredential userCredential = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      if (userCredential.user != null) {
        final user = UserModel(
          id: userCredential.user!.uid,
          email: email,
          name: name,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        );

        await _firestore.collection('users').doc(user.id).set(user.toJson());
        return user;
      }
    } on FirebaseAuthException catch (e) {
      switch (e.code) {
        case 'email-already-in-use':
          throw Exception('This email is already registered. Please sign in instead.');
        case 'weak-password':
          throw Exception('Password is too weak. Please use a stronger password.');
        case 'invalid-email':
          throw Exception('Invalid email address.');
        case 'operation-not-allowed':
          throw Exception('Email/password accounts are not enabled.');
        default:
          throw Exception('Sign up failed: ${e.message}');
      }
    } catch (e) {
      throw Exception('Sign up failed: $e');
    }
    return null;
  }

  // Sign in with email and password
  Future<UserModel?> signInWithEmail({
    required String email,
    required String password,
  }) async {
    try {
      final UserCredential userCredential = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );

      if (userCredential.user != null) {
        return await getUserData(userCredential.user!.uid);
      }
    } on FirebaseAuthException catch (e) {
      switch (e.code) {
        case 'user-not-found':
          throw Exception('No account found with this email. Please sign up first.');
        case 'wrong-password':
          throw Exception('Incorrect password. Please try again.');
        case 'invalid-email':
          throw Exception('Invalid email address.');
        case 'user-disabled':
          throw Exception('This account has been disabled.');
        case 'too-many-requests':
          throw Exception('Too many failed attempts. Please try again later.');
        default:
          throw Exception('Sign in failed: ${e.message}');
      }
    } catch (e) {
      throw Exception('Sign in failed: $e');
    }
    return null;
  }

  // Get user data from Firestore
  Future<UserModel?> getUserData(String uid) async {
    try {
      final doc = await _firestore.collection('users').doc(uid).get();
      if (doc.exists) {
        return UserModel.fromJson(doc.data()!);
      }
    } catch (e) {
      throw Exception('Failed to get user data: $e');
    }
    return null;
  }

  // Update user profile
  Future<void> updateUserProfile(UserModel user) async {
    try {
      await _firestore.collection('users').doc(user.id).update(user.toJson());
    } catch (e) {
      throw Exception('Failed to update user profile: $e');
    }
  }

  // Sign out
  Future<void> signOut() async {
    try {
      await _auth.signOut();
    } catch (e) {
      throw Exception('Sign out failed: $e');
    }
  }

  // Reset password
  Future<void> resetPassword(String email) async {
    try {
      await _auth.sendPasswordResetEmail(email: email);
    } on FirebaseAuthException catch (e) {
      switch (e.code) {
        case 'user-not-found':
          throw Exception('No account found with this email.');
        case 'invalid-email':
          throw Exception('Invalid email address.');
        default:
          throw Exception('Password reset failed: ${e.message}');
      }
    } catch (e) {
      throw Exception('Password reset failed: $e');
    }
  }

  // Delete account
  Future<void> deleteAccount() async {
    try {
      final userId = currentUser?.uid;
      if (userId != null) {
        await _firestore.collection('users').doc(userId).delete();
        await currentUser?.delete();
      }
    } catch (e) {
      throw Exception('Account deletion failed: $e');
    }
  }
}
