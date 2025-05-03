import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import '../models/weather_model.dart';

class WeatherService {
  final String apiKey = '2047e1716f7332e749e131ae27499df3';
  final String baseUrl = 'https://api.openweathermap.org/data/2.5';

  Future<List<ForecastDay>> getFiveDayForecast(String city) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/forecast?q=$city&units=metric&appid=$apiKey'),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final List<dynamic> list = data['list'];

        // Group forecasts by day
        final Map<String, ForecastDay> dailyForecasts = {};

        for (var item in list) {
          final date = DateTime.fromMillisecondsSinceEpoch(item['dt'] * 1000);
          final day = DateFormat('yyyy-MM-dd').format(date);

          if (!dailyForecasts.containsKey(day)) {
            dailyForecasts[day] = ForecastDay(
              date: date,
              maxTemp: item['main']['temp_max'].toDouble(),
              minTemp: item['main']['temp_min'].toDouble(),
              condition: item['weather'][0]['description'],
              icon: item['weather'][0]['icon'],
              humidity: item['main']['humidity'],
              windSpeed: item['wind']['speed'].toDouble(),
              clouds: item['clouds']['all'],
            );
          } else {
            final existing = dailyForecasts[day]!;
            if (item['main']['temp_max'] > existing.maxTemp) {
              dailyForecasts[day] = ForecastDay(
                date: existing.date,
                maxTemp: item['main']['temp_max'].toDouble(),
                minTemp: existing.minTemp,
                condition: existing.condition,
                icon: existing.icon,
                humidity: existing.humidity,
                windSpeed: existing.windSpeed,
                clouds: existing.clouds,
              );
            }
            if (item['main']['temp_min'] < existing.minTemp) {
              dailyForecasts[day] = ForecastDay(
                date: existing.date,
                maxTemp: existing.maxTemp,
                minTemp: item['main']['temp_min'].toDouble(),
                condition: existing.condition,
                icon: existing.icon,
                humidity: existing.humidity,
                windSpeed: existing.windSpeed,
                clouds: existing.clouds,
              );
            }
          }
        }

        // Take first 5 days
        final result = dailyForecasts.values.toList();
        result.sort((a, b) => a.date.compareTo(b.date));
        return result.take(5).toList();
      } else {
        print('Error fetching weather data: ${response.statusCode}');
        throw Exception('Failed to load forecast data');
      }
    } catch (e) {
      print('Error in getFiveDayForecast: $e');
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
