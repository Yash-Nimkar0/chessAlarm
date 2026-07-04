import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:alarm/alarm.dart';
import 'dart:async';
import 'edit_alarm_screen.dart';
import '../services/elo_service.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({Key? key}) : super(key: key);

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  late List<AlarmSettings> alarms = [];
  StreamSubscription? subscription;
  int _userElo = 400;

  @override
  void initState() {
    super.initState();
    loadAlarms();
    _loadElo();
    subscription = Alarm.ringing.listen((_) {
      loadAlarms();
      _loadElo();
    });
  }

  void _loadElo() async {
    final elo = await EloService.getElo();
    if (mounted) {
      setState(() {
        _userElo = elo;
      });
    }
  }

  void loadAlarms() async {
    final fetchedAlarms = await Alarm.getAlarms();
    fetchedAlarms.sort((a, b) => a.dateTime.compareTo(b.dateTime));
    if (mounted) {
      setState(() {
        alarms = fetchedAlarms;
      });
    }
  }

  @override
  void dispose() {
    subscription?.cancel();
    super.dispose();
  }

  void navigateToAlarmScreen(AlarmSettings? settings) async {
    final res = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => EditAlarmScreen(alarmSettings: settings),
      ),
    );

    if (res != null && res == true) {
      loadAlarms();
      _loadElo();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black, // Ensure consistent dark background
      body: SafeArea(
        child: Column(
          children: [
            // Safe Custom Header
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 10),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'CHESS ALARMS', 
                    style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900, letterSpacing: 2.0, color: Colors.white)
                  ),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: BackdropFilter(
                      filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.05),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: Colors.greenAccent.withOpacity(0.3), width: 1.5),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.military_tech, color: Colors.amberAccent, size: 20),
                            const SizedBox(width: 6),
                            Text(
                              '$_userElo',
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.white),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            
            // Expanded List View
            Expanded(
              child: alarms.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.alarm_off_rounded, size: 80, color: Colors.white.withOpacity(0.1)),
                          const SizedBox(height: 16),
                          const Text(
                            'No alarms set.',
                            style: TextStyle(fontSize: 18, color: Colors.white54, fontWeight: FontWeight.w600),
                          ),
                        ],
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.all(16.0),
                      itemCount: alarms.length,
                      itemBuilder: (context, index) {
                        final alarm = alarms[index];
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 16.0),
                          child: GestureDetector(
                            onTap: () => navigateToAlarmScreen(alarm),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(24),
                              child: BackdropFilter(
                                filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
                                child: Container(
                                  decoration: BoxDecoration(
                                    color: Theme.of(context).colorScheme.surface.withOpacity(0.6),
                                    borderRadius: BorderRadius.circular(24),
                                    border: Border.all(color: Colors.white.withOpacity(0.05)),
                                  ),
                                  padding: const EdgeInsets.all(24.0),
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            DateFormat('h:mm a').format(alarm.dateTime),
                                            style: const TextStyle(
                                              fontSize: 36,
                                              fontWeight: FontWeight.w900,
                                              color: Colors.white,
                                              letterSpacing: 1.5,
                                            ),
                                          ),
                                          const SizedBox(height: 4),
                                          Text(
                                            DateFormat('EEEE, MMM d').format(alarm.dateTime),
                                            style: const TextStyle(
                                              fontSize: 14,
                                              fontWeight: FontWeight.w500,
                                              color: Colors.greenAccent,
                                              letterSpacing: 1.1,
                                            ),
                                          ),
                                        ],
                                      ),
                                      IconButton(
                                        icon: const Icon(Icons.delete_outline_rounded, color: Colors.redAccent, size: 28),
                                        onPressed: () async {
                                          await Alarm.stop(alarm.id);
                                          loadAlarms();
                                        },
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => navigateToAlarmScreen(null),
        icon: const Icon(Icons.add_alarm_rounded),
        label: const Text('NEW ALARM', style: TextStyle(fontWeight: FontWeight.w800, letterSpacing: 1.2)),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
    );
  }
}
