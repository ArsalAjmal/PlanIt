import 'package:flutter/material.dart';
import '../views/weather_screen.dart';
import '../views/feedback_screen.dart';

class NavigationHelper {
  static void navigateToWeatherScreen(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const WeatherScreen(isInBottomNavBar: false),
      ),
    );
  }

  static void navigateToFeedbackScreen(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const FeedbackScreen(isInBottomNavBar: false),
      ),
    );
  }
}
