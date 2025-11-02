// lib/services/auth_service.dart
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Get the stream of user authentication changes
  Stream<User?> get authStateChanges => _auth.authStateChanges();

  // Sign In with Email & Password
  Future<UserCredential?> signInWithEmail(String email, String password) async {
    try {
      UserCredential userCredential = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
      return userCredential;
    } on FirebaseAuthException catch (e) {
      // You can handle errors here (e.g., show a snackbar)
      print('Sign-in error: ${e.message}');
      return null;
    }
  }

  // Sign Up with Email & Password
  Future<UserCredential?> signUpWithEmail(String email, String password) async {
    try {
      UserCredential userCredential = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      // After sign up, save user info to Firestore
      if (userCredential.user != null) {
        await _saveUserToFirestore(userCredential.user!);
      }
      return userCredential;
    } on FirebaseAuthException catch (e) {
      print('Sign-up error: ${e.message}');
      return null;
    }
  }

  // Save new user to 'users' collection
  Future<void> _saveUserToFirestore(User user) async {
    return _firestore.collection('users').doc(user.uid).set({
      'uid': user.uid,
      'email': user.email,
      'role': 'requester', // Default role, can be changed later
      'createdAt': Timestamp.now(),
    });
  }

  // Sign Out
  Future<void> signOut() async {
    await _auth.signOut();
  }
}