import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/activities_provider.dart';

class StoryDisplay extends StatefulWidget {
  const StoryDisplay({super.key});

  @override
  State<StoryDisplay> createState() => _StoryDisplayState();
}

class _StoryDisplayState extends State<StoryDisplay> {
  String? _story;
  bool _loading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadStory();
  }

  Future<void> _loadStory() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    final provider = Provider.of<ActivitiesProvider>(context, listen: false);
    final story = await provider.getStory();
    if (mounted) {
      setState(() {
        _story = story;
        _loading = false;
        _error = story == null ? 'No story available' : null;
      });

      // Show dialog if all stories have been read
      if (story != null && story.startsWith("You've read all the stories")) {
        if (mounted) {
          showDialog(
            context: context,
            builder: (context) => AlertDialog(
              title: const Text('All Stories Read'),
              content: const Text(
                  'You\'ve read all the available stories! Starting fresh...'),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('OK'),
                ),
              ],
            ),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Uplifting Story')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(
                  child: Text('Error: $_error',
                      style: const TextStyle(color: Colors.red)))
              : _story == null
                  ? const Center(
                      child: Text('No story available',
                          style: TextStyle(fontSize: 16)))
                  : SingleChildScrollView(
                      child: Padding(
                        padding: const EdgeInsets.all(24.0),
                        child: Column(
                          children: [
                            const Icon(Icons.auto_stories,
                                size: 64, color: Colors.purple),
                            const SizedBox(height: 24),
                            Text(
                              _story!,
                              style: Theme.of(context)
                                  .textTheme
                                  .bodyLarge
                                  ?.copyWith(height: 1.5),
                              textAlign: TextAlign.justify,
                            ),
                            const SizedBox(height: 32),
                            ElevatedButton(
                              onPressed: _loadStory,
                              child: const Text('Read Another Story'),
                            ),
                          ],
                        ),
                      ),
                    ),
    );
  }
}
