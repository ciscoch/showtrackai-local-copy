import 'package:flutter/material.dart';

// Minimal Flutter app to test if basic rendering works
class MinimalTestApp extends StatelessWidget {
  const MinimalTestApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    print('🎨 MinimalTestApp build() called');
    
    return MaterialApp(
      title: 'Flutter Black Screen Test',
      home: const MinimalTestScreen(),
      debugShowCheckedModeBanner: false,
    );
  }
}

class MinimalTestScreen extends StatelessWidget {
  const MinimalTestScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    print('🖥️ MinimalTestScreen build() called');
    
    return Scaffold(
      backgroundColor: Colors.white, // Force white background
      body: Container(
        width: double.infinity,
        height: double.infinity,
        color: Colors.white, // Double-ensure white background
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // Big success indicator
            Container(
              padding: const EdgeInsets.all(30),
              decoration: BoxDecoration(
                color: Colors.green,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: Colors.grey.withOpacity(0.5),
                    spreadRadius: 5,
                    blurRadius: 7,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: const Column(
                children: [
                  Icon(
                    Icons.check_circle,
                    color: Colors.white,
                    size: 80,
                  ),
                  SizedBox(height: 20),
                  Text(
                    '🎉 FLUTTER IS WORKING!',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  SizedBox(height: 10),
                  Text(
                    'If you can see this screen, Flutter is rendering correctly',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                    ),
                  ),
                ],
              ),
            ),
            
            const SizedBox(height: 40),
            
            // Test different colors
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _buildColorBox(Colors.red, 'RED'),
                _buildColorBox(Colors.blue, 'BLUE'),
                _buildColorBox(Colors.orange, 'ORANGE'),
                _buildColorBox(Colors.purple, 'PURPLE'),
              ],
            ),
            
            const SizedBox(height: 40),
            
            // Test buttons
            ElevatedButton(
              onPressed: () {
                print('🔘 Test button pressed!');
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                  horizontal: 30,
                  vertical: 15,
                ),
              ),
              child: const Text(
                'Test Button - Check Console',
                style: TextStyle(fontSize: 16),
              ),
            ),
            
            const SizedBox(height: 20),
            
            // Instructions
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.blue.withOpacity(0.1),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.blue),
              ),
              child: const Column(
                children: [
                  Text(
                    '🔍 What This Test Shows:',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.black,
                    ),
                  ),
                  SizedBox(height: 10),
                  Text(
                    '✅ If you see this colorful screen: Flutter works fine!\n'
                    '❌ If you see black screen: Flutter initialization issue\n'
                    '⚠️ If you see white screen: Theme/color issue\n\n'
                    'Check browser console for additional debug info.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.black87,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
  
  static Widget _buildColorBox(Color color, String label) {
    return Container(
      width: 60,
      height: 60,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.black, width: 2),
      ),
      child: Center(
        child: Text(
          label,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 10,
          ),
          textAlign: TextAlign.center,
        ),
      ),
    );
  }
}