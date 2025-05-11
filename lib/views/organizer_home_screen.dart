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

class OrganizerHomeScreen extends StatefulWidget {
  const OrganizerHomeScreen({super.key});

  @override
  State<OrganizerHomeScreen> createState() => _OrganizerHomeScreenState();
}

class _OrganizerHomeScreenState extends State<OrganizerHomeScreen>
    with SingleTickerProviderStateMixin {
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
  static const String _profileImagePathKey = 'profile_image_path';

  @override
  void initState() {
    super.initState();
    _loadPendingOrders();
    _debugCheckAllResponses();
    startTimer();
    _loadProfileImage();

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
    super.dispose();
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
      // Don't show error to user, just fail silently
    }
  }

  // Save profile image path to shared preferences
  Future<void> _saveProfileImagePath(String imagePath) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_profileImagePathKey, imagePath);
    } catch (e) {
      print('Error saving profile image path: $e');
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
      final XFile? pickedImage = await _imagePicker.pickImage(
        source: source,
        maxWidth: 400,
        maxHeight: 400,
        imageQuality: 85,
      );

      if (pickedImage != null) {
        // Copy the image to app directory for persistence
        final appDir = await getApplicationDocumentsDirectory();
        final fileName =
            'organizer_profile_${DateTime.now().millisecondsSinceEpoch}.jpg';
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
          content: Text('Could not remove profile picture: $e'),
          backgroundColor: Colors.red,
        ),
      );
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
      margin: const EdgeInsets.fromLTRB(20, 20, 20, 8),
      width: double.infinity,
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
            color: const Color(0xFF9D9DCC).withOpacity(0.3),
            blurRadius: 10,
            offset: const Offset(0, 4),
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
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
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
                          size: 24,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Upcoming Event',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 14,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            const Text(
                              'Summer Wedding',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 20,
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
                  _buildModernCountdownTimer(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildModernCountdownTimer() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 5),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.1),
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
            color: Colors.black.withOpacity(0.15),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.1),
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
            color: Colors.white.withOpacity(0.1),
          ),
          child: Text(
            label,
            style: TextStyle(
              color: Colors.white.withOpacity(0.9),
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
                        // Navigate to Account screen and refresh profile image when returning
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder:
                                (context) => AccountScreen(
                                  onProfileImageChanged: _loadProfileImage,
                                ),
                          ),
                        );
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
                              _profileImage != null
                                  ? FileImage(_profileImage!)
                                  : null,
                          child:
                              _profileImage == null
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
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder:
                                (context) => AccountScreen(
                                  onProfileImageChanged: _loadProfileImage,
                                ),
                          ),
                        );
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
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
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
