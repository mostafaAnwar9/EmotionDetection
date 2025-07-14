import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:emotion_detection_app/providers/emotion_provider.dart';
import 'package:emotion_detection_app/providers/activities_provider.dart';
import 'package:emotion_detection_app/providers/auth_provider.dart';
import 'package:emotion_detection_app/screens/home_screen.dart';
import 'package:emotion_detection_app/screens/login_screen.dart';
import 'package:path_provider/path_provider.dart';
import 'package:camera/camera.dart';

void main() async {
  try {
    WidgetsFlutterBinding.ensureInitialized();

    final cameras = await availableCameras();
    if (cameras.isEmpty) {
      debugPrint('No cameras available');
    }

    await getTemporaryDirectory();
  } catch (e) {
    debugPrint('Error during initialization: $e');
  }
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => EmotionProvider()),
        ChangeNotifierProvider(create: (_) => ActivitiesProvider()),
        ChangeNotifierProvider(create: (_) => AuthProvider()),
      ],
      child: MaterialApp(
        title: 'Emotion Detection',
        theme: ThemeData(
          colorScheme: ColorScheme.fromSeed(seedColor: Colors.purple),
          useMaterial3: true,
        ),
        home: Consumer<AuthProvider>(
          builder: (context, auth, _) {
            if (auth.isLoading) {
              return const Scaffold(
                body: Center(
                  child: CircularProgressIndicator(),
                ),
              );
            }
            return auth.isAuthenticated
                ? const HomeScreen()
                : const LoginScreen();
          },
        ),
      ),
    );
  }
}
