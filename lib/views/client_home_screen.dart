import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../controllers/client_controller.dart';
import 'dart:ui';
import './weather_screen.dart';
import './feedback_screen.dart';
import './order_history_screen.dart';
import 'package:firebase_auth/firebase_auth.dart';
import './login_view.dart';
import './organizer_search_screen.dart';
import 'package:intl/intl.dart';
import '../services/weather_service.dart';
import '../models/weather_model.dart';
import '../providers/city_provider.dart';
import 'dart:math';
import '../constants/app_colors.dart';

class ClientHomeScreen extends StatefulWidget {
  const ClientHomeScreen({super.key});

  @override
  State<ClientHomeScreen> createState() => _ClientHomeScreenState();
}

class _ClientHomeScreenState extends State<ClientHomeScreen>
    with SingleTickerProviderStateMixin {
  // Static timer values (to be replaced with Firestore later)
  int days = 0;
  int hours = 1;
  int minutes = 32;
  int seconds = 6;
  late Timer _timer;
  String? _currentCity;
  late Stream<List<ForecastDay>> weatherStream;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;

  // Add notification badge counter
  int _notificationCount = 3;
  bool _showNotificationBadge = true;

  // Add a scaffold key to access the drawer
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  @override
  void initState() {
    super.initState();
    _initializeWeatherStream();
    startTimer();

    // Animation setup
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeOut),
    );

    _animationController.forward();

    // Print the current user ID for debugging
    print('Current user ID: ${_auth.currentUser?.uid}');
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

  void _initializeWeatherStream() {
    weatherStream = Stream.fromFuture(
      WeatherService().getFiveDayForecast('Islamabad'),
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
                  child: FadeTransition(
                    opacity: _fadeAnimation,
                    child: ListView(
                      padding: EdgeInsets.zero,
                      children: [
                        _buildCompactWeatherAlert(context),
                        _buildEventCountdown(context),
                        const SizedBox(height: 12),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 20.0),
                          child: Row(
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
                        const SizedBox(height: 8),
                        _buildMenuGrid(context),
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

    return Drawer(
      child: Container(
        color: Colors.white,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            UserAccountsDrawerHeader(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [Color(0xFF9D9DCC), Color(0xFF7575A8)],
                ),
              ),
              currentAccountPicture: CircleAvatar(
                backgroundColor: Colors.white,
                child: Text(
                  avatarText,
                  style: const TextStyle(
                    color: Color(0xFF9D9DCC),
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              accountName: Text(
                displayName,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                ),
              ),
              accountEmail: Text(
                email,
                style: const TextStyle(color: Colors.white, fontSize: 14),
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
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Text(
                                  'Upcoming Event',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 14,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
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
          return _buildModernMenuCard(
            context,
            title: item['title'],
            icon: item['icon'],
            color: item['color'],
            onTap: item['onTap'],
            index: index,
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
                                    SnackBar(
                                      content: Text("Support ticket sent!"),
                                      backgroundColor: Color(0xFF9D9DCC),
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
