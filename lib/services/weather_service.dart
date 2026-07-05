import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:geolocator/geolocator.dart';
import 'package:intl/intl.dart';

class HourlyForecast {
  final DateTime time;
  final double temperature;
  final int weatherCode;
  final int precipitationProbability;
  
  HourlyForecast(this.time, this.temperature, this.weatherCode, this.precipitationProbability);
}

class DailyForecast {
  final DateTime date;
  final DateTime sunrise;
  final DateTime sunset;
  final int weatherCode;
  final double maxTemp;
  final double minTemp;

  DailyForecast(this.date, this.sunrise, this.sunset, this.weatherCode, this.maxTemp, this.minTemp);
}

class WeatherData {
  final double temperature;
  final int weatherCode;
  final bool isDay;
  final List<HourlyForecast> hourly;
  final List<DailyForecast> daily;

  WeatherData({
    required this.temperature,
    required this.weatherCode,
    required this.isDay,
    required this.hourly,
    required this.daily,
  });

  String get conditionTitle {
    if (weatherCode == 0) return 'Clear';
    if (weatherCode >= 1 && weatherCode <= 3) return 'Cloudy';
    if (weatherCode >= 45 && weatherCode <= 48) return 'Foggy';
    if (weatherCode >= 51 && weatherCode <= 67) return 'Rainy';
    if (weatherCode >= 71 && weatherCode <= 77) return 'Snowy';
    if (weatherCode >= 80 && weatherCode <= 82) return 'Rainy';
    if (weatherCode >= 95) return 'Stormy';
    return 'Unknown';
  }

  String get contextSentence {
    // Check next 12 hours for rain/storms
    DateTime now = DateTime.now();
    DateTime limit = now.add(const Duration(hours: 12));
    
    HourlyForecast? rainForecast;
    HourlyForecast? stormForecast;
    
    for (var h in hourly) {
        if (h.time.isAfter(now) && h.time.isBefore(limit)) {
            if (h.weatherCode >= 51 && h.weatherCode <= 67 && rainForecast == null) rainForecast = h;
            if (h.weatherCode >= 95 && stormForecast == null) stormForecast = h;
        }
    }
    
    if (stormForecast != null) {
        String timeStr = stormForecast.time.hour > 12 ? '${stormForecast.time.hour - 12} PM' : (stormForecast.time.hour == 0 ? '12 AM' : '${stormForecast.time.hour} AM');
        return 'Storms possible around $timeStr';
    }
    
    if (rainForecast != null) {
        String timeStr = rainForecast.time.hour > 12 ? '${rainForecast.time.hour - 12} PM' : (rainForecast.time.hour == 0 ? '12 AM' : '${rainForecast.time.hour} AM');
        return 'Rain expected around $timeStr (${rainForecast.precipitationProbability}%)';
    }
    
    if (weatherCode == 0) return 'Clear skies through the afternoon';
    if (weatherCode >= 71 && weatherCode <= 77) return 'Cold morning, warmer later today';
    
    return 'Cooler day ahead';
  }

  String get iconEmoji {
    if (weatherCode == 0) return isDay ? '☀️' : '🌙';
    if (weatherCode >= 1 && weatherCode <= 3) return isDay ? '⛅' : '☁️';
    if (weatherCode >= 45 && weatherCode <= 48) return '🌫️';
    if (weatherCode >= 51 && weatherCode <= 67) return '🌧️';
    if (weatherCode >= 71 && weatherCode <= 77) return '❄️';
    if (weatherCode >= 80 && weatherCode <= 82) return '🌦️';
    if (weatherCode >= 95) return '⛈️';
    return '🌡️';
  }
}

class WeatherService {
  static WeatherData? cachedWeather;
  static DateTime? _lastFetchTime;

  static Future<bool> _handleLocationPermission() async {
    bool serviceEnabled;
    LocationPermission permission;
    
    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) return false;
    
    permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied || permission == LocationPermission.deniedForever) {
      return false;
    }
    if (permission == LocationPermission.deniedForever) return false;
    
    return true;
  }

  static Future<WeatherData?> getCurrentWeather() async {
    if (cachedWeather != null && _lastFetchTime != null) {
      if (DateTime.now().difference(_lastFetchTime!).inMinutes < 60) {
        return cachedWeather;
      }
    }

    final hasPermission = await _handleLocationPermission();
    if (!hasPermission) return cachedWeather;

    try {
      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.low,
        timeLimit: const Duration(seconds: 5),
      );

      final url = Uri.parse(
        'https://api.open-meteo.com/v1/forecast?latitude=${position.latitude}&longitude=${position.longitude}&current_weather=true&hourly=temperature_2m,weathercode,precipitation_probability&daily=sunrise,sunset,weathercode,temperature_2m_max,temperature_2m_min&timezone=auto'
      );

      final response = await http.get(url).timeout(const Duration(seconds: 8));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final current = data['current_weather'];
        
        List<HourlyForecast> hourly = [];
        if (data['hourly'] != null) {
            final times = data['hourly']['time'] as List;
            final temps = data['hourly']['temperature_2m'] as List;
            final codes = data['hourly']['weathercode'] as List;
            final probs = data['hourly']['precipitation_probability'] as List?;
            
            for (int i = 0; i < times.length; i++) {
                hourly.add(HourlyForecast(
                   DateTime.parse(times[i]),
                   (temps[i] as num).toDouble(),
                   codes[i] as int,
                   probs != null ? (probs[i] as int) : 0,
                ));
            }
        }
        
        List<DailyForecast> daily = [];
        if (data['daily'] != null) {
            final times = data['daily']['time'] as List;
            final sunrises = data['daily']['sunrise'] as List;
            final sunsets = data['daily']['sunset'] as List;
            final codes = data['daily']['weathercode'] as List;
            final maxT = data['daily']['temperature_2m_max'] as List;
            final minT = data['daily']['temperature_2m_min'] as List;
            
            for (int i = 0; i < times.length; i++) {
                daily.add(DailyForecast(
                   DateTime.parse(times[i]),
                   DateTime.parse(sunrises[i]),
                   DateTime.parse(sunsets[i]),
                   codes[i] as int,
                   (maxT[i] as num).toDouble(),
                   (minT[i] as num).toDouble(),
                ));
            }
        }
        
        cachedWeather = WeatherData(
          temperature: current['temperature'].toDouble(),
          weatherCode: current['weathercode'],
          isDay: current['is_day'] == 1,
          hourly: hourly,
          daily: daily,
        );
        _lastFetchTime = DateTime.now();
        return cachedWeather;
      }
    } catch (e) {
      print('Weather Error: $e');
    }
    return cachedWeather;
  }
}
