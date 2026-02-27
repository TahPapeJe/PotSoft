import 'dart:ui';
import 'package:flutter/material.dart';

/// Full-screen frosted overlay that locks access to the contractor dashboard.
/// Rendered by [ContractorScreen] when the user is not authenticated.
class SecureGateWidget extends StatelessWidget {
  final TextEditingController passwordController;
  final String? errorMessage;
  final VoidCallback onSubmit;

  const SecureGateWidget({
    super.key,
    required this.passwordController,
    required this.onSubmit,
    this.errorMessage,
  });

  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
        child: Container(
          color: Colors.black.withValues(alpha: 0.65),
          child: Center(
            child: Container(
              width: 420,
              padding: const EdgeInsets.all(36),
              decoration: BoxDecoration(
                color: const Color(0xFF1E1E1E),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: Colors.tealAccent.withValues(alpha: 0.25),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.5),
                    blurRadius: 30,
                    spreadRadius: 5,
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.tealAccent.withValues(alpha: 0.1),
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: Colors.tealAccent.withValues(alpha: 0.3),
                      ),
                    ),
                    child: const Icon(
                      Icons.lock_outline,
                      size: 36,
                      color: Colors.tealAccent,
                    ),
                  ),
                  const SizedBox(height: 24),
                  const Text(
                    'JKR / PIC Restricted Access',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'This dashboard is accessible only to\nverified contractor and JKR personnel.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.white54,
                      fontSize: 13,
                      height: 1.5,
                    ),
                  ),
                  const SizedBox(height: 32),
                  TextField(
                    controller: passwordController,
                    obscureText: true,
                    autofocus: true,
                    decoration: InputDecoration(
                      labelText: 'Access Passcode',
                      prefixIcon: const Icon(Icons.vpn_key_outlined, size: 18),
                      errorText: (errorMessage?.isEmpty ?? true)
                          ? null
                          : errorMessage,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: const BorderSide(color: Colors.tealAccent),
                      ),
                    ),
                    onSubmitted: (_) => onSubmit(),
                  ),
                  const SizedBox(height: 20),
                  FilledButton.icon(
                    onPressed: onSubmit,
                    icon: const Icon(Icons.login),
                    label: const Text(
                      'UNLOCK DASHBOARD',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1.2,
                      ),
                    ),
                    style: FilledButton.styleFrom(
                      minimumSize: const Size(double.infinity, 50),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(28),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
