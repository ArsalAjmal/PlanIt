import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:ui';
import 'dart:async';
import './login_view.dart';
import './pending_orders_screen.dart';
import './organizer_reviews_screen.dart';
import './organizer_todo_screen.dart';
import './account_screen.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'organizer/portfolio_creation_screen.dart';
import '../controllers/pending_orders_controller.dart';
import '../models/response_model.dart';
import '../services/portfolio_service.dart';
import '../constants/app_colors.dart';
import 'organizer/my_portfolios_screen.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;
import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';

class OrganizerHomeScreen extends StatefulWidget {
  const OrganizerHomeScreen({super.key});

  @override
  State<OrganizerHomeScreen> createState() => _OrganizerHomeScreenState();
}

class _OrganizerHomeScreenState extends State<OrganizerHomeScreen>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  // Controller for pending orders
  final PendingOrdersController _pendingOrdersController =
      PendingOrdersController();
  bool _isLoading = true;

  // Add timer values
  int days = 10;
  int hours = 12;
  int minutes = 30;
  int seconds = 6;
  late Timer _timer;

  // Add a scaffold key to access the drawer
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // Add animation controller
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;

  // Add this variable for profile image
  final ImagePicker _imagePicker = ImagePicker();
  File? _profileImage;
  String? _profileImagePath; // Add this to track the path
  static const String _profileImagePathKey = 'organizer_profile_image_path';
  static const String _clientProfileImagePathKey = 'client_profile_image_path';
  bool _profileImageLoaded = false; // Track if we've tried to load the image

  // Add event management variables
  int _currentEventIndex = 0;
  late PageController _eventPageController;
  final List<Map<String, dynamic>> _events = [
    {
      'title': 'Summer Wedding',
      'date': DateTime.now().add(
        const Duration(days: 10, hours: 12, minutes: 30, seconds: 6),
      ),
    },
    {
      'title': 'Birthday Party',
      'date': DateTime.now().add(
        const Duration(days: 5, hours: 8, minutes: 45, seconds: 30),
      ),
    },
    {
      'title': 'Corporate Event',
      'date': DateTime.now().add(
        const Duration(days: 15, hours: 3, minutes: 20, seconds: 15),
      ),
    },
    {
      'title': 'Anniversary Celebration',
      'date': DateTime.now().add(
        const Duration(days: 2, hours: 14, minutes: 30),
      ),
    },
  ];

  @override
  void initState() {
    super.initState();
    // Register for lifecycle changes
    WidgetsBinding.instance.addObserver(this);

    _loadPendingOrders();
    _debugCheckAllResponses();
    startTimer();
    _clearCrossProfileImages();
    _loadProfileImage();
    _eventPageController = PageController(
      initialPage: 0,
      viewportFraction: 0.95, // Slightly smaller to show a hint of next page
    );

    // Animation setup
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeOut),
    );

    _animationController.forward();
  }

  @override
  void dispose() {
    _timer.cancel();
    _animationController.dispose();
    _eventPageController.dispose();
    // Remove observer
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  // React to app lifecycle changes
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      // App came back to foreground, reload profile image
      print('OrganizerHomeScreen: App resumed, reloading profile image');
      setState(() {
        _profileImageLoaded = false;
        _profileImage = null;
        _profileImagePath = null;
      });
      _loadProfileImage();
    }
  }

  void startTimer() {
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      setState(() {
        if (seconds > 0) {
          seconds--;
        } else {
          if (minutes > 0) {
            minutes--;
            seconds = 59;
          } else {
            if (hours > 0) {
              hours--;
              minutes = 59;
              seconds = 59;
            } else {
              if (days > 0) {
                days--;
                hours = 23;
                minutes = 59;
                seconds = 59;
              } else {
                timer.cancel();
              }
            }
          }
        }
      });
    });
  }

  Future<void> _loadPendingOrders() async {
    setState(() {
      _isLoading = true;
    });

    // Get current user ID from Firebase Auth
    final user = _auth.currentUser;

    if (user != null) {
      // Initialize the stream first for real-time updates
      _pendingOrdersController.initPendingOrdersStream(user.uid);
      // Then fetch orders to populate the initial list
      await _pendingOrdersController.fetchPendingOrders(user.uid);
    } else {
      print('Cannot fetch orders: User is not logged in');
    }

    setState(() {
      _isLoading = false;
    });
  }

  Future<void> _debugCheckAllResponses() async {
    final portfolioService = PortfolioService();
    await portfolioService.debugCheckAllResponses();
  }

  // Clear any potential cross-contamination between client and organizer images
  Future<void> _clearCrossProfileImages() async {
    try {
      final prefs = await SharedPreferences.getInstance();

      // Add this check to make sure we're enforcing the organizer role
      // Store user role in SharedPreferences to ensure consistency
      await prefs.setString('user_role', 'organizer');

      // Check if client key exists and remove it to prevent contamination
      if (prefs.containsKey(_clientProfileImagePathKey)) {
        print(
          'OrganizerHomeScreen: Found client key in organizer screen, removing it',
        );
        await prefs.remove(_clientProfileImagePathKey);
      }

      // Also verify the organizer image path points to an existing file
      final organizerPath = prefs.getString(_profileImagePathKey);
      if (organizerPath != null) {
        final file = File(organizerPath);
        if (!await file.exists()) {
          print(
            'OrganizerHomeScreen: Organizer image file does not exist, removing path',
          );
          await prefs.remove(_profileImagePathKey);
        }
      }
    } catch (e) {
      print('OrganizerHomeScreen: Error clearing cross profile images: $e');
    }
  }

  // Load profile image from shared preferences
  Future<void> _loadProfileImage() async {
    // Early return if already loading to prevent loops
    if (_profileImageLoaded) {
      print('OrganizerHomeScreen: Profile image already loaded, skipping');
      return;
    }

    print('OrganizerHomeScreen: _loadProfileImage called');
    try {
      final prefs = await SharedPreferences.getInstance();

      // Ensure we're using the right user role
      final userRole = prefs.getString('user_role');
      if (userRole != null && userRole != 'organizer') {
        print(
          'OrganizerHomeScreen: User role mismatch in SharedPreferences: $userRole',
        );
        // Force organizer role for this screen
        await prefs.setString('user_role', 'organizer');
      }

      // Always reset state first to avoid stale data
      setState(() {
        _profileImageLoaded = false;
        _profileImage = null;
        _profileImagePath = null;
      });

      // Only use the organizer key - we don't want to use the client image
      String? imagePath = prefs.getString(_profileImagePathKey);

      // If not found in SharedPreferences, try to get from Firestore
      if (imagePath == null) {
        final user = _auth.currentUser;
        if (user != null) {
          try {
            final userDoc =
                await FirebaseFirestore.instance
                    .collection('users')
                    .doc(user.uid)
                    .get();
            if (userDoc.exists && userDoc.data() != null) {
              final userData = userDoc.data()!;
              if (userData['organizerProfileImagePath'] != null) {
                imagePath = userData['organizerProfileImagePath'] as String;
                print(
                  'OrganizerHomeScreen: Found profile image path in Firestore: $imagePath',
                );

                // Save to SharedPreferences for future access
                if (imagePath != null) {
                  await prefs.setString(_profileImagePathKey, imagePath);
                }
              }
            }
          } catch (e) {
            print(
              'OrganizerHomeScreen: Error retrieving profile image from Firestore: $e',
            );
          }
        }
      }

      print(
        'OrganizerHomeScreen: imagePath = $imagePath, current path = $_profileImagePath',
      );

      // If there's no path, mark as loaded with no image and exit early
      if (imagePath == null) {
        setState(() {
          _profileImage = null;
          _profileImagePath = null;
          _profileImageLoaded = true;
        });
        print(
          'OrganizerHomeScreen: No image path found, marked as loaded with no image',
        );
        return;
      }

      // Check if file exists
      final file = File(imagePath);
      final exists = await file.exists();
      print('OrganizerHomeScreen: File exists: $exists at path: $imagePath');

      if (exists) {
        setState(() {
          _profileImage = file;
          _profileImagePath = imagePath;
          _profileImageLoaded = true;
          print('OrganizerHomeScreen: Profile image set');
        });
        print('OrganizerHomeScreen: Loaded profile image from: $imagePath');
      } else {
        // File doesn't exist but path is stored, clear the path
        print(
          'OrganizerHomeScreen: Profile image file not found, removing path',
        );
        await prefs.remove(_profileImagePathKey);

        // Also remove from Firestore if possible
        final user = _auth.currentUser;
        if (user != null) {
          try {
            await FirebaseFirestore.instance
                .collection('users')
                .doc(user.uid)
                .update({'organizerProfileImagePath': FieldValue.delete()});
            print(
              'OrganizerHomeScreen: Removed invalid image path from Firestore',
            );
          } catch (e) {
            print(
              'OrganizerHomeScreen: Error removing invalid path from Firestore: $e',
            );
          }
        }

        setState(() {
          _profileImage = null;
          _profileImagePath = null;
          _profileImageLoaded = true;
          print(
            'OrganizerHomeScreen: Profile image set to null (file not found)',
          );
        });
      }
    } catch (e) {
      print('OrganizerHomeScreen: Error loading profile image: $e');
      setState(() {
        _profileImageLoaded = true;
        _profileImage = null;
        _profileImagePath = null;
      });
    }
  }

  // Save profile image path to shared preferences
  Future<void> _saveProfileImagePath(String imagePath) async {
    try {
      print('OrganizerHomeScreen: Saving profile image path: $imagePath');
      final prefs = await SharedPreferences.getInstance();

      // Ensure we're not using the client key
      if (prefs.containsKey(_clientProfileImagePathKey)) {
        await prefs.remove(_clientProfileImagePathKey);
        print('OrganizerHomeScreen: Removed client key for safety');
      }

      // Always use the organizer key in this screen
      await prefs.setString(_profileImagePathKey, imagePath);

      // Verify we've saved correctly
      final savedPath = prefs.getString(_profileImagePathKey);
      print('OrganizerHomeScreen: Verified saved path: $savedPath');

      // Update our state
      setState(() {
        _profileImagePath = imagePath;
      });
    } catch (e) {
      print('OrganizerHomeScreen: Error saving profile image path: $e');
      // Show a more specific error message
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Could not save profile settings, but your image was updated.',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
          ),
          backgroundColor: Colors.green,
        ),
      );
    }
  }

  // Function to pick image
  Future<void> _pickImage(ImageSource source) async {
    try {
      print('OrganizerHomeScreen: Picking image from source: $source');
      final XFile? pickedImage = await _imagePicker.pickImage(
        source: source,
        maxWidth: 400,
        maxHeight: 400,
        imageQuality: 85,
      );

      if (pickedImage != null) {
        print('OrganizerHomeScreen: Image picked: ${pickedImage.path}');

        // Copy the image to app directory for persistence with user ID
        final appDir = await getApplicationDocumentsDirectory();
        final userId = _auth.currentUser?.uid ?? 'unknown';
        final fileName =
            'organizer_${userId}_profile_${DateTime.now().millisecondsSinceEpoch}.jpg';
        final savedImagePath = path.join(appDir.path, fileName);
        print('OrganizerHomeScreen: Saving image to: $savedImagePath');

        // Delete existing profile image if any
        if (_profileImage != null && await _profileImage!.exists()) {
          await _profileImage!.delete();
          print('OrganizerHomeScreen: Deleted existing profile image');
        }

        // Copy the image
        final File savedImage = await File(
          pickedImage.path,
        ).copy(savedImagePath);
        print('OrganizerHomeScreen: Image copied successfully');

        setState(() {
          _profileImage = savedImage;
          _profileImagePath = savedImagePath; // Update the path
          _profileImageLoaded = true;
          print('OrganizerHomeScreen: Updated state with new image');
        });

        // Save the path for future app launches
        await _saveProfileImagePath(savedImagePath);

        // Here you would typically upload to Firebase Storage
        // For now, just show a success message
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
        print('OrganizerHomeScreen: No image picked');
      }
    } catch (e) {
      print('OrganizerHomeScreen: Error picking image: $e');
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
      print('OrganizerHomeScreen: Deleting profile image');
      // Remove image path from shared preferences - but only for the current user type
      final prefs = await SharedPreferences.getInstance();

      // Ensure we're only using organizer key
      if (prefs.containsKey(_clientProfileImagePathKey)) {
        await prefs.remove(_clientProfileImagePathKey);
        print('OrganizerHomeScreen: Removed client key during deletion');
      }

      await prefs.remove(_profileImagePathKey);
      print(
        'OrganizerHomeScreen: Removed profile image path from key: $_profileImagePathKey',
      );

      // Delete the file if it exists
      if (_profileImage != null && await _profileImage!.exists()) {
        await _profileImage!.delete();
        print('OrganizerHomeScreen: Deleted profile image file');
      }

      setState(() {
        _profileImage = null;
        _profileImagePath = null;
        _profileImageLoaded = true;
      });

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
      print('OrganizerHomeScreen: Error deleting profile image: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Could not remove profile picture: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  // Make sure we're using the organizer profile image key
  Future<void> _ensureUsingOrganizerKey() async {
    try {
      // Check if there's a client profile image mistakenly being used
      final prefs = await SharedPreferences.getInstance();
      final clientPath = prefs.getString(_clientProfileImagePathKey);

      // If there's a profile image in the client key but not in the organizer key,
      // copy it to the organizer key
      if (clientPath != null) {
        final organizerPath = prefs.getString(_profileImagePathKey);
        if (organizerPath == null) {
          print(
            'OrganizerHomeScreen: Found client profile image, copying to organizer key',
          );

          // Copy path to organizer key
          await prefs.setString(_profileImagePathKey, clientPath);

          // Clear path from client key to avoid confusion
          await prefs.remove(_clientProfileImagePathKey);

          print(
            'OrganizerHomeScreen: Transferred profile image path from client to organizer',
          );
        }
      }
    } catch (e) {
      print('OrganizerHomeScreen: Error ensuring organizer key: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    // Set status bar color to match background
    SystemChrome.setSystemUIOverlayStyle(
      const SystemUiOverlayStyle(
        statusBarColor: Color(0xFFFFFDE5),
        statusBarIconBrightness: Brightness.dark,
      ),
    );

    final screenHeight = MediaQuery.of(context).size.height;

    return SafeArea(
      child: Scaffold(
        key: _scaffoldKey,
        backgroundColor: AppColors.creamBackground,
        drawer: _buildDrawer(context),
        floatingActionButton: _buildChatFab(context),
        body: Stack(
          children: [
            // Background design with patterns
            Positioned.fill(child: _buildPatternBackground()),

            // Main content
            Column(
              children: [
                // App bar stays fixed at top
                _buildAppBar(context),

                // Everything else scrolls
                Expanded(
                  child: SingleChildScrollView(
                    physics: const BouncingScrollPhysics(),
                    child: Column(
                      children: [
                        FadeTransition(
                          opacity: _fadeAnimation,
                          child: Column(
                            children: [
                              // Notification
                              _buildCompactCollaborationNotification(context),

                              // Countdown
                              _buildEventCountdown(context),

                              // Services header
                              const SizedBox(height: 12),
                              Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 20.0,
                                ),
                                child: Row(
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
                                    const Text(
                                      'Services',
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
                              const SizedBox(height: 8),

                              // The cards
                              Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 16.0,
                                ),
                                child: Container(
                                  // Use fixed height based on screen size for menu cards
                                  height: screenHeight * 0.45,
                                  child: Row(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.stretch,
                                    children: [
                                      // Left side - Large Pending Orders card
                                      Expanded(
                                        flex: 3,
                                        child: _buildPendingOrdersCard(),
                                      ),
                                      const SizedBox(width: 12),
                                      // Right side - Two smaller cards
                                      Expanded(
                                        flex: 2,
                                        child: Column(
                                          children: [
                                            Expanded(
                                              child: _buildModernMenuCard(
                                                context,
                                                title: 'Reviews',
                                                icon: Icons.star,
                                                color: const Color(0xFF9D9DCC),
                                                onTap: () {
                                                  Navigator.push(
                                                    context,
                                                    MaterialPageRoute(
                                                      builder:
                                                          (context) =>
                                                              const OrganizerReviewsScreen(),
                                                    ),
                                                  );
                                                },
                                                index: 0,
                                              ),
                                            ),
                                            const SizedBox(height: 12),
                                            Expanded(
                                              child: _buildModernMenuCard(
                                                context,
                                                title: 'Todo List',
                                                icon: Icons.checklist_rounded,
                                                color: const Color(0xFF9D9DCC),
                                                onTap: () {
                                                  Navigator.push(
                                                    context,
                                                    MaterialPageRoute(
                                                      builder:
                                                          (context) =>
                                                              const OrganizerTodoScreen(),
                                                    ),
                                                  );
                                                },
                                                index: 1,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),

                              // Extra bottom padding
                              const SizedBox(height: 20),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPendingOrdersCard() {
    return GestureDetector(
      onTap: () {
        if (_pendingOrdersController.pendingOrders.isNotEmpty) {
          final firstOrder = _pendingOrdersController.pendingOrders.first;
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => PendingOrdersScreen(orderId: firstOrder.id),
            ),
          ).then((result) {
            if (result == 'ORDER_COMPLETED') {
              _loadPendingOrders();
            }
          });
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('You have no pending orders.'),
              backgroundColor: Color(0xFF9D9DCC),
            ),
          );
        }
      },
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF9D9DCC).withOpacity(0.12),
              blurRadius: 12,
              offset: const Offset(0, 4),
              spreadRadius: 0,
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: Stack(
            children: [
              // Background gradient overlay
              Positioned.fill(
                child: Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        Colors.white,
                        const Color(0xFF9D9DCC).withOpacity(0.03),
                      ],
                    ),
                  ),
                ),
              ),

              // Pattern overlay
              Positioned.fill(
                child: CustomPaint(
                  painter: MenuCardPatternPainter(
                    color: const Color(0xFF9D9DCC),
                  ),
                ),
              ),

              // Content
              Padding(
                padding: const EdgeInsets.all(20.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            const Color(0xFF9D9DCC),
                            const Color(0xFF7575A8),
                          ],
                        ),
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFF9D9DCC).withOpacity(0.25),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: const Icon(
                        Icons.pending_actions,
                        size: 26,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 16),

                    const Text(
                      'Pending Orders',
                      style: TextStyle(
                        color: Colors.black87,
                        fontWeight: FontWeight.bold,
                        fontSize: 17,
                      ),
                    ),

                    const SizedBox(height: 12),

                    // Progress indicator
                    Row(
                      children: [
                        Expanded(
                          child: Container(
                            height: 4,
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.centerLeft,
                                end: Alignment.centerRight,
                                colors: [
                                  const Color(0xFF9D9DCC),
                                  const Color(0xFF9D9DCC).withOpacity(0.3),
                                ],
                              ),
                              borderRadius: BorderRadius.circular(3),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            color: const Color(0xFF9D9DCC).withOpacity(0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Icon(
                            Icons.arrow_forward_ios,
                            color: const Color(0xFF9D9DCC),
                            size: 12,
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 16),

                    Expanded(
                      child:
                          _isLoading
                              ? const Center(
                                child: CircularProgressIndicator(
                                  color: Color(0xFF9D9DCC),
                                ),
                              )
                              : StreamBuilder<List<ResponseModel>>(
                                stream:
                                    _pendingOrdersController
                                        .pendingOrdersStream,
                                builder: (context, snapshot) {
                                  if (snapshot.connectionState ==
                                          ConnectionState.waiting &&
                                      _pendingOrdersController
                                          .pendingOrders
                                          .isEmpty) {
                                    return const Center(
                                      child: CircularProgressIndicator(
                                        color: Color(0xFF9D9DCC),
                                      ),
                                    );
                                  }

                                  if (snapshot.hasError) {
                                    return Center(
                                      child: Text(
                                        'Error loading orders',
                                        style: TextStyle(color: Colors.black54),
                                      ),
                                    );
                                  }

                                  final pendingOrders =
                                      snapshot.data ??
                                      _pendingOrdersController.pendingOrders;

                                  if (pendingOrders.isEmpty) {
                                    return Center(
                                      child: Column(
                                        mainAxisAlignment:
                                            MainAxisAlignment.center,
                                        children: [
                                          const Icon(
                                            Icons.inbox,
                                            size: 48,
                                            color: Color(0xFF9D9DCC),
                                          ),
                                          const SizedBox(height: 16),
                                          const Text(
                                            'No pending orders',
                                            style: TextStyle(
                                              color: Colors.black54,
                                              fontSize: 16,
                                            ),
                                          ),
                                        ],
                                      ),
                                    );
                                  }

                                  return ListView.builder(
                                    itemCount: pendingOrders.length,
                                    padding: EdgeInsets.zero,
                                    shrinkWrap: true,
                                    physics: const BouncingScrollPhysics(),
                                    itemBuilder: (context, index) {
                                      final order = pendingOrders[index];
                                      return Card(
                                        color: const Color(0xFF9D9DCC),
                                        margin: const EdgeInsets.only(
                                          bottom: 8,
                                        ),
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(
                                            12,
                                          ),
                                        ),
                                        child: ListTile(
                                          contentPadding:
                                              const EdgeInsets.symmetric(
                                                horizontal: 16,
                                                vertical: 8,
                                              ),
                                          title: Text(
                                            order.eventName,
                                            style: const TextStyle(
                                              color: Colors.white,
                                              fontWeight: FontWeight.bold,
                                              fontSize: 16,
                                            ),
                                          ),
                                          subtitle: Text(
                                            'Client: ${order.clientName}',
                                            style: const TextStyle(
                                              color: Colors.white70,
                                              fontSize: 14,
                                            ),
                                          ),
                                        ),
                                      );
                                    },
                                  );
                                },
                              ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPatternBackground() {
    return CustomPaint(painter: PatternPainter());
  }

  Widget _buildCompactCollaborationNotification(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 10, 20, 5),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color(0xFF00BCD4), // Vibrant teal
              Color(0xFF009688), // Rich turquoise
            ],
          ),
          boxShadow: [
            BoxShadow(
              color: Color(0xFF00BCD4).withOpacity(0.3),
              blurRadius: 8,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.2),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(
                Icons.food_bank_outlined,
                color: Colors.white,
                size: 18,
              ),
            ),
            const SizedBox(width: 12),
            const Expanded(
              child: Text(
                'Coming Soon: Collaborate with Caterers',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                ),
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.2),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Text(
                'NEW',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 9,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEventCountdown(BuildContext context) {
    return Container(
      height: 200,
      margin: const EdgeInsets.fromLTRB(20, 20, 20, 8),
      child: Stack(
        children: [
          // Event container
          PageView.builder(
            controller: _eventPageController,
            itemCount: _events.length,
            physics:
                const BouncingScrollPhysics(), // Bouncing effect when reaching edges
            pageSnapping: true, // Ensures page snaps into place
            onPageChanged: (index) {
              setState(() {
                _currentEventIndex = index;
              });
            },
            itemBuilder: (context, index) {
              final currentEvent = _events[index];
              final eventDate = currentEvent['date'] as DateTime;
              final daysUntil = eventDate.difference(DateTime.now()).inDays;
              final hoursUntil =
                  eventDate.difference(DateTime.now()).inHours % 24;
              final minutesUntil =
                  eventDate.difference(DateTime.now()).inMinutes % 60;
              final secondsUntil =
                  eventDate.difference(DateTime.now()).inSeconds % 60;

              // Calculate animation values for current page
              final isCurrentPage = index == _currentEventIndex;
              final isNextPage = index == _currentEventIndex + 1;
              final isPreviousPage = index == _currentEventIndex - 1;

              return AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                curve: Curves.easeOutCubic,
                margin: EdgeInsets.only(
                  right: 8,
                  left: 8,
                  top: isCurrentPage ? 0 : 8,
                  bottom: isCurrentPage ? 0 : 8,
                ),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(24),
                  gradient: const LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [Color(0xFF9D9DCC), Color(0xFF7575A8)],
                    stops: [0.3, 1.0],
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(
                        0xFF9D9DCC,
                      ).withOpacity(isCurrentPage ? 0.3 : 0.2),
                      blurRadius: isCurrentPage ? 10 : 8,
                      offset:
                          isCurrentPage
                              ? const Offset(0, 4)
                              : const Offset(0, 2),
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(24),
                  child: Stack(
                    children: [
                      // Background image
                      Positioned.fill(
                        child: Opacity(
                          opacity: 0.15,
                          child: Image.asset(
                            'assets/images/Drawing.png',
                            fit: BoxFit.cover,
                          ),
                        ),
                      ),
                      // Content
                      Container(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: Colors.white.withOpacity(0.2),
                                    borderRadius: BorderRadius.circular(14),
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.black.withOpacity(0.1),
                                        blurRadius: 4,
                                        offset: const Offset(0, 2),
                                      ),
                                    ],
                                  ),
                                  child: const Icon(
                                    Icons.event,
                                    color: Colors.white,
                                    size: 20,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      const Text(
                                        'Upcoming Event',
                                        style: TextStyle(
                                          color: Colors.white,
                                          fontSize: 12,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                      Text(
                                        currentEvent['title'],
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 18,
                                          fontWeight: FontWeight.bold,
                                          letterSpacing: 0.5,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 20),
                            _buildModernCountdownTimer(
                              days: daysUntil,
                              hours: hoursUntil,
                              minutes: minutesUntil,
                              seconds: secondsUntil,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),

          // Left arrow
          Positioned(
            left: 0,
            top: 0,
            bottom: 0,
            child:
                _currentEventIndex > 0
                    ? GestureDetector(
                      onTap: () {
                        _eventPageController.previousPage(
                          duration: const Duration(milliseconds: 500),
                          curve: Curves.easeOutCubic,
                        );
                      },
                      child: Container(
                        width: 50,
                        height: double.infinity,
                        color: Colors.transparent,
                        child: Center(
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: Colors.grey.shade400.withOpacity(0.3),
                              shape: BoxShape.circle,
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.1),
                                  blurRadius: 4,
                                  spreadRadius: 1,
                                ),
                              ],
                            ),
                            child: const Icon(
                              Icons.arrow_back_ios_rounded,
                              color: Colors.white,
                              size: 24,
                            ),
                          ),
                        ),
                      ),
                    )
                    : const SizedBox.shrink(),
          ),

          // Right arrow
          Positioned(
            right: 0,
            top: 0,
            bottom: 0,
            child:
                _currentEventIndex < _events.length - 1
                    ? GestureDetector(
                      onTap: () {
                        _eventPageController.nextPage(
                          duration: const Duration(milliseconds: 500),
                          curve: Curves.easeOutCubic,
                        );
                      },
                      child: Container(
                        width: 50,
                        height: double.infinity,
                        color: Colors.transparent,
                        child: Center(
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: Colors.grey.shade400.withOpacity(0.3),
                              shape: BoxShape.circle,
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.1),
                                  blurRadius: 4,
                                  spreadRadius: 1,
                                ),
                              ],
                            ),
                            child: const Icon(
                              Icons.arrow_forward_ios_rounded,
                              color: Colors.white,
                              size: 24,
                            ),
                          ),
                        ),
                      ),
                    )
                    : const SizedBox.shrink(),
          ),

          // Page indicator
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: Container(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(
                  _events.length,
                  (index) => GestureDetector(
                    onTap: () {
                      _eventPageController.animateToPage(
                        index,
                        duration: const Duration(milliseconds: 500),
                        curve: Curves.easeOutCubic,
                      );
                    },
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 300),
                      width: _currentEventIndex == index ? 18 : 8,
                      height: 8,
                      margin: const EdgeInsets.symmetric(horizontal: 4),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(12),
                        color:
                            _currentEventIndex == index
                                ? Colors.white
                                : Colors.white.withOpacity(0.4),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildModernCountdownTimer({
    required int days,
    required int hours,
    required int minutes,
    required int seconds,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 5),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.18), // Slightly darker background
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.2), width: 1),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _buildGradientTimeUnit(days.toString().padLeft(2, '0'), 'DAYS'),
          _buildTimeSeparator(),
          _buildGradientTimeUnit(hours.toString().padLeft(2, '0'), 'HRS'),
          _buildTimeSeparator(),
          _buildGradientTimeUnit(minutes.toString().padLeft(2, '0'), 'MIN'),
          _buildTimeSeparator(),
          _buildGradientTimeUnit(seconds.toString().padLeft(2, '0'), 'SEC'),
        ],
      ),
    );
  }

  Widget _buildGradientTimeUnit(String value, String label) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10),
            color: Colors.black.withOpacity(0.3), // Slightly darker background
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(
                  0.18,
                ), // Slightly stronger shadow
                blurRadius: 2,
                offset: const Offset(0, 1),
                spreadRadius: 0,
              ),
              BoxShadow(
                color: Colors.white.withOpacity(0.1),
                blurRadius: 2,
                offset: const Offset(0, -1),
                spreadRadius: 0,
              ),
            ],
          ),
          child: Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontFamily: 'Roboto',
              fontWeight: FontWeight.w700,
              fontSize: 22,
              height: 1.0,
              letterSpacing: 1.0,
            ),
          ),
        ),
        const SizedBox(height: 6),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10),
            color: Colors.black.withOpacity(
              0.18,
            ), // Slightly darker background for label
          ),
          child: Text(
            label,
            style: const TextStyle(
              color: Colors.white, // Pure white for better visibility
              fontSize: 10,
              fontWeight: FontWeight.w500,
              letterSpacing: 1,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildTimeSeparator() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Container(
          width: 4,
          height: 4,
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.8),
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          width: 4,
          height: 4,
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.8),
            shape: BoxShape.circle,
          ),
        ),
      ],
    );
  }

  Widget _buildModernMenuCard(
    BuildContext context, {
    required String title,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
    int index = 0,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: color.withOpacity(0.12),
              blurRadius: 12,
              offset: const Offset(0, 4),
              spreadRadius: 0,
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: Stack(
            children: [
              // Background gradient overlay
              Positioned.fill(
                child: Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [Colors.white, color.withOpacity(0.03)],
                    ),
                  ),
                ),
              ),

              // Pattern overlay
              Positioned.fill(
                child: CustomPaint(
                  painter: MenuCardPatternPainter(color: color),
                ),
              ),

              // Content
              Padding(
                padding: const EdgeInsets.all(20.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [color, const Color(0xFF7575A8)],
                        ),
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: color.withOpacity(0.25),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Icon(icon, color: Colors.white, size: 26),
                    ),
                    const Spacer(),

                    // Clear, non-faded title text
                    Text(
                      title,
                      style: const TextStyle(
                        color: Colors.black87,
                        fontWeight: FontWeight.bold,
                        fontSize: 17,
                      ),
                    ),

                    const SizedBox(height: 12),

                    // Progress indicator
                    Row(
                      children: [
                        Expanded(
                          child: Container(
                            height: 4,
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.centerLeft,
                                end: Alignment.centerRight,
                                colors: [color, color.withOpacity(0.3)],
                              ),
                              borderRadius: BorderRadius.circular(3),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            color: color.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Icon(
                            Icons.arrow_forward_ios,
                            color: color,
                            size: 12,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDrawer(BuildContext context) {
    final userData = _auth.currentUser;
    final email = userData?.email ?? 'organizer@email.com';
    final displayName = userData?.displayName ?? email.split('@')[0];
    final avatarText =
        displayName.isNotEmpty ? displayName[0].toUpperCase() : 'O';

    print(
      'OrganizerHomeScreen: _buildDrawer called, profileImage: ${_profileImage != null}, profileImageLoaded: $_profileImageLoaded',
    );

    // Since we're accessing drawer, verify profile image exists
    if (_profileImage != null) {
      String filePath = _profileImage!.path;
      print(
        'OrganizerHomeScreen: Double-checking if file exists at: $filePath',
      );
      bool fileExists = File(filePath).existsSync();
      print('OrganizerHomeScreen: File exists check result: $fileExists');
      if (!fileExists) {
        print(
          'OrganizerHomeScreen: Image file does not exist on direct check, forcing reload',
        );
        setState(() {
          _profileImage = null;
          _profileImageLoaded = false;
          _profileImagePath = null;
        });
        // Immediate reload in a microtask to avoid build phase issues
        Future.microtask(() => _loadProfileImage());
      }
    }

    // Either not loaded yet or file doesn't exist - load it
    if (!_profileImageLoaded || _profileImage == null) {
      print(
        'OrganizerHomeScreen: Profile image not loaded or null, loading now',
      );
      // Use Future.microtask to avoid rebuilding during build phase
      Future.microtask(() => _loadProfileImage());
    }

    return Drawer(
      backgroundColor: Colors.transparent,
      child: SafeArea(
        child: Container(
          margin: const EdgeInsets.only(
            right: 1,
          ), // Small margin to eliminate any gap
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.only(
              topRight: Radius.circular(20),
              bottomRight: Radius.circular(20),
            ),
          ),
          clipBehavior: Clip.antiAlias,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: double.infinity,
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [Color(0xFF9D9DCC), Color(0xFF7575A8)],
                  ),
                ),
                padding: const EdgeInsets.symmetric(
                  vertical: 25,
                  horizontal: 20,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.start,
                  children: [
                    GestureDetector(
                      onTap: () {
                        Navigator.pop(context);
                        // Navigate to Account screen and refresh profile image when returning
                        Future.delayed(Duration(milliseconds: 300), () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder:
                                  (context) => AccountScreen(
                                    onProfileImageChanged: () {
                                      print(
                                        'OrganizerHomeScreen: onProfileImageChanged callback triggered',
                                      );
                                      // Force a full reset of state and rebuild drawer
                                      if (mounted) {
                                        setState(() {
                                          _profileImageLoaded = false;
                                          _profileImage = null;
                                          _profileImagePath = null;
                                        });
                                        // Force reload image immediately
                                        _loadProfileImage();
                                      }
                                    },
                                  ),
                            ),
                          ).then((_) {
                            // Also attempt reload when returning from screen
                            if (mounted) {
                              setState(() {
                                _profileImageLoaded = false;
                                _profileImage = null;
                                _profileImagePath = null;
                              });
                              _loadProfileImage();

                              // Add a delayed reload to ensure we catch any changes
                              Future.delayed(Duration(milliseconds: 500), () {
                                if (mounted) {
                                  _loadProfileImage();
                                }
                              });
                            }
                          });
                        });
                      },
                      child: Container(
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 2.5),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.1),
                              blurRadius: 8,
                              spreadRadius: 2,
                            ),
                          ],
                        ),
                        child: CircleAvatar(
                          radius: 40,
                          backgroundColor: Colors.grey[200],
                          backgroundImage:
                              _profileImage != null &&
                                      _profileImage!.existsSync()
                                  ? FileImage(_profileImage!)
                                  : null,
                          onBackgroundImageError:
                              _profileImage != null &&
                                      _profileImage!.existsSync()
                                  ? (exception, stackTrace) {
                                    print(
                                      'OrganizerHomeScreen: Error loading profile image: $exception',
                                    );
                                    setState(() {
                                      _profileImage = null;
                                      _profileImageLoaded = false;
                                      _profileImagePath = null;
                                    });
                                    _loadProfileImage();
                                  }
                                  : null,
                          child:
                              _profileImage == null ||
                                      !_profileImage!.existsSync()
                                  ? Text(
                                    avatarText,
                                    style: const TextStyle(
                                      color: Colors.black,
                                      fontSize: 32,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  )
                                  : null,
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      displayName,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 18,
                      ),
                      textAlign: TextAlign.start,
                      overflow: TextOverflow.visible,
                    ),
                  ],
                ),
              ),
              Expanded(
                child: ListView(
                  padding: EdgeInsets.zero,
                  children: [
                    // Account section
                    Padding(
                      padding: const EdgeInsets.only(
                        left: 20,
                        top: 16,
                        bottom: 8,
                      ),
                      child: Text(
                        'Account',
                        style: TextStyle(
                          color: Colors.black87,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    _buildDrawerTile(
                      context,
                      icon: Icons.account_circle,
                      title: 'My Account',
                      onTap: () {
                        Navigator.pop(context);
                        // Navigate to Account screen and refresh profile image when returning
                        Future.delayed(Duration(milliseconds: 300), () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder:
                                  (context) => AccountScreen(
                                    onProfileImageChanged: () {
                                      print(
                                        'OrganizerHomeScreen: onProfileImageChanged callback triggered',
                                      );
                                      // Force a full reset of state and rebuild drawer
                                      if (mounted) {
                                        setState(() {
                                          _profileImageLoaded = false;
                                          _profileImage = null;
                                          _profileImagePath = null;
                                          print(
                                            'OrganizerHomeScreen: Reset profile image state completely',
                                          );
                                        });

                                        // Force reload image immediately to ensure it's updated
                                        _loadProfileImage();

                                        // And again after a short delay to catch any in-progress changes
                                        Future.delayed(
                                          Duration(milliseconds: 500),
                                          () {
                                            if (mounted) {
                                              setState(() {
                                                _profileImageLoaded = false;
                                                _profileImage = null;
                                              });
                                              _loadProfileImage().then((_) {
                                                if (mounted) {
                                                  // Force another rebuild to ensure UI updates
                                                  setState(() {});
                                                }
                                              });
                                            }
                                          },
                                        );
                                      }
                                    },
                                  ),
                            ),
                          ).then((_) {
                            // Also attempt reload when returning from screen
                            if (mounted) {
                              setState(() {
                                _profileImageLoaded = false;
                                _profileImage = null;
                                _profileImagePath = null;
                              });
                              _loadProfileImage();

                              // Add a delayed reload to ensure we catch any changes that might
                              // happen after returning to this screen
                              Future.delayed(Duration(milliseconds: 500), () {
                                if (mounted) {
                                  setState(() {
                                    _profileImageLoaded = false;
                                    _profileImage = null;
                                  });
                                  _loadProfileImage();
                                }
                              });
                            }
                          });
                        });
                      },
                    ),
                    // Divider
                    Padding(
                      padding: const EdgeInsets.only(left: 20, right: 20),
                      child: Divider(color: Colors.grey[200], height: 1),
                    ),
                    _buildDrawerTile(
                      context,
                      icon: Icons.create,
                      title: 'Create Portfolio',
                      onTap: () {
                        Navigator.pop(context); // Close the drawer
                        final String organizerId = _auth.currentUser?.uid ?? '';
                        if (organizerId.isNotEmpty) {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder:
                                  (context) => PortfolioCreationScreen(
                                    organizerId: organizerId,
                                  ),
                            ),
                          );
                        } else {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text(
                                'User not authenticated. Please log in again.',
                              ),
                              backgroundColor: Colors.red,
                            ),
                          );
                        }
                      },
                    ),
                    // Divider
                    Padding(
                      padding: const EdgeInsets.only(left: 20, right: 20),
                      child: Divider(color: Colors.grey[200], height: 1),
                    ),
                    _buildDrawerTile(
                      context,
                      icon: Icons.book,
                      title: 'My Portfolio',
                      onTap: () {
                        Navigator.pop(context);
                        // Navigation will be added later
                        final String organizerId = _auth.currentUser?.uid ?? '';
                        if (organizerId.isNotEmpty) {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder:
                                  (context) => MyPortfoliosScreen(
                                    organizerId: organizerId,
                                  ),
                            ),
                          );
                        } else {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text(
                                'User not authenticated. Please log in again.',
                              ),
                              backgroundColor: Colors.red,
                            ),
                          );
                        }
                      },
                    ),
                    // Divider
                    Padding(
                      padding: const EdgeInsets.only(left: 20, right: 20),
                      child: Divider(color: Colors.grey[200], height: 1),
                    ),
                    _buildDrawerTile(
                      context,
                      icon: Icons.people,
                      title: 'Invite friends',
                      onTap: () {
                        Navigator.pop(context);
                        // Navigation will be added later
                      },
                    ),

                    // Perks section
                    Padding(
                      padding: const EdgeInsets.only(
                        left: 20,
                        top: 24,
                        bottom: 8,
                      ),
                      child: Text(
                        'Perks for you',
                        style: TextStyle(
                          color: Colors.black87,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    _buildDrawerTile(
                      context,
                      icon: Icons.star,
                      title: 'Become a pro',
                      onTap: () {
                        Navigator.pop(context);
                        // Navigation will be added later
                      },
                    ),
                    // Divider
                    Padding(
                      padding: const EdgeInsets.only(left: 20, right: 20),
                      child: Divider(color: Colors.grey[200], height: 1),
                    ),
                    _buildDrawerTile(
                      context,
                      icon: Icons.emoji_events,
                      title: 'PlanIt rewards',
                      onTap: () {
                        Navigator.pop(context);
                        // Navigation will be added later
                      },
                    ),

                    // General section
                    Padding(
                      padding: const EdgeInsets.only(
                        left: 20,
                        top: 24,
                        bottom: 8,
                      ),
                      child: Text(
                        'General',
                        style: TextStyle(
                          color: Colors.black87,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    _buildDrawerTile(
                      context,
                      icon: Icons.help_outline,
                      title: 'Help center',
                      onTap: () {
                        Navigator.pop(context);
                        // Navigation will be added later
                      },
                    ),
                    // Divider
                    Padding(
                      padding: const EdgeInsets.only(left: 20, right: 20),
                      child: Divider(color: Colors.grey[200], height: 1),
                    ),
                    _buildDrawerTile(
                      context,
                      icon: Icons.policy,
                      title: 'Terms & policies',
                      onTap: () {
                        Navigator.pop(context);
                        // Navigation will be added later
                      },
                    ),

                    // Logout button
                    Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Container(
                        width: double.infinity,
                        child: OutlinedButton(
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => const LoginView(),
                              ),
                            );
                          },
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            side: BorderSide(color: Colors.grey[300]!),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                          child: const Text(
                            'Log out',
                            style: TextStyle(
                              color: Colors.black87,
                              fontSize: 16,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ),
                    ),
                    // Version info with beta tag
                    Padding(
                      padding: const EdgeInsets.only(bottom: 16.0, top: 8.0),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            'Version 1.0.0',
                            style: TextStyle(
                              color: Colors.grey[500],
                              fontSize: 12,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.green.withOpacity(0.2),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: const Text(
                              'BETA - Multan only',
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                color: Colors.green,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDrawerTile(
    BuildContext context, {
    required IconData icon,
    required String title,
    required VoidCallback onTap,
  }) {
    return ListTile(
      leading: Icon(icon, color: const Color(0xFF9D9DCC), size: 22),
      title: Text(
        title,
        style: const TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w400,
          color: Colors.black87,
        ),
      ),
      trailing: Icon(
        Icons.arrow_forward_ios,
        size: 14,
        color: Colors.grey[400],
      ),
      onTap: onTap,
      contentPadding: const EdgeInsets.symmetric(
        horizontal: 20.0,
        vertical: 2.0,
      ),
      dense: true,
    );
  }

  Widget _buildAppBar(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: const BoxDecoration(
        color: Color(0xFF9D9DCC),
        boxShadow: [
          BoxShadow(color: Colors.black12, offset: Offset(0, 2), blurRadius: 4),
        ],
      ),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.menu, color: Colors.white),
            onPressed: () {
              // Force reload profile image before opening drawer
              setState(() {
                _profileImageLoaded = false;
                _profileImage = null;
                _profileImagePath = null;
              });
              _loadProfileImage();

              // Open the drawer
              _scaffoldKey.currentState?.openDrawer();
            },
          ),
          const Spacer(),
          const Text(
            'PlanIt',
            style: TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          const Spacer(),
          Container(
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              borderRadius: BorderRadius.circular(25),
            ),
            child: IconButton(
              icon: const Icon(
                Icons.notifications_outlined,
                color: Colors.white,
              ),
              onPressed: () {
                // Show notification panel
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildChatFab(BuildContext context) {
    return FloatingActionButton(
      onPressed: () {
        _showChatDialog(context);
      },
      backgroundColor: const Color(0xFF9D9DCC),
      elevation: 4,
      tooltip: "Chat with support",
      child: const Icon(Icons.chat, color: Colors.white),
    );
  }

  void _showChatDialog(BuildContext context) {
    final TextEditingController _messageController = TextEditingController();
    bool _isSending = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder:
          (context) => StatefulBuilder(
            builder: (BuildContext context, StateSetter setState) {
              return Container(
                height: MediaQuery.of(context).size.height * 0.75,
                decoration: const BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.only(
                    topLeft: Radius.circular(25),
                    topRight: Radius.circular(25),
                  ),
                ),
                child: Column(
                  children: [
                    // Chat header
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 15,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFF9D9DCC),
                        borderRadius: const BorderRadius.only(
                          topLeft: Radius.circular(25),
                          topRight: Radius.circular(25),
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.1),
                            blurRadius: 10,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: Colors.white.withOpacity(0.3),
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(
                                  Icons.support_agent,
                                  color: Colors.white,
                                  size: 20,
                                ),
                              ),
                              const SizedBox(width: 12),
                              const Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Customer Support',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 16,
                                    ),
                                  ),
                                  Text(
                                    'We usually respond within an hour',
                                    style: TextStyle(
                                      color: Colors.white70,
                                      fontSize: 12,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                          IconButton(
                            icon: const Icon(Icons.close, color: Colors.white),
                            onPressed: () => Navigator.pop(context),
                          ),
                        ],
                      ),
                    ),

                    // Chat message area
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.all(16),
                        color: Colors.grey.shade50,
                        child: SingleChildScrollView(
                          child: Column(
                            children: [
                              // System welcome message
                              _buildChatBubble(
                                message: "Hello! How can we help you today?",
                                isUser: false,
                                time: "Just now",
                              ),

                              // Placeholder for future messages
                              // Messages will be added here from Firebase
                            ],
                          ),
                        ),
                      ),
                    ),

                    // Message input area
                    Container(
                      padding: EdgeInsets.only(
                        left: 16,
                        right: 16,
                        top: 10,
                        bottom: MediaQuery.of(context).viewInsets.bottom + 10,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.05),
                            blurRadius: 10,
                            offset: const Offset(0, -2),
                          ),
                        ],
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: _messageController,
                              decoration: InputDecoration(
                                hintText: "Type your message...",
                                hintStyle: TextStyle(
                                  color: Colors.grey.shade400,
                                ),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(25),
                                  borderSide: BorderSide.none,
                                ),
                                filled: true,
                                fillColor: Colors.grey.shade100,
                                contentPadding: EdgeInsets.symmetric(
                                  horizontal: 20,
                                  vertical: 10,
                                ),
                              ),
                              maxLines: 3,
                              minLines: 1,
                              textCapitalization: TextCapitalization.sentences,
                            ),
                          ),
                          const SizedBox(width: 8),
                          InkWell(
                            onTap: () {
                              if (_messageController.text.trim().isNotEmpty &&
                                  !_isSending) {
                                setState(() {
                                  _isSending = true;
                                });

                                // Simulate sending message
                                Future.delayed(Duration(seconds: 1), () {
                                  // Here is where you would integrate with Firebase
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text(
                                        "Support ticket sent!",
                                        style: TextStyle(
                                          color: Colors.white,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                      backgroundColor: Colors.green,
                                      duration: Duration(seconds: 2),
                                    ),
                                  );

                                  setState(() {
                                    _isSending = false;
                                  });

                                  Navigator.pop(context);
                                });
                              }
                            },
                            child: Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color:
                                    _messageController.text.trim().isEmpty ||
                                            _isSending
                                        ? Colors.grey.shade300
                                        : const Color(0xFF9D9DCC),
                                shape: BoxShape.circle,
                              ),
                              child:
                                  _isSending
                                      ? SizedBox(
                                        width: 20,
                                        height: 20,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          valueColor:
                                              AlwaysStoppedAnimation<Color>(
                                                Colors.white,
                                              ),
                                        ),
                                      )
                                      : Icon(
                                        Icons.send_rounded,
                                        color: Colors.white,
                                        size: 20,
                                      ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
    );
  }

  Widget _buildChatBubble({
    required String message,
    required bool isUser,
    required String time,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        mainAxisAlignment:
            isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (!isUser)
            Container(
              height: 32,
              width: 32,
              margin: const EdgeInsets.only(right: 8),
              decoration: BoxDecoration(
                color: const Color(0xFF9D9DCC),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.support_agent,
                color: Colors.white,
                size: 18,
              ),
            ),

          Flexible(
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: isUser ? const Color(0xFF9D9DCC) : Colors.white,
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(isUser ? 16 : 0),
                  topRight: Radius.circular(isUser ? 0 : 16),
                  bottomLeft: const Radius.circular(16),
                  bottomRight: const Radius.circular(16),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 5,
                    offset: const Offset(0, 1),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    message,
                    style: TextStyle(
                      color: isUser ? Colors.white : Colors.black87,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    time,
                    style: TextStyle(
                      color: isUser ? Colors.white70 : Colors.black54,
                      fontSize: 10,
                    ),
                  ),
                ],
              ),
            ),
          ),

          if (isUser)
            Container(
              height: 32,
              width: 32,
              margin: const EdgeInsets.only(left: 8),
              decoration: BoxDecoration(
                color: const Color(0xFF9D9DCC),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.person, color: Colors.white, size: 16),
            ),
        ],
      ),
    );
  }
}

class MenuCardPatternPainter extends CustomPainter {
  final Color color;

  MenuCardPatternPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint =
        Paint()
          ..color = color.withOpacity(0.03)
          ..style = PaintingStyle.fill;

    // Draw subtle geometric patterns

    // Top-right corner design
    final path = Path();
    path.moveTo(size.width - 40, 0);
    path.lineTo(size.width, 0);
    path.lineTo(size.width, 40);
    path.close();
    canvas.drawPath(path, paint);

    // Small circles
    for (int i = 0; i < 3; i++) {
      canvas.drawCircle(
        Offset(size.width - 15, size.height - 60 + (i * 15)),
        2,
        paint..color = color.withOpacity(0.05),
      );
    }

    // Small dots pattern in top-left
    for (int i = 0; i < 3; i++) {
      for (int j = 0; j < 3; j++) {
        if ((i + j) % 2 == 0) {
          canvas.drawCircle(
            Offset(10 + (i * 8), 60 + (j * 8)),
            1.5,
            paint..color = color.withOpacity(0.04),
          );
        }
      }
    }

    // Bottom-left triangle
    final bottomPath = Path();
    bottomPath.moveTo(0, size.height - 30);
    bottomPath.lineTo(30, size.height);
    bottomPath.lineTo(0, size.height);
    bottomPath.close();
    canvas.drawPath(bottomPath, paint..color = color.withOpacity(0.02));
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) {
    return false;
  }
}

class PatternPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint =
        Paint()
          ..color = const Color(0xFF9D9DCC).withOpacity(0.02)
          ..style = PaintingStyle.fill;

    // Draw subtle pattern with triangles and dots
    final patternSize = 30.0;
    final rows = (size.height / patternSize).ceil();
    final cols = (size.width / patternSize).ceil();

    for (int i = 0; i < rows; i++) {
      for (int j = 0; j < cols; j++) {
        // Only draw some patterns for a sparse effect
        if ((i + j) % 5 == 0) {
          final x = j * patternSize;
          final y = i * patternSize;

          // Draw small dot
          canvas.drawCircle(
            Offset(x + patternSize / 2, y + patternSize / 2),
            1.5,
            paint,
          );
        }

        // Draw triangles in very limited positions
        if ((i + j) % 9 == 0) {
          final x = j * patternSize;
          final y = i * patternSize;

          final path = Path();
          path.moveTo(x + patternSize / 2, y);
          path.lineTo(x + patternSize, y + patternSize);
          path.lineTo(x, y + patternSize);
          path.close();

          canvas.drawPath(
            path,
            paint..color = const Color(0xFF9D9DCC).withOpacity(0.01),
          );
        }
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) {
    return false;
  }
}
