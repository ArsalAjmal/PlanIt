class WeatherModel {
  final String cityName;
  final double temperature;
  final double feelsLike;
  final String condition;
  final String icon;
  final int humidity;
  final double windSpeed;
  final double maxTemp;
  final double minTemp;
  final int pressure;

  WeatherModel({
    required this.cityName,
    required this.temperature,
    required this.feelsLike,
    required this.condition,
    required this.icon,
    required this.humidity,
    required this.windSpeed,
    required this.maxTemp,
    required this.minTemp,
    required this.pressure,
  });

  factory WeatherModel.fromJson(Map<String, dynamic> json) {
    final main = json['main'];
    final weather = json['weather'][0];
    final wind = json['wind'];

    return WeatherModel(
      cityName: json['name'],
      temperature: main['temp'].toDouble(),
      feelsLike: main['feels_like'].toDouble(),
      condition: weather['description'],
      icon: weather['icon'],
      humidity: main['humidity'],
      windSpeed: wind['speed'].toDouble(),
      maxTemp: main['temp_max'].toDouble(),
      minTemp: main['temp_min'].toDouble(),
      pressure: main['pressure'],
    );
  }
}

class ForecastDay {
  final DateTime date;
  final double maxTemp;
  final double minTemp;
  final String condition;
  final String icon;
  final int humidity;
  final double windSpeed;
  final int clouds;

  ForecastDay({
    required this.date,
    required this.maxTemp,
    required this.minTemp,
    required this.condition,
    required this.icon,
    required this.humidity,
    required this.windSpeed,
    required this.clouds,
  });

  factory ForecastDay.fromJson(Map<String, dynamic> json) {
    return ForecastDay(
      date: DateTime.fromMillisecondsSinceEpoch(json['dt'] * 1000),
      maxTemp: (json['main']['temp_max'] as num).toDouble(),
      minTemp: (json['main']['temp_min'] as num).toDouble(),
      condition: json['weather'][0]['description'],
      icon: json['weather'][0]['icon'],
      humidity: json['main']['humidity'] ?? 0,
      windSpeed: (json['wind']['speed'] as num).toDouble(),
      clouds: json['clouds']['all'] ?? 0,
    );
  }
}
