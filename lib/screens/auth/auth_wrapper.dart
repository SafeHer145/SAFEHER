import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../auth/auth_choice_page.dart';
import '../../dashboard/dashboard_page.dart';

class AuthWrapper extends StatelessWidget {
  const AuthWrapper({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(
              child: CircularProgressIndicator(),
            ),
          );
        }

        if (snapshot.hasData) {
          // User is logged in
          final user = snapshot.data!;

          // 1) Block access until email verified
          if (!user.emailVerified) {
            return _VerifyEmailGate(user: user);
          }

          // 2) Email verified – check Firestore profile
          String userId = user.uid;

          return FutureBuilder<DocumentSnapshot>(
            future: FirebaseFirestore.instance
                .collection('users')
                .doc(userId)
                .get(),
            builder: (context, docSnapshot) {
              if (docSnapshot.connectionState == ConnectionState.waiting) {
                return const Scaffold(
                  body: Center(child: CircularProgressIndicator()),
                );
              }
              
              if (docSnapshot.hasData && docSnapshot.data!.exists) {
                return DashboardPage(userId: userId);
              } else {
                // No user document yet. This usually means the user verified but didn't
                // finish profile setup on the registration flow. Redirect to AuthChoice
                // so they can complete registration (or we can add a dedicated onboarding).
                return const AuthChoicePage();
              }
            },
          );
        } else {
          // User is not logged in
          return const AuthChoicePage();
        }
      },
    );
  }
}

class _VerifyEmailGate extends StatefulWidget {
  final User user;
  const _VerifyEmailGate({required this.user});

  @override
  State<_VerifyEmailGate> createState() => _VerifyEmailGateState();
}

class _VerifyEmailGateState extends State<_VerifyEmailGate> {
  bool _sending = false;
  bool _checking = false;

  Future<void> _resend() async {
    setState(() => _sending = true);
    try {
      await FirebaseAuth.instance.setLanguageCode('en');
      await widget.user.sendEmailVerification();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Verification email sent. Please check your inbox.')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to send verification: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  Future<void> _check() async {
    setState(() => _checking = true);
    await widget.user.reload();
    final refreshed = FirebaseAuth.instance.currentUser;
    if (refreshed != null && refreshed.emailVerified) {
      // Trigger rebuild of AuthWrapper
      if (mounted) setState(() => _checking = false);
    } else {
      if (mounted) {
        setState(() => _checking = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Email not verified yet.')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Verify Email')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('A verification link has been sent to your email. Please verify to continue.'),
            const SizedBox(height: 24),
            Row(children: [
              ElevatedButton(
                onPressed: _checking ? null : _check,
                child: _checking ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2)) : const Text('I\'ve verified'),
              ),
              const SizedBox(width: 16),
              TextButton(
                onPressed: _sending ? null : _resend,
                child: _sending ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2)) : const Text('Resend email'),
              ),
            ]),
            const SizedBox(height: 16),
            TextButton(
              onPressed: () async { await FirebaseAuth.instance.signOut(); },
              child: const Text('Sign out'),
            ),
          ],
        ),
      ),
    );
  }
}
