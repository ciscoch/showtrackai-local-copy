import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'screens/dashboard_screen_local.dart';
import 'screens/journal_entry_form.dart';
import 'theme/mobile_responsive_theme.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Initialize Supabase
  await Supabase.initialize(
    url: const String.fromEnvironment('SUPABASE_URL'),
    anonKey: const String.fromEnvironment('SUPABASE_ANON_KEY'),
  );
  
  runApp(const ShowTrackAIJournaling());
}

class ShowTrackAIJournaling extends StatelessWidget {
  const ShowTrackAIJournaling({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'ShowTrackAI Journaling',
      theme: MobileResponsiveTheme.lightTheme,
      debugShowCheckedModeBanner: false,
      initialRoute: '/',
      routes: {
        '/': (context) => const DashboardScreen(),
        '/journal/new': (context) => const JournalEntryForm(),
        '/dashboard': (context) => const DashboardScreen(),
        '/projects': (context) => const Placeholder(), // TODO: Add projects screen
        '/animals': (context) => const Placeholder(), // TODO: Add animals screen
        '/records': (context) => const Placeholder(), // TODO: Add records screen
        '/tasks': (context) => const Placeholder(), // TODO: Add tasks screen
        '/profile': (context) => const Placeholder(), // TODO: Add profile screen
        '/settings': (context) => const Placeholder(), // TODO: Add settings screen
        '/login': (context) => const Placeholder(), // TODO: Add login screen
      },
    );
  }
}