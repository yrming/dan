import 'package:flutter/widgets.dart';
import 'package:webview_flutter_platform_interface/webview_flutter_platform_interface.dart';

/// In-memory web view for testing document loading without a native view.
class FakeWebViewPlatform extends WebViewPlatform {
  final requests = <Uri>[];
  late FakeNavigationDelegate delegate;
  Exception? loadError;
  Color? backgroundColor;

  @override
  PlatformWebViewController createPlatformWebViewController(
    PlatformWebViewControllerCreationParams params,
  ) => _Controller(params, this);

  @override
  PlatformNavigationDelegate createPlatformNavigationDelegate(
    PlatformNavigationDelegateCreationParams params,
  ) => delegate = FakeNavigationDelegate(params);

  @override
  PlatformWebViewWidget createPlatformWebViewWidget(
    PlatformWebViewWidgetCreationParams params,
  ) => _Widget(params);
}

class _Controller extends PlatformWebViewController {
  _Controller(super.params, this.platform) : super.implementation();

  final FakeWebViewPlatform platform;

  @override
  Future<void> setPlatformNavigationDelegate(
    PlatformNavigationDelegate handler,
  ) async {}

  @override
  Future<void> setJavaScriptMode(JavaScriptMode mode) async {}

  @override
  Future<void> setBackgroundColor(Color color) async {
    platform.backgroundColor = color;
  }

  @override
  Future<void> loadRequest(LoadRequestParams params) async {
    platform.requests.add(params.uri);
    if (platform.loadError case final error?) throw error;
  }
}

class _Widget extends PlatformWebViewWidget {
  _Widget(super.params) : super.implementation();

  @override
  Widget build(BuildContext context) => const SizedBox.expand();
}

/// Exposes native page callbacks to widget tests.
class FakeNavigationDelegate extends PlatformNavigationDelegate {
  FakeNavigationDelegate(super.params) : super.implementation();

  late PageEventCallback onStarted;
  late PageEventCallback onFinished;
  late WebResourceErrorCallback onError;
  late HttpResponseErrorCallback onHttpError;
  late NavigationRequestCallback onNavigation;

  @override
  Future<void> setOnPageStarted(PageEventCallback callback) async {
    onStarted = callback;
  }

  @override
  Future<void> setOnPageFinished(PageEventCallback callback) async {
    onFinished = callback;
  }

  @override
  Future<void> setOnWebResourceError(WebResourceErrorCallback callback) async {
    onError = callback;
  }

  @override
  Future<void> setOnHttpError(HttpResponseErrorCallback callback) async {
    onHttpError = callback;
  }

  @override
  Future<void> setOnNavigationRequest(
    NavigationRequestCallback callback,
  ) async {
    onNavigation = callback;
  }
}
