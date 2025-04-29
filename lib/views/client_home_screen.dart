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

class ClientHomeScreen extends StatefulWidget {
  const ClientHomeScreen({super.key});

  @override
  State<ClientHomeScreen> createState() => _ClientHomeScreenState();
}

class _ClientHomeScreenState extends State<ClientHomeScreen> {
  // Static timer values (to be replaced with Firestore later)
  int days = 0;
  int hours = 1;
  int minutes = 32;
  int seconds = 6;
  late Timer _timer;
  String? _currentCity;
  late Stream<List<ForecastDay>> weatherStream;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // Add a scaffold key to access the drawer
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  @override
  void initState() {
    super.initState();
    _initializeWeatherStream();
    startTimer();
    // Print the current user ID for debugging
    print('Current user ID: ${_auth.currentUser?.uid}');
  }

  @override
  void dispose() {
    _timer.cancel();
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
    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: const Color(0xFFFFFDE5), // Slightly lighter cream color
      drawer: _buildDrawer(context),
      body: SafeArea(
        child: Column(
          children: [
            _buildAppBar(context),
            _buildWeatherAlert(context),
            _buildEventCountdown(context),
            _buildMenuGrid(context),
          ],
        ),
      ),
    );
  }

  Widget _buildDrawer(BuildContext context) {
    return Drawer(
      child: ListView(
        padding: EdgeInsets.zero,
        children: [
          DrawerHeader(
            decoration: const BoxDecoration(color: Color(0xFF9D9DCC)),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                const CircleAvatar(
                  backgroundColor: Color(0xFFFFFDD0),
                  radius: 30,
                  child: Icon(Icons.person, size: 30, color: Color(0xFF9D9DCC)),
                ),
                const SizedBox(height: 10),
                Text(
                  'Client Menu',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
          ListTile(
            leading: const Icon(Icons.account_circle, color: Color(0xFF9D9DCC)),
            title: const Text('My Account'),
            onTap: () {
              Navigator.pop(context); // Close the drawer
              // Navigation will be added later
            },
          ),
          ListTile(
            leading: const Icon(Icons.help_outline, color: Color(0xFF9D9DCC)),
            title: const Text('Help Center'),
            onTap: () {
              Navigator.pop(context); // Close the drawer
              // Navigation will be added later
            },
          ),
          ListTile(
            leading: const Icon(Icons.policy, color: Color(0xFF9D9DCC)),
            title: const Text('Terms and Policies'),
            onTap: () {
              Navigator.pop(context); // Close the drawer
              // Navigation will be added later
            },
          ),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.logout, color: Color(0xFF9D9DCC)),
            title: const Text('Logout'),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const LoginView()),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildAppBar(BuildContext context) {
    return AppBar(
      backgroundColor: const Color(0xFF9D9DCC),
      title: const Text(
        'Client Homepage',
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

  Widget _buildWeatherAlert(BuildContext context) {
    return Consumer<CityProvider>(
      builder: (context, cityProvider, child) {
        return StreamBuilder<List<ForecastDay>>(
          stream: weatherStream,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return Container(
                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
                decoration: BoxDecoration(
                  color: Colors.grey.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: Colors.grey.withOpacity(0.3),
                    width: 1,
                  ),
                ),
                child: const Row(
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
                    SizedBox(width: 12),
                    Text(
                      'Checking weather conditions...',
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
                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
                decoration: BoxDecoration(
                  color: Colors.orange.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: Colors.orange.withOpacity(0.3),
                    width: 1,
                  ),
                ),
                child: const Row(
                  children: [
                    Icon(
                      Icons.warning_amber_rounded,
                      color: Colors.orange,
                      size: 24,
                    ),
                    SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Unable to check weather conditions. Please check again later.',
                        style: TextStyle(
                          color: Colors.orange,
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

              return Container(
                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
                decoration: BoxDecoration(
                  color:
                      hasRain
                          ? Colors.red.withOpacity(0.1)
                          : Colors.green.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color:
                        hasRain
                            ? Colors.red.withOpacity(0.3)
                            : Colors.green.withOpacity(0.3),
                    width: 1,
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      hasRain
                          ? Icons.warning_amber_rounded
                          : Icons.check_circle_outline,
                      color: hasRain ? Colors.red : Colors.green,
                      size: 24,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        hasRain
                            ? 'Weather not suitable for outdoor events. Check forecast for further details.'
                            : 'Weather is suitable for outdoor events.',
                        style: TextStyle(
                          color: hasRain ? Colors.red : Colors.green,
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
            color: const Color(0xFF9D9DCC).withAlpha(25),
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
                      color: Colors.black.withAlpha(77),
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
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 36,
              shadows: [
                Shadow(
                  offset: Offset(1, 1),
                  blurRadius: 3.0,
                  color: Color(0x80000000),
                ),
              ],
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.w500,
              shadows: [
                Shadow(
                  offset: Offset(1, 1),
                  blurRadius: 3.0,
                  color: Color(0x80000000),
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
        style: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.bold,
          fontSize: 36,
          shadows: [
            Shadow(
              offset: Offset(1, 1),
              blurRadius: 3.0,
              color: Color(0x80000000),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMenuGrid(BuildContext context) {
    final String clientId = _auth.currentUser?.uid ?? '';
    final String clientName =
        _auth.currentUser?.email?.split('@')[0] ?? 'Client';

    return Expanded(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32.0, vertical: 24.0),
        child: GridView.count(
          crossAxisCount: 2,
          childAspectRatio: 1.0,
          crossAxisSpacing: 24,
          mainAxisSpacing: 24,
          children: [
            // First row
            _buildMenuCard(
              color: const Color(0xFF9D9DCC),
              icon: Icons.search,
              title: 'Search Organizer',
              onTap: () {
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
            ),
            _buildMenuCard(
              color: const Color(0xFF9D9DCC),
              icon: Icons.list_alt,
              title: 'Order History',
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => OrderHistoryScreen()),
                );
              },
            ),
            // Second row
            _buildMenuCard(
              color: const Color(0xFF9D9DCC),
              icon: Icons.cloud,
              title: 'Weather Update',
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const WeatherScreen(),
                  ),
                );
              },
            ),
            _buildMenuCard(
              color: const Color(0xFF9D9DCC),
              icon: Icons.star,
              title: 'Feedback',
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const FeedbackScreen(),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMenuCard({
    required Color color,
    required IconData icon,
    required String title,
    required VoidCallback onTap,
  }) {
    return Card(
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
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFFFFDD0),
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white70),
              ),
              child: Icon(icon, size: 28, color: color),
            ),
            const SizedBox(height: 12),
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
    );
  }
}
