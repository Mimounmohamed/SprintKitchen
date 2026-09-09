import 'package:flutter/material.dart';
import 'screens/hub_screen.dart';
import 'theme/app_colors.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'SprintKitchen',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        scaffoldBackgroundColor: AppColors.background,
        colorScheme: ColorScheme.fromSeed(
          seedColor: AppColors.gold,
          primary: AppColors.brandDark,
          secondary: AppColors.gold,
        ),
        fontFamily: 'Roboto',
      ),
      home: const HubScreen(),
    );
  }
}