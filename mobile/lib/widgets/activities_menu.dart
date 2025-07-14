import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/activities_provider.dart';
import 'tic_tac_toe_game.dart';
import 'tip_display.dart';
import 'story_display.dart';

class ActivitiesMenu extends StatelessWidget {
  final String emotion;

  const ActivitiesMenu({
    super.key,
    required this.emotion,
  });

  @override
  Widget build(BuildContext context) {
    return Consumer<ActivitiesProvider>(
      builder: (context, provider, child) {
        if (provider.isLoading) {
          return const Center(child: CircularProgressIndicator());
        }

        if (provider.error != null) {
          return Center(
            child: Text(
              'Error: ${provider.error}',
              style: const TextStyle(color: Colors.red),
            ),
          );
        }

        if (provider.activities.isEmpty) {
          return const Center(
            child: Text(
              'No activities available for this emotion',
              style: TextStyle(fontSize: 16),
            ),
          );
        }

        return ListView.builder(
          itemCount: provider.activities.length,
          itemBuilder: (context, index) {
            final activity = provider.activities[index];
            return Card(
              margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: ListTile(
                title: Text(
                  activity['name'],
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: Theme.of(context).colorScheme.primary,
                        fontWeight: FontWeight.bold,
                      ),
                ),
                subtitle: Text(activity['description']),
                onTap: () {
                  switch (activity['id']) {
                    case 'tic_tac_toe':
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const TicTacToeGame(),
                        ),
                      );
                      break;
                    case 'tip':
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const TipDisplay(),
                        ),
                      );
                      break;
                    case 'story':
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const StoryDisplay(),
                        ),
                      );
                      break;
                  }
                },
              ),
            );
          },
        );
      },
    );
  }
}
