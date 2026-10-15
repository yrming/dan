import 'package:dan/app/navigation/routes.dart';

/// Main shell tabs.
enum AppShellTab {
  /// Home timeline.
  home(AppRouteName.home, AppRoutePath.home),

  /// Mentions timeline.
  mentions(AppRouteName.mentions, AppRoutePath.mentions),

  /// Browse hub.
  browse(AppRouteName.browse, AppRoutePath.browse),

  /// Active account profile.
  mine(AppRouteName.mine, AppRoutePath.mine);

  const AppShellTab(this.routeName, this.path);

  /// Named route for the tab root.
  final String routeName;

  /// Absolute path for the tab root.
  final String path;

  /// Finds the active tab from the stateful shell branch [index].
  static AppShellTab fromIndex(int index) {
    return AppShellTab.values.elementAtOrNull(index) ?? AppShellTab.home;
  }
}
