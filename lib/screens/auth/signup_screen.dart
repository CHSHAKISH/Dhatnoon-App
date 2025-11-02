import 'package:dhatnoon_app/services/auth_service.dart';
import 'package:flutter/material.dart';

// Enum to hold our role options
enum UserRole { requester, sender }

class SignUpScreen extends StatefulWidget {
  const SignUpScreen({super.key});

  @override
  State<SignUpScreen> createState() => _SignUpScreenState();
}

class _SignUpScreenState extends State<SignUpScreen> {
  final AuthService _authService = AuthService();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  // --- NEW ---
  // State to hold the selected role, default to 'requester'
  UserRole _selectedRole = UserRole.requester;

  void _signUp() async {
    if (_emailController.text.isEmpty || _passwordController.text.isEmpty) {
      print("Email and password cannot be empty");
      return;
    }

    // Convert the enum to a string for Firebase
    String roleString =
    _selectedRole == UserRole.requester ? 'requester' : 'sender';

    var result = await _authService.signUpWithEmail(
      _emailController.text.trim(),
      _passwordController.text.trim(),
      roleString, // Pass the selected role to our auth service
    );

    if (result != null && mounted) {
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Create Account'),
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 60),
              const Text(
                'Get Started',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 40),
              // Email Field
              TextField(
                controller: _emailController,
                keyboardType: TextInputType.emailAddress,
                decoration: const InputDecoration(labelText: 'Email', prefixIcon: Icon(Icons.email_outlined)),
              ),
              const SizedBox(height: 16),
              // Password Field
              TextField(
                controller: _passwordController,
                obscureText: true,
                decoration: const InputDecoration(labelText: 'Password', prefixIcon: Icon(Icons.lock_outline_rounded)),
              ),
              const SizedBox(height: 24),

              // --- NEW ROLE SELECTOR ---
              const Text(
                'I am a:',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 12),
              SegmentedButton<UserRole>(
                segments: const [
                  ButtonSegment(
                    value: UserRole.requester,
                    label: Text('Requester'),
                    icon: Icon(Icons.person_search),
                  ),
                  ButtonSegment(
                    value: UserRole.sender,
                    label: Text('Sender'),
                    icon: Icon(Icons.local_shipping),
                  ),
                ],
                selected: {_selectedRole},
                onSelectionChanged: (Set<UserRole> newSelection) {
                  setState(() {
                    _selectedRole = newSelection.first;
                  });
                },
                style: SegmentedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
              ),
              // --- END OF NEW WIDGET ---

              const SizedBox(height: 30),
              // Sign Up Button
              ElevatedButton(
                onPressed: _signUp,
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
                child: const Text(
                  'Sign Up',
                  style: TextStyle(fontSize: 18),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}