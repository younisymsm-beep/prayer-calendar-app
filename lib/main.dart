import 'dart:async';
import 'package:flutter/material.dart';
import 'package:adhan/adhan.dart';
import 'package:geolocator/geolocator.dart';
import 'package:hijri/hijri_calendar.dart';
import 'package:intl/intl.dart' as intl;
import 'package:google_fonts/google_fonts.dart';

void main() {
  runApp(const PrayerApp());
}

class PrayerApp extends StatelessWidget {
  const PrayerApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'رزنامة الصلاة',
      theme: ThemeData(
        primaryColor: const Color(0xFF0D5C46),
        scaffoldBackgroundColor: const Color(0xFFF4F7F6),
        textTheme: GoogleFonts.cairoTextTheme(),
        useMaterial3: true,
      ),
      home: const MainNavigationScreen(),
    );
  }
}

class MainNavigationScreen extends StatefulWidget {
  const MainNavigationScreen({super.key});

  @override
  State<MainNavigationScreen> createState() => _MainNavigationScreenState();
}

class _MainNavigationScreenState extends State<MainNavigationScreen> {
  int _selectedIndex = 0;

  final List<Widget> _pages = [
    const PrayerTimesScreen(),
    const TasbeehScreen(),
    const AdhkarScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        body: _pages[_selectedIndex],
        bottomNavigationBar: NavigationBar(
          selectedIndex: _selectedIndex,
          onDestinationSelected: (index) => setState(() => _selectedIndex = index),
          indicatorColor: const Color(0xFF0D5C46).withOpacity(0.2),
          destinations: const [
            NavigationDestination(
              icon: Icon(Icons.mosque_outlined),
              selectedIcon: Icon(Icons.mosque, color: Color(0xFF0D5C46)),
              label: 'مواقيت الصلاة',
            ),
            NavigationDestination(
              icon: Icon(Icons.fingerprint),
              selectedIcon: Icon(Icons.fingerprint, color: Color(0xFF0D5C46)),
              label: 'السبحة',
            ),
            NavigationDestination(
              icon: Icon(Icons.menu_book_outlined),
              selectedIcon: Icon(Icons.menu_book, color: Color(0xFF0D5C46)),
              label: 'الأذكار',
            ),
          ],
        ),
      ),
    );
  }
}

// ==========================================
// 1. شاشة مواقيت الصلاة والعد التنازلي
// ==========================================
class PrayerTimesScreen extends StatefulWidget {
  const PrayerTimesScreen({super.key});

  @override
  State<PrayerTimesScreen> createState() => _PrayerTimesScreenState();
}

class _PrayerTimesScreenState extends State<PrayerTimesScreen> {
  PrayerTimes? _prayerTimes;
  String _statusMessage = "جاري تحديد الموقع وحساب المواقيت...";
  Timer? _timer;
  Duration _timeUntilNext = Duration.zero;
  String _nextPrayerName = "";

  @override
  void initState() {
    super.initState();
    _initLocationAndPrayers();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _initLocationAndPrayers() async {
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        setState(() => _statusMessage = "يرجى تفعيل خدمة الموقع (GPS)");
        return;
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          setState(() => _statusMessage = "تم رفض إذن الوصول للموقع");
          return;
        }
      }

      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.medium,
      );

      final coordinates = Coordinates(position.latitude, position.longitude);
      final params = CalculationMethod.muslim_world_league.getParameters();
      params.madhab = Madhab.shafi;

      final date = DateComponents.from(DateTime.now());
      final prayerTimes = PrayerTimes(coordinates, date, params);

      setState(() {
        _prayerTimes = prayerTimes;
      });

      _startCountdown();
    } catch (e) {
      setState(() => _statusMessage = "حدث خطأ أثناء جلب الموقع: $e");
    }
  }

  void _startCountdown() {
    _updateRemainingTime();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      _updateRemainingTime();
    });
  }

  void _updateRemainingTime() {
    if (_prayerTimes == null) return;
    final now = DateTime.now();
    Prayer next = _prayerTimes!.nextPrayer();
    DateTime? nextTime = _prayerTimes!.timeForPrayer(next);

    if (next == Prayer.none || nextTime == null) {
      final tomorrow = DateComponents.from(now.add(const Duration(days: 1)));
      final tomorrowPrayers = PrayerTimes(
        _prayerTimes!.coordinates,
        tomorrow,
        _prayerTimes!.calculationParameters,
      );
      next = Prayer.fajr;
      nextTime = tomorrowPrayers.fajr;
    }

    setState(() {
      _nextPrayerName = _getArabicPrayerName(next);
      _timeUntilNext = nextTime!.difference(now);
    });
  }

  String _getArabicPrayerName(Prayer prayer) {
    switch (prayer) {
      case Prayer.fajr:
        return "الفجر";
      case Prayer.sunrise:
        return "الشروق";
      case Prayer.dhuhr:
        return "الظهر";
      case Prayer.asr:
        return "العصر";
      case Prayer.maghrib:
        return "المغرب";
      case Prayer.isha:
        return "العشاء";
      default:
        return "الفجر";
    }
  }

  String _formatDuration(Duration d) {
    if (d.isNegative) return "00:00:00";
    String twoDigits(int n) => n.toString().padLeft(2, "0");
    return "${twoDigits(d.inHours)}:${twoDigits(d.inMinutes.remainder(60))}:${twoDigits(d.inSeconds.remainder(60))}";
  }

  @override
  Widget build(BuildContext context) {
    HijriCalendar.setLocal("ar");
    final hijriDate = HijriCalendar.now();
    final gregorianDate = intl.DateFormat('yyyy/MM/dd').format(DateTime.now());

    return SafeArea(
      child: _prayerTimes == null
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const CircularProgressIndicator(color: Color(0xFF0D5C46)),
                  const SizedBox(height: 16),
                  Text(_statusMessage, style: const TextStyle(fontSize: 16)),
                  const SizedBox(height: 12),
                  ElevatedButton(
                    onPressed: _initLocationAndPrayers,
                    child: const Text("إعادة المحاولة"),
                  )
                ],
              ),
            )
          : Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                children: [
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF0D5C46), Color(0xFF168A6A)],
                        begin: Alignment.topRight,
                        end: Alignment.bottomLeft,
                      ),
                      borderRadius: BorderRadius.circular(24),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF0D5C46).withOpacity(0.3),
                          blurRadius: 12,
                          offset: const Offset(0, 6),
                        ),
                      ],
                    ),
                    child: Column(
                      children: [
                        Text(
                          "${hijriDate.hDay} ${hijriDate.longMonthName} ${hijriDate.hYear} هـ",
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          "الموافق $gregorianDate م",
                          style: const TextStyle(color: Colors.white70, fontSize: 13),
                        ),
                        const Divider(color: Colors.white24, height: 24),
                        Text(
                          "متبقي على صلاة $_nextPrayerName",
                          style: const TextStyle(color: Colors.white, fontSize: 16),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          _formatDuration(_timeUntilNext),
                          style: const TextStyle(
                            color: Colors.amberAccent,
                            fontSize: 38,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 2,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                  Expanded(
                    child: ListView(
                      children: [
                        _buildPrayerTile("الفجر", _prayerTimes!.fajr, Icons.wb_twilight),
                        _buildPrayerTile("الشروق", _prayerTimes!.sunrise, Icons.wb_sunny_outlined),
                        _buildPrayerTile("الظهر", _prayerTimes!.dhuhr, Icons.wb_sunny),
                        _buildPrayerTile("العصر", _prayerTimes!.asr, Icons.sunny_snowing),
                        _buildPrayerTile("المغرب", _prayerTimes!.maghrib, Icons.nights_stay_outlined),
                        _buildPrayerTile("العشاء", _prayerTimes!.isha, Icons.bedtime),
                      ],
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  Widget _buildPrayerTile(String name, DateTime time, IconData icon) {
    final formattedTime = intl.DateFormat('hh:mm a').format(time);
    final isNext = name == _nextPrayerName;

    return Card(
      elevation: isNext ? 3 : 0.5,
      color: isNext ? const Color(0xFFE6F4F0) : Colors.white,
      margin: const EdgeInsets.only(bottom: 10),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: isNext
            ? const BorderSide(color: Color(0xFF0D5C46), width: 1.5)
            : BorderSide.none,
      ),
      child: ListTile(
        leading: Icon(icon, color: const Color(0xFF0D5C46)),
        title: Text(
          name,
          style: TextStyle(
            fontWeight: isNext ? FontWeight.bold : FontWeight.w600,
            fontSize: 17,
          ),
        ),
        trailing: Text(
          formattedTime,
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 17,
            color: isNext ? const Color(0xFF0D5C46) : Colors.black87,
          ),
        ),
      ),
    );
  }
}

// ==========================================
// 2. شاشة السبحة الإلكترونية
// ==========================================
class TasbeehScreen extends StatefulWidget {
  const TasbeehScreen({super.key});

  @override
  State<TasbeehScreen> createState() => _TasbeehScreenState();
}

class _TasbeehScreenState extends State<TasbeehScreen> {
  int _counter = 0;
  final List<String> _adhkar = [
    "سبحان الله",
    "الحمد لله",
    "الله أكبر",
    "أستغفر الله العظيم",
    "لا إله إلا الله",
    "اللهم صل وسلم على نبينا محمد"
  ];
  int _selectedDhikrIndex = 0;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            DropdownButtonFormField<int>(
              value: _selectedDhikrIndex,
              decoration: InputDecoration(
                filled: true,
                fillColor: Colors.white,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
              items: List.generate(
                _adhkar.length,
                (index) => DropdownMenuItem(
                  value: index,
                  child: Text(_adhkar[index], style: const TextStyle(fontSize: 18)),
                ),
              ),
              onChanged: (val) {
                setState(() {
                  _selectedDhikrIndex = val!;
                  _counter = 0;
                });
              },
            ),
            const Spacer(),
            GestureDetector(
              onTap: () => setState(() => _counter++),
              child: Container(
                width: 220,
                height: 220,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: const Color(0xFF0D5C46),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF0D5C46).withOpacity(0.4),
                      blurRadius: 20,
                      spreadRadius: 5,
                    )
                  ],
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      "$_counter",
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 56,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const Text(
                      "اضغط للتسبيح",
                      style: TextStyle(color: Colors.white70, fontSize: 14),
                    ),
                  ],
                ),
              ),
            ),
            const Spacer(),
            TextButton.icon(
              onPressed: () => setState(() => _counter = 0),
              icon: const Icon(Icons.refresh, color: Colors.red),
              label: const Text("تصفير العداد", style: TextStyle(color: Colors.red, fontSize: 16)),
            ),
          ],
        ),
      ),
    );
  }
}

// ==========================================
// 3. شاشة الأذكار
// ==========================================
class AdhkarScreen extends StatelessWidget {
  const AdhkarScreen({super.key});

  final List<Map<String, String>> _adhkarList = const [
    {
      "title": "سيد الاستغفار",
      "text": "اللَّهُمَّ أَنْتَ رَبِّي لَا إِلَهَ إِلَّا أَنْتَ، خَلَقْتَنِي وَأَنَا عَبْدُكَ، وَأَنَا عَلَى عَهْدِكَ وَوَعْدِكَ مَا اسْتَطَعْتُ...",
      "count": "مرة واحدة صباحاً ومساءً"
    },
    {
      "title": "أذكار الصباح والمساء",
      "text": "أَصْبَحْنَا وَأَصْبَحَ الْمُلْكُ لِلَّهِ، وَالْحَمْدُ لِلَّهِ، لَا إِلَهَ إِلَّا اللَّهُ وَحْدَهُ لَا شَرِيكَ لَهُ...",
      "count": "مرة واحدة"
    },
    {
      "title": "الحفظ من كل سوء",
      "text": "بِسْمِ اللَّهِ الَّذِي لَا يَضُرُّ مَعَ اسْمِهِ شَيْءٌ فِي الْأَرْضِ وَلَا فِي السَّمَاءِ وَهُوَ السَّمِيعُ الْعَلِيمُ.",
      "count": "3 مرات"
    },
    {
      "title": "الرضا بالله",
      "text": "رَضِيتُ بِاللَّهِ رَبًّا، وَبِالْإِسْلَامِ دِينًا، وَبِمُحَمَّدٍ صَلَّى اللَّهُ عَلَيْهِ وَسَلَّمَ نَبِيًّا.",
      "count": "3 مرات"
    }
  ];

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _adhkarList.length,
        itemBuilder: (context, index) {
          final item = _adhkarList[index];
          return Card(
            margin: const EdgeInsets.only(bottom: 12),
            color: Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item["title"]!,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF0D5C46),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    item["text"]!,
                    style: const TextStyle(fontSize: 16, height: 1.6),
                  ),
                  const SizedBox(height: 10),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: const Color(0xFFE6F4F0),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      item["count"]!,
                      style: const TextStyle(color: Color(0xFF0D5C46), fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
