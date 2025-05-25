import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../controllers/client_controller.dart';
import 'dart:ui';
import './weather_screen.dart';
import './feedback_screen.dart';
import './order_history_screen.dart';
import './account_screen.dart';
import 'package:firebase_auth/firebase_auth.dart';
import './login_view.dart';
import './organizer_search_screen.dart';
import 'package:intl/intl.dart';
import '../services/weather_service.dart';
import '../models/weather_model.dart';
import '../providers/city_provider.dart';
import 'dart:math';
import '../constants/app_colors.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;
import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/response_model.dart';
import '../services/portfolio_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter/services.dart';

class ClientHomeScreen extends StatefulWidget {
  const ClientHomeScreen({super.key});

  // Route observer for detecting navigation
  static final RouteObserver<PageRoute> routeObserver =
      RouteObserver<PageRoute>();

  @override
  State<ClientHomeScreen> createState() => _ClientHomeScreenState();
}

class _ClientHomeScreenState extends State<ClientHomeScreen>
    with TickerProviderStateMixin, RouteAware {
  // Timer values for countdown
  int days = 0;
  int hours = 0;
  int minutes = 0;
  int seconds = 0;
  Timer? _timer;
  String? _currentCity;
  late Stream<List<ForecastDay>> weatherStream;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // Animation controllers
  late AnimationController _weatherAnimController;
  late AnimationController _countdownAnimController;
  late AnimationController _sectionTitleAnimController;
  late AnimationController _menuAnimController;

  // Animations
  late Animation<double> _weatherFadeAnim;
  late Animation<double> _countdownFadeAnim;
  late Animation<double> _sectionTitleFadeAnim;
  late Animation<Offset> _sectionTitleSlideAnim;

  // Menu card animations list
  late List<Animation<double>> _menuCardAnimations;

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  bool _isLoadingEvents = true;

  // Add this variable for profile image
  final ImagePicker _imagePicker = ImagePicker();
  File? _profileImage;
  String? _profileImagePath; // Add this to track the path
  static const String _profileImagePathKey = 'client_profile_image_path';
  bool _profileImageLoaded = false; // Track if we've tried to load the image

  // Add notification badge counter
  int _notificationCount = 3;
  bool _showNotificationBadge = true;

  // Add a scaffold key to access the drawer
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  // Add event management variables
  int _currentEventIndex = 0;
  late PageController _eventPageController;
  List<Map<String, dynamic>> _events = [];

  // For rating and event count caching
  double _portfolioRating = 0.0;
  int _eventCount = 0;
  bool _loadingRating = true;

  @override
  void initState() {
    super.initState();
    _initializeWeatherStream();
    _loadClientEvents();
    _clearCrossProfileImages(); // Add this to clear any mixed cache
    _loadProfileImage();
    _eventPageController = PageController(
      initialPage: 0,
      viewportFraction: 0.95, // Slightly smaller to show a hint of next page
    );

    // Create animation controllers directly without disposing first on initial creation
    _createAnimationControllers();
    _setupAnimations();
    _startAnimations();
  }

  // Create animation controllers
  void _createAnimationControllers() {
    // Set up animation controllers with longer durations for smoother animations
    _weatherAnimController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000), // Increased from 600ms
    );

    _countdownAnimController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200), // Increased from 800ms
    );

    _sectionTitleAnimController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000), // Increased from 600ms
    );

    _menuAnimController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500), // Increased from 1000ms
    );
  }

  // Setup animations with proper curves
  void _setupAnimations() {
    // Set up the animations with gentler curves
    _weatherFadeAnim = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _weatherAnimController,
        curve: Curves.easeInOut,
      ), // Changed from easeOut
    );

    _countdownFadeAnim = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _countdownAnimController,
        curve: Curves.easeInOut,
      ), // Changed from easeOut
    );

    _sectionTitleFadeAnim = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _sectionTitleAnimController,
        curve: Curves.easeInOut,
      ), // Changed from easeOut
    );

    _sectionTitleSlideAnim = Tween<Offset>(
      begin: const Offset(
        -0.1,
        0.0,
      ), // Reduced offset from -0.2 for subtler slide
      end: Offset.zero,
    ).animate(
      CurvedAnimation(
        parent: _sectionTitleAnimController,
        curve: Curves.easeOutQuart,
      ), // Changed to easeOutQuart for smoother finish
    );

    // Initialize menu card animations list - will be populated when menu items are known
    _menuCardAnimations = [];
  }

  // Extract animation initialization to a separate method
  void _initializeAnimations() {
    // Safety dispose the old controllers if they exist
    _disposeAnimationControllers();

    // Recreate and setup controllers
    _createAnimationControllers();
    _setupAnimations();

    // Start the animations
    _startAnimations();
  }

  // Extract animation start to a separate method
  void _startAnimations() {
    // Reset animations to the beginning
    _weatherAnimController.reset();
    _countdownAnimController.reset();
    _sectionTitleAnimController.reset();
    _menuAnimController.reset();

    Future.delayed(const Duration(milliseconds: 300), () {
      // Increased from 100ms
      if (mounted) _weatherAnimController.forward();
    });

    Future.delayed(const Duration(milliseconds: 700), () {
      // Increased from 400ms
      if (mounted) _countdownAnimController.forward();
    });

    Future.delayed(const Duration(milliseconds: 1100), () {
      // Increased from 800ms
      if (mounted) _sectionTitleAnimController.forward();
    });

    Future.delayed(const Duration(milliseconds: 1400), () {
      // Increased from 1000ms
      if (mounted) _menuAnimController.forward();
    });
  }

  // Clean disposal of animation controllers
  void _disposeAnimationControllers() {
    try {
      // Check if the controllers have been initialized
      if (this.mounted) {
        // Only dispose if the controller exists and is not already disposed
        if (_weatherAnimController.isAnimating)
          _weatherAnimController.dispose();
        if (_countdownAnimController.isAnimating)
          _countdownAnimController.dispose();
        if (_sectionTitleAnimController.isAnimating)
          _sectionTitleAnimController.dispose();
        if (_menuAnimController.isAnimating) _menuAnimController.dispose();
      }
    } catch (e) {
      // Controllers might not be initialized yet, which is fine when the widget is first created
      print('Animation controllers not yet initialized: $e');
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Register with the route observer
    ClientHomeScreen.routeObserver.subscribe(
      this,
      ModalRoute.of(context) as PageRoute,
    );
  }

  @override
  void dispose() {
    if (_timer != null && _timer!.isActive) {
      _timer!.cancel();
    }

    // Unsubscribe from route observer
    ClientHomeScreen.routeObserver.unsubscribe(this);

    // Dispose all animation controllers
    _disposeAnimationControllers();

    _eventPageController.dispose();
    super.dispose();
  }

  // Called when returning to this route
  @override
  void didPopNext() {
    super.didPopNext();
    print('ClientHomeScreen: Returned to screen, restarting animations');
    // Restart animations when returning to this screen
    _startAnimations();

    // Also refresh data
    _loadClientEvents();
  }

  // Load client events from Firebase
  Future<void> _loadClientEvents() async {
    // Initialize timer values to 0 immediately
    setState(() {
      _isLoadingEvents = true;
      days = 0;
      hours = 0;
      minutes = 0;
      seconds = 0;
    });

    try {
      final user = _auth.currentUser;
      if (user == null) {
        print('ClientHomeScreen: User not logged in');
        setState(() {
          _isLoadingEvents = false;
        });
        return;
      }

      // Fetch responses where the client is the current user
      final snapshot =
          await _firestore
              .collection('responses')
              .where('clientId', isEqualTo: user.uid)
              .where('status', whereIn: ['accepted', 'pending'])
              .orderBy('eventDate')
              .get();

      final List<Map<String, dynamic>> loadedEvents = [];

      if (snapshot.docs.isNotEmpty) {
        for (var doc in snapshot.docs) {
          final responseData = doc.data();
          final response = ResponseModel.fromMap(responseData);

          // Only include future events
          if (response.eventDate.isAfter(DateTime.now())) {
            loadedEvents.add({
              'title': response.eventName,
              'date': response.eventDate,
              'eventType': response.eventType,
              'id': response.id,
              'status': response.status,
            });
          }
        }

        // Sort events by date (closest first)
        loadedEvents.sort((a, b) {
          final DateTime dateA = a['date'] as DateTime;
          final DateTime dateB = b['date'] as DateTime;
          return dateA.compareTo(dateB);
        });
      }

      // If no events found, add a default placeholder event
      if (loadedEvents.isEmpty) {
        loadedEvents.add({
          'title': 'No upcoming events',
          'date':
              DateTime.now(), // Use current time for better placeholder indication
          'eventType': 'None',
          'id': 'placeholder',
          'status': 'none', // Ensure we use consistent status
        });
      }

      setState(() {
        _events = loadedEvents;
        _isLoadingEvents = false;
      });

      // Start the timer after loading events
      startTimer();
    } catch (e) {
      print('ClientHomeScreen: Error loading client events: $e');
      setState(() {
        _isLoadingEvents = false;
        // Add a default event in case of error
        _events = [
          {
            'title': 'Error loading events',
            'date':
                DateTime.now(), // Use current time for better placeholder indication
            'eventType': 'None',
            'id': 'error',
            'status':
                'error', // Keep 'error' status to distinguish from normal empty state
          },
        ];
      });
      startTimer();
    }
  }

  void startTimer() {
    // Cancel any existing timer
    if (_timer != null && _timer!.isActive) {
      _timer!.cancel();
    }

    // Make sure we have events before starting the timer
    if (_events.isEmpty) {
      print('ClientHomeScreen: No events to start timer for');
      setState(() {
        days = 0;
        hours = 0;
        minutes = 0;
        seconds = 0;
      });
      return;
    }

    // Check if the current event is a placeholder (no real event)
    final currentEvent = _events[_currentEventIndex];
    final eventStatus = currentEvent['status'] as String? ?? '';
    if (eventStatus == 'none' || eventStatus == 'error') {
      setState(() {
        days = 0;
        hours = 0;
        minutes = 0;
        seconds = 0;
      });
      return;
    }

    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted || _events.isEmpty) {
        timer.cancel();
        return;
      }

      setState(() {
        // Get the current selected event
        final currentEvent = _events[_currentEventIndex];
        final eventDate = currentEvent['date'] as DateTime;
        final eventStatus = currentEvent['status'] as String? ?? '';

        // If status is none or error, show all zeros
        if (eventStatus == 'none' || eventStatus == 'error') {
          days = 0;
          hours = 0;
          minutes = 0;
          seconds = 0;
          return;
        }

        // Calculate time difference
        final difference = eventDate.difference(DateTime.now());

        if (difference.isNegative) {
          // Event has passed
          days = 0;
          hours = 0;
          minutes = 0;
          seconds = 0;
        } else {
          // Update countdown values
          days = difference.inDays;
          hours = difference.inHours % 24;
          minutes = difference.inMinutes % 60;
          seconds = difference.inSeconds % 60;
        }
      });
    });
  }

  void _initializeWeatherStream() {
    weatherStream = Stream.fromFuture(
      WeatherService().getFiveDayForecast('Multan'),
    ).handleError((error) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Failed to load weather data. Using cached data if available.',
          ),
          backgroundColor: Colors.orange,
          duration: Duration(seconds: 3),
        ),
      );
      return [];
    });
  }

  @override
  Widget build(BuildContext context) {
    final screenHeight = MediaQuery.of(context).size.height;
    final screenWidth = MediaQuery.of(context).size.width;
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    // Initialize menu card animations in build if they weren't created yet
    if (_menuCardAnimations.isEmpty) {
      final int itemCount = 4; // Default number of menu items
      for (int i = 0; i < itemCount; i++) {
        final startInterval =
            0.1 * i; // Changed from 0.15 for smoother transition
        final endInterval = 0.1 * i + 0.9; // Changed to 0.9 for longer fade

        _menuCardAnimations.add(
          Tween<double>(begin: 0.0, end: 1.0).animate(
            CurvedAnimation(
              parent: _menuAnimController,
              curve: Interval(
                startInterval,
                endInterval > 1.0 ? 1.0 : endInterval,
                curve:
                    Curves
                        .easeOutQuart, // Changed from easeOutCubic for smoother motion
              ),
            ),
          ),
        );
      }
    }

    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: AppColors.creamBackground,
      drawer: _buildDrawer(context),
      floatingActionButton: _buildChatFab(context),
      body: SafeArea(
        child: Stack(
          children: [
            // Background design with patterns instead of blobs
            Positioned.fill(child: _buildPatternBackground()),
            // Main content
            Column(
              children: [
                _buildAppBar(context),
                Expanded(
                  child: SingleChildScrollView(
                    physics: const BouncingScrollPhysics(),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      mainAxisAlignment: MainAxisAlignment.start,
                      children: [
                        // Weather alert with fade-in animation
                        FadeTransition(
                          opacity: _weatherFadeAnim,
                          child: _buildCompactWeatherAlert(context),
                        ),

                        // Event countdown with fade-in animation
                        FadeTransition(
                          opacity: _countdownFadeAnim,
                          child: _buildEventCountdown(context),
                        ),

                        const SizedBox(height: 12),

                        // Section title with combined slide and fade animations
                        FadeTransition(
                          opacity: _sectionTitleFadeAnim,
                          child: SlideTransition(
                            position: _sectionTitleSlideAnim,
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 20.0,
                              ),
                              child: Row(
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
                                  Text(
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
                          ),
                        ),

                        const SizedBox(height: 8),

                        // Menu grid with animated cards
                        FadeTransition(
                          opacity: _menuAnimController,
                          child: _buildMenuGrid(context),
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

  Widget _buildDrawer(BuildContext context) {
    final userData = _auth.currentUser;
    final email = userData?.email ?? 'user@email.com';
    final displayName = userData?.displayName ?? email.split('@')[0];
    final avatarText =
        displayName.isNotEmpty ? displayName[0].toUpperCase() : 'U';

    print(
      'ClientHomeScreen: _buildDrawer called, profileImage: ${_profileImage != null}, profileImageLoaded: $_profileImageLoaded',
    );

    // Since we're accessing drawer, verify profile image exists
    if (_profileImage != null) {
      String filePath = _profileImage!.path;
      print('ClientHomeScreen: Double-checking if file exists at: $filePath');
      bool fileExists = File(filePath).existsSync();
      print('ClientHomeScreen: File exists check result: $fileExists');
      if (!fileExists) {
        print(
          'ClientHomeScreen: Image file does not exist on direct check, forcing reload',
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
    if (!_profileImageLoaded) {
      print('ClientHomeScreen: Profile image not loaded, loading now');
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
                        // Navigate to Account screen instead of showing dialog
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder:
                                (context) => AccountScreen(
                                  onProfileImageChanged: () {
                                    // Force a complete reload by resetting state
                                    setState(() {
                                      _profileImageLoaded = false;
                                      _profileImage = null;
                                      _profileImagePath = null;
                                    });
                                    // Explicitly reload the profile image and update state
                                    _loadProfileImage();

                                    // Add a delayed check to ensure all updates are processed
                                    Future.delayed(
                                      Duration(milliseconds: 500),
                                      () {
                                        if (mounted) {
                                          _loadProfileImage();
                                        }
                                      },
                                    );
                                  },
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
                              _profileImage != null &&
                                      _profileImage!.existsSync()
                                  ? FileImage(_profileImage!)
                                  : null,
                          onBackgroundImageError:
                              _profileImage != null &&
                                      _profileImage!.existsSync()
                                  ? (exception, stackTrace) {
                                    print(
                                      'ClientHomeScreen: Error loading profile image: $exception',
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
                        // Navigate to Account screen with profile image update callback
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder:
                                (context) => AccountScreen(
                                  onProfileImageChanged: () {
                                    // Force a complete reload by resetting state
                                    setState(() {
                                      _profileImageLoaded = false;
                                      _profileImage = null;
                                      _profileImagePath = null;
                                    });
                                    // Explicitly reload the profile image and update state
                                    _loadProfileImage();

                                    // Add a delayed check to ensure all updates are processed
                                    Future.delayed(
                                      Duration(milliseconds: 500),
                                      () {
                                        if (mounted) {
                                          _loadProfileImage();
                                        }
                                      },
                                    );
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
                    // Divider
                    Padding(
                      padding: const EdgeInsets.only(left: 20, right: 20),
                      child: Divider(color: Colors.grey[200], height: 1),
                    ),
                    _buildDrawerTile(
                      context,
                      icon: Icons.card_giftcard,
                      title: 'Vouchers',
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
          Image.asset(
            'assets/images/newlogo3.png',
            height: 45,
            width: 160,
            fit: BoxFit.contain,
          ),
          const Spacer(),
          Stack(
            alignment: Alignment.center,
            children: [
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
                    _showNotificationsPanel(context);
                  },
                ),
              ),
              if (_showNotificationBadge)
                Positioned(
                  top: 8,
                  right: 8,
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: Colors.red,
                      shape: BoxShape.circle,
                    ),
                    constraints: const BoxConstraints(
                      minWidth: 18,
                      minHeight: 18,
                    ),
                    child: Text(
                      _notificationCount.toString(),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  // Method to show notifications panel
  void _showNotificationsPanel(BuildContext context) {
    setState(() {
      _showNotificationBadge = false;
    });

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder:
          (context) => DraggableScrollableSheet(
            initialChildSize: 0.6,
            minChildSize: 0.3,
            maxChildSize: 0.9,
            builder:
                (_, controller) => Container(
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.only(
                      topLeft: Radius.circular(28),
                      topRight: Radius.circular(28),
                    ),
                  ),
                  child: Column(
                    children: [
                      // Drag handle
                      Container(
                        margin: const EdgeInsets.only(top: 12, bottom: 4),
                        width: 40,
                        height: 5,
                        decoration: BoxDecoration(
                          color: Colors.grey[300],
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: const Color(
                                      0xFF9D9DCC,
                                    ).withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: const Icon(
                                    Icons.notifications_none_rounded,
                                    color: Color(0xFF9D9DCC),
                                    size: 20,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                const Text(
                                  'Notifications',
                                  style: TextStyle(
                                    fontSize: 20,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.black87,
                                  ),
                                ),
                              ],
                            ),
                            TextButton(
                              onPressed: () {
                                // Mark all as read
                                setState(() {
                                  _notificationCount = 0;
                                });
                                Navigator.pop(context);
                              },
                              style: TextButton.styleFrom(
                                foregroundColor: Colors.black54,
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 4,
                                ),
                                minimumSize: Size.zero,
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.check_circle_outline,
                                    size: 16,
                                    color: Colors.black54,
                                  ),
                                  const SizedBox(width: 6),
                                  const Text(
                                    'Mark all as read',
                                    style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),

                      // Filter tabs
                      Padding(
                        padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
                        child: Container(
                          height: 40,
                          decoration: BoxDecoration(
                            color: Colors.grey.shade100,
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Row(
                            children: [
                              Expanded(
                                child: Container(
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF9D9DCC),
                                    borderRadius: BorderRadius.circular(20),
                                    boxShadow: [
                                      BoxShadow(
                                        color: const Color(
                                          0xFF9D9DCC,
                                        ).withOpacity(0.2),
                                        blurRadius: 4,
                                        offset: const Offset(0, 2),
                                      ),
                                    ],
                                  ),
                                  child: Center(
                                    child: Text(
                                      'All',
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.w600,
                                        fontSize: 14,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                              Expanded(
                                child: Center(
                                  child: Text(
                                    'Events',
                                    style: TextStyle(
                                      color: Colors.black54,
                                      fontWeight: FontWeight.w500,
                                      fontSize: 14,
                                    ),
                                  ),
                                ),
                              ),
                              Expanded(
                                child: Center(
                                  child: Text(
                                    'Alerts',
                                    style: TextStyle(
                                      color: Colors.black54,
                                      fontWeight: FontWeight.w500,
                                      fontSize: 14,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),

                      const Divider(),
                      Expanded(
                        child:
                            _notificationCount > 0
                                ? ListView(
                                  controller: controller,
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 20,
                                  ),
                                  children: [
                                    _buildNotificationItem(
                                      title: 'Event Reminder',
                                      message:
                                          'Your "Summer Wedding" event is coming up in just 1 day!',
                                      time: '10 min ago',
                                      icon: Icons.event,
                                      isUnread: true,
                                      category: 'Event',
                                      actionText: 'View Event',
                                    ),
                                    _buildNotificationItem(
                                      title: 'Weather Alert',
                                      message:
                                          'There\'s a 70% chance of rain on your upcoming event day.',
                                      time: '1 hour ago',
                                      icon: Icons.wb_cloudy,
                                      isUnread: true,
                                      category: 'Alert',
                                      actionText: 'Check Forecast',
                                    ),
                                    _buildNotificationItem(
                                      title: 'New Feature',
                                      message:
                                          'Check out our new vendor collaboration features!',
                                      time: '2 hours ago',
                                      icon: Icons.new_releases,
                                      isUnread: true,
                                      category: 'Update',
                                      actionText: 'Explore',
                                    ),
                                    _buildNotificationItem(
                                      title: 'Payment Confirmed',
                                      message:
                                          'Your payment for Venue Services has been confirmed.',
                                      time: '1 day ago',
                                      icon: Icons.payment,
                                      isUnread: false,
                                      category: 'Payment',
                                      actionText: 'View Receipt',
                                    ),
                                    _buildNotificationItem(
                                      title: 'Feedback Request',
                                      message:
                                          'Please rate your experience with our catering service.',
                                      time: '2 days ago',
                                      icon: Icons.star,
                                      isUnread: false,
                                      category: 'Feedback',
                                      actionText: 'Leave Review',
                                    ),
                                  ],
                                )
                                : _buildEmptyNotifications(),
                      ),
                    ],
                  ),
                ),
          ),
    );
  }

  Widget _buildEmptyNotifications() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.grey.shade50,
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.notifications_off_outlined,
              size: 60,
              color: Colors.grey.shade400,
            ),
          ),
          const SizedBox(height: 24),
          Text(
            'No notifications yet',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 12),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 40),
            child: Text(
              'We\'ll notify you about event updates, reminders, and special offers.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey.shade600,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Notification item widget
  Widget _buildNotificationItem({
    required String title,
    required String message,
    required String time,
    required IconData icon,
    required bool isUnread,
    required String category,
    required String actionText,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      child: Stack(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color:
                    isUnread
                        ? const Color(0xFF9D9DCC).withOpacity(0.3)
                        : Colors.grey.withOpacity(0.1),
                width: isUnread ? 1.5 : 1,
              ),
              boxShadow: [
                BoxShadow(
                  color:
                      isUnread
                          ? const Color(0xFF9D9DCC).withOpacity(0.1)
                          : Colors.grey.withOpacity(0.05),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                  spreadRadius: 0,
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        gradient:
                            isUnread
                                ? LinearGradient(
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                  colors: [
                                    const Color(0xFF9D9DCC),
                                    const Color(0xFF7575A8),
                                  ],
                                )
                                : null,
                        color: isUnread ? null : Colors.grey.shade100,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Icon(
                        icon,
                        color: isUnread ? Colors.white : Colors.grey,
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 3,
                                ),
                                decoration: BoxDecoration(
                                  color: _getCategoryColor(
                                    category,
                                  ).withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: Text(
                                  category,
                                  style: TextStyle(
                                    color: _getCategoryColor(category),
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                              const Spacer(),
                              Text(
                                time,
                                style: TextStyle(
                                  color: Colors.grey.shade500,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Text(
                            title,
                            style: TextStyle(
                              fontWeight:
                                  isUnread ? FontWeight.bold : FontWeight.w600,
                              fontSize: 16,
                              color: Colors.black87,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            message,
                            style: TextStyle(
                              color: Colors.black54,
                              fontSize: 14,
                              height: 1.4,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () {
                          // Dismiss notification
                          Navigator.pop(context);
                        },
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          foregroundColor: Colors.black54,
                          side: BorderSide(color: Colors.grey.shade300),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: const Text('Dismiss'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () {
                          // Action specific to the notification
                          Navigator.pop(context);
                        },
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          backgroundColor: const Color(0xFF9D9DCC),
                          foregroundColor: Colors.white,
                          elevation: isUnread ? 2 : 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: Text(actionText),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Unread indicator
          if (isUnread)
            Positioned(
              top: 0,
              right: 0,
              child: Container(
                width: 12,
                height: 12,
                decoration: BoxDecoration(
                  color: Colors.red,
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 2),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Color _getCategoryColor(String category) {
    switch (category.toLowerCase()) {
      case 'event':
        return const Color(0xFF9D9DCC);
      case 'alert':
        return Colors.orange;
      case 'update':
        return Colors.blue;
      case 'payment':
        return Colors.green;
      case 'feedback':
        return Colors.amber;
      default:
        return Colors.grey;
    }
  }

  Widget _buildCompactWeatherAlert(BuildContext context) {
    return Consumer<CityProvider>(
      builder: (context, cityProvider, child) {
        return StreamBuilder<List<ForecastDay>>(
          stream: weatherStream,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return Container(
                margin: const EdgeInsets.fromLTRB(20, 10, 20, 10),
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.05),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(
                          Color(0xFF9D9DCC),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    const Text(
                      'Checking weather...',
                      style: TextStyle(
                        color: Color(0xFF9D9DCC),
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              );
            }

            if (snapshot.hasError) {
              return Container(
                margin: const EdgeInsets.fromLTRB(20, 10, 20, 10),
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: Colors.orange,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.orange.withOpacity(0.3),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.warning_amber_rounded,
                      color: Colors.white,
                      size: 20,
                    ),
                    const SizedBox(width: 10),
                    const Expanded(
                      child: Text(
                        'Unable to check weather conditions',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
              );
            }

            if (snapshot.hasData) {
              final forecast = snapshot.data!;
              final hasRain = forecast.any(
                (day) =>
                    day.condition.toLowerCase().contains('rain') ||
                    day.condition.toLowerCase().contains('storm'),
              );

              final Color accentColor =
                  hasRain ? Color(0xFFD32F2F) : Color(0xFF4CAF50);
              final IconData weatherIcon =
                  hasRain ? Icons.umbrella_rounded : Icons.wb_sunny_rounded;
              final String message =
                  hasRain
                      ? 'Weather not suitable for outdoor events'
                      : 'Weather is suitable for outdoor events';

              return Container(
                margin: const EdgeInsets.fromLTRB(20, 10, 20, 10),
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: accentColor,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: accentColor.withOpacity(0.3),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    Icon(weatherIcon, color: Colors.white, size: 20),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        message,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
              );
            }
            return const SizedBox.shrink();
          },
        );
      },
    );
  }

  Widget _buildEventCountdown(BuildContext context) {
    return Container(
      height: 200,
      margin: const EdgeInsets.fromLTRB(20, 20, 20, 8),
      child:
          _isLoadingEvents
              ? Center(
                child: CircularProgressIndicator(color: Color(0xFF9D9DCC)),
              )
              : Stack(
                children: [
                  // Event container
                  PageView.builder(
                    controller: _eventPageController,
                    itemCount: _events.length,
                    physics: const BouncingScrollPhysics(),
                    pageSnapping: true,
                    onPageChanged: (index) {
                      setState(() {
                        _currentEventIndex = index;

                        // Check if the new event is a placeholder and reset timer immediately
                        final currentEvent = _events[index];
                        final eventStatus =
                            currentEvent['status'] as String? ?? '';

                        // Reset timer values for placeholder events
                        if (eventStatus == 'none' || eventStatus == 'error') {
                          days = 0;
                          hours = 0;
                          minutes = 0;
                          seconds = 0;
                        } else {
                          // For real events, calculate time immediately
                          final eventDate = currentEvent['date'] as DateTime;
                          final difference = eventDate.difference(
                            DateTime.now(),
                          );

                          if (difference.isNegative) {
                            days = 0;
                            hours = 0;
                            minutes = 0;
                            seconds = 0;
                          } else {
                            days = difference.inDays;
                            hours = difference.inHours % 24;
                            minutes = difference.inMinutes % 60;
                            seconds = difference.inSeconds % 60;
                          }
                        }
                      });
                    },
                    itemBuilder: (context, index) {
                      final currentEvent = _events[index];
                      final eventDate = currentEvent['date'] as DateTime;

                      // Calculate time difference
                      final difference = eventDate.difference(DateTime.now());
                      final daysUntil =
                          difference.isNegative ? 0 : difference.inDays;
                      final hoursUntil =
                          difference.isNegative ? 0 : difference.inHours % 24;
                      final minutesUntil =
                          difference.isNegative ? 0 : difference.inMinutes % 60;
                      final secondsUntil =
                          difference.isNegative ? 0 : difference.inSeconds % 60;

                      // Check if timer is at zero
                      final isTimerZero =
                          daysUntil == 0 &&
                          hoursUntil == 0 &&
                          minutesUntil == 0 &&
                          secondsUntil == 0;

                      final eventStatus =
                          currentEvent['status'] as String? ?? '';

                      // Calculate animation values for current page
                      final isCurrentPage = index == _currentEventIndex;

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
                          gradient: LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: _getEventCardColors(
                              eventStatus,
                              isTimerZero: isTimerZero,
                            ),
                            stops: const [0.3, 1.0],
                          ),
                          boxShadow: [
                            BoxShadow(
                              color:
                                  isTimerZero
                                      ? Colors.red.withOpacity(
                                        isCurrentPage ? 0.3 : 0.2,
                                      )
                                      : const Color(
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

                              // Close button for expired events
                              if (isTimerZero &&
                                  eventStatus != 'none' &&
                                  eventStatus != 'error')
                                Positioned(
                                  top: 8,
                                  right: 8,
                                  child: GestureDetector(
                                    onTap: () {
                                      // Immediately remove from local list for responsive UI
                                      setState(() {
                                        // Create a new list without the current event
                                        _events = List.from(_events)
                                          ..removeAt(_currentEventIndex);

                                        // If the list is now empty, add a placeholder event
                                        if (_events.isEmpty) {
                                          _events.add({
                                            'title': 'No upcoming events',
                                            'date': DateTime.now(),
                                            'eventType': 'None',
                                            'id': 'placeholder',
                                            'status': 'none',
                                          });
                                        }

                                        // Reset the page controller to avoid index out of range
                                        _currentEventIndex =
                                            _currentEventIndex >= _events.length
                                                ? _events.length - 1
                                                : _currentEventIndex;
                                      });

                                      // Also update the database
                                      if (currentEvent['id'] != null &&
                                          currentEvent['id'] != 'placeholder' &&
                                          currentEvent['id'] != 'error') {
                                        final portfolioService =
                                            PortfolioService();
                                        portfolioService
                                            .markResponseAsCompleted(
                                              currentEvent['id'],
                                            )
                                            .then((_) {
                                              // Show a confirmation snackbar
                                              ScaffoldMessenger.of(
                                                context,
                                              ).showSnackBar(
                                                const SnackBar(
                                                  content: Text(
                                                    'Event marked as complete',
                                                  ),
                                                  backgroundColor: Colors.green,
                                                  duration: Duration(
                                                    seconds: 2,
                                                  ),
                                                ),
                                              );
                                            });
                                      }
                                    },
                                    child: Container(
                                      padding: const EdgeInsets.all(6),
                                      decoration: BoxDecoration(
                                        color: Colors.white.withOpacity(0.3),
                                        shape: BoxShape.circle,
                                      ),
                                      child: const Icon(
                                        Icons.close,
                                        color: Colors.white,
                                        size: 18,
                                      ),
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
                                            color: Colors.white.withOpacity(
                                              0.2,
                                            ),
                                            borderRadius: BorderRadius.circular(
                                              14,
                                            ),
                                            boxShadow: [
                                              BoxShadow(
                                                color: Colors.black.withOpacity(
                                                  0.1,
                                                ),
                                                blurRadius: 4,
                                                offset: const Offset(0, 2),
                                              ),
                                            ],
                                          ),
                                          child: Icon(
                                            isTimerZero
                                                ? Icons.access_time_filled
                                                : Icons.event,
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
                                              Row(
                                                children: [
                                                  Text(
                                                    currentEvent['eventType'] ??
                                                        'Upcoming Event',
                                                    style: const TextStyle(
                                                      color: Colors.white,
                                                      fontSize: 12,
                                                      fontWeight:
                                                          FontWeight.w500,
                                                    ),
                                                  ),
                                                ],
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
                                    const SizedBox(height: 8),
                                    // Remove date display container that's causing overflow
                                    const SizedBox(height: 12),
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
                  if (_events.length > 1)
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
                                      duration: const Duration(
                                        milliseconds: 200,
                                      ),
                                      padding: const EdgeInsets.all(8),
                                      decoration: BoxDecoration(
                                        color: Colors.grey.shade400.withOpacity(
                                          0.3,
                                        ),
                                        shape: BoxShape.circle,
                                        boxShadow: [
                                          BoxShadow(
                                            color: Colors.black.withOpacity(
                                              0.1,
                                            ),
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
                  if (_events.length > 1)
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
                                      duration: const Duration(
                                        milliseconds: 200,
                                      ),
                                      padding: const EdgeInsets.all(8),
                                      decoration: BoxDecoration(
                                        color: Colors.grey.shade400.withOpacity(
                                          0.3,
                                        ),
                                        shape: BoxShape.circle,
                                        boxShadow: [
                                          BoxShadow(
                                            color: Colors.black.withOpacity(
                                              0.1,
                                            ),
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

                  // Page indicator - only show if multiple events
                  if (_events.length > 1)
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
                              child: Container(
                                width: _currentEventIndex == index ? 18 : 8,
                                height: 8,
                                margin: const EdgeInsets.symmetric(
                                  horizontal: 4,
                                ),
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(12),
                                  color:
                                      _currentEventIndex == index
                                          ? Colors.white
                                          : Colors.white.withOpacity(0.4),
                                  boxShadow:
                                      _currentEventIndex == index
                                          ? [
                                            BoxShadow(
                                              color: Colors.black.withOpacity(
                                                0.2,
                                              ),
                                              blurRadius: 2,
                                              spreadRadius: 0,
                                            ),
                                          ]
                                          : null,
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

  // Helper method to get gradient colors based on event status
  List<Color> _getEventCardColors(String status, {bool isTimerZero = false}) {
    // If timer is at 00:00:00:00, return red gradient regardless of status
    if (isTimerZero) {
      return [
        Colors.red.shade400,
        Colors.red.shade700,
      ]; // Red gradient for expired events
    } else if (status.toLowerCase() == 'error') {
      return [Colors.grey.shade400, Colors.grey.shade600]; // Grey for error
    } else {
      return [
        const Color(0xFF9D9DCC),
        const Color(0xFF7575A8),
      ]; // Default purple for all events
    }
  }

  Widget _buildModernCountdownTimer({
    required int days,
    required int hours,
    required int minutes,
    required int seconds,
  }) {
    // Check if timer is at zero
    final bool isTimerZero =
        days == 0 && hours == 0 && minutes == 0 && seconds == 0;

    // If timer is zero, show a special message instead
    if (isTimerZero) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 15, horizontal: 5),
        decoration: BoxDecoration(
          color: Colors.black.withOpacity(0.25),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.red.withOpacity(0.3), width: 1),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.timer_off, color: Colors.white, size: 24),
            const SizedBox(width: 8),
            const Text(
              'EVENT TIME EXPIRED',
              style: TextStyle(
                color: Colors.white,
                fontFamily: 'Roboto',
                fontWeight: FontWeight.w700,
                fontSize: 18,
                letterSpacing: 1.0,
              ),
            ),
          ],
        ),
      );
    }

    // Ensure values are properly formatted with leading zeros
    final daysStr = days.toString().padLeft(2, '0');
    final hoursStr = hours.toString().padLeft(2, '0');
    final minutesStr = minutes.toString().padLeft(2, '0');
    final secondsStr = seconds.toString().padLeft(2, '0');

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
          _buildGradientTimeUnit(daysStr, 'DAYS'),
          _buildTimeSeparator(),
          _buildGradientTimeUnit(hoursStr, 'HRS'),
          _buildTimeSeparator(),
          _buildGradientTimeUnit(minutesStr, 'MIN'),
          _buildTimeSeparator(),
          _buildGradientTimeUnit(secondsStr, 'SEC'),
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
            color: Colors.black.withOpacity(
              0.3,
            ), // Darker background for better visibility
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

  Widget _buildMenuGrid(BuildContext context) {
    final String clientId = _auth.currentUser?.uid ?? '';
    final String clientName =
        _auth.currentUser?.email?.split('@')[0] ?? 'Client';

    // Define menu items for a more structured approach
    final List<Map<String, dynamic>> menuItems = [
      {
        'title': 'Search\nOrganizer',
        'icon': Icons.search,
        'color': const Color(0xFF9D9DCC),
        'onTap': () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder:
                  (context) => OrganizerSearchScreen(
                    clientId: clientId,
                    clientName: clientName,
                  ),
            ),
          );
        },
      },
      {
        'title': 'Order\nHistory',
        'icon': Icons.history,
        'color': const Color(0xFF9D9DCC),
        'onTap': () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => OrderHistoryScreen()),
          );
        },
      },
      {
        'title': 'Weather\nForecast',
        'icon': Icons.cloud,
        'color': const Color(0xFF9D9DCC),
        'onTap': () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder:
                  (context) => const WeatherScreen(isInBottomNavBar: false),
            ),
          );
        },
      },
      {
        'title': 'Leave\nFeedback',
        'icon': Icons.star,
        'color': const Color(0xFF9D9DCC),
        'onTap': () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder:
                  (context) => const FeedbackScreen(isInBottomNavBar: false),
            ),
          );
        },
      },
    ];

    // Initialize card animations if not already created
    if (_menuCardAnimations.isEmpty && menuItems.isNotEmpty) {
      for (int i = 0; i < menuItems.length; i++) {
        // Create staggered animations with different start delays and more overlap
        final startInterval =
            0.1 *
            i; // 0.0, 0.1, 0.2, 0.3 - reduced from 0.15 for smoother transition
        final endInterval =
            0.1 * i +
            0.9; // 0.9, 1.0, 1.1, 1.2 - increased to 0.9 for longer fade

        _menuCardAnimations.add(
          Tween<double>(begin: 0.0, end: 1.0).animate(
            CurvedAnimation(
              parent: _menuAnimController,
              curve: Interval(
                startInterval,
                endInterval > 1.0 ? 1.0 : endInterval,
                curve:
                    Curves
                        .easeOutQuart, // Changed from easeOutCubic for smoother motion
              ),
            ),
          ),
        );
      }
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
      child: GridView.builder(
        physics: const NeverScrollableScrollPhysics(),
        shrinkWrap: true,
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          childAspectRatio: 0.9,
          crossAxisSpacing: 16,
          mainAxisSpacing: 16,
        ),
        itemCount: menuItems.length,
        itemBuilder: (context, index) {
          final item = menuItems[index];

          // Apply animation to each card with its own controller
          return AnimatedBuilder(
            animation:
                _menuCardAnimations.isNotEmpty
                    ? _menuCardAnimations[index]
                    : _menuAnimController,
            builder: (context, child) {
              return Transform.translate(
                offset: Offset(
                  0,
                  15 *
                      (1 -
                          (_menuCardAnimations
                                  .isNotEmpty // Reduced from 20 for subtler movement
                              ? _menuCardAnimations[index].value
                              : _menuAnimController.value)),
                ),
                child: Opacity(
                  opacity:
                      _menuCardAnimations.isNotEmpty
                          ? _menuCardAnimations[index].value
                          : _menuAnimController.value,
                  child: child,
                ),
              );
            },
            child: _buildModernMenuCard(
              context,
              title: item['title'],
              icon: item['icon'],
              color: item['color'],
              onTap: item['onTap'],
              index: index,
            ),
          );
        },
      ),
    );
  }

  Widget _buildModernMenuCard(
    BuildContext context, {
    required String title,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
    required int index,
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
                          colors: [color, color.withOpacity(0.8)],
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
                                colors: [color, color.withOpacity(0.3)],
                              ),
                              borderRadius: BorderRadius.circular(3),
                            ),
                          ),
                        ),
                        const SizedBox(width: 40),
                      ],
                    ),
                  ],
                ),
              ),

              // Arrow indicator without animation
              Positioned(
                bottom: 20,
                right: 16,
                child: Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(Icons.arrow_forward_ios, color: color, size: 12),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // New widget for pattern background instead of blobs
  Widget _buildPatternBackground() {
    return CustomPaint(painter: PatternPainter());
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
                                    const SnackBar(
                                      content: Text(
                                        "Support ticket sent!",
                                        style: TextStyle(
                                          color: Colors.white,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                      backgroundColor: Colors.green,
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

  // Clear any potential cross-contamination between organizer and client images
  Future<void> _clearCrossProfileImages() async {
    try {
      final prefs = await SharedPreferences.getInstance();

      // Add this check to make sure we're enforcing the client role
      // Store user role in SharedPreferences to ensure consistency
      await prefs.setString('user_role', 'client');

      // Check if organizer key exists and remove it to prevent contamination
      if (prefs.containsKey('organizer_profile_image_path')) {
        print(
          'ClientHomeScreen: Found organizer key in client screen, removing it',
        );
        await prefs.remove('organizer_profile_image_path');
      }

      // Also verify the client image path points to an existing file
      final clientPath = prefs.getString(_profileImagePathKey);
      if (clientPath != null) {
        final file = File(clientPath);
        if (!await file.exists()) {
          print(
            'ClientHomeScreen: Client image file does not exist, removing path',
          );
          await prefs.remove(_profileImagePathKey);
        }
      }
    } catch (e) {
      print('ClientHomeScreen: Error clearing cross profile images: $e');
    }
  }

  // Load profile image from shared preferences
  Future<void> _loadProfileImage() async {
    try {
      final prefs = await SharedPreferences.getInstance();

      // Ensure we're using the right user role
      final userRole = prefs.getString('user_role');
      if (userRole != null && userRole != 'client') {
        print(
          'ClientHomeScreen: User role mismatch in SharedPreferences: $userRole',
        );
        // Force client role for this screen
        await prefs.setString('user_role', 'client');
      }

      // Try to get from SharedPreferences first
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
              if (userData['clientProfileImagePath'] != null) {
                imagePath = userData['clientProfileImagePath'] as String;
                print(
                  'ClientHomeScreen: Found profile image path in Firestore: $imagePath',
                );

                // Save to SharedPreferences for future access
                if (imagePath != null) {
                  await prefs.setString(_profileImagePathKey, imagePath);
                }
              }
            }
          } catch (e) {
            print(
              'ClientHomeScreen: Error retrieving profile image from Firestore: $e',
            );
          }
        }
      }

      print(
        'ClientHomeScreen: Loading profile image with key: $_profileImagePathKey',
      );
      print('ClientHomeScreen: Found image path: $imagePath');

      // Always reset the state first to avoid stale data
      setState(() {
        _profileImageLoaded = false;
        _profileImage = null;
        _profileImagePath = null;
      });

      if (imagePath != null) {
        final file = File(imagePath);
        final exists = await file.exists();
        print('ClientHomeScreen: File exists: $exists at path: $imagePath');

        if (exists) {
          setState(() {
            _profileImage = file;
            _profileImagePath = imagePath;
            _profileImageLoaded = true;
          });
          print('ClientHomeScreen: Loaded profile image from: $imagePath');
        } else {
          // File doesn't exist but path is stored
          print(
            'ClientHomeScreen: Profile image file not found, removing path',
          );
          await prefs.remove(_profileImagePathKey);

          // Also remove from Firestore if possible
          final user = _auth.currentUser;
          if (user != null) {
            try {
              await FirebaseFirestore.instance
                  .collection('users')
                  .doc(user.uid)
                  .update({'clientProfileImagePath': FieldValue.delete()});
              print(
                'ClientHomeScreen: Removed invalid image path from Firestore',
              );
            } catch (e) {
              print(
                'ClientHomeScreen: Error removing invalid path from Firestore: $e',
              );
            }
          }

          setState(() {
            _profileImage = null;
            _profileImagePath = null;
            _profileImageLoaded = true;
          });
          print('ClientHomeScreen: Profile image set to null (file not found)');
        }
      } else {
        // No image path stored
        setState(() {
          _profileImage = null;
          _profileImagePath = null;
          _profileImageLoaded = true;
        });
        print('ClientHomeScreen: No profile image path stored');
      }
    } catch (e) {
      print('ClientHomeScreen: Error loading profile image: $e');
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
      print('ClientHomeScreen: Saving profile image path: $imagePath');
      final prefs = await SharedPreferences.getInstance();

      // Ensure we're not using the organizer key
      if (prefs.containsKey('organizer_profile_image_path')) {
        await prefs.remove('organizer_profile_image_path');
        print('ClientHomeScreen: Removed organizer key for safety');
      }

      await prefs.setString(_profileImagePathKey, imagePath);

      // Verify we've saved correctly
      final savedPath = prefs.getString(_profileImagePathKey);
      print('ClientHomeScreen: Verified saved path: $savedPath');
    } catch (e) {
      print('ClientHomeScreen: Error saving profile image path: $e');
      // Show a more specific error message
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Could not save profile settings, but your image was updated.',
          ),
          backgroundColor: Colors.orange,
        ),
      );
    }
  }

  // Function to pick image
  Future<void> _pickImage(ImageSource source) async {
    try {
      print('ClientHomeScreen: Picking image from source: $source');
      final XFile? pickedImage = await _imagePicker.pickImage(
        source: source,
        maxWidth: 400,
        maxHeight: 400,
        imageQuality: 85,
      );

      if (pickedImage != null) {
        print('ClientHomeScreen: Image picked: ${pickedImage.path}');

        // Copy the image to app directory for persistence
        final appDir = await getApplicationDocumentsDirectory();
        final userId = _auth.currentUser?.uid ?? 'unknown';
        final fileName =
            'client_${userId}_profile_${DateTime.now().millisecondsSinceEpoch}.jpg';
        final savedImagePath = path.join(appDir.path, fileName);
        print('ClientHomeScreen: Saving image to: $savedImagePath');

        // Delete existing profile image if any
        if (_profileImage != null && await _profileImage!.exists()) {
          await _profileImage!.delete();
          print('ClientHomeScreen: Deleted existing profile image');
        }

        // Copy the image
        final File savedImage = await File(
          pickedImage.path,
        ).copy(savedImagePath);
        print('ClientHomeScreen: Image copied successfully');

        setState(() {
          _profileImage = savedImage;
          _profileImagePath = savedImagePath;
          _profileImageLoaded = true;
          print('ClientHomeScreen: Updated state with new image');
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
        print('ClientHomeScreen: No image picked');
      }
    } catch (e) {
      print('ClientHomeScreen: Error picking image: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error picking image: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  // Delete profile image
  Future<void> _deleteProfileImage() async {
    try {
      print('ClientHomeScreen: Deleting profile image');
      // Remove image path from shared preferences
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_profileImagePathKey);
      print(
        'ClientHomeScreen: Removed profile image path from SharedPreferences',
      );

      // Delete the file if it exists
      if (_profileImage != null && await _profileImage!.exists()) {
        await _profileImage!.delete();
        print('ClientHomeScreen: Deleted profile image file');
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
      print('ClientHomeScreen: Error deleting profile image: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Could not remove profile picture: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }
}

// Custom Painter for the background pattern
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

// Custom Painter for the countdown card pattern
class CountdownPatternPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint =
        Paint()
          ..color = Colors.white.withOpacity(0.05)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1;

    // Draw wave patterns
    final path = Path();

    // First wave pattern
    for (int i = 0; i < size.width + 20; i += 20) {
      path.moveTo(i.toDouble(), 0);
      path.quadraticBezierTo(i + 10, 10, i + 20, 0);
    }

    canvas.drawPath(path, paint);

    // Second wave pattern (bottom)
    final bottomPath = Path();
    for (int i = 0; i < size.width + 20; i += 15) {
      bottomPath.moveTo(i.toDouble(), size.height);
      bottomPath.quadraticBezierTo(
        i + 7.5,
        size.height - 8,
        i + 15,
        size.height,
      );
    }

    canvas.drawPath(bottomPath, paint);

    // Draw a few diagonal lines
    for (int i = 0; i < 5; i++) {
      canvas.drawLine(
        Offset(size.width - 40 - (i * 20), 0),
        Offset(size.width, 40 + (i * 20)),
        paint,
      );
    }

    // Draw grid pattern on top-right
    final rectSize = 8.0;
    for (int i = 0; i < 5; i++) {
      for (int j = 0; j < 5; j++) {
        if ((i + j) % 2 == 0) {
          canvas.drawRect(
            Rect.fromLTWH(
              size.width - 100 + (i * rectSize),
              10 + (j * rectSize),
              rectSize - 2,
              rectSize - 2,
            ),
            paint,
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

// Custom Painter for menu card patterns
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

// Add this class at the end of the file with the other painter classes
class WeatherAlertPatternPainter extends CustomPainter {
  final Color color;

  WeatherAlertPatternPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint =
        Paint()
          ..color = color.withOpacity(0.03)
          ..style = PaintingStyle.fill;

    // Draw subtle weather-related patterns

    // Cloud-like shapes
    final cloudPath = Path();
    cloudPath.moveTo(size.width * 0.8, size.height * 0.2);
    cloudPath.quadraticBezierTo(
      size.width * 0.85,
      size.height * 0.1,
      size.width * 0.9,
      size.height * 0.2,
    );
    cloudPath.quadraticBezierTo(
      size.width * 0.95,
      size.height * 0.2,
      size.width,
      size.height * 0.15,
    );
    cloudPath.lineTo(size.width, 0);
    cloudPath.lineTo(size.width * 0.7, 0);
    cloudPath.close();

    canvas.drawPath(cloudPath, paint);

    // Rain or sun rays (depending on weather)
    if (color == Colors.red) {
      // Rain drops for rainy weather
      for (int i = 0; i < 5; i++) {
        final dropPath = Path();
        dropPath.moveTo(
          size.width * 0.1 + (i * size.width * 0.15),
          size.height * 0.7,
        );
        dropPath.quadraticBezierTo(
          size.width * 0.05 + (i * size.width * 0.15),
          size.height,
          size.width * 0.1 + (i * size.width * 0.15),
          size.height,
        );
        dropPath.quadraticBezierTo(
          size.width * 0.15 + (i * size.width * 0.15),
          size.height,
          size.width * 0.1 + (i * size.width * 0.15),
          size.height * 0.7,
        );
        dropPath.close();

        canvas.drawPath(dropPath, paint..color = color.withOpacity(0.02));
      }
    } else {
      // Sun rays for sunny weather
      for (int i = 0; i < 6; i++) {
        final angle = (i * 60) * (3.14159 / 180);
        canvas.drawLine(
          Offset(size.width * 0.1, size.height * 0.5),
          Offset(
            size.width * 0.1 + cos(angle) * size.width * 0.15,
            size.height * 0.5 + sin(angle) * size.width * 0.15,
          ),
          paint..color = color.withOpacity(0.04),
        );
      }
    }

    // Small dots pattern
    for (int i = 0; i < 8; i++) {
      for (int j = 0; j < 3; j++) {
        if ((i + j) % 2 == 0) {
          canvas.drawCircle(
            Offset(
              size.width * 0.1 + (i * size.width * 0.1),
              size.height * 0.75 + (j * size.height * 0.1),
            ),
            1,
            paint..color = color.withOpacity(0.03),
          );
        }
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
