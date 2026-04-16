import 'package:flutter/material.dart';

/// Ana oyun ekranı — boş scaffold.
/// TODO: implement per docs/ux-flows.md §5.1
class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(
        child: Text('Crumbs — Home'),
      ),
    );
  }
}
