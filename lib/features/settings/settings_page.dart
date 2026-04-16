import 'package:flutter/material.dart';

/// Settings ekranı — boş scaffold.
/// TODO: implement per docs/ux-flows.md §8
class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(
        child: Text('Crumbs — Settings'),
      ),
    );
  }
}
