import 'dart:io';
import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:provider/provider.dart';
import 'package:emotion_detection_app/providers/emotion_provider.dart';
import 'package:emotion_detection_app/providers/auth_provider.dart';
import 'package:emotion_detection_app/widgets/emotion_display.dart';
import 'package:emotion_detection_app/widgets/camera_preview.dart';
import 'package:emotion_detection_app/widgets/history_list.dart';
import 'package:emotion_detection_app/widgets/analytics_chart.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _selectedIndex = 0;
  List<CameraDescription>? _cameras;
  bool _isCameraInitialized = false;
  String? _cameraError;

  @override
  void initState() {
    super.initState();
    _initializeCamera();
  }

  Future<void> _initializeCamera() async {
    try {
      final cameras = await availableCameras();
      if (cameras.isEmpty) {
        setState(() {
          _cameraError = 'No cameras available';
          _isCameraInitialized = true;
        });
        return;
      }
      setState(() {
        _cameras = cameras;
        _isCameraInitialized = true;
      });
    } catch (e) {
      setState(() {
        _cameraError = 'Error initializing camera: $e';
        _isCameraInitialized = true;
      });
      debugPrint('Error initializing camera: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Emotion Detection'),
        actions: [
          Tooltip(
            message: 'Logout from your account',
            child: IconButton(
              icon: const Icon(Icons.logout),
              onPressed: () {
                showDialog(
                  context: context,
                  builder: (context) => AlertDialog(
                    title: const Text('Logout'),
                    content: const Text('Are you sure you want to logout?'),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: const Text('Cancel'),
                      ),
                      TextButton(
                        onPressed: () {
                          context.read<AuthProvider>().logout();
                          Navigator.pop(context);
                        },
                        child: const Text('Logout'),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
      body: !_isCameraInitialized
          ? const Center(
              child: CircularProgressIndicator(),
            )
          : _selectedIndex == 0 && _cameraError != null
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(
                        Icons.error_outline,
                        color: Colors.red,
                        size: 48,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        _cameraError!,
                        textAlign: TextAlign.center,
                        style: const TextStyle(color: Colors.red),
                      ),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: _initializeCamera,
                        child: const Text('Retry'),
                      ),
                    ],
                  ),
                )
              : IndexedStack(
                  index: _selectedIndex,
                  children: [
                    _buildCameraScreen(),
                    const HistoryList(),
                    const AnalyticsChart(),
                  ],
                ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _selectedIndex,
        onDestinationSelected: (index) {
          setState(() {
            _selectedIndex = index;
          });
        },
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.camera_alt),
            label: 'Camera',
          ),
          NavigationDestination(
            icon: Icon(Icons.history),
            label: 'History',
          ),
          NavigationDestination(
            icon: Icon(Icons.analytics),
            label: 'Analytics',
          ),
        ],
      ),
    );
  }

  Widget _buildCameraScreen() {
    if (_cameras == null || _cameras!.isEmpty) {
      return const Center(
        child: Text('No cameras available'),
      );
    }

    return Column(
      children: [
        Expanded(
          child: CameraPreviewWidget(
            cameras: _cameras!,
            onImageCaptured: (imageBytes) {
              context.read<EmotionProvider>().predictEmotion(
                    imageBytes,
                    context,
                  );
            },
          ),
        ),
        const EmotionDisplay(),
      ],
    );
  }
}
