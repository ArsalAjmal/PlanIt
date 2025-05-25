import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../constants/app_colors.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import 'dart:math';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;
import 'name_edit_screen.dart';
import 'email_edit_screen.dart';
import 'password_edit_screen.dart';

class AccountScreen extends StatefulWidget {
  final VoidCallback? onProfileImageChanged;

  const AccountScreen({Key? key, this.onProfileImageChanged}) : super(key: key);

  // Add route observer for detecting navigation
  static final RouteObserver<PageRoute> routeObserver =
      RouteObserver<PageRoute>();

  @override
  State<AccountScreen> createState() => _AccountScreenState();
}

class _AccountScreenState extends State<AccountScreen>
    with TickerProviderStateMixin, RouteAware {
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
  static const String _clientProfileImagePathKey = 'client_profile_image_path';
  static const String _organizerProfileImagePathKey =
      'organizer_profile_image_path';
  bool _isOrganizer = false;

  // Animation controllers
  late AnimationController _profileAnimController;
  late AnimationController _titleAnimController;
  late AnimationController _containerAnimController;

  // Animations
  late Animation<Offset> _profileSlideAnim;
  late Animation<double> _profileFadeAnim;
  late Animation<Offset> _titleSlideAnim;
  late Animation<double> _titleFadeAnim;

  // Container animations list
  List<Animation<Offset>> _containerSlideAnims = [];
  List<Animation<double>> _containerFadeAnims = [];

  @override
  void initState() {
    super.initState();
    _loadUserData();
    _checkUserType();
    _clearCrossOverProfileImages();

    // Initialize animation controllers
    _setupAnimations();
  }

  // Add function to restart animations
  void _restartAnimations() {
    // Reset animations to the beginning
    _profileAnimController.reset();
    _titleAnimController.reset();
    _containerAnimController.reset();

    // Start the animations with staggered timing
    Future.delayed(const Duration(milliseconds: 300), () {
      if (mounted) _profileAnimController.forward();
    });

    Future.delayed(const Duration(milliseconds: 700), () {
      if (mounted) _titleAnimController.forward();
    });

    Future.delayed(const Duration(milliseconds: 1100), () {
      if (mounted) _containerAnimController.forward();
    });
  }

  void _setupAnimations() {
    // Profile animation controller - increased duration
    _profileAnimController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000), // Increased from 800ms
    );

    // Title animation controller - increased duration
    _titleAnimController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000), // Increased from 800ms
    );

    // Container animation controller - longer duration for staggered effect
    _containerAnimController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500), // Increased from 1200ms
    );

    // Profile animations - gentler curves
    _profileSlideAnim = Tween<Offset>(
      begin: const Offset(0, 0.2), // Reduced offset for subtler motion
      end: Offset.zero,
    ).animate(
      CurvedAnimation(
        parent: _profileAnimController,
        curve:
            Curves.easeOutQuart, // Changed to easeOutQuart for smoother finish
      ),
    );

    _profileFadeAnim = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _profileAnimController,
        curve: Curves.easeInOut, // Changed to easeInOut for smoother transition
      ),
    );

    // Title animations - gentler curves
    _titleSlideAnim = Tween<Offset>(
      begin: const Offset(0, 0.2), // Reduced offset for subtler motion
      end: Offset.zero,
    ).animate(
      CurvedAnimation(
        parent: _titleAnimController,
        curve:
            Curves.easeOutQuart, // Changed to easeOutQuart for smoother finish
      ),
    );

    _titleFadeAnim = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _titleAnimController,
        curve: Curves.easeInOut, // Changed to easeInOut for smoother transition
      ),
    );

    // Create staggered animations for the 4 info containers
    for (int i = 0; i < 4; i++) {
      // More gradual staggering with smaller interval
      final startInterval =
          0.1 * i; // Changed from 0.15 for smoother transition
      // Make sure endInterval never exceeds 1.0
      final endInterval = min(
        startInterval + 0.8,
        1.0,
      ); // Increased from 0.7 for longer fade

      _containerSlideAnims.add(
        Tween<Offset>(
          begin: const Offset(0, 0.2), // Reduced from 0.3 for subtler motion
          end: Offset.zero,
        ).animate(
          CurvedAnimation(
            parent: _containerAnimController,
            curve: Interval(
              startInterval,
              endInterval,
              curve:
                  Curves
                      .easeOutQuart, // Using easeOutQuart for consistent animation style
            ),
          ),
        ),
      );

      _containerFadeAnims.add(
        Tween<double>(begin: 0.0, end: 1.0).animate(
          CurvedAnimation(
            parent: _containerAnimController,
            curve: Interval(
              startInterval,
              endInterval,
              curve:
                  Curves
                      .easeInOut, // Changed to easeInOut for smoother transition
            ),
          ),
        ),
      );
    }

    // Start animations with longer delays to match client home screen
    Future.delayed(const Duration(milliseconds: 300), () {
      // Increased from 100ms
      if (mounted) _profileAnimController.forward();
    });

    Future.delayed(const Duration(milliseconds: 700), () {
      // Increased from 300ms
      if (mounted) _titleAnimController.forward();
    });

    Future.delayed(const Duration(milliseconds: 1100), () {
      // Increased from 500ms
      if (mounted) _containerAnimController.forward();
    });
  }

  @override
  void didPopNext() {
    super.didPopNext();
    // Restart animations when returning to this screen
    _restartAnimations();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Register with the route observer
    AccountScreen.routeObserver.subscribe(
      this,
      ModalRoute.of(context) as PageRoute,
    );
  }

  @override
  void dispose() {
    // Unsubscribe from route observer
    AccountScreen.routeObserver.unsubscribe(this);

    _profileAnimController.dispose();
    _titleAnimController.dispose();
    _containerAnimController.dispose();
    super.dispose();
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

            // Check for stored profile image paths
            await _checkForStoredProfileImage(userData);
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

  // New method to check for stored profile image paths in Firestore
  Future<void> _checkForStoredProfileImage(
    Map<String, dynamic> userData,
  ) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final userType = _isOrganizer ? 'organizer' : 'client';

      // Check if path exists in Firestore
      if (userData['${userType}ProfileImagePath'] != null) {
        final storedPath = userData['${userType}ProfileImagePath'] as String;
        print(
          'AccountScreen: Found ${userType} profile image path in Firestore: $storedPath',
        );

        // Check if file exists
        final file = File(storedPath);
        if (await file.exists()) {
          // Update SharedPreferences and state
          final key =
              _isOrganizer
                  ? _organizerProfileImagePathKey
                  : _clientProfileImagePathKey;
          await prefs.setString(key, storedPath);
          setState(() {
            _profileImage = file;
          });

          print(
            'AccountScreen: Successfully restored profile image from Firestore',
          );
        } else {
          print(
            'AccountScreen: Stored image file no longer exists: $storedPath',
          );
          // Remove invalid path from Firestore
          final user = _auth.currentUser;
          if (user != null) {
            await _firestore.collection('users').doc(user.uid).update({
              '${userType}ProfileImagePath': FieldValue.delete(),
            });
          }
        }
      } else {
        print(
          'AccountScreen: No ${userType} profile image path stored in Firestore',
        );
      }
    } catch (e) {
      print('AccountScreen: Error checking for stored profile image: $e');
    }
  }

  Future<void> _checkUserType() async {
    try {
      final user = _auth.currentUser;
      if (user != null) {
        // First check user_role in SharedPreferences - highest priority
        final prefs = await SharedPreferences.getInstance();
        String? userRole = prefs.getString('user_role');
        if (userRole != null) {
          setState(() {
            _isOrganizer = userRole == 'organizer';
          });
          print(
            'AccountScreen: Determined user type from SharedPreferences user_role: $_isOrganizer',
          );
          _loadProfileImage();
          return; // Exit early, we have our answer
        }

        // Check the user's role in Firestore
        final userDoc =
            await _firestore.collection('users').doc(user.uid).get();
        print('AccountScreen: Checking user type for ${user.uid}');

        bool foundUserType = false;

        if (userDoc.exists && userDoc.data() != null) {
          final userData = userDoc.data()!;
          final bool wasOrganizer = _isOrganizer;

          // Check if role field exists
          if (userData.containsKey('role')) {
            setState(() {
              _isOrganizer = userData['role'] == 'organizer';
            });
            foundUserType = true;
            print(
              'AccountScreen: isOrganizer = $_isOrganizer (was $wasOrganizer), role = ${userData['role']}',
            );
          } else {
            print('AccountScreen: User document does not contain role field');
          }
        } else {
          print('AccountScreen: User document not found or has no data');
        }

        // If we can't determine from Firestore, check which screens the user can access
        if (!foundUserType) {
          // Try to determine from SharedPreferences keys
          final hasOrganizerImage = prefs.containsKey(
            _organizerProfileImagePathKey,
          );
          final hasClientImage = prefs.containsKey(_clientProfileImagePathKey);

          if (hasOrganizerImage && !hasClientImage) {
            setState(() {
              _isOrganizer = true;
            });
            print(
              'AccountScreen: Determined user is organizer from SharedPreferences',
            );
          } else if (!hasOrganizerImage && hasClientImage) {
            setState(() {
              _isOrganizer = false;
            });
            print(
              'AccountScreen: Determined user is client from SharedPreferences',
            );
          }
          // If both or neither exist, we can't determine - keep current value
        }

        // Store the detected role for future use
        if (userRole == null) {
          await prefs.setString(
            'user_role',
            _isOrganizer ? 'organizer' : 'client',
          );
          print(
            'AccountScreen: Storing detected user role: ${_isOrganizer ? "organizer" : "client"}',
          );
        }
      } else {
        print('AccountScreen: User is null');
      }

      // Load profile image after determining user type
      _loadProfileImage();
    } catch (e) {
      print('AccountScreen: Error checking user type: $e');
      _loadProfileImage(); // Load profile image anyway
    }
  }

  // Load profile image from shared preferences
  Future<void> _loadProfileImage() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final key =
          _isOrganizer
              ? _organizerProfileImagePathKey
              : _clientProfileImagePathKey;
      print(
        'AccountScreen: Loading profile image with key: $key, isOrganizer: $_isOrganizer',
      );

      // Only check the key for the current user type - don't use alternate keys
      String? imagePath = prefs.getString(key);
      print('AccountScreen: Found image path: $imagePath for key: $key');

      if (imagePath != null) {
        final file = File(imagePath);
        final exists = await file.exists();
        print('AccountScreen: File exists: $exists');

        if (exists) {
          setState(() {
            _profileImage = file;
            print('AccountScreen: Set profile image to $imagePath');
          });
        } else {
          print('AccountScreen: Image file not found at path: $imagePath');
          // Remove only this key if file doesn't exist
          await prefs.remove(key);
          print(
            'AccountScreen: Removed non-existent image path from key: $key',
          );
        }
      } else {
        print('AccountScreen: No image path stored for key: $key');
      }
    } catch (e) {
      print('AccountScreen: Error loading profile image: $e');
    }
  }

  // Save profile image path to shared preferences
  Future<void> _saveProfileImagePath(String imagePath) async {
    try {
      final user = _auth.currentUser;
      if (user == null) {
        print('AccountScreen: Cannot save profile image - user is null');
        return;
      }

      final prefs = await SharedPreferences.getInstance();
      final key =
          _isOrganizer
              ? _organizerProfileImagePathKey
              : _clientProfileImagePathKey;
      print(
        'AccountScreen: Saving profile image path: $imagePath with key: $key, isOrganizer: $_isOrganizer',
      );

      // Save locally to SharedPreferences
      await prefs.setString(key, imagePath);

      // Store in Firestore to persist across logins
      final userType = _isOrganizer ? 'organizer' : 'client';
      await _firestore.collection('users').doc(user.uid).update({
        '${userType}ProfileImagePath': imagePath,
        'lastProfileUpdate': DateTime.now(),
      });

      print(
        'AccountScreen: Saved profile image path to Firestore and SharedPreferences',
      );
      print(
        'AccountScreen: User type is: ${_isOrganizer ? "Organizer" : "Client"}',
      );
    } catch (e) {
      print('AccountScreen: Error saving profile image path: $e');
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

  // New method to clear any cross-over profile images
  Future<void> _clearCrossOverProfileImages() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final user = _auth.currentUser;

      // Clear all keys if we detect inconsistencies or if we're switching types
      final hasOrganizerKey = prefs.containsKey(_organizerProfileImagePathKey);
      final hasClientKey = prefs.containsKey(_clientProfileImagePathKey);

      // If both keys exist, we need to clear them as this indicates a problem
      if (hasOrganizerKey && hasClientKey) {
        print('AccountScreen: Found both keys, clearing all profile images');
        await prefs.remove(_organizerProfileImagePathKey);
        await prefs.remove(_clientProfileImagePathKey);
      }
    } catch (e) {
      print('AccountScreen: Error clearing cross-over images: $e');
    }
  }

  // Function to pick image
  Future<void> _pickImage(ImageSource source) async {
    try {
      print('AccountScreen: Picking image from source: $source');
      final XFile? pickedImage = await _imagePicker.pickImage(
        source: source,
        maxWidth: 400,
        maxHeight: 400,
        imageQuality: 85,
      );

      if (pickedImage != null) {
        print('AccountScreen: Image picked: ${pickedImage.path}');
        // Copy the image to app directory for persistence with user ID in filename
        final user = _auth.currentUser;
        final userId = user?.uid ?? 'unknown';
        final appDir = await getApplicationDocumentsDirectory();
        final userType = _isOrganizer ? 'organizer' : 'client';
        final fileName =
            '${userType}_${userId}_profile_${DateTime.now().millisecondsSinceEpoch}.jpg';
        final savedImagePath = path.join(appDir.path, fileName);
        print('AccountScreen: Saving image to: $savedImagePath');

        // Delete any existing profile image first
        if (_profileImage != null && await _profileImage!.exists()) {
          await _profileImage!.delete();
          print('AccountScreen: Deleted existing profile image file');
        }

        // Copy the image
        final File savedImage = await File(
          pickedImage.path,
        ).copy(savedImagePath);
        print('AccountScreen: Image copied successfully to: $savedImagePath');

        setState(() {
          _profileImage = savedImage;
        });

        // Save the path for future app launches
        await _saveProfileImagePath(savedImagePath);

        // Notify parent screens about the change
        if (widget.onProfileImageChanged != null) {
          print('AccountScreen: Calling onProfileImageChanged callback');
          widget.onProfileImageChanged!();
        } else {
          print('AccountScreen: No onProfileImageChanged callback provided');
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
      } else {
        print('AccountScreen: No image picked');
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
      final user = _auth.currentUser;
      if (user == null) {
        print('AccountScreen: Cannot delete profile image - user is null');
        return;
      }

      // Remove image path from SharedPreferences - but only for the current user type
      final prefs = await SharedPreferences.getInstance();
      final key =
          _isOrganizer
              ? _organizerProfileImagePathKey
              : _clientProfileImagePathKey;

      await prefs.remove(key);
      print('AccountScreen: Removed profile image path from key: $key');

      // Also remove from Firestore
      final userType = _isOrganizer ? 'organizer' : 'client';
      await _firestore.collection('users').doc(user.uid).update({
        '${userType}ProfileImagePath': FieldValue.delete(),
      });
      print('AccountScreen: Removed profile image path from Firestore');

      // Delete the file if it exists
      if (_profileImage != null && await _profileImage!.exists()) {
        await _profileImage!.delete();
        print('AccountScreen: Deleted profile image file');
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
                                  FadeTransition(
                                    opacity: _profileFadeAnim,
                                    child: SlideTransition(
                                      position: _profileSlideAnim,
                                      child: Stack(
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
                                                        fontWeight:
                                                            FontWeight.bold,
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
                                                // Show a compact profile photo picker
                                                showModalBottomSheet(
                                                  context: context,
                                                  backgroundColor:
                                                      Colors.transparent,
                                                  isScrollControlled: true,
                                                  builder: (
                                                    BuildContext context,
                                                  ) {
                                                    return Container(
                                                      padding:
                                                          const EdgeInsets.fromLTRB(
                                                            0,
                                                            12,
                                                            0,
                                                            20,
                                                          ),
                                                      decoration: const BoxDecoration(
                                                        color:
                                                            AppColors
                                                                .creamBackground, // App cream background
                                                        borderRadius:
                                                            BorderRadius.only(
                                                              topLeft:
                                                                  Radius.circular(
                                                                    16,
                                                                  ),
                                                              topRight:
                                                                  Radius.circular(
                                                                    16,
                                                                  ),
                                                            ),
                                                        boxShadow: [
                                                          BoxShadow(
                                                            color:
                                                                Colors.black12,
                                                            blurRadius: 8,
                                                            spreadRadius: 0,
                                                          ),
                                                        ],
                                                      ),
                                                      child: Column(
                                                        mainAxisSize:
                                                            MainAxisSize.min,
                                                        children: <Widget>[
                                                          // Drag handle
                                                          Container(
                                                            width: 36,
                                                            height: 4,
                                                            margin:
                                                                const EdgeInsets.only(
                                                                  bottom: 8,
                                                                ),
                                                            decoration: BoxDecoration(
                                                              color:
                                                                  Colors
                                                                      .grey
                                                                      .shade300,
                                                              borderRadius:
                                                                  BorderRadius.circular(
                                                                    2,
                                                                  ),
                                                            ),
                                                          ),

                                                          // Title
                                                          const Text(
                                                            'Profile photo',
                                                            style: TextStyle(
                                                              fontSize: 16,
                                                              fontWeight:
                                                                  FontWeight
                                                                      .w600,
                                                              color:
                                                                  Colors
                                                                      .black87,
                                                            ),
                                                          ),

                                                          const SizedBox(
                                                            height: 16,
                                                          ),

                                                          // Option buttons
                                                          Row(
                                                            mainAxisAlignment:
                                                                MainAxisAlignment
                                                                    .center,
                                                            children: [
                                                              // Camera option
                                                              Padding(
                                                                padding:
                                                                    const EdgeInsets.symmetric(
                                                                      horizontal:
                                                                          16,
                                                                    ),
                                                                child: Column(
                                                                  children: [
                                                                    GestureDetector(
                                                                      onTap: () {
                                                                        Navigator.of(
                                                                          context,
                                                                        ).pop();
                                                                        _pickImage(
                                                                          ImageSource
                                                                              .camera,
                                                                        );
                                                                      },
                                                                      child: Container(
                                                                        width:
                                                                            55,
                                                                        height:
                                                                            55,
                                                                        decoration: BoxDecoration(
                                                                          shape:
                                                                              BoxShape.circle,
                                                                          border: Border.all(
                                                                            color:
                                                                                Colors.black87, // Black outline
                                                                            width:
                                                                                1.0,
                                                                          ),
                                                                        ),
                                                                        child: const Center(
                                                                          child: Icon(
                                                                            Icons.camera_alt_rounded,
                                                                            color:
                                                                                Colors.black87,
                                                                            size:
                                                                                22,
                                                                          ),
                                                                        ),
                                                                      ),
                                                                    ),
                                                                    const SizedBox(
                                                                      height: 6,
                                                                    ),
                                                                    const Text(
                                                                      'Camera',
                                                                      style: TextStyle(
                                                                        color:
                                                                            Colors.black87,
                                                                        fontSize:
                                                                            13,
                                                                        fontWeight:
                                                                            FontWeight.w500,
                                                                      ),
                                                                    ),
                                                                  ],
                                                                ),
                                                              ),

                                                              // Gallery option
                                                              Padding(
                                                                padding:
                                                                    const EdgeInsets.symmetric(
                                                                      horizontal:
                                                                          16,
                                                                    ),
                                                                child: Column(
                                                                  children: [
                                                                    GestureDetector(
                                                                      onTap: () {
                                                                        Navigator.of(
                                                                          context,
                                                                        ).pop();
                                                                        _pickImage(
                                                                          ImageSource
                                                                              .gallery,
                                                                        );
                                                                      },
                                                                      child: Container(
                                                                        width:
                                                                            55,
                                                                        height:
                                                                            55,
                                                                        decoration: BoxDecoration(
                                                                          shape:
                                                                              BoxShape.circle,
                                                                          border: Border.all(
                                                                            color:
                                                                                Colors.black87, // Black outline
                                                                            width:
                                                                                1.0,
                                                                          ),
                                                                        ),
                                                                        child: const Center(
                                                                          child: Icon(
                                                                            Icons.photo_library_rounded,
                                                                            color:
                                                                                Colors.black87,
                                                                            size:
                                                                                22,
                                                                          ),
                                                                        ),
                                                                      ),
                                                                    ),
                                                                    const SizedBox(
                                                                      height: 6,
                                                                    ),
                                                                    const Text(
                                                                      'Gallery',
                                                                      style: TextStyle(
                                                                        color:
                                                                            Colors.black87,
                                                                        fontSize:
                                                                            13,
                                                                        fontWeight:
                                                                            FontWeight.w500,
                                                                      ),
                                                                    ),
                                                                  ],
                                                                ),
                                                              ),
                                                            ],
                                                          ),

                                                          const SizedBox(
                                                            height: 16,
                                                          ),

                                                          // Bottom padding for safe area
                                                          SizedBox(
                                                            height:
                                                                MediaQuery.of(
                                                                      context,
                                                                    )
                                                                    .padding
                                                                    .bottom,
                                                          ),
                                                        ],
                                                      ),
                                                    );
                                                  },
                                                );
                                              },
                                              child: Container(
                                                padding: const EdgeInsets.all(
                                                  4,
                                                ),
                                                decoration: BoxDecoration(
                                                  color: const Color(
                                                    0xFF9D9DCC,
                                                  ),
                                                  shape: BoxShape.circle,
                                                  boxShadow: [
                                                    BoxShadow(
                                                      color: Colors.black
                                                          .withOpacity(0.1),
                                                      blurRadius: 4,
                                                      offset: const Offset(
                                                        0,
                                                        2,
                                                      ),
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
                                        ],
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 10),
                                  FadeTransition(
                                    opacity: _titleFadeAnim,
                                    child: SlideTransition(
                                      position: _titleSlideAnim,
                                      child: Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.start,
                                        children: [
                                          Container(
                                            width: 3,
                                            height: 24,
                                            decoration: BoxDecoration(
                                              color: Colors.black87,
                                              borderRadius:
                                                  BorderRadius.circular(1.5),
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
                                    ),
                                  ),
                                ],
                              ),
                            ),

                            const SizedBox(height: 24),

                            // Name container
                            FadeTransition(
                              opacity: _containerFadeAnims[0],
                              child: SlideTransition(
                                position: _containerSlideAnims[0],
                                child: _buildInfoContainer(
                                  title: 'Name',
                                  value: _displayName,
                                  icon: Icons.person_outline,
                                  onEdit: _showNameEditScreen,
                                ),
                              ),
                            ),

                            const SizedBox(height: 16),

                            // Email container
                            FadeTransition(
                              opacity: _containerFadeAnims[1],
                              child: SlideTransition(
                                position: _containerSlideAnims[1],
                                child: _buildInfoContainer(
                                  title: 'Email',
                                  value: _email,
                                  icon: Icons.email_outlined,
                                  onEdit: _showEmailEditScreen,
                                ),
                              ),
                            ),

                            const SizedBox(height: 16),

                            // Password container
                            FadeTransition(
                              opacity: _containerFadeAnims[2],
                              child: SlideTransition(
                                position: _containerSlideAnims[2],
                                child: _buildInfoContainer(
                                  title: 'Password',
                                  value: _password,
                                  icon: Icons.lock_outline,
                                  onEdit: _showPasswordChangeDialog,
                                ),
                              ),
                            ),

                            const SizedBox(height: 16),

                            // Phone number container
                            FadeTransition(
                              opacity: _containerFadeAnims[3],
                              child: SlideTransition(
                                position: _containerSlideAnims[3],
                                child: _buildInfoContainer(
                                  title: 'Mobile Number',
                                  value: _phoneNumber,
                                  icon: Icons.phone_outlined,
                                  onEdit: () {
                                    // Will be implemented later
                                  },
                                ),
                              ),
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
