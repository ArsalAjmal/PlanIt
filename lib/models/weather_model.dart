class WeatherModel {
  final String cityName;
  final String condition;
  final String icon;
  final double temperature;
  final double minTemp;
  final double maxTemp;
  final DateTime date;
  final int humidity;
  final double windSpeed;

  WeatherModel({
    required this.cityName,
    required this.condition,
    required this.icon,
    required this.temperature,
    required this.minTemp,
    required this.maxTemp,
    required this.date,
    required this.humidity,
    required this.windSpeed,
  });

  factory WeatherModel.fromJson(Map<String, dynamic> json) {
    return WeatherModel(
      cityName: json['name'] ?? '',
      condition: json['weather'][0]['description'] ?? '',
      icon: json['weather'][0]['icon'] ?? '',
      temperature: (json['main']['temp'] as num).toDouble(),
      minTemp: (json['main']['temp_min'] as num).toDouble(),
      maxTemp: (json['main']['temp_max'] as num).toDouble(),
      date: DateTime.fromMillisecondsSinceEpoch(json['dt'] * 1000),
      humidity: json['main']['humidity'] ?? 0,
      windSpeed: (json['wind']['speed'] as num).toDouble(),
    );
  }
}

class ForecastDay {
  final DateTime date;
  final String condition;
  final String icon;
  final double maxTemp;
  final double minTemp;

  ForecastDay({
    required this.date,
    required this.condition,
    required this.icon,
    required this.maxTemp,
    required this.minTemp,
  });

  factory ForecastDay.fromJson(Map<String, dynamic> json) {
    return ForecastDay(
      date: DateTime.fromMillisecondsSinceEpoch(json['dt'] * 1000),
      condition: json['weather'][0]['description'],
      icon: json['weather'][0]['icon'],
      maxTemp: (json['main']['temp_max'] as num).toDouble(),
      minTemp: (json['main']['temp_min'] as num).toDouble(),
    );
  }
}
