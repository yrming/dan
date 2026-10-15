import 'package:dan/app/navigation/app_shell_tab.dart';
import 'package:flutter/widgets.dart';

/// Exposes the selected shell tab so nested pages can react to activations.
///
/// The stateful shell keeps branch pages alive inside an indexed stack, so a
/// page cannot rely on being rebuilt to notice that its tab became active.
class AppShellTabScope extends InheritedWidget {
  /// Creates a scope around the shell navigation branches.
  const AppShellTabScope({
    required this.selectedTab,
    required super.child,
    super.key,
  });

  /// Tab that is currently displayed by the shell.
  final AppShellTab selectedTab;

  /// Returns the selected tab, registering a dependency on future changes.
  static AppShellTab of(BuildContext context) {
    final scope = context
        .dependOnInheritedWidgetOfExactType<AppShellTabScope>();
    assert(scope != null, 'AppShellTabScope is missing above $context.');
    return scope!.selectedTab;
  }

  @override
  bool updateShouldNotify(AppShellTabScope oldWidget) =>
      oldWidget.selectedTab != selectedTab;
}
