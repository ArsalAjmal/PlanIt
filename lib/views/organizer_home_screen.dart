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
import 'package:flutter/widgets.dart';

class OrganizerHomeScreen extends StatefulWidget {
  const OrganizerHomeScreen({super.key});

  // Route observer for detecting navigation
  static final RouteObserver<PageRoute> routeObserver =
      RouteObserver<PageRoute>();

  @override
  State<OrganizerHomeScreen> createState() => _OrganizerHomeScreenState();
}

class _OrganizerHomeScreenState extends State<OrganizerHomeScreen>
    with TickerProviderStateMixin, WidgetsBindingObserver, RouteAware {
  // Controller for pending orders
  final PendingOrdersController _pendingOrdersController =
      PendingOrdersController();
  bool _isLoading = true;
  bool _isLoadingEvents = true;

  // Add timer values
  int days = 0;
  int hours = 0;
  int minutes = 0;
  int seconds = 0;
  Timer? _timer;

  // Add a scaffold key to access the drawer
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Animation controllers for staggered animations
  late AnimationController _notificationAnimController;
  late AnimationController _countdownAnimController;
  late AnimationController _sectionTitleAnimController;
  late AnimationController _pendingOrdersAnimController;
  late AnimationController _reviewsTodoAnimController;

  // Animations
  late Animation<double> _notificationFadeAnim;
  late Animation<double> _countdownFadeAnim;
  late Animation<double> _sectionTitleFadeAnim;
  late Animation<Offset> _sectionTitleSlideAnim;
  late Animation<double> _pendingOrdersFadeAnim;
  late Animation<Offset> _pendingOrdersSlideAnim;
  late Animation<double> _reviewsCardAnim;
  late Animation<double> _todoCardAnim;

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
  List<Map<String, dynamic>> _events = [];

  @override
  void initState() {
    super.initState();
    // Register for lifecycle changes
    WidgetsBinding.instance.addObserver(this);

    _loadPendingOrders();
    _loadOrganizerEvents();
    _debugCheckAllResponses();
    _clearCrossProfileImages();
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
    _notificationAnimController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    );

    _countdownAnimController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );

    _sectionTitleAnimController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    );

    _pendingOrdersAnimController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    );

    _reviewsTodoAnimController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    );
  }

  // Setup animations with proper curves
  void _setupAnimations() {
    // Set up the animations with gentler curves
    _notificationFadeAnim = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _notificationAnimController,
        curve: Curves.easeInOut,
      ),
    );

    _countdownFadeAnim = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _countdownAnimController,
        curve: Curves.easeInOut,
      ),
    );

    _sectionTitleFadeAnim = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _sectionTitleAnimController,
        curve: Curves.easeInOut,
      ),
    );

    _sectionTitleSlideAnim = Tween<Offset>(
      begin: const Offset(-0.1, 0.0), // Subtler slide
      end: Offset.zero,
    ).animate(
      CurvedAnimation(
        parent: _sectionTitleAnimController,
        curve: Curves.easeOutQuart,
      ),
    );

    _pendingOrdersFadeAnim = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _pendingOrdersAnimController,
        curve: Curves.easeInOut,
      ),
    );

    _pendingOrdersSlideAnim = Tween<Offset>(
      begin: const Offset(0.0, 0.08), // Subtle slide up
      end: Offset.zero,
    ).animate(
      CurvedAnimation(
        parent: _pendingOrdersAnimController,
        curve: Curves.easeOutQuart,
      ),
    );

    // Reviews card animation - fade in and scale
    _reviewsCardAnim = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _reviewsTodoAnimController,
        curve: const Interval(0.0, 0.7, curve: Curves.easeOutQuart),
      ),
    );

    // Todo card animation - fade in and scale with delay
    _todoCardAnim = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _reviewsTodoAnimController,
        curve: const Interval(0.3, 1.0, curve: Curves.easeOutQuart),
      ),
    );
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
    _notificationAnimController.reset();
    _countdownAnimController.reset();
    _sectionTitleAnimController.reset();
    _pendingOrdersAnimController.reset();
    _reviewsTodoAnimController.reset();

    Future.delayed(const Duration(milliseconds: 300), () {
      if (mounted) _notificationAnimController.forward();
    });

    Future.delayed(const Duration(milliseconds: 700), () {
      if (mounted) _countdownAnimController.forward();
    });

    Future.delayed(const Duration(milliseconds: 1100), () {
      if (mounted) _sectionTitleAnimController.forward();
    });

    Future.delayed(const Duration(milliseconds: 1400), () {
      if (mounted) _pendingOrdersAnimController.forward();
    });

    Future.delayed(const Duration(milliseconds: 1700), () {
      if (mounted) _reviewsTodoAnimController.forward();
    });
  }

  // Clean disposal of animation controllers
  void _disposeAnimationControllers() {
    try {
      // Check if the controllers have been initialized
      if (this.mounted) {
        // Only dispose if the controller exists and is not already disposed
        if (_notificationAnimController.isAnimating)
          _notificationAnimController.dispose();
        if (_countdownAnimController.isAnimating)
          _countdownAnimController.dispose();
        if (_sectionTitleAnimController.isAnimating)
          _sectionTitleAnimController.dispose();
        if (_pendingOrdersAnimController.isAnimating)
          _pendingOrdersAnimController.dispose();
        if (_reviewsTodoAnimController.isAnimating)
          _reviewsTodoAnimController.dispose();
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
    OrganizerHomeScreen.routeObserver.subscribe(
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
    OrganizerHomeScreen.routeObserver.unsubscribe(this);

    // Unregister from lifecycle changes
    WidgetsBinding.instance.removeObserver(this);

    // Dispose animation controllers
    _disposeAnimationControllers();

    _eventPageController.dispose();
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

      // Restart animations when app comes back to foreground
      _startAnimations();
    }
  }

  // Called when returning to this route
  @override
  void didPopNext() {
    super.didPopNext();
    print('OrganizerHomeScreen: Returned to screen, restarting animations');
    // Restart animations when returning to this screen
    _startAnimations();
  }

  // Load organizer events from Firebase
  Future<void> _loadOrganizerEvents() async {
    print('OrganizerHomeScreen: Starting to load events...');

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
        print('OrganizerHomeScreen: User not logged in');
        setState(() {
          _isLoadingEvents = false;
        });
        return;
      }

      print(
        'OrganizerHomeScreen: Loading events for organizer ID: ${user.uid}',
      );

      // Fetch responses where the organizer is the current user
      final snapshot =
          await _firestore
              .collection('responses')
              .where('organizerId', isEqualTo: user.uid)
              // Include both accepted and pending events with no status filter
              .orderBy('eventDate')
              .get();

      print(
        'OrganizerHomeScreen: Found ${snapshot.docs.length} total responses',
      );

      final List<Map<String, dynamic>> loadedEvents = [];

      // Debug: Compare the user.uid with the organizer IDs in the responses
      print('OrganizerHomeScreen: Current user (organizer) ID: ${user.uid}');

      // Print all responses for debugging
      for (var doc in snapshot.docs) {
        final data = doc.data();
        print(
          'OrganizerHomeScreen: Response ID: ${doc.id}, Status: ${data['status']}, Organizer ID: ${data['organizerId']}',
        );
      }

      if (snapshot.docs.isNotEmpty) {
        for (var doc in snapshot.docs) {
          final responseData = doc.data();
          final eventDate = DateTime.parse(responseData['eventDate']);
          final status =
              (responseData['status'] as String? ?? '').toLowerCase();

          // Only include future events with accepted or pending status
          // Explicitly exclude events with 'completed' status
          if (eventDate.isAfter(DateTime.now()) &&
              (status == 'accepted' || status == 'pending') &&
              status != 'completed') {
            loadedEvents.add({
              'title': responseData['eventName'],
              'date': eventDate,
              'eventType': responseData['eventType'],
              'id': responseData['id'],
              'status': status,
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
        print(
          'OrganizerHomeScreen: No future events found, adding placeholder',
        );
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
      print('OrganizerHomeScreen: Error loading events: $e');
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
      print('OrganizerHomeScreen: No events to start timer for');
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

    // For real events, calculate time immediately before starting the timer
    final eventDate = currentEvent['date'] as DateTime;
    final initialDifference = eventDate.difference(DateTime.now());

    // Debug the initial time calculation
    print('OrganizerHomeScreen: Initial time calculation:');
    print('- Event date: $eventDate');
    print('- Current time: ${DateTime.now()}');
    print('- Total hours: ${initialDifference.inHours}');
    print('- Days: ${initialDifference.inDays}');
    print('- Hours after days: ${initialDifference.inHours % 24}');

    if (!initialDifference.isNegative) {
      setState(() {
        days = initialDifference.inDays;
        hours = initialDifference.inHours % 24;
        minutes = initialDifference.inMinutes % 60;
        seconds = initialDifference.inSeconds % 60;

        // Debug log the values we're setting
        print(
          'OrganizerHomeScreen: Setting timer values - Days: $days, Hours: $hours, Minutes: $minutes, Seconds: $seconds',
        );
      });
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

          // Add debug logging every minute to check the hours calculation
          if (seconds == 0) {
            print(
              'OrganizerHomeScreen: Timer update - Days: $days, Hours: $hours, Minutes: $minutes, Seconds: $seconds',
            );
          }
        }
      });
    });
  }

  Future<void> _loadPendingOrders() async {
    print('OrganizerHomeScreen: Starting to load pending orders...');
    setState(() {
      _isLoading = true;
    });

    // Get current user ID from Firebase Auth
    final user = _auth.currentUser;

    if (user != null) {
      print('OrganizerHomeScreen: Current user ID: ${user.uid}');

      // First do a direct check of the responses collection to verify data
      try {
        final snapshot = await _firestore.collection('responses').get();

        print('Total responses in database: ${snapshot.docs.length}');

        // Print all responses to see what's available
        print('======= RESPONSE CHECK =======');
        for (var doc in snapshot.docs) {
          final data = doc.data();
          print('Response: ${doc.id}');
          print('- Status: ${data['status']}');
          print('- Organizer ID: ${data['organizerId']}');
          print('- Client ID: ${data['clientId']}');
          print('- Event Name: ${data['eventName']}');
          print('- Created At: ${data['createdAt']}');
          print('-----------------------------------');
        }
        print('======= END RESPONSE CHECK =======');
      } catch (e) {
        print('Error in direct database check: $e');
      }

      // Initialize the stream first for real-time updates
      _pendingOrdersController.initPendingOrdersStream(user.uid);
      // Then fetch orders to populate the initial list
      await _pendingOrdersController.fetchPendingOrders(user.uid);

      // Check how many orders were loaded
      print(
        'OrganizerHomeScreen: Loaded ${_pendingOrdersController.pendingOrders.length} pending orders',
      );
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
                        Column(
                          children: [
                            // Notification with fade-in animation
                            FadeTransition(
                              opacity: _notificationFadeAnim,
                              child: _buildCompactCollaborationNotification(
                                context,
                              ),
                            ),

                            // Countdown with fade-in animation
                            FadeTransition(
                              opacity: _countdownFadeAnim,
                              child: _buildEventCountdown(context),
                            ),

                            // Services header with combined slide and fade animations
                            FadeTransition(
                              opacity: _sectionTitleFadeAnim,
                              child: SlideTransition(
                                position: _sectionTitleSlideAnim,
                                child: Padding(
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
                              ),
                            ),
                            const SizedBox(height: 8),

                            // The cards with staggered animations
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
                                      child: FadeTransition(
                                        opacity: _pendingOrdersFadeAnim,
                                        child: SlideTransition(
                                          position: _pendingOrdersSlideAnim,
                                          child: _buildPendingOrdersCard(),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    // Right side - Two smaller cards with staggered animation
                                    Expanded(
                                      flex: 2,
                                      child: Column(
                                        children: [
                                          // Reviews card
                                          Expanded(
                                            child: AnimatedBuilder(
                                              animation: _reviewsCardAnim,
                                              builder: (context, child) {
                                                return Opacity(
                                                  opacity:
                                                      _reviewsCardAnim.value,
                                                  child: Transform.scale(
                                                    scale:
                                                        0.95 +
                                                        (_reviewsCardAnim
                                                                .value *
                                                            0.05),
                                                    child: child,
                                                  ),
                                                );
                                              },
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
                                          ),
                                          const SizedBox(height: 12),
                                          // Todo card with delayed animation
                                          Expanded(
                                            child: AnimatedBuilder(
                                              animation: _todoCardAnim,
                                              builder: (context, child) {
                                                return Opacity(
                                                  opacity: _todoCardAnim.value,
                                                  child: Transform.scale(
                                                    scale:
                                                        0.95 +
                                                        (_todoCardAnim.value *
                                                            0.05),
                                                    child: child,
                                                  ),
                                                );
                                              },
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
              _loadOrganizerEvents(); // Also reload events when an order is completed
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

                          // Debug logs for tracking hours calculation
                          print(
                            'OrganizerHomeScreen: onPageChanged time calculation:',
                          );
                          print('- Event date: $eventDate');
                          print('- Current time: ${DateTime.now()}');
                          print('- Total hours: ${difference.inHours}');
                          print('- Days: ${difference.inDays}');
                          print(
                            '- Hours after days: ${difference.inHours % 24}',
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

                            // Final verification of the values
                            print(
                              'OrganizerHomeScreen: Setting timer in onPageChanged - Days: $days, Hours: $hours, Minutes: $minutes, Seconds: $seconds',
                            );
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
                          currentEvent['status'] as String? ?? 'pending';

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
                                              Text(
                                                currentEvent['eventType'] ??
                                                    'Upcoming Event',
                                                style: const TextStyle(
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

    // For non-zero timers, show the regular countdown display
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
            color: Colors.black.withOpacity(0.3), // Darker background
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.18), // Stronger shadow
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
            ), // Darker background for label
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
                        // Navigate to Account screen
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
                        // Navigate to Account screen
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
                    // Removed the large SizedBox to reduce blank space
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
          IconButton(
            icon: const Icon(Icons.notifications_outlined, color: Colors.white),
            onPressed: () {
              // TODO: Implement notifications panel
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Notifications coming soon'),
                  duration: Duration(seconds: 2),
                ),
              );
            },
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
