import 'package:flutter/material.dart';
import '../constants/app_colors.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class EmailEditScreen extends StatefulWidget {
  final String initialEmail;
  final Function(String) onSave;

  const EmailEditScreen({
    Key? key,
    required this.initialEmail,
    required this.onSave,
  }) : super(key: key);

  @override
  State<EmailEditScreen> createState() => _EmailEditScreenState();
}

class _EmailEditScreenState extends State<EmailEditScreen> {
  late TextEditingController _emailController;
  bool _isLoading = false;
  String? _errorText;

  @override
  void initState() {
    super.initState();
    _emailController = TextEditingController(text: widget.initialEmail);
  }

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  bool _isValidEmail(String email) {
    final emailRegex = RegExp(
      r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$',
    );
    return emailRegex.hasMatch(email);
  }

  void _saveEmail() {
    final email = _emailController.text.trim();

    if (email.isEmpty) {
      setState(() {
        _errorText = 'Email cannot be empty';
      });
      return;
    }

    if (!_isValidEmail(email)) {
      setState(() {
        _errorText = 'Please enter a valid email address';
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _errorText = null;
    });

    // Call the onSave callback
    widget
        .onSave(email)
        .then((_) {
          // Show success message
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'Email updated successfully',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
              backgroundColor: Colors.green,
            ),
          );

          // Go back to previous screen after saving
          Navigator.pop(context);
        })
        .catchError((error) {
          setState(() {
            _isLoading = false;
            _errorText = error.toString();
          });
        });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.creamBackground,
      body: SafeArea(
        child: Column(
          children: [
            // Custom app bar with the same style as client home screen
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: const BoxDecoration(
                color: Color(0xFF9D9DCC),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black12,
                    offset: Offset(0, 2),
                    blurRadius: 4,
                  ),
                ],
              ),
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.arrow_back, color: Colors.white),
                    onPressed: () => Navigator.pop(context),
                  ),
                  const Text(
                    'Email',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.check, color: Colors.white),
                    onPressed: _isLoading ? null : _saveEmail,
                  ),
                ],
              ),
            ),

            // Main content
            Expanded(
              child:
                  _isLoading
                      ? const Center(
                        child: CircularProgressIndicator(
                          color: Color(0xFF9D9DCC),
                        ),
                      )
                      : SingleChildScrollView(
                        child: Padding(
                          padding: const EdgeInsets.all(20.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.start,
                                mainAxisSize: MainAxisSize.max,
                                children: [
                                  Container(
                                    width: 3,
                                    height: 24,
                                    decoration: BoxDecoration(
                                      color: Colors.black87,
                                      borderRadius: BorderRadius.circular(1.5),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  const Text(
                                    'Change Email',
                                    style: TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.black87,
                                      letterSpacing: 0.5,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 32),

                              // Email field
                              TextField(
                                controller: _emailController,
                                decoration: InputDecoration(
                                  labelText: 'Email',
                                  filled: true,
                                  fillColor: Colors.grey.withOpacity(0.1),
                                  labelStyle: TextStyle(
                                    color: Colors.grey[600],
                                    fontSize: 16,
                                  ),
                                  contentPadding: const EdgeInsets.symmetric(
                                    vertical: 10.0,
                                    horizontal: 12.0,
                                  ),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                    borderSide: BorderSide.none,
                                  ),
                                  enabledBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                    borderSide: BorderSide.none,
                                  ),
                                  focusedBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                    borderSide: const BorderSide(
                                      color: Color(0xFF9D9DCC),
                                      width: 1,
                                    ),
                                  ),
                                  isDense: true,
                                  errorText: _errorText,
                                ),
                                style: const TextStyle(
                                  color: Colors.black87,
                                  fontSize: 16,
                                ),
                                keyboardType: TextInputType.emailAddress,
                                textInputAction: TextInputAction.done,
                                onSubmitted: (_) => _saveEmail(),
                              ),
                            ],
                          ),
                        ),
                      ),
            ),

            // Continue button at bottom
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              child: ElevatedButton(
                onPressed: _isLoading ? null : _saveEmail,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF9D9DCC),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 15),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  elevation: 0,
                ),
                child:
                    _isLoading
                        ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2,
                          ),
                        )
                        : const Text(
                          'Continue',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
