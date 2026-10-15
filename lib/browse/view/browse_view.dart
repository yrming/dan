import 'package:dan/app/navigation/app_shell_tab.dart';
import 'package:dan/status/status.dart';
import 'package:flutter/material.dart';

/// Displays the public timeline on the browse tab.
class BrowseView extends StatelessWidget {
  /// Creates a browse view.
  const BrowseView({super.key});

  @override
  Widget build(BuildContext context) =>
      const StatusList(scrollToTopKey: AppShellTab.browse);
}
