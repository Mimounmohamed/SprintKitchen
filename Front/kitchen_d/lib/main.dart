import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'kds_screen.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  // Lock to landscape — tablet mounted horizontally in the kitchen
  SystemChrome.setPreferredOrientations([
    DeviceOrientation.landscapeLeft,
    DeviceOrientation.landscapeRight,
  ]);
  SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
  runApp(const SprintKitchenKdsApp());
}

class SprintKitchenKdsApp extends StatelessWidget {
  const SprintKitchenKdsApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'SprintKitchen KDS',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        scaffoldBackgroundColor: const Color(0xFFF5F4F0),
        fontFamily: 'Roboto',
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF2E1F0F)),
      ),
      home: const KdsScreen(),
    );
  }
}
