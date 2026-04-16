import 'package:flutter/material.dart';

/// Session recap modal — session start pop-up.
/// TODO: implement per docs/ux-flows.md §6
class SessionRecapModal extends StatelessWidget {
  const SessionRecapModal({super.key});

  @override
  Widget build(BuildContext context) {
    return const Dialog(
      child: Padding(
        padding: EdgeInsets.all(24),
        child: Text('Crumbs — Session Recap'),
      ),
    );
  }
}
