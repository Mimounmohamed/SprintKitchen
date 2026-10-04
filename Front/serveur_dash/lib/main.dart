import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'screens/serveur_pos_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.landscapeLeft,
    DeviceOrientation.landscapeRight,
  ]);
  await SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
  runApp(const ServeurApp());
}

class ServeurApp extends StatelessWidget {
  const ServeurApp({super.key});
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'SprintKitchen Serveur',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF2E1F0F)),
        useMaterial3: true,
      ),
      home: const ServeurPosScreen(
        posteLabel: 'Serveur 01',
      ),
    );
  }
}
