import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/activities_provider.dart';

class TipDisplay extends StatefulWidget {
  const TipDisplay({super.key});

  @override
  State<TipDisplay> createState() => _TipDisplayState();
}

class _TipDisplayState extends State<TipDisplay> {
  String? _tip;
  bool _loading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadTip();
  }

  Future<void> _loadTip() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    final provider = Provider.of<ActivitiesProvider>(context, listen: false);
    final tip = await provider.getTip();
    if (mounted) {
      setState(() {
        _tip = tip;
        _loading = false;
        _error = tip == null ? 'No tip available' : null;
      });

      // Show dialog if all tips have been shown
      if (tip != null && tip.startsWith("You've seen all the tips")) {
        if (mounted) {
          showDialog(
            context: context,
            builder: (context) => AlertDialog(
              title: const Text('All Tips Shown'),
              content: const Text(
                  'You\'ve seen all the available tips! Starting fresh...'),
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
      appBar: AppBar(title: const Text('Helpful Tip')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(
                  child: Text('Error: $_error',
                      style: const TextStyle(color: Colors.red)))
              : _tip == null
                  ? const Center(
                      child: Text('No tip available',
                          style: TextStyle(fontSize: 16)))
                  : SingleChildScrollView(
                      child: Padding(
                        padding: const EdgeInsets.all(24.0),
                        child: Column(
                          children: [
                            const Icon(Icons.lightbulb_outline,
                                size: 64, color: Colors.amber),
                            const SizedBox(height: 24),
                            Text(
                              _tip!,
                              style: Theme.of(context)
                                  .textTheme
                                  .bodyLarge
                                  ?.copyWith(height: 1.5),
                              textAlign: TextAlign.justify,
                            ),
                            const SizedBox(height: 32),
                            ElevatedButton(
                              onPressed: _loadTip,
                              child: const Text('Get Another Tip'),
                            ),
                          ],
                        ),
                      ),
                    ),
    );
  }
}
