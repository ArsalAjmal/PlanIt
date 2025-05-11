import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../constants/app_colors.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;
import 'name_edit_screen.dart';
import 'email_edit_screen.dart';
import 'password_edit_screen.dart';

class AccountScreen extends StatefulWidget {
  final VoidCallback? onProfileImageChanged;

  const AccountScreen({Key? key, this.onProfileImageChanged}) : super(key: key);

  @override
  State<AccountScreen> createState() => _AccountScreenState();
}

class _AccountScreenState extends State<AccountScreen> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final ImagePicker _imagePicker = ImagePicker();
  bool _isLoading = true;

  String _displayName = '';
  String _email = '';
  String _password = '••••••••'; // Default masked password with 8 dots
  String _phoneNumber = 'Phone number not added';

  // Profile image handling
  File? _profileImage;
  static const String _profileImagePathKey = 'profile_image_path';

  @override
  void initState() {
    super.initState();
    _loadUserData();
    _loadProfileImage();
  }

  Future<void> _loadUserData() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final user = _auth.currentUser;
      if (user == null) {
        setState(() {
          _isLoading = false;
        });
        return;
      }

      // Set email from Firebase Auth
      _email = user.email ?? '';

      // Get display name from Firebase Auth or use email prefix as fallback
      _displayName = user.displayName ?? _email.split('@')[0];

      // Get phone number if available
      if (user.phoneNumber != null && user.phoneNumber!.isNotEmpty) {
        _phoneNumber = user.phoneNumber!;
      }

      // Attempt to get additional user data from Firestore
      try {
        final userDoc =
            await _firestore.collection('users').doc(user.uid).get();

        // Check if user document exists, if not create it
        if (!userDoc.exists) {
          // Create user document with initial data
          await _firestore.collection('users').doc(user.uid).set({
            'displayName': _displayName,
            'email': _email,
            'passwordLength': 14, // Set to length of "arsalajmal1337"
            'createdAt': DateTime.now(),
          });

          // Set password mask to match "arsalajmal1337"
          _password = '•' * 14;
        } else {
          final userData = userDoc.data();
          if (userData != null) {
            // Update with Firestore data if available
            if (userData['displayName'] != null) {
              _displayName = userData['displayName'];
            }
            if (userData['phoneNumber'] != null &&
                userData['phoneNumber'].toString().isNotEmpty) {
              _phoneNumber = userData['phoneNumber'];
            }

            // Try to get password length if stored in metadata
            if (userData['passwordLength'] != null) {
              int passwordLength = userData['passwordLength'];
              // Generate masked password with correct number of dots
              _password = '•' * passwordLength;
            } else {
              // If passwordLength doesn't exist, initialize it with length of "arsalajmal1337"
              await _firestore.collection('users').doc(user.uid).update({
                'passwordLength': 14,
              });
              _password = '•' * 14;
            }

            // Note: We don't retrieve the password as it should be stored as a hash
            // and not in plaintext for security reasons
          }
        }
      } catch (e) {
        print('Error fetching user data from Firestore: $e');
      }
    } catch (e) {
      print('Error loading user data: $e');
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  // Load profile image from shared preferences
  Future<void> _loadProfileImage() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final imagePath = prefs.getString(_profileImagePathKey);

      if (imagePath != null) {
        final file = File(imagePath);
        if (await file.exists()) {
          setState(() {
            _profileImage = file;
          });
        }
      }
    } catch (e) {
      print('Error loading profile image: $e');
    }
  }

  // Save profile image path to shared preferences
  Future<void> _saveProfileImagePath(String imagePath) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_profileImagePathKey, imagePath);
    } catch (e) {
      print('Error saving profile image path: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Could not save profile settings',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
          ),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  // Function to pick image
  Future<void> _pickImage(ImageSource source) async {
    try {
      final XFile? pickedImage = await _imagePicker.pickImage(
        source: source,
        maxWidth: 400,
        maxHeight: 400,
        imageQuality: 85,
      );

      if (pickedImage != null) {
        // Copy the image to app directory for persistence
        final appDir = await getApplicationDocumentsDirectory();
        final fileName = 'profile_${DateTime.now().millisecondsSinceEpoch}.jpg';
        final savedImagePath = path.join(appDir.path, fileName);

        // Copy the image
        final File savedImage = await File(
          pickedImage.path,
        ).copy(savedImagePath);

        setState(() {
          _profileImage = savedImage;
        });

        // Save the path for future app launches
        await _saveProfileImagePath(savedImagePath);

        // Notify parent screens about the change
        if (widget.onProfileImageChanged != null) {
          widget.onProfileImageChanged!();
        }

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Profile picture updated!',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Error picking image: $e',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
          ),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  // Delete profile image
  Future<void> _deleteProfileImage() async {
    try {
      // Remove image path from shared preferences
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_profileImagePathKey);

      // Delete the file if it exists
      if (_profileImage != null && await _profileImage!.exists()) {
        await _profileImage!.delete();
      }

      setState(() {
        _profileImage = null;
      });

      // Notify parent screens about the change
      if (widget.onProfileImageChanged != null) {
        widget.onProfileImageChanged!();
      }

      // Show a success message
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Profile picture removed',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
          ),
          backgroundColor: Colors.red,
        ),
      );
    } catch (e) {
      print('Error deleting profile image: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Could not remove profile picture',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
          ),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  // Adapter method for the PasswordEditScreen
  Future<void> _handlePasswordUpdate(String newPassword) async {
    // We don't have the current password from the screen
    // It will be entered in the PasswordEditScreen and verified there
    final user = _auth.currentUser;
    if (user == null) {
      throw Exception('User not found');
    }

    // Update password in Firebase Auth - authentication is handled in the PasswordEditScreen
    await user.updatePassword(newPassword);

    // Store password length in Firestore (not the password itself)
    await _firestore.collection('users').doc(user.uid).update({
      'passwordLength': newPassword.length,
      'lastPasswordUpdate': DateTime.now(),
    });

    // Update local state
    setState(() {
      _password = '•' * newPassword.length;
    });
  }

  // Show password edit screen
  void _showPasswordChangeDialog() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => PasswordEditScreen(onSave: _handlePasswordUpdate),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.creamBackground,
      body: SafeArea(
        child: Column(
          children: [
            // Custom app bar with curved bottom
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
                    'Account',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.refresh, color: Colors.white),
                    onPressed: _loadUserData,
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
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Profile picture at the top
                            Center(
                              child: Column(
                                children: [
                                  Stack(
                                    children: [
                                      CircleAvatar(
                                        radius: 50,
                                        backgroundColor: Colors.grey[200],
                                        backgroundImage:
                                            _profileImage != null
                                                ? FileImage(_profileImage!)
                                                : null,
                                        child:
                                            _profileImage == null
                                                ? Text(
                                                  _displayName.isNotEmpty
                                                      ? _displayName[0]
                                                          .toUpperCase()
                                                      : 'U',
                                                  style: const TextStyle(
                                                    color: Colors.black,
                                                    fontSize: 40,
                                                    fontWeight: FontWeight.bold,
                                                  ),
                                                )
                                                : null,
                                      ),

                                      // Camera icon
                                      Positioned(
                                        bottom: 0,
                                        right: 0,
                                        child: GestureDetector(
                                          onTap: () {
                                            // Show a dialog to select image source
                                            showDialog(
                                              context: context,
                                              builder: (BuildContext context) {
                                                return AlertDialog(
                                                  title: const Text(
                                                    'Change Profile Picture',
                                                  ),
                                                  content: SingleChildScrollView(
                                                    child: ListBody(
                                                      children: <Widget>[
                                                        GestureDetector(
                                                          child: const ListTile(
                                                            leading: Icon(
                                                              Icons
                                                                  .photo_library,
                                                            ),
                                                            title: Text(
                                                              'Choose from Gallery',
                                                            ),
                                                          ),
                                                          onTap: () {
                                                            Navigator.of(
                                                              context,
                                                            ).pop();
                                                            _pickImage(
                                                              ImageSource
                                                                  .gallery,
                                                            );
                                                          },
                                                        ),
                                                        GestureDetector(
                                                          child: const ListTile(
                                                            leading: Icon(
                                                              Icons.camera_alt,
                                                            ),
                                                            title: Text(
                                                              'Take a Photo',
                                                            ),
                                                          ),
                                                          onTap: () {
                                                            Navigator.of(
                                                              context,
                                                            ).pop();
                                                            _pickImage(
                                                              ImageSource
                                                                  .camera,
                                                            );
                                                          },
                                                        ),
                                                      ],
                                                    ),
                                                  ),
                                                );
                                              },
                                            );
                                          },
                                          child: Container(
                                            padding: const EdgeInsets.all(4),
                                            decoration: BoxDecoration(
                                              color: const Color(0xFF9D9DCC),
                                              shape: BoxShape.circle,
                                              boxShadow: [
                                                BoxShadow(
                                                  color: Colors.black
                                                      .withOpacity(0.1),
                                                  blurRadius: 4,
                                                  offset: const Offset(0, 2),
                                                ),
                                              ],
                                            ),
                                            child: const Icon(
                                              Icons.camera_alt,
                                              color: Colors.white,
                                              size: 16,
                                            ),
                                          ),
                                        ),
                                      ),

                                      // Delete icon (only visible when there's a profile image)
                                      if (_profileImage != null)
                                        Positioned(
                                          bottom: 0,
                                          left: 0,
                                          child: GestureDetector(
                                            onTap: _deleteProfileImage,
                                            child: Container(
                                              padding: const EdgeInsets.all(4),
                                              decoration: BoxDecoration(
                                                color: Colors.red,
                                                shape: BoxShape.circle,
                                                boxShadow: [
                                                  BoxShadow(
                                                    color: Colors.black
                                                        .withOpacity(0.1),
                                                    blurRadius: 4,
                                                    offset: const Offset(0, 2),
                                                  ),
                                                ],
                                              ),
                                              child: const Icon(
                                                Icons.delete,
                                                color: Colors.white,
                                                size: 16,
                                              ),
                                            ),
                                          ),
                                        ),
                                    ],
                                  ),
                                  const SizedBox(height: 10),
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.start,
                                    children: [
                                      Container(
                                        width: 3,
                                        height: 24,
                                        decoration: BoxDecoration(
                                          color: Colors.black87,
                                          borderRadius: BorderRadius.circular(
                                            1.5,
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Text(
                                        'Personal Info',
                                        style: TextStyle(
                                          fontSize: 18,
                                          fontWeight: FontWeight.bold,
                                          color: Colors.black87,
                                          letterSpacing: 0.5,
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),

                            const SizedBox(height: 24),

                            // Name container
                            _buildInfoContainer(
                              title: 'Name',
                              value: _displayName,
                              icon: Icons.person_outline,
                              onEdit: _showNameEditScreen,
                            ),

                            const SizedBox(height: 16),

                            // Email container
                            _buildInfoContainer(
                              title: 'Email',
                              value: _email,
                              icon: Icons.email_outlined,
                              onEdit: _showEmailEditScreen,
                            ),

                            const SizedBox(height: 16),

                            // Password container
                            _buildInfoContainer(
                              title: 'Password',
                              value: _password,
                              icon: Icons.lock_outline,
                              onEdit: _showPasswordChangeDialog,
                            ),

                            const SizedBox(height: 16),

                            // Phone number container
                            _buildInfoContainer(
                              title: 'Mobile Number',
                              value: _phoneNumber,
                              icon: Icons.phone_outlined,
                              onEdit: () {
                                // Will be implemented later
                              },
                            ),
                          ],
                        ),
                      ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoContainer({
    required String title,
    required String value,
    required IconData icon,
    required VoidCallback onEdit,
  }) {
    // Determine if this is the password container
    bool isPassword = title == 'Password';
    bool isName = title == 'Name';
    bool isEmail = title == 'Email';

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Stack(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.grey.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(icon, color: const Color(0xFF9D9DCC), size: 24),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: Colors.black87,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        value,
                        style: const TextStyle(
                          fontSize: 16,
                          color: Colors.black54,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Positioned(
            top: 16,
            right: 16,
            child: InkWell(
              onTap:
                  isPassword
                      ? _showPasswordChangeDialog
                      : isName
                      ? _showNameEditScreen
                      : isEmail
                      ? _showEmailEditScreen
                      : onEdit,
              borderRadius: BorderRadius.circular(20),
              child: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.grey.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.edit, color: Colors.black54, size: 16),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Function to update the display name
  Future<void> _updateDisplayName(String newName) async {
    setState(() {
      _isLoading = true;
    });

    try {
      final user = _auth.currentUser;
      if (user == null) {
        throw Exception('User not found');
      }

      // Update display name in Firebase Auth
      await user.updateDisplayName(newName);

      // Update display name in Firestore
      await _firestore.collection('users').doc(user.uid).update({
        'displayName': newName,
        'lastUpdated': DateTime.now(),
      });

      // Update local state
      setState(() {
        _displayName = newName;
        _isLoading = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Name updated successfully',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
          ),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      setState(() {
        _isLoading = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Failed to update name: ${e.toString()}',
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
            ),
          ),
          backgroundColor: Colors.red,
        ),
      );
      print('Error updating display name: $e');
    }
  }

  // Show name edit screen
  void _showNameEditScreen() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder:
            (context) => NameEditScreen(
              initialName: _displayName,
              onSave: _updateDisplayName,
            ),
      ),
    );
  }

  // Show email edit screen
  void _showEmailEditScreen() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder:
            (context) =>
                EmailEditScreen(initialEmail: _email, onSave: _updateEmail),
      ),
    );
  }

  // Function to update the email
  Future<void> _updateEmail(String newEmail) async {
    setState(() {
      _isLoading = true;
    });

    try {
      final user = _auth.currentUser;
      if (user == null) {
        throw Exception('User not found');
      }

      // Update email in Firebase Auth
      await user.updateEmail(newEmail);

      // Update email in Firestore
      await _firestore.collection('users').doc(user.uid).update({
        'email': newEmail,
        'lastUpdated': DateTime.now(),
      });

      // Update local state
      setState(() {
        _email = newEmail;
        _isLoading = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Email updated successfully',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
          ),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      setState(() {
        _isLoading = false;
      });

      String errorMessage = 'Failed to update email';

      // Provide more specific error messages
      if (e.toString().contains('requires-recent-login')) {
        errorMessage =
            'Please log out and log in again before changing your email';
      } else if (e.toString().contains('email-already-in-use')) {
        errorMessage = 'This email is already in use by another account';
      } else if (e.toString().contains('invalid-email')) {
        errorMessage = 'The email address is not valid';
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            errorMessage,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
            ),
          ),
          backgroundColor: Colors.red,
        ),
      );
      print('Error updating email: $e');
      throw e; // Rethrow to let the EmailEditScreen handle it
    }
  }
}
