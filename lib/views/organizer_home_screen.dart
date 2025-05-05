import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:ui';
import './login_view.dart';
import './pending_orders_screen.dart';
import './organizer_reviews_screen.dart';
import './organizer_todo_screen.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'organizer/portfolio_creation_screen.dart';
import '../controllers/pending_orders_controller.dart';
import '../models/response_model.dart';
import '../services/portfolio_service.dart';
import '../constants/app_colors.dart';
import 'organizer/my_portfolios_screen.dart';

class OrganizerHomeScreen extends StatefulWidget {
  const OrganizerHomeScreen({super.key});

  @override
  State<OrganizerHomeScreen> createState() => _OrganizerHomeScreenState();
}

class _OrganizerHomeScreenState extends State<OrganizerHomeScreen> {
  // Static timer values (to be replaced with Firestore later)
  int days = 10;
  int hours = 12;
  int minutes = 30;
  int seconds = 6;

  // Controller for pending orders
  final PendingOrdersController _pendingOrdersController =
      PendingOrdersController();
  bool _isLoading = true;

  // Add a scaffold key to access the drawer
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  final FirebaseAuth _auth = FirebaseAuth.instance;

  @override
  void initState() {
    super.initState();
    _loadPendingOrders();
    _debugCheckAllResponses();
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

  @override
  Widget build(BuildContext context) {
    // Set status bar color to match background
    SystemChrome.setSystemUIOverlayStyle(
      const SystemUiOverlayStyle(
        statusBarColor: Color(0xFFFFFDE5),
        statusBarIconBrightness: Brightness.dark,
      ),
    );

    return SafeArea(
      child: Scaffold(
        key: _scaffoldKey,
        backgroundColor: AppColors.creamBackground,
        drawer: _buildDrawer(context),
        body: Column(
          children: [
            _buildAppBar(context),
            _buildEventCountdown(context),
            _buildMenuSection(context),
          ],
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

  Widget _buildMenuSection(BuildContext context) {
    return Expanded(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Left side - Large Pending Orders card
            Expanded(flex: 3, child: _buildPendingOrdersCard()),
            const SizedBox(width: 12),
            // Right side - Two smaller cards
            Expanded(
              flex: 2,
              child: Column(
                children: [
                  Expanded(
                    child: LayoutBuilder(
                      builder: (context, constraints) {
                        return _buildMenuCard(
                          title: 'Reviews',
                          icon: Icons.star,
                          color: const Color(0xFF9D9DCC),
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder:
                                    (context) => const OrganizerReviewsScreen(),
                              ),
                            );
                          },
                          constraints: constraints,
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 12),
                  Expanded(
                    child: LayoutBuilder(
                      builder: (context, constraints) {
                        return _buildMenuCard(
                          title: 'Todo List',
                          icon: Icons.checklist_rounded,
                          color: const Color(0xFF9D9DCC),
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder:
                                    (context) => const OrganizerTodoScreen(),
                              ),
                            );
                          },
                          constraints: constraints,
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
    );
  }

  Widget _buildPendingOrdersCard() {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      color: const Color(0xFF9D9DCC),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFFDD0),
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white70),
                  ),
                  child: const Icon(
                    Icons.pending_actions,
                    size: 28,
                    color: Color(0xFF9D9DCC),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Pending Orders',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            Expanded(
              child:
                  _isLoading
                      ? const Center(
                        child: CircularProgressIndicator(color: Colors.white),
                      )
                      : StreamBuilder<List<ResponseModel>>(
                        stream: _pendingOrdersController.pendingOrdersStream,
                        builder: (context, snapshot) {
                          if (snapshot.connectionState ==
                                  ConnectionState.waiting &&
                              _pendingOrdersController.pendingOrders.isEmpty) {
                            return const Center(
                              child: CircularProgressIndicator(
                                color: Colors.white,
                              ),
                            );
                          }

                          if (snapshot.hasError) {
                            return Center(
                              child: Text(
                                'Error loading orders',
                                style: TextStyle(color: Colors.white),
                              ),
                            );
                          }

                          // Use data from stream if available, otherwise use controller's cached data
                          final pendingOrders =
                              snapshot.data ??
                              _pendingOrdersController.pendingOrders;

                          if (pendingOrders.isEmpty) {
                            return Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  const Icon(
                                    Icons.inbox,
                                    size: 48,
                                    color: Colors.white70,
                                  ),
                                  const SizedBox(height: 16),
                                  const Text(
                                    'No pending orders',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 16,
                                    ),
                                  ),
                                  const SizedBox(height: 24),
                                  ElevatedButton.icon(
                                    onPressed: _loadPendingOrders,
                                    icon: const Icon(
                                      Icons.refresh,
                                      color: Color(0xFF9D9DCC),
                                    ),
                                    label: const Text(
                                      'Refresh',
                                      style: TextStyle(
                                        color: Color(0xFF9D9DCC),
                                      ),
                                    ),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: const Color(0xFFFFFDD0),
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 16,
                                        vertical: 8,
                                      ),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(20),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            );
                          }

                          return Column(
                            children: [
                              Expanded(
                                child: ListView.builder(
                                  itemCount: pendingOrders.length,
                                  itemBuilder: (context, index) {
                                    final order = pendingOrders[index];
                                    return Card(
                                      color: Colors.white.withOpacity(0.1),
                                      margin: const EdgeInsets.only(bottom: 8),
                                      child: ListTile(
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
                                        trailing: const Icon(
                                          Icons.arrow_forward_ios,
                                          color: Colors.white,
                                          size: 16,
                                        ),
                                        onTap: () {
                                          Navigator.push(
                                            context,
                                            MaterialPageRoute(
                                              builder:
                                                  (context) =>
                                                      PendingOrdersScreen(
                                                        orderId: order.id,
                                                      ),
                                            ),
                                          ).then((result) {
                                            // If order was marked as completed, refresh the list
                                            if (result == 'ORDER_COMPLETED') {
                                              _loadPendingOrders();
                                            }
                                          });
                                        },
                                      ),
                                    );
                                  },
                                ),
                              ),
                              Padding(
                                padding: const EdgeInsets.only(top: 8.0),
                                child: TextButton.icon(
                                  onPressed: _loadPendingOrders,
                                  icon: const Icon(
                                    Icons.refresh,
                                    color: Colors.white,
                                  ),
                                  label: const Text(
                                    'Reload orders',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          );
                        },
                      ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMenuCard({
    required String title,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
    required BoxConstraints constraints,
  }) {
    return SizedBox(
      width: constraints.maxWidth,
      height: constraints.maxHeight,
      child: Card(
        elevation: 4,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        color: color,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFFDD0),
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white70),
                ),
                child: Icon(
                  icon,
                  size: constraints.maxWidth * 0.2, // Responsive icon size
                  color: color,
                ),
              ),
              const SizedBox(height: 16),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8.0),
                child: Text(
                  title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                  textAlign: TextAlign.center,
                  maxLines: 2,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEventCountdown(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Container(
        height: 250,
        width: double.infinity,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: const Color(0xFF9D9DCC), width: 2),
          image: const DecorationImage(
            image: AssetImage('assets/images/Drawing.png'),
            fit: BoxFit.cover,
            opacity: 0.7,
          ),
          color: Colors.white,
        ),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            color: const Color(0xFF9D9DCC).withOpacity(0.1),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                'Event Name',
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                  color: Colors.white,
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                  shadows: [
                    Shadow(
                      offset: const Offset(1, 1),
                      blurRadius: 3.0,
                      color: Colors.black.withOpacity(0.3),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _buildTimeUnit(days.toString().padLeft(2, '0'), 'Days'),
                    _buildTimeSeparator(),
                    _buildTimeUnit(hours.toString().padLeft(2, '0'), 'Hrs'),
                    _buildTimeSeparator(),
                    _buildTimeUnit(minutes.toString().padLeft(2, '0'), 'Min'),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTimeUnit(String value, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.25),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.4), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          Text(
            value,
            style: Theme.of(context).textTheme.headlineMedium?.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 36,
              shadows: [
                Shadow(
                  offset: const Offset(1, 1),
                  blurRadius: 3.0,
                  color: Colors.black.withOpacity(0.5),
                ),
              ],
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.w500,
              shadows: [
                Shadow(
                  offset: const Offset(1, 1),
                  blurRadius: 3.0,
                  color: Colors.black.withOpacity(0.5),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTimeSeparator() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10.0),
      child: Text(
        ':',
        style: Theme.of(context).textTheme.headlineMedium?.copyWith(
          color: Colors.white,
          fontWeight: FontWeight.bold,
          fontSize: 36,
          shadows: [
            Shadow(
              offset: const Offset(1, 1),
              blurRadius: 3.0,
              color: Colors.black.withOpacity(0.5),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAppBar(BuildContext context) {
    return AppBar(
      backgroundColor: const Color(0xFF9D9DCC),
      elevation: 0,
      title: const Text(
        'Organizer Homepage',
        style: TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.bold,
          fontSize: 20,
        ),
      ),
      leading: IconButton(
        icon: const Icon(Icons.menu, color: Colors.white),
        onPressed: () {
          _scaffoldKey.currentState?.openDrawer();
        },
      ),
    );
  }
}
