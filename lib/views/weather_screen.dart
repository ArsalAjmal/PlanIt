import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import '../models/weather_model.dart';
import '../services/weather_service.dart';
import '../providers/city_provider.dart';
import 'package:provider/provider.dart';
import '../constants/app_colors.dart';

class WeatherScreen extends StatefulWidget {
  final bool isInBottomNavBar;

  const WeatherScreen({super.key, this.isInBottomNavBar = true});

  @override
  _WeatherScreenState createState() => _WeatherScreenState();
}

class _WeatherScreenState extends State<WeatherScreen> {
  final WeatherService _weatherService = WeatherService();
  final TextEditingController _cityController = TextEditingController();
  WeatherModel? currentWeather;
  List<ForecastDay> forecast = [];
  bool isLoading = false;
  String? error;

  @override
  void initState() {
    super.initState();
    Future.delayed(Duration.zero, () {
      _requestLocationPermission();
    });
  }

  Future<void> _requestLocationPermission() async {
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Please enable location services'),
            backgroundColor: Colors.orange,
            duration: Duration(seconds: 3),
          ),
        );
        // Default to Multan if services are not enabled
        _loadWeatherData('Multan');
        return;
      }

      // Check permission status
      LocationPermission permission = await Geolocator.checkPermission();

      if (permission == LocationPermission.denied) {
        // Request permission
        permission = await Geolocator.requestPermission();

        if (permission == LocationPermission.denied) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Location permission denied'),
              backgroundColor: Colors.orange,
              duration: Duration(seconds: 3),
            ),
          );
          _loadWeatherData('Multan');
          return;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        // User denied permissions forever, show instructions to enable
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Please enable location permissions in app settings'),
            backgroundColor: Colors.orange,
            duration: Duration(seconds: 3),
          ),
        );
        _loadWeatherData('Multan');
        return;
      }

      // We have permission, get current city
      _getCurrentCity();
    } catch (e) {
      print('Error requesting location permission: $e');
      _loadWeatherData('Multan');
    }
  }

  Future<void> _getCurrentCity() async {
    setState(() {
      isLoading = true;
    });

    try {
      // Get current position with timeout
      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
        timeLimit: const Duration(seconds: 10),
      );

      // Get place information from coordinates
      List<Placemark> placemarks = await placemarkFromCoordinates(
        position.latitude,
        position.longitude,
      );

      if (placemarks.isNotEmpty && mounted) {
        // Use locality (city) if available, or fallback to subAdministrativeArea or a default
        final city =
            placemarks[0].locality ??
            placemarks[0].subAdministrativeArea ??
            'Multan';

        // Update city in provider
        context.read<CityProvider>().updateCity(city);

        // Set text field value
        if (mounted) {
          _cityController.text = city;
        }

        // Load weather data
        _loadWeatherData(city);
      } else {
        // No placemarks found
        _loadWeatherData('Multan');
      }
    } catch (e) {
      print('Error getting current city: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Could not determine your location. Using default city.',
            ),
            backgroundColor: Colors.orange,
            duration: const Duration(seconds: 3),
          ),
        );
        _loadWeatherData('Multan');
      }
    }
  }

  Future<void> _loadWeatherData(String city) async {
    setState(() {
      isLoading = true;
      error = null;
    });

    try {
      final weatherData = await _weatherService.getCurrentWeather(city);
      final forecastData = await _weatherService.getFiveDayForecast(city);

      if (mounted) {
        setState(() {
          currentWeather = weatherData;
          forecast = forecastData;
          isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          error = 'Failed to load weather data. Please try again.';
          isLoading = false;
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(error ?? 'An error occurred'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final Widget content = Column(
      children: [
        if (!widget.isInBottomNavBar)
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
                  'Weather Forecast',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
        Container(height: 1, color: const Color(0xFF9D9DCC).withOpacity(0.3)),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: TextField(
            controller: _cityController,
            decoration: InputDecoration(
              labelText: 'City',
              hintText: 'Enter city name',
              hintStyle: TextStyle(color: Colors.grey[600], fontSize: 16),
              filled: true,
              fillColor: Colors.grey.withOpacity(0.1),
              labelStyle: TextStyle(color: Colors.grey[600], fontSize: 16),
              prefixIcon: const Icon(
                Icons.search,
                color: Color(0xFF9D9DCC),
                size: 24,
              ),
              contentPadding: const EdgeInsets.symmetric(
                vertical: 10.0,
                horizontal: 12.0,
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(
                  color: Color(0xFF9D9DCC),
                  width: 1,
                ),
              ),
              isDense: true,
            ),
            style: const TextStyle(color: Colors.black87, fontSize: 16),
            onSubmitted: (value) {
              if (value.isNotEmpty) {
                _loadWeatherData(value);
              }
            },
          ),
        ),
        Expanded(
          child:
              isLoading
                  ? const Center(
                    child: CircularProgressIndicator(
                      valueColor: AlwaysStoppedAnimation<Color>(
                        Color(0xFF9D9DCC),
                      ),
                    ),
                  )
                  : error != null
                  ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.cloud_off, size: 64, color: Colors.grey),
                        const SizedBox(height: 16),
                        Text(
                          error!,
                          style: TextStyle(color: Colors.red.shade400),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 16),
                        ElevatedButton(
                          onPressed:
                              () => _loadWeatherData(
                                _cityController.text.isEmpty
                                    ? 'Multan'
                                    : _cityController.text,
                              ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF9D9DCC),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: const Text(
                            'Retry',
                            style: TextStyle(color: Colors.white),
                          ),
                        ),
                      ],
                    ),
                  )
                  : Container(
                    decoration: BoxDecoration(
                      color: Colors.transparent,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: SingleChildScrollView(
                      physics: const BouncingScrollPhysics(),
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (currentWeather != null) ...[
                              // Display a greeting based on time of day
                              Padding(
                                padding: const EdgeInsets.only(bottom: 8),
                                child: Text(
                                  _getGreeting(),
                                  style: const TextStyle(
                                    fontSize: 16,
                                    color: Colors.black54,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                              _buildCurrentWeather(),
                              const SizedBox(height: 24),
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  const Text(
                                    '5-Day Forecast',
                                    style: TextStyle(
                                      fontSize: 20,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.black87,
                                    ),
                                  ),
                                  IconButton(
                                    icon: const Icon(
                                      Icons.refresh,
                                      color: Color(0xFF9D9DCC),
                                    ),
                                    onPressed:
                                        () => _loadWeatherData(
                                          _cityController.text.isEmpty
                                              ? currentWeather!.cityName
                                              : _cityController.text,
                                        ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 16),
                              _buildForecast(),
                            ],
                          ],
                        ),
                      ),
                    ),
                  ),
        ),
      ],
    );

    if (widget.isInBottomNavBar) {
      return content;
    } else {
      return Scaffold(
        backgroundColor: AppColors.creamBackground,
        body: SafeArea(child: content),
      );
    }
  }

  Widget _buildCurrentWeather() {
    // Determine card color based on weather condition
    Color cardColor;
    final condition = currentWeather!.condition.toLowerCase();

    if (condition.contains('rain') ||
        condition.contains('drizzle') ||
        condition.contains('thunderstorm')) {
      cardColor = Colors.blue.shade50; // Light blue for rain
    } else if (condition.contains('cloud') ||
        condition.contains('mist') ||
        condition.contains('fog')) {
      cardColor = Colors.grey.shade100; // Light grey for cloudy/foggy
    } else if (condition.contains('sun') || condition.contains('clear')) {
      cardColor = Colors.yellow.shade50; // Light yellow for sunny
    } else {
      cardColor = Colors.white; // Default
    }

    // Get appropriate weather icon based on condition
    IconData weatherIcon;
    if (condition.contains('rain') || condition.contains('drizzle')) {
      weatherIcon = Icons.grain;
    } else if (condition.contains('thunderstorm')) {
      weatherIcon = Icons.flash_on;
    } else if (condition.contains('cloud')) {
      weatherIcon = Icons.cloud;
    } else if (condition.contains('mist') || condition.contains('fog')) {
      weatherIcon = Icons.blur_on;
    } else if (condition.contains('sun') || condition.contains('clear')) {
      weatherIcon = Icons.wb_sunny;
    } else {
      weatherIcon = Icons.wb_cloudy;
    }

    return Card(
      elevation: 4,
      color: cardColor,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [cardColor, cardColor.withOpacity(0.7)],
          ),
        ),
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      currentWeather!.cityName,
                      style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87,
                      ),
                    ),
                    Text(
                      DateFormat('EEEE, MMM dd').format(DateTime.now()),
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.black54,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.3),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(weatherIcon, color: Colors.black87, size: 32),
                ),
              ],
            ),
            const SizedBox(height: 40),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${currentWeather!.temperature.round()}',
                          style: const TextStyle(
                            fontSize: 52,
                            fontWeight: FontWeight.bold,
                            color: Colors.black87,
                            height: 0.9,
                          ),
                        ),
                        const Text(
                          '°C',
                          style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            color: Colors.black87,
                          ),
                        ),
                      ],
                    ),
                    Text(
                      'Feels like ${currentWeather!.feelsLike.round()}°C',
                      style: const TextStyle(
                        fontSize: 14,
                        color: Colors.black54,
                      ),
                    ),
                  ],
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      currentWeather!.condition.toUpperCase(),
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87,
                      ),
                    ),
                    Row(
                      children: [
                        Text(
                          'H:${currentWeather!.maxTemp.round()}°',
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                            color: Colors.red,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'L:${currentWeather!.minTemp.round()}°',
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                            color: Colors.green,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 24),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.3),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _buildWeatherDetail(
                    Icons.water_drop_outlined,
                    'Humidity',
                    '${currentWeather!.humidity}%',
                  ),
                  _buildDivider(),
                  _buildWeatherDetail(
                    Icons.air,
                    'Wind',
                    '${currentWeather!.windSpeed} km/h',
                  ),
                  _buildDivider(),
                  _buildWeatherDetail(
                    Icons.cloud_outlined,
                    'Pressure',
                    '${currentWeather!.pressure} hPa',
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDivider() {
    return Container(height: 40, width: 1, color: Colors.black12);
  }

  Widget _buildWeatherDetail(IconData icon, String label, String value) {
    return Column(
      children: [
        Icon(icon, size: 20, color: Colors.black54),
        const SizedBox(height: 6),
        Text(
          label,
          style: const TextStyle(
            fontSize: 12,
            color: Colors.black54,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.bold,
            color: Colors.black87,
          ),
        ),
      ],
    );
  }

  Widget _buildForecast() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.5),
        borderRadius: BorderRadius.circular(20),
      ),
      child: ListView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: forecast.length,
        itemBuilder: (context, index) {
          final day = forecast[index];

          // Determine card color based on weather condition
          Color cardColor;
          final condition = day.condition.toLowerCase();

          if (condition.contains('rain') ||
              condition.contains('drizzle') ||
              condition.contains('thunderstorm')) {
            cardColor = Colors.blue.shade50; // Light blue for rain
          } else if (condition.contains('cloud') ||
              condition.contains('mist') ||
              condition.contains('fog')) {
            cardColor = Colors.grey.shade100; // Light grey for cloudy/foggy
          } else if (condition.contains('sun') || condition.contains('clear')) {
            cardColor = Colors.yellow.shade50; // Light yellow for sunny
          } else {
            cardColor = Colors.white; // Default
          }

          // Get appropriate weather icon based on condition
          IconData weatherIcon;
          if (condition.contains('rain') || condition.contains('drizzle')) {
            weatherIcon = Icons.grain;
          } else if (condition.contains('thunderstorm')) {
            weatherIcon = Icons.flash_on;
          } else if (condition.contains('cloud')) {
            weatherIcon = Icons.cloud;
          } else if (condition.contains('mist') || condition.contains('fog')) {
            weatherIcon = Icons.blur_on;
          } else if (condition.contains('sun') || condition.contains('clear')) {
            weatherIcon = Icons.wb_sunny;
          } else {
            weatherIcon = Icons.wb_cloudy;
          }

          return Container(
            margin: EdgeInsets.only(
              bottom: index == forecast.length - 1 ? 0 : 8,
            ),
            decoration: BoxDecoration(
              color: cardColor,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Material(
              color: Colors.transparent,
              borderRadius: BorderRadius.circular(16),
              child: InkWell(
                borderRadius: BorderRadius.circular(16),
                onTap: () {
                  // Show detailed forecast when tapped
                  _showDayForecastDetails(context, day);
                },
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    vertical: 12,
                    horizontal: 16,
                  ),
                  child: Row(
                    children: [
                      // Day of week
                      SizedBox(
                        width: 100,
                        child: Text(
                          DateFormat('EEEE').format(day.date),
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                            color: Colors.black87,
                          ),
                        ),
                      ),

                      // Weather icon
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.3),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          weatherIcon,
                          size: 20,
                          color: Colors.black87,
                        ),
                      ),

                      const SizedBox(width: 12),

                      // Weather condition
                      Expanded(
                        child: Text(
                          day.condition.toCapitalized(),
                          style: const TextStyle(
                            color: Colors.black54,
                            fontSize: 14,
                          ),
                        ),
                      ),

                      // Temperature
                      RichText(
                        text: TextSpan(
                          children: [
                            TextSpan(
                              text: '${day.maxTemp.round()}°',
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                                color: Colors.red,
                              ),
                            ),
                            const TextSpan(
                              text: '/',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                                color: Colors.black54,
                              ),
                            ),
                            TextSpan(
                              text: '${day.minTemp.round()}°',
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                                color: Colors.green,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  void _showDayForecastDetails(BuildContext context, ForecastDay day) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(20),
              topRight: Radius.circular(20),
            ),
          ),
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    DateFormat('EEEE, MMM dd').format(day.date),
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, size: 20),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  Icon(
                    _getWeatherIcon(day.condition),
                    size: 48,
                    color: const Color(0xFF9D9DCC),
                  ),
                  const SizedBox(width: 16),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        day.condition.toCapitalized(),
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Colors.black87,
                        ),
                      ),
                      const SizedBox(height: 4),
                      RichText(
                        text: TextSpan(
                          children: [
                            TextSpan(
                              text: 'High: ${day.maxTemp.round()}°C  ',
                              style: const TextStyle(
                                fontSize: 14,
                                color: Colors.red,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            TextSpan(
                              text: 'Low: ${day.minTemp.round()}°C',
                              style: const TextStyle(
                                fontSize: 14,
                                color: Colors.green,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 20),
              const Text(
                'Weather Details',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
              const SizedBox(height: 10),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _buildDetailColumn(
                    Icons.water_drop_outlined,
                    'Humidity',
                    '${day.humidity}%',
                  ),
                  _buildDetailColumn(
                    Icons.air,
                    'Wind Speed',
                    '${day.windSpeed.toStringAsFixed(1)} km/h',
                  ),
                  _buildDetailColumn(
                    Icons.cloud_outlined,
                    'Clouds',
                    '${day.clouds}%',
                  ),
                ],
              ),
              const SizedBox(height: 20),
            ],
          ),
        );
      },
    );
  }

  IconData _getWeatherIcon(String condition) {
    final lowerCaseCondition = condition.toLowerCase();
    if (lowerCaseCondition.contains('rain') ||
        lowerCaseCondition.contains('drizzle')) {
      return Icons.grain;
    } else if (lowerCaseCondition.contains('thunderstorm')) {
      return Icons.flash_on;
    } else if (lowerCaseCondition.contains('cloud')) {
      return Icons.cloud;
    } else if (lowerCaseCondition.contains('mist') ||
        lowerCaseCondition.contains('fog')) {
      return Icons.blur_on;
    } else if (lowerCaseCondition.contains('sun') ||
        lowerCaseCondition.contains('clear')) {
      return Icons.wb_sunny;
    } else {
      return Icons.wb_cloudy;
    }
  }

  Widget _buildDetailColumn(IconData icon, String label, String value) {
    return Column(
      children: [
        Icon(icon, size: 24, color: Colors.black54),
        const SizedBox(height: 8),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: Colors.black54,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.bold,
            color: Colors.black87,
          ),
        ),
      ],
    );
  }

  String _getGreeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) {
      return 'Good Morning';
    } else if (hour < 17) {
      return 'Good Afternoon';
    } else {
      return 'Good Evening';
    }
  }
}

// Extension for better text formatting
extension StringExtension on String {
  String toCapitalized() =>
      length > 0 ? '${this[0].toUpperCase()}${substring(1)}' : '';
}
