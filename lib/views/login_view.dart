// ignore_for_file: deprecated_member_use

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import '../controllers/login_controller.dart';
import '../utils/gradient_animation.dart';
import '../views/signup_screen.dart';
import 'client_home_screen.dart';
import 'organizer_home_screen.dart';
import 'forgot_password_screen.dart';

class LoginView extends StatefulWidget {
  const LoginView({super.key});

  @override
  State<LoginView> createState() => _LoginViewState();
}

class _LoginViewState extends State<LoginView> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _passwordVisible = false;
  String? _verificationEmail;
  bool _isResendingEmail = false;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _handleLogin() async {
    if (_formKey.currentState!.validate()) {
      final loginController = context.read<LoginController>();
      final result = await loginController.login(
        _emailController.text,
        _passwordController.text,
      );

      if (result) {
        // Login success, navigate based on role
        if (mounted) {
          final role = loginController.userRole;
          if (role == 'client') {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(builder: (context) => const ClientHomeScreen()),
            );
          } else if (role == 'organizer') {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(
                builder: (context) => const OrganizerHomeScreen(),
              ),
            );
          }
        }
      } else if (loginController.errorMessage?.contains('verify your email') ==
          true) {
        // If verification error, double-check status directly with Firebase
        // This handles cases where the user verified but the cached status hasn't updated
        final isVerified = await loginController.checkEmailVerificationStatus();
        if (isVerified) {
          // User is actually verified, try login again
          setState(() {
            _verificationEmail = null; // Clear verification message
          });
          // Retry login
          _handleLogin();
        } else {
          // Verification truly needed, show the verification UI
          setState(() {
            _verificationEmail = _emailController.text;
          });

          // Show verification needed message
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                loginController.errorMessage ??
                    'Please verify your email before logging in',
                style: const TextStyle(color: Colors.white),
              ),
              backgroundColor: Colors.red,
              duration: const Duration(seconds: 5),
              behavior: SnackBarBehavior.floating,
              margin: const EdgeInsets.all(16),
              action: SnackBarAction(
                label: 'Resend',
                textColor: Colors.white,
                onPressed: _resendVerificationEmail,
              ),
            ),
          );
        }
      } else {
        // Other login error, show snackbar
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                loginController.errorMessage ?? 'Login failed',
                style: const TextStyle(color: Colors.white),
              ),
              backgroundColor: Colors.red,
              duration: const Duration(seconds: 3),
              behavior: SnackBarBehavior.floating,
              margin: const EdgeInsets.all(16),
            ),
          );
        }
      }
    }
  }

  Future<void> _resendVerificationEmail() async {
    if (_verificationEmail != null && _passwordController.text.isNotEmpty) {
      final loginController = context.read<LoginController>();

      // Show loading
      setState(() {
        _isResendingEmail = true;
      });

      final success = await loginController.resendVerificationEmail(
        _verificationEmail!,
        _passwordController.text,
      );

      // Show result
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              success
                  ? 'Verification email sent to $_verificationEmail'
                  : 'Failed to send verification email. Please try again.',
              style: const TextStyle(color: Colors.white),
            ),
            backgroundColor: success ? Colors.green : Colors.red,
            duration: const Duration(seconds: 3),
          ),
        );
      }

      // Hide loading
      setState(() {
        _isResendingEmail = false;
      });
    }
  }

  void _navigateToSignUp() {
    Navigator.push(
      context,
      PageRouteBuilder(
        pageBuilder:
            (context, animation, secondaryAnimation) => const SignUpScreen(),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return FadeTransition(opacity: animation, child: child);
        },
        transitionDuration: const Duration(milliseconds: 300),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: CreamNavyGradient(
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Form(
                  key: _formKey,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      // Logo
                      Container(
                        margin: const EdgeInsets.only(bottom: 5.0),
                        width: 150,
                        height: 150,
                        child: Image.asset(
                          'assets/images/newlogo3.png',
                          fit: BoxFit.contain,
                          errorBuilder: (context, error, stackTrace) {
                            return const Icon(
                              Icons.error_outline,
                              color: Colors.red,
                              size: 50,
                            );
                          },
                        ),
                      ),
                      // Login Form
                      Container(
                        padding: const EdgeInsets.all(24.0),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.9),
                          borderRadius: BorderRadius.circular(16.0),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.1),
                              blurRadius: 10,
                              spreadRadius: 2,
                            ),
                          ],
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              'Welcome!',
                              style: GoogleFonts.poppins(
                                fontSize: 32,
                                fontWeight: FontWeight.bold,
                                color: const Color(0xFF9D9DCC),
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Please Login to Your Account',
                              style: GoogleFonts.poppins(
                                fontSize: 16,
                                color: Colors.grey[600],
                              ),
                            ),
                            const SizedBox(height: 32),
                            // Email Field
                            TextFormField(
                              controller: _emailController,
                              decoration: InputDecoration(
                                labelText: 'Email',
                                prefixIcon: const Icon(Icons.email_outlined),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                              validator: (value) {
                                if (value == null || value.isEmpty) {
                                  return 'Please enter your email';
                                }
                                return null;
                              },
                            ),
                            const SizedBox(height: 16),
                            // Password Field
                            TextFormField(
                              controller: _passwordController,
                              obscureText: !_passwordVisible,
                              decoration: InputDecoration(
                                labelText: 'Password',
                                prefixIcon: const Icon(Icons.lock_outline),
                                suffixIcon: IconButton(
                                  icon: Icon(
                                    _passwordVisible
                                        ? Icons.visibility_off
                                        : Icons.visibility,
                                  ),
                                  onPressed: () {
                                    setState(() {
                                      _passwordVisible = !_passwordVisible;
                                    });
                                  },
                                ),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                              validator: (value) {
                                if (value == null || value.isEmpty) {
                                  return 'Please enter your password';
                                }
                                return null;
                              },
                            ),
                            const SizedBox(height: 8),
                            // Forgot Password Text
                            Align(
                              alignment: Alignment.centerRight,
                              child: GestureDetector(
                                onTap: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder:
                                          (context) =>
                                              const ForgotPasswordScreen(),
                                    ),
                                  );
                                },
                                child: Text(
                                  'Forgot Password?',
                                  style: TextStyle(
                                    color: Colors.black87,
                                    fontWeight: FontWeight.w500,
                                    fontSize: 14,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(height: 24),
                            // Login Button
                            Consumer<LoginController>(
                              builder: (context, controller, child) {
                                return SizedBox(
                                  width: double.infinity,
                                  height: 50,
                                  child: ElevatedButton(
                                    onPressed:
                                        controller.isLoading
                                            ? null
                                            : _handleLogin,
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: const Color(0xFF9D9DCC),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                    ),
                                    child:
                                        controller.isLoading
                                            ? const CircularProgressIndicator(
                                              color: Colors.white,
                                            )
                                            : const Text(
                                              'Login',
                                              style: TextStyle(
                                                fontSize: 16,
                                                color: Colors.white,
                                              ),
                                            ),
                                  ),
                                );
                              },
                            ),
                            const SizedBox(height: 16),
                            // Sign Up Text and Button
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(
                                  'Don\'t have an account? ',
                                  style: TextStyle(
                                    color: Colors.black87,
                                    fontSize: 14,
                                  ),
                                ),
                                GestureDetector(
                                  onTap: _navigateToSignUp,
                                  child: Text(
                                    'Sign up',
                                    style: TextStyle(
                                      color: const Color(0xFF9D9DCC),
                                      fontWeight: FontWeight.bold,
                                      fontSize: 14,
                                    ),
                                  ),
                                ),
                              ],
                            ),

                            // Verification Email Reminder
                            if (_verificationEmail != null) ...[
                              const SizedBox(height: 16),
                              Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: Colors.red.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(
                                    color: Colors.red.shade300,
                                  ),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text(
                                      "Email Verification Required",
                                      style: TextStyle(
                                        color: Colors.red,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      "Please verify ${_verificationEmail} before logging in.",
                                      style: TextStyle(
                                        color: Colors.red.shade700,
                                        fontSize: 13,
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    Align(
                                      alignment: Alignment.centerRight,
                                      child: TextButton(
                                        onPressed: _resendVerificationEmail,
                                        style: TextButton.styleFrom(
                                          foregroundColor: Colors.red,
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 12,
                                            vertical: 4,
                                          ),
                                        ),
                                        child: const Text(
                                          "Resend Verification Email",
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
