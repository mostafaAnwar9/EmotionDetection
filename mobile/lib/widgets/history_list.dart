import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:emotion_detection_app/providers/emotion_provider.dart';
import 'package:intl/intl.dart';

class HistoryList extends StatefulWidget {
  const HistoryList({super.key});

  @override
  State<HistoryList> createState() => _HistoryListState();
}

class _HistoryListState extends State<HistoryList> {
  @override
  void initState() {
    super.initState();
    // Fetch history when the widget is first created
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<EmotionProvider>().fetchHistory(context);
    });
  }

  DateTime _parseTimestamp(dynamic timestamp) {
    if (timestamp == null) return DateTime.now();

    if (timestamp is String) {
      try {
        // Try parsing ISO format first
        return DateTime.parse(timestamp);
      } catch (e) {
        try {
          // Try parsing MongoDB date format
          return DateFormat('EEE, dd MMM yyyy HH:mm:ss z').parse(timestamp);
        } catch (e) {
          debugPrint('Error parsing timestamp: $e');
          return DateTime.now();
        }
      }
    }

    if (timestamp is Map && timestamp['\$date'] != null) {
      // Handle MongoDB ISODate format
      return DateTime.parse(timestamp['\$date']);
    }

    return DateTime.now();
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<EmotionProvider>(
      builder: (context, provider, child) {
        if (provider.isLoading) {
          return const Center(
            child: CircularProgressIndicator(),
          );
        }

        if (provider.error != null) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  'Error: ${provider.error}',
                  style: const TextStyle(color: Colors.red),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: () => provider.fetchHistory(context),
                  child: const Text('Retry'),
                ),
              ],
            ),
          );
        }

        if (provider.history.isEmpty) {
          return const Center(
            child: Text(
              'No history available',
              style: TextStyle(fontSize: 16),
            ),
          );
        }

        return RefreshIndicator(
          onRefresh: () => provider.fetchHistory(context),
          child: ListView.builder(
            itemCount: provider.history.length,
            itemBuilder: (context, index) {
              final item = provider.history[index];
              final timestamp = _parseTimestamp(item['timestamp']);
              final formattedDate =
                  DateFormat('MMM d, y HH:mm').format(timestamp);
              final emotion =
                  item['emotion']?.toString().toUpperCase() ?? 'Unknown';

              return Card(
                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: ListTile(
                  title: Text(
                    emotion,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          color: Theme.of(context).colorScheme.primary,
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                  subtitle: Text(formattedDate),
                ),
              );
            },
          ),
        );
      },
    );
  }
}
