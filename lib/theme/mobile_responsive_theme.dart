import 'package:flutter/material.dart';

/// Mobile-responsive theme configuration specifically optimized for ShowTrackAI
/// Addresses text readability, spacing, and touch target issues on mobile devices
class MobileResponsiveTheme {
  
  /// Base theme with mobile-optimized configurations
  static ThemeData get lightTheme {
    return ThemeData(
      // Color scheme optimized for agricultural/FFA branding
      primarySwatch: MaterialColor(0xFF4CAF50, const {
        50: Color(0xFFE8F5E8),
        100: Color(0xFFC8E6C9),
        200: Color(0xFFA5D6A7),
        300: Color(0xFF81C784),
        400: Color(0xFF66BB6A),
        500: Color(0xFF4CAF50),
        600: Color(0xFF43A047),
        700: Color(0xFF388E3C),
        800: Color(0xFF2E7D32),
        900: Color(0xFF1B5E20),
      }),
      
      // Typography optimized for mobile readability
      textTheme: _getMobileTextTheme(),
      
      // Card theme with proper spacing
      cardTheme: CardThemeData(
        elevation: 2,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        margin: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
        clipBehavior: Clip.antiAlias,
      ),
      
      // Bottom navigation theme
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        selectedItemColor: Color(0xFF4CAF50),
        unselectedItemColor: Colors.grey,
        backgroundColor: Colors.white,
        elevation: 0,
        selectedLabelStyle: TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
        unselectedLabelStyle: TextStyle(fontSize: 11),
        type: BottomNavigationBarType.fixed,
      ),
      
      // Button themes with proper touch targets
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          minimumSize: const Size(88, 44), // Minimum touch target
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
        ),
      ),
      
      // Input decoration theme
      inputDecorationTheme: InputDecorationTheme(
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        floatingLabelStyle: const TextStyle(color: Color(0xFF4CAF50)),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: Color(0xFF4CAF50), width: 2),
        ),
      ),
      
      // App bar theme
      appBarTheme: const AppBarTheme(
        backgroundColor: Color(0xFF4CAF50),
        foregroundColor: Colors.white,
        elevation: 0,
        titleTextStyle: TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.w600,
          color: Colors.white,
        ),
        iconTheme: IconThemeData(color: Colors.white),
      ),
    );
  }
  
  /// Mobile-optimized text theme with proper scaling
  static TextTheme _getMobileTextTheme() {
    return const TextTheme(
      // Headlines
      headlineLarge: TextStyle(
        fontSize: 28,
        fontWeight: FontWeight.bold,
        color: Colors.black87,
        height: 1.2,
      ),
      headlineMedium: TextStyle(
        fontSize: 24,
        fontWeight: FontWeight.w600,
        color: Colors.black87,
        height: 1.2,
      ),
      headlineSmall: TextStyle(
        fontSize: 20,
        fontWeight: FontWeight.w600,
        color: Colors.black87,
        height: 1.3,
      ),
      
      // Titles
      titleLarge: TextStyle(
        fontSize: 18,
        fontWeight: FontWeight.w600,
        color: Colors.black87,
        height: 1.3,
      ),
      titleMedium: TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.w500,
        color: Colors.black87,
        height: 1.3,
      ),
      titleSmall: TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.w500,
        color: Colors.black87,
        height: 1.4,
      ),
      
      // Body text
      bodyLarge: TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.normal,
        color: Colors.black87,
        height: 1.5,
      ),
      bodyMedium: TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.normal,
        color: Colors.black87,
        height: 1.4,
      ),
      bodySmall: TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.normal,
        color: Colors.black54,
        height: 1.4,
      ),
      
      // Labels and captions
      labelLarge: TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.w500,
        color: Colors.black87,
        height: 1.4,
      ),
      labelMedium: TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.w500,
        color: Colors.black87,
        height: 1.4,
      ),
      labelSmall: TextStyle(
        fontSize: 11,
        fontWeight: FontWeight.w400,
        color: Colors.black54,
        height: 1.4,
      ),
    );
  }
}

/// Responsive utility class for consistent spacing and sizing
class ResponsiveUtils {
  
  /// Get responsive padding based on screen width
  static EdgeInsets getResponsivePadding(BuildContext context, {
    double mobile = 16,
    double tablet = 24,
    double desktop = 32,
  }) {
    final width = MediaQuery.of(context).size.width;
    
    if (width < 480) {
      return EdgeInsets.all(mobile);
    } else if (width < 768) {
      return EdgeInsets.all(tablet);
    } else {
      return EdgeInsets.all(desktop);
    }
  }
  
  /// Get responsive font size
  static double getResponsiveFontSize(BuildContext context, {
    required double baseSize,
    double scaleFactor = 1.0,
  }) {
    final width = MediaQuery.of(context).size.width;
    
    if (width < 320) {
      // Very small screens - reduce by 10%
      return baseSize * 0.9 * scaleFactor;
    } else if (width < 480) {
      // Normal mobile screens
      return baseSize * scaleFactor;
    } else {
      // Larger screens - increase slightly
      return baseSize * 1.1 * scaleFactor;
    }
  }
  
  /// Get grid configuration based on screen size
  static Map<String, dynamic> getGridConfig(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    
    if (width < 320) {
      return {'crossAxisCount': 1, 'childAspectRatio': 1.8, 'spacing': 8.0};
    } else if (width < 480) {
      return {'crossAxisCount': 2, 'childAspectRatio': 0.85, 'spacing': 12.0};
    } else if (width < 768) {
      return {'crossAxisCount': 2, 'childAspectRatio': 1.0, 'spacing': 16.0};
    } else {
      return {'crossAxisCount': 3, 'childAspectRatio': 1.1, 'spacing': 20.0};
    }
  }
  
  /// Check if screen is small (mobile phone size)
  static bool isSmallScreen(BuildContext context) {
    return MediaQuery.of(context).size.width < 480;
  }
  
  /// Check if screen is very small (older phones)
  static bool isVerySmallScreen(BuildContext context) {
    return MediaQuery.of(context).size.width < 360;
  }
  
  /// Get safe area padding for bottom navigation
  static double getSafeAreaBottomPadding(BuildContext context) {
    final mediaQuery = MediaQuery.of(context);
    return mediaQuery.padding.bottom + 16; // Extra padding for comfort
  }
}

/// Color constants for ShowTrackAI branding
class ShowTrackColors {
  // Primary FFA/Agricultural colors
  static const Color primary = Color(0xFF4CAF50);
  static const Color primaryLight = Color(0xFF66BB6A);
  static const Color primaryDark = Color(0xFF388E3C);
  
  // Degree-specific colors
  static const Color greenehandDegree = Color(0xFF4CAF50);
  static const Color chapterDegree = Color(0xFF2196F3);
  static const Color stateDegree = Color(0xFFFF9800);
  static const Color americanDegree = Color(0xFFE91E63);
  
  // Status colors
  static const Color success = Color(0xFF4CAF50);
  static const Color warning = Color(0xFFFF9800);
  static const Color error = Color(0xFFF44336);
  static const Color info = Color(0xFF2196F3);
  
  // Text colors
  static const Color textPrimary = Color(0xFF212121);
  static const Color textSecondary = Color(0xFF757575);
  static const Color textHint = Color(0xFF9E9E9E);
  
  // Background colors
  static const Color background = Color(0xFFFAFAFA);
  static const Color surface = Color(0xFFFFFFFF);
  static const Color cardBackground = Color(0xFFFFFFFF);
}