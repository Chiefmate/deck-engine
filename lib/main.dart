import 'dart:async';
import 'deck_ukc.dart' show UkcCalculatorScreen;
import 'deck_gm_roll.dart' show GmRollScreen;
import 'package:flutter/material.dart';
import 'engine_log.dart';
import 'deck_tanks.dart' show FuelTanksScreen;
import 'deck_ballast_time.dart' show BallastTimeScreen;
import 'deck_port_codes.dart' show PortCodesScreen;
import 'deck_logbook_records.dart' show LogbookRecordsScreen;
import 'deck_organizer.dart' show DeckOrganizerScreen;
import 'deck_safety_depth.dart' show SafetyDepthScreen;
import 'deck_eta.dart' show EtaCalculatorScreen;

const navy = Color(0xFF081522);
const panel = Color(0xFF112437);
const accent = Color(0xFF4DDAC6);
const muted = Color(0xFF9BB0C3);
const outline = Color(0xFF294155);

void main() => runApp(const VesselApp());

class VesselApp extends StatelessWidget {
  const VesselApp({super.key});
  @override
  Widget build(BuildContext context) => MaterialApp(
    debugShowCheckedModeBanner: false,
    title: 'Deck + Engine',
    theme: ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      scaffoldBackgroundColor: navy,
      colorScheme: ColorScheme.fromSeed(seedColor: accent, brightness: Brightness.dark),
      appBarTheme: const AppBarTheme(backgroundColor: navy, foregroundColor: Colors.white),
    ),
    builder: (context, child) => Column(children: [
      const UtcClock(),
      Expanded(child: child ?? const SizedBox.shrink()),
    ]),
    home: const MainMenuScreen(),
  );
}

class MainMenuScreen extends StatelessWidget {
  const MainMenuScreen({super.key});
  @override
  Widget build(BuildContext context) => Scaffold(
    body: ListView(padding: const EdgeInsets.all(24), children: [
      const SizedBox(height: 24),
      const Icon(Icons.anchor, color: accent, size: 48),
      const SizedBox(height: 24),
      const Text('Deck + Engine', style: TextStyle(fontSize: 34, fontWeight: FontWeight.w700)),
      const SizedBox(height: 12),
      const Text('SELECT DEPARTMENT', style: TextStyle(color: accent, letterSpacing: 2)),
      const SizedBox(height: 32),
      MenuCard(title: 'Deck', subtitle: 'Navigation and deck operations',
        icon: Icons.explore_outlined,
        onTap: () => Navigator.of(context).push(MaterialPageRoute<void>(
          builder: (_) => const DeckScreen(),
        )),
      ),
      MenuCard(title: 'Engine', subtitle: 'EngineLog tools and records',
        icon: Icons.settings_outlined,
        onTap: () => Navigator.of(context).push(MaterialPageRoute<void>(
          builder: (_) => const EngineLogScreen(),
        )),
      ),
    ]),
  );
}

class DeckScreen extends StatelessWidget {
  const DeckScreen({super.key});
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Deck')),
    body: ListView(padding: const EdgeInsets.all(24), children: [
      const Text('Deck Tools', style: TextStyle(fontSize: 30, fontWeight: FontWeight.w700)),
      const SizedBox(height: 24),
      MenuCard(title: 'Cargo', subtitle: 'Tanks and ballast calculations',
        icon: Icons.folder_outlined,
        onTap: () => Navigator.of(context).push(MaterialPageRoute<void>(
          builder: (_) => const CargoScreen(),
        )),
      ),
      MenuCard(title: 'Navigation', subtitle: 'Port codes and navigation tools',
        icon: Icons.explore_outlined,
        onTap: () => Navigator.of(context).push(MaterialPageRoute<void>(
          builder: (_) => const NavigationScreen(),
        )),
      ),
      MenuCard(title: 'Deck Organizer', subtitle: 'Notes, documents and expiry reminders',
        icon: Icons.event_note_outlined,
        onTap: () => Navigator.of(context).push(MaterialPageRoute<void>(
          builder: (_) => const DeckOrganizerScreen(),
        )),
      ),
      MenuCard(title: 'Logbook Records', subtitle: 'Inspection wording and schedule reference',
        icon: Icons.menu_book_outlined,
        onTap: () => Navigator.of(context).push(MaterialPageRoute<void>(
          builder: (_) => const LogbookRecordsScreen(),
        )),
      ),
    ]),
  );
}

class CargoScreen extends StatelessWidget {
  const CargoScreen({super.key});
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Cargo')),
    body: ListView(padding: const EdgeInsets.all(24), children: [
      const Text('Cargo Tools', style: TextStyle(fontSize: 30, fontWeight: FontWeight.w700)),
      const SizedBox(height: 24),
      MenuCard(title: 'Tanks', subtitle: 'Water volume, density and mass on board',
        icon: Icons.storage_outlined,
        onTap: () => Navigator.of(context).push(MaterialPageRoute<void>(
          builder: (_) => Scaffold(
            appBar: AppBar(title: const Text('Tanks')),
            body: const FuelTanksScreen(),
          ),
        )),
      ),
      MenuCard(title: 'GM Estimate', subtitle: 'Estimate GM from roll period',
        icon: Icons.straighten_outlined,
        onTap: () => Navigator.of(context).push(MaterialPageRoute<void>(
          builder: (_) => const GmRollScreen(),
        )),
      ),
      MenuCard(title: 'Ballast Time', subtitle: 'Pumping duration and estimated completion',
        icon: Icons.water_outlined,
        onTap: () => Navigator.of(context).push(MaterialPageRoute<void>(
          builder: (_) => const BallastTimeScreen(),
        )),
      ),
    ]),
  );
}

class NavigationScreen extends StatelessWidget {
  const NavigationScreen({super.key});
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Navigation')),
    body: ListView(padding: const EdgeInsets.all(24), children: [
      const Text('Navigation Tools', style: TextStyle(fontSize: 30, fontWeight: FontWeight.w700)),
      const SizedBox(height: 24),
      MenuCard(title: 'ETA Calculator', subtitle: 'Arrival time and required average speed',
        icon: Icons.schedule_outlined,
        onTap: () => Navigator.of(context).push(MaterialPageRoute<void>(
          builder: (_) => const EtaCalculatorScreen(),
        )),
      ),
      MenuCard(title: 'UKC Calculator', subtitle: 'Under-keel clearance and speed comparison',
        icon: Icons.waves_outlined,
        onTap: () => Navigator.of(context).push(MaterialPageRoute<void>(
          builder: (_) => const UkcCalculatorScreen(),
        )),
      ),
      MenuCard(title: 'Safety Depth', subtitle: 'Vessel settings and safety depth calculation',
        icon: Icons.straighten_outlined,
        onTap: () => Navigator.of(context).push(MaterialPageRoute<void>(
          builder: (_) => const SafetyDepthScreen(),
        )),
      ),
      MenuCard(title: 'Port Codes', subtitle: 'Search ports by name or UN/LOCODE',
        icon: Icons.travel_explore,
        onTap: () => Navigator.of(context).push(MaterialPageRoute<void>(
          builder: (_) => const PortCodesScreen(),
        )),
      ),
    ]),
  );
}

class MenuCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final VoidCallback? onTap;
  const MenuCard({super.key, required this.title, required this.subtitle,
    required this.icon, this.onTap});
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 18),
    child: Material(color: panel, clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20),
        side: const BorderSide(color: outline)),
      child: ListTile(
        contentPadding: const EdgeInsets.all(22),
        leading: Icon(icon, color: accent, size: 34),
        title: Text(title, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w700)),
        subtitle: Text(subtitle, style: const TextStyle(color: muted)),
        trailing: Icon(onTap == null ? Icons.lock_outline : Icons.arrow_forward,
          color: onTap == null ? muted : accent),
        onTap: onTap,
      ),
    ),
  );
}

class UtcClock extends StatefulWidget {
  const UtcClock({super.key});
  @override
  State<UtcClock> createState() => _UtcClockState();
}

class _UtcClockState extends State<UtcClock> with WidgetsBindingObserver {
  DateTime _now = DateTime.now().toUtc();
  late final Timer _timer;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() => _now = DateTime.now().toUtc());
    });
  }
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && mounted) {
      setState(() => _now = DateTime.now().toUtc());
    }
  }
  @override
  void dispose() {
    _timer.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }
  String _two(int value) => value.toString().padLeft(2, '0');
  @override
  Widget build(BuildContext context) {
    final time = '${_two(_now.hour)}:${_two(_now.minute)}:${_two(_now.second)}';
    final date = '${_now.year}-${_two(_now.month)}-${_two(_now.day)}';
    return Material(color: panel, child: SafeArea(bottom: false,
      child: Container(width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
        child: Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
          const Text('UTC', style: TextStyle(color: muted)),
          Text(time, style: const TextStyle(color: accent, fontSize: 20,
            fontWeight: FontWeight.w700, fontFamily: 'monospace')),
          Text(date, style: const TextStyle(color: muted, fontSize: 11)),
        ]),
      ),
    ));
  }
}
