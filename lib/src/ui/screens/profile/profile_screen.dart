import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:jewelry_nafisa/src/auth/firebase_auth_service.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final FirebaseAuthService authService = FirebaseAuthService();
    final User? currentUser = FirebaseAuth.instance.currentUser;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Profile'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () async {
              await authService.signOut();
              // The AuthGate will handle navigation to the LoginScreen
            },
          ),
        ],
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            const SizedBox(height: 20),
            // Profile picture
            const CircleAvatar(
              radius: 50,
              // You can use a network image here if you have one
              // backgroundImage: NetworkImage(currentUser?.photoURL ?? ''),
              child: Icon(Icons.person, size: 50),
            ),
            const SizedBox(height: 10),
            // Username
            Text(
              currentUser?.displayName ?? 'Username',
              style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 20),
            // Create Board Button
            ElevatedButton(
              onPressed: () {
                // TODO: Implement "Create Board" functionality
              },
              child: const Text('Create Board'),
            ),
            const SizedBox(height: 20),
            const Divider(),
            // You can add the user's boards/pins here
            const Center(
              child: Text(
                'Your boards will appear here',
                style: TextStyle(fontSize: 16, color: Colors.grey),
              ),
            ),
          ],
        ),
      ),
    );
  }
}