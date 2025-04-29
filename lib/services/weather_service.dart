import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import '../models/weather_model.dart';

class WeatherService {
  final String apiKey = '2047e1716f7332e749e131ae27499df3';

  Future<List<ForecastDay>> getFiveDayForecast(String city) async {
    try {
      // First get coordinates for the city
      final geoResponse = await http.get(
        Uri.parse(
          'http://api.openweathermap.org/geo/1.0/direct?q=$city&limit=1&appid=$apiKey',
        ),
      );

      if (geoResponse.statusCode != 200) {
        throw Exception('Failed to get city coordinates');
      }

      final geoData = json.decode(geoResponse.body);
      if (geoData.isEmpty) {
        throw Exception('City not found');
      }

      final lat = geoData[0]['lat'];
      final lon = geoData[0]['lon'];

      // Get daily forecast using coordinates
      final response = await http.get(
        Uri.parse(
          'https://api.openweathermap.org/data/2.5/forecast/daily?lat=$lat&lon=$lon&cnt=5&appid=$apiKey&units=metric',
        ),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        List<ForecastDay> forecast = [];

        for (var item in data['list']) {
          forecast.add(
            ForecastDay(
              date: DateTime.fromMillisecondsSinceEpoch(item['dt'] * 1000),
              condition: item['weather'][0]['description'],
              icon: item['weather'][0]['icon'],
              maxTemp: (item['temp']['max'] as num).toDouble(),
              minTemp: (item['temp']['min'] as num).toDouble(),
            ),
          );
        }

        return forecast;
      } else {
        // Fallback to 5-day/3-hour forecast if daily forecast fails
        final fallbackResponse = await http.get(
          Uri.parse(
            'https://api.openweathermap.org/data/2.5/forecast?lat=$lat&lon=$lon&appid=$apiKey&units=metric',
          ),
        );

        if (fallbackResponse.statusCode == 200) {
          final data = json.decode(fallbackResponse.body);
          List<ForecastDay> forecast = [];
          Map<String, List<dynamic>> dailyData = {};

          // Group by date
          for (var item in data['list']) {
            DateTime date = DateTime.fromMillisecondsSinceEpoch(
              item['dt'] * 1000,
            );
            String dateKey = DateFormat('yyyy-MM-dd').format(date);

            if (!dailyData.containsKey(dateKey)) {
              dailyData[dateKey] = [];
            }
            dailyData[dateKey]!.add(item);
          }

          // Get daily min/max
          dailyData.forEach((dateKey, items) {
            if (forecast.length < 5) {
              double maxTemp = -double.infinity;
              double minTemp = double.infinity;
              String condition = items[0]['weather'][0]['description'];
              String icon = items[0]['weather'][0]['icon'];

              for (var item in items) {
                double temp = (item['main']['temp'] as num).toDouble();
                if (temp > maxTemp) maxTemp = temp;
                if (temp < minTemp) minTemp = temp;
              }

              forecast.add(
                ForecastDay(
                  date: DateTime.parse(dateKey),
                  condition: condition,
                  icon: icon,
                  maxTemp: maxTemp,
                  minTemp: minTemp,
                ),
              );
            }
          });

          forecast.sort((a, b) => a.date.compareTo(b.date));
          return forecast;
        } else {
          throw Exception('Failed to load forecast data');
        }
      }
    } catch (e) {
      throw Exception('Failed to load forecast data');
    }
  }

  Future<WeatherModel> getCurrentWeather(String city) async {
    try {
      final response = await http.get(
        Uri.parse(
          'https://api.openweathermap.org/data/2.5/weather?q=$city&appid=$apiKey&units=metric',
        ),
      );

      if (response.statusCode == 200) {
        return WeatherModel.fromJson(json.decode(response.body));
      } else {
        throw Exception('Failed to load weather data');
      }
    } catch (e) {
      throw Exception('Failed to load weather data');
    }
  }
}
