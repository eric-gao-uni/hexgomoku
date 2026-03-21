import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:upgrader/upgrader.dart';
import 'screens/game_screen.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
  ]);
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
      systemNavigationBarColor: Color(0xFF1A0D0D),
      systemNavigationBarIconBrightness: Brightness.light,
    ),
  );
  runApp(const HexGomokuApp());
}

class HexGomokuApp extends StatelessWidget {
  const HexGomokuApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'HexGomoku',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: const Color(0xFF1A0D0D),
        textTheme: GoogleFonts.splineSansTextTheme(
          ThemeData.dark().textTheme,
        ),
        colorScheme: const ColorScheme.dark(
          primary: Color(0xFFEC1313),
          surface: Color(0xFF1A0D0D),
        ),
      ),
      home: UpgradeAlert(
        upgrader: Upgrader(),
        dialogStyle: UpgradeDialogStyle.cupertino,
        showIgnore: false,
        showLater: false,
        child: const GameScreen(),
      ),
    );
  }
}
