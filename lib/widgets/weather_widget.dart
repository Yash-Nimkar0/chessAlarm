import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:geolocator/geolocator.dart';
import '../services/weather_service.dart';
import '../services/preferences_service.dart';
import '../utils/greeting_utils.dart';
import 'dart:ui';


class WeatherWidget extends StatefulWidget {
  const WeatherWidget({Key? key}) : super(key: key);

  @override
  State<WeatherWidget> createState() => _WeatherWidgetState();
}

class _WeatherWidgetState extends State<WeatherWidget> with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  WeatherData? _weatherData;
  bool _isLoading = true;
  String _userName = "Grandmaster";
  late AnimationController _bgAnimController;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _bgAnimController = AnimationController(vsync: this, duration: const Duration(seconds: 10))..repeat(reverse: true);
    if (WeatherService.cachedWeather != null) {
      _weatherData = WeatherService.cachedWeather;
      _isLoading = false;
    }
    _fetchWeather();
    _loadName();
  }
  
  Future<void> _loadName() async {
    final name = await PreferencesService.getUserName();
    if (mounted) setState(() => _userName = name);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused || state == AppLifecycleState.inactive) {
      _bgAnimController.stop();
    } else if (state == AppLifecycleState.resumed) {
      _bgAnimController.repeat(reverse: true);
    }
  }

  Future<void> _fetchWeather() async {
    final data = await WeatherService.getCurrentWeather();
    if (mounted) {
      setState(() {
        _weatherData = data;
        _isLoading = false;
      });
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _bgAnimController.dispose();
    super.dispose();
  }
  
  List<Color> _getWeatherGradients() {
     if (_weatherData == null) return [Colors.indigo.shade900, Colors.purple.shade900];
     
     final code = _weatherData!.weatherCode;
     if (code == 0) return [Colors.blue.shade400, Colors.orange.shade300]; // Sunny
     if (code >= 1 && code <= 3) return [Colors.blueGrey.shade400, Colors.grey.shade600]; // Cloud
     if (code >= 51 && code <= 67) return [Colors.blueGrey.shade800, Colors.blue.shade900]; // Rain
     if (code >= 71 && code <= 77) return [Colors.lightBlue.shade200, Colors.grey.shade300]; // Snow
     
     return [Colors.indigo.shade900, Colors.purple.shade900];
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading && _weatherData == null) {
      return Container(
        height: 200,
        width: double.infinity,
        decoration: BoxDecoration(color: Colors.black26, borderRadius: BorderRadius.circular(24)),
        child: const Center(child: CircularProgressIndicator(strokeWidth: 2)),
      );
    }

    if (_weatherData == null) {
      // Permission prompt
      return GestureDetector(
        onTap: () async {

           final permission = await Geolocator.requestPermission();
           if (permission != LocationPermission.denied && permission != LocationPermission.deniedForever) {
              setState(() => _isLoading = true);
              _fetchWeather();
           }
        },
        child: Container(
           padding: const EdgeInsets.all(20),
           decoration: BoxDecoration(color: Colors.black26, borderRadius: BorderRadius.circular(24)),
           child: const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                 Text("Personalize your mornings", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18)),
                 SizedBox(height: 8),
                 Text("Use location for:\n✓ weather\n✓ sunrise\n✓ daily conditions", style: TextStyle(color: Colors.white70)),
                 SizedBox(height: 12),
                 Text("Tap to allow →", style: TextStyle(color: Colors.blueAccent, fontWeight: FontWeight.bold)),
              ]
           )
        )
      );
    }
    
    // Build hourly forecast
    List<HourlyForecast> upcoming = _weatherData!.hourly.where((h) => h.time.isAfter(DateTime.now().subtract(const Duration(hours: 1)))).take(6).toList();
    
    String sunriseStr = "6:00";
    String sunsetStr = "18:00";
    if (_weatherData!.daily.isNotEmpty) {
       sunriseStr = DateFormat('H:mm').format(_weatherData!.daily.first.sunrise);
       sunsetStr = DateFormat('H:mm').format(_weatherData!.daily.first.sunset);
    }

    return AnimatedBuilder(
      animation: _bgAnimController,
      builder: (context, child) {
        return Container(
          width: double.infinity,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(24),
            gradient: LinearGradient(
              colors: _getWeatherGradients(),
              begin: Alignment.topLeft,
              end: Alignment(1.0, _bgAnimController.value * 2 - 1.0), // subtle movement
            ),
            boxShadow: [
              BoxShadow(color: Colors.black.withOpacity(0.3), blurRadius: 15, offset: const Offset(0, 5)),
            ],
          ),
          child: ClipRRect(
             borderRadius: BorderRadius.circular(24),
             child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 5, sigmaY: 5),
                child: Padding(
                   padding: const EdgeInsets.all(24.0),
                   child: Column(
                     crossAxisAlignment: CrossAxisAlignment.start,
                     children: [
                        Row(
                           mainAxisAlignment: MainAxisAlignment.spaceBetween,
                           crossAxisAlignment: CrossAxisAlignment.start,
                           children: [
                              Expanded(
                                child: Text('${GreetingUtils.getGreeting()}, $_userName ${_weatherData!.iconEmoji}', style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold), maxLines: 2, overflow: TextOverflow.ellipsis),
                              ),
                              const SizedBox(width: 12),
                              Text('${_weatherData!.temperature.floor()}°C', style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.w900)),
                           ]
                        ),
                        const SizedBox(height: 4),
                        Text(_weatherData!.conditionTitle, style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w500)),
                        const SizedBox(height: 8),
                        Expanded(
                             flex: 0,
                             child: Text(_weatherData!.contextSentence, style: const TextStyle(color: Colors.white70, fontSize: 14), maxLines: 2, overflow: TextOverflow.ellipsis),
                          ),
                        
                        const Padding(
                           padding: EdgeInsets.symmetric(vertical: 16.0),
                           child: Divider(color: Colors.white24, height: 1),
                        ),
                        
                        SizedBox(
                           height: 60,
                           child: ListView.builder(
                              scrollDirection: Axis.horizontal,
                              itemCount: upcoming.length,
                              itemBuilder: (context, i) {
                                 final h = upcoming[i];
                                 String timeStr = DateFormat('h a').format(h.time);
                                 if (i == 0) timeStr = "Now";
                                 
                                 // Basic icon mapping for hourly
                                 String emoji = '☀️';
                                 if (h.weatherCode >= 51 && h.weatherCode <= 67) emoji = '🌧️';
                                 else if (h.weatherCode >= 1 && h.weatherCode <= 3) emoji = '☁️';
                                 else if (h.weatherCode >= 71) emoji = '❄️';
                                 
                                 return Padding(
                                    padding: const EdgeInsets.only(right: 24.0),
                                    child: Column(
                                       children: [
                                          Text(timeStr, style: const TextStyle(color: Colors.white70, fontSize: 12)),
                                          const SizedBox(height: 4),
                                          Text('$emoji ${h.temperature.floor()}°', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
                                          if (h.precipitationProbability > 0)
                                             Text('${h.precipitationProbability}%', style: const TextStyle(color: Colors.lightBlueAccent, fontSize: 10, fontWeight: FontWeight.bold)),
                                       ]
                                    )
                                 );
                              }
                           )
                        ),
                        
                        const Padding(
                           padding: EdgeInsets.symmetric(vertical: 16.0),
                           child: Divider(color: Colors.white24, height: 1),
                        ),
                        
                        FittedBox(
                           fit: BoxFit.scaleDown,
                           child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceAround,
                              children: [
                                 Row(
                                    children: [
                                       const Icon(Icons.wb_twighlight, color: Colors.amberAccent, size: 20),
                                       const SizedBox(width: 8),
                                       Text('Sunrise $sunriseStr', style: const TextStyle(color: Colors.white70, fontSize: 12)),
                                    ]
                                 ),
                                 const SizedBox(width: 16),
                                 Row(
                                    children: [
                                       const Icon(Icons.nights_stay, color: Colors.indigoAccent, size: 20),
                                       const SizedBox(width: 8),
                                       Text('Sunset $sunsetStr', style: const TextStyle(color: Colors.white70, fontSize: 12)),
                                    ]
                                 )
                              ]
                           ),
                        )
                     ],
                   )
                )
             )
          )
        );
      }
    );
  }
}
