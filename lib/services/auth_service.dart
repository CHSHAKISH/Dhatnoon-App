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
      print('Sign-in error: ${e.message}');
      return null;
    }
  }

  // --- UPDATED ---
  // Now accepts a 'role' parameter
  Future<UserCredential?> signUpWithEmail(String email, String password, String role) async {
    try {
      UserCredential userCredential = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      // After sign up, save user info (including the role) to Firestore
      if (userCredential.user != null) {
        // Pass the role to our save function
        await _saveUserToFirestore(userCredential.user!, role);
      }
      return userCredential;
    } on FirebaseAuthException catch (e) {
      print('Sign-up error: ${e.message}');
      return null;
    }
  }

  // --- UPDATED ---
  // Now accepts a 'role' parameter
  Future<void> _saveUserToFirestore(User user, String role) async {
    return _firestore.collection('users').doc(user.uid).set({
      'uid': user.uid,
      'email': user.email,
      'role': role, // <-- Save the selected role
      'createdAt': Timestamp.now(),
    });
  }

  // Sign Out
  Future<void> signOut() async {
    await _auth.signOut();
  }
}