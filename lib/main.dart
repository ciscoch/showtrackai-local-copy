import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'screens/dashboard_screen.dart';
import 'screens/journal_entry_form.dart';
import 'screens/journal_entry_form_page.dart';
import 'screens/journal_list_page.dart';
import 'screens/login_screen.dart';
import 'screens/animal_create_screen.dart';
import 'screens/animal_list_screen.dart';
import 'screens/animal_detail_screen.dart';
import 'models/animal.dart';
import 'services/auth_service.dart';
import 'theme/app_theme.dart';
import 'debug/theme_diagnostic.dart';

void main() async {
  print('🚀 Starting ShowTrackAI Journaling App');
  
  WidgetsFlutterBinding.ensureInitialized();
  
  try {
    // Initialize Supabase with working credentials (validated via API test)
    print('🔗 Initializing Supabase...');
    await Supabase.initialize(
      url: 'https://zifbuzsdhparxlhsifdi.supabase.co',
      anonKey: 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InppZmJ1enNkaHBhcnhsaHNpZmRpIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NTIwMTUzOTEsImV4cCI6MjA2NzU5MTM5MX0.Lmg6kZ0E35Q9nNsJei9CDxH2uUQZO4AJaiU6H3TvXqU',
    );
    print('✅ Supabase initialized successfully');
    
    // Initialize AuthService
    AuthService().initialize();
    print('✅ AuthService initialized');
    
    // Test connection with a simple query
    try {
      final client = Supabase.instance.client;
      print('📊 Testing database connection...');
      // Just check if we can reach the API
      await client.from('animals').select('id').limit(1);
      print('✅ Database connection verified');
    } catch (dbError) {
      print('⚠️ Database test failed: $dbError');
      print('📝 Database connection issues - app may not function properly');
    }
  } catch (e) {
    print('❌ Supabase initialization failed: $e');
    print('📝 Error details: ${e.toString()}');
    print('🚨 App requires Supabase connection to function');
  }
  
  print('🎬 Starting ShowTrackAI app...');
  runApp(const ShowTrackAIJournaling());
}

class ShowTrackAIJournaling extends StatelessWidget {
  const ShowTrackAIJournaling({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    print('🎨 Building MaterialApp...');
    
    return MaterialApp(
      title: 'ShowTrackAI Journaling',
      theme: AppTheme.lightTheme.copyWith(
        // Extra safety: ensure all backgrounds are explicitly white
        scaffoldBackgroundColor: Colors.white,
        canvasColor: Colors.white,
        colorScheme: AppTheme.lightTheme.colorScheme.copyWith(
          surface: Colors.white,
        ),
      ),
      debugShowCheckedModeBanner: false,
      initialRoute: '/login',
      // Add error handling
      builder: (context, child) {
        print('🏗️ MaterialApp builder called with child: ${child?.runtimeType}');
        return Container(
          color: Colors.white,
          child: child,
        );
      },
      routes: {
        '/': (context) {
          print('🏠 Navigating to root route (redirecting to login)');
          return const LoginScreen();
        },
        '/login': (context) {
          print('🔐 Navigating to login route');
          return const LoginScreen();
        },
        '/debug': (context) {
          print('🔍 Navigating to debug route');
          return const ThemeDiagnosticScreen();
        },
        '/dashboard': (context) => const DashboardScreen(),
        '/journal': (context) => const JournalListPage(),
        '/journal/new': (context) => const JournalEntryFormPage(),
        '/projects': (context) => const Placeholder(), // TODO: Add projects screen
        '/animals': (context) => const AnimalListScreen(),
        '/animals/create': (context) => const AnimalCreateScreen(),
        '/records': (context) => const Placeholder(), // TODO: Add records screen
        '/tasks': (context) => const Placeholder(), // TODO: Add tasks screen
        '/profile': (context) => const Placeholder(), // TODO: Add profile screen
        '/settings': (context) => const Placeholder(), // TODO: Add settings screen
      },
      onGenerateRoute: (settings) {
        // Handle dynamic routes like animal detail pages
        if (settings.name?.startsWith('/animals/') == true) {
          final uri = Uri.parse(settings.name!);
          if (uri.pathSegments.length == 2 && uri.pathSegments[1] != 'create') {
            // This is an animal detail route: /animals/{id}
            final animalId = uri.pathSegments[1];
            final animal = settings.arguments as Animal?;
            if (animal != null) {
              return MaterialPageRoute<bool>(
                builder: (context) => AnimalDetailScreen(animal: animal),
                settings: settings,
              );
            }
          }
        }
        
        // Handle journal detail routes
        if (settings.name?.startsWith('/journal/') == true) {
          final uri = Uri.parse(settings.name!);
          if (uri.pathSegments.length == 2 && uri.pathSegments[1] != 'new') {
            // This could be a journal detail route
            return MaterialPageRoute(
              builder: (context) => const Placeholder(), // TODO: Add journal detail screen
              settings: settings,
            );
          }
        }
        
        // Return null to let the default route handling take over
        return null;
      },
    );
  }
}
