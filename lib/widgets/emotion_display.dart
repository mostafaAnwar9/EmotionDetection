import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:emotion_detection_app/providers/emotion_provider.dart';
import 'package:emotion_detection_app/providers/activities_provider.dart';
import 'package:emotion_detection_app/widgets/activities_menu.dart';

class EmotionDisplay extends StatefulWidget {
  const EmotionDisplay({super.key});

  @override
  State<EmotionDisplay> createState() => _EmotionDisplayState();
}

class _EmotionDisplayState extends State<EmotionDisplay> {
  String? _lastEmotion;

  void _handleEmotionChange(String? newEmotion) {
    if (newEmotion != null &&
        newEmotion != _lastEmotion &&
        !['happy', 'neutral'].contains(newEmotion)) {
      _lastEmotion = newEmotion;
      // Use Future.microtask to schedule the state change after the build
      Future.microtask(() {
        if (mounted) {
          Provider.of<ActivitiesProvider>(context, listen: false)
              .fetchActivities(newEmotion);
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer2<EmotionProvider, ActivitiesProvider>(
      builder: (context, emotionProvider, activitiesProvider, child) {
        // Handle emotion changes
        _handleEmotionChange(emotionProvider.currentEmotion);

        if (emotionProvider.isLoading) {
          return const Padding(
            padding: EdgeInsets.all(16.0),
            child: Center(
              child: CircularProgressIndicator(),
            ),
          );
        }

        if (emotionProvider.error != null) {
          return Padding(
            padding: const EdgeInsets.all(16.0),
            child: Text(
              'Error: ${emotionProvider.error}',
              style: const TextStyle(color: Colors.red),
            ),
          );
        }

        if (emotionProvider.currentEmotion == null) {
          return const Padding(
            padding: EdgeInsets.all(16.0),
            child: Text(
              'Take a picture to detect emotion',
              style: TextStyle(fontSize: 16),
            ),
          );
        }

        return SizedBox(
          height: MediaQuery.of(context).size.height * 0.4,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(16.0),
                color: Theme.of(context).colorScheme.surfaceVariant,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Detected Emotion:',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      emotionProvider.currentEmotion!.toUpperCase(),
                      style:
                          Theme.of(context).textTheme.headlineMedium?.copyWith(
                                color: Theme.of(context).colorScheme.primary,
                                fontWeight: FontWeight.bold,
                              ),
                    ),
                  ],
                ),
              ),
              if (!['happy', 'neutral']
                  .contains(emotionProvider.currentEmotion))
                Expanded(
                  child: ActivitiesMenu(
                    emotion: emotionProvider.currentEmotion!,
                  ),
                )
              else
                Expanded(
                  child: Center(
                    child: Text(
                      'Great! You\'re feeling ${emotionProvider.currentEmotion}',
                      style: Theme.of(context).textTheme.titleLarge,
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}
