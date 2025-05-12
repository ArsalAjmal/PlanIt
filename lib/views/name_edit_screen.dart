import 'package:flutter/material.dart';
import '../constants/app_colors.dart';

class NameEditScreen extends StatefulWidget {
  final String initialName;
  final Function(String) onSave;

  const NameEditScreen({
    Key? key,
    required this.initialName,
    required this.onSave,
  }) : super(key: key);

  @override
  State<NameEditScreen> createState() => _NameEditScreenState();
}

class _NameEditScreenState extends State<NameEditScreen> {
  late TextEditingController _firstNameController;
  late TextEditingController _lastNameController;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    // Split the full name into first name and last name
    final nameParts = widget.initialName.split(' ');
    _firstNameController = TextEditingController(
      text: nameParts.isNotEmpty ? nameParts[0] : '',
    );
    _lastNameController = TextEditingController(
      text: nameParts.length > 1 ? nameParts.sublist(1).join(' ') : '',
    );
  }

  @override
  void dispose() {
    _firstNameController.dispose();
    _lastNameController.dispose();
    super.dispose();
  }

  void _saveName() {
    final firstName = _firstNameController.text.trim();
    final lastName = _lastNameController.text.trim();

    if (firstName.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'First name cannot be empty',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
          ),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    // Combine first and last name
    final fullName = lastName.isEmpty ? firstName : '$firstName $lastName';

    // Call the onSave callback
    widget
        .onSave(fullName)
        .then((_) {
          // Show success message
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'Username updated successfully',
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
                    'Name',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.check, color: Colors.white),
                    onPressed: _isLoading ? null : _saveName,
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
                                    'Change username',
                                    style: TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.black87,
                                      letterSpacing: 0.5,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 24),
                              // First name field with portfolio style
                              TextField(
                                controller: _firstNameController,
                                decoration: InputDecoration(
                                  labelText: 'First Name',
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
                                ),
                                style: const TextStyle(
                                  color: Colors.black87,
                                  fontSize: 16,
                                ),
                              ),

                              const SizedBox(height: 20),

                              // Last name field with portfolio style
                              TextField(
                                controller: _lastNameController,
                                decoration: InputDecoration(
                                  labelText: 'Last Name',
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
                                ),
                                style: const TextStyle(
                                  color: Colors.black87,
                                  fontSize: 16,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
            ),

            // Save button at bottom
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              child: ElevatedButton(
                onPressed: _isLoading ? null : _saveName,
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
                          'Save',
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
