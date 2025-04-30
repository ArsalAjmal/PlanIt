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
          ),
        );
        return;
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          _loadWeatherData('Islamabad');
          return;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        _loadWeatherData('Islamabad');
        return;
      }

      _getCurrentCity();
    } catch (e) {
      print('Error requesting location permission: $e');
      _loadWeatherData('Islamabad');
    }
  }

  Future<void> _getCurrentCity() async {
    try {
      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );

      List<Placemark> placemarks = await placemarkFromCoordinates(
        position.latitude,
        position.longitude,
      );

      if (placemarks.isNotEmpty && mounted) {
        final city = placemarks[0].locality ?? 'Islamabad';
        context.read<CityProvider>().updateCity(city);
        _loadWeatherData(city);
      }
    } catch (e) {
      print('Error getting current city: $e');
      _loadWeatherData('Islamabad');
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
              hintText: 'Enter city name',
              hintStyle: const TextStyle(color: Colors.grey),
              fillColor: Colors.white,
              filled: true,
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(
                  color: Color(0xFF9D9DCC),
                  width: 1,
                ),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(
                  color: Color(0xFF9D9DCC),
                  width: 2,
                ),
              ),
              suffixIcon: IconButton(
                icon: const Icon(Icons.search, color: Color(0xFF9D9DCC)),
                onPressed: () {
                  if (_cityController.text.isNotEmpty) {
                    _loadWeatherData(_cityController.text);
                  }
                },
              ),
            ),
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
                  ? const Center(child: CircularProgressIndicator())
                  : error != null
                  ? Center(child: Text(error!))
                  : SingleChildScrollView(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (currentWeather != null) ...[
                            _buildCurrentWeather(),
                            const SizedBox(height: 24),
                            const Text(
                              '5-Day Forecast',
                              style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF9D9DCC),
                              ),
                            ),
                            const SizedBox(height: 16),
                            _buildForecast(),
                          ],
                        ],
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
    return Card(
      elevation: 4,
      color: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              currentWeather!.cityName,
              style: const TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Color(0xFF9D9DCC),
              ),
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${currentWeather!.temperature.round()}°C',
                      style: const TextStyle(
                        fontSize: 36,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      currentWeather!.condition.toUpperCase(),
                      style: const TextStyle(fontSize: 16, color: Colors.grey),
                    ),
                  ],
                ),
                Image.network(
                  'https://openweathermap.org/img/w/${currentWeather!.icon}.png',
                  scale: 0.5,
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildWeatherDetail('Humidity', '${currentWeather!.humidity}%'),
                _buildWeatherDetail(
                  'Wind',
                  '${currentWeather!.windSpeed} km/h',
                ),
                _buildWeatherDetail(
                  'Max',
                  '${currentWeather!.maxTemp.round()}°C',
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildWeatherDetail(String label, String value) {
    return Column(
      children: [
        Text(label, style: const TextStyle(fontSize: 14, color: Colors.grey)),
        Text(
          value,
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
      ],
    );
  }

  Widget _buildForecast() {
    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: forecast.length,
      itemBuilder: (context, index) {
        final day = forecast[index];
        return Card(
          margin: const EdgeInsets.only(bottom: 8),
          child: ListTile(
            leading: Image.network(
              'https://openweathermap.org/img/w/${day.icon}.png',
              width: 40,
              height: 40,
            ),
            title: Text(
              DateFormat('EEEE').format(day.date),
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                color: Color(0xFF9D9DCC),
              ),
            ),
            subtitle: Text(
              day.condition.toCapitalized(),
              style: const TextStyle(color: Colors.grey),
            ),
            trailing: Text(
              '${day.maxTemp.round()}°/${day.minTemp.round()}°',
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                color: Color(0xFF9D9DCC),
              ),
            ),
          ),
        );
      },
    );
  }
}

// Extension for better text formatting
extension StringExtension on String {
  String toCapitalized() =>
      length > 0 ? '${this[0].toUpperCase()}${substring(1)}' : '';
}
