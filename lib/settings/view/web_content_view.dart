import 'dart:async';

import 'package:dan/app/theme/theme.dart';
import 'package:dan/app/view/app_subpage_app_bar.dart';
import 'package:dan/app/widgets/widgets.dart';
import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';

/// Displays a legal document with native web rendering and loading feedback.
class WebContentView extends StatefulWidget {
  /// Creates a document reader.
  const WebContentView({required this.title, required this.uri, super.key});

  /// Localized navigation title.
  final String title;

  /// Document to display.
  final Uri uri;

  @override
  State<WebContentView> createState() => _WebContentViewState();
}

class _WebContentViewState extends State<WebContentView> {
  late final WebViewController _controller;
  late Uri _currentUri;
  bool _loading = true;
  bool _failed = false;

  @override
  void initState() {
    super.initState();
    _currentUri = widget.uri;
    _controller = WebViewController();
    unawaited(_load());
  }

  Color get _backgroundColor => context.appColors.bgBase;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    unawaited(_controller.setBackgroundColor(_backgroundColor));
  }

  Future<void> _load() async {
    _update(loading: true, failed: false);
    try {
      await _controller.setJavaScriptMode(JavaScriptMode.unrestricted);
      if (!mounted) return;
      await _controller.setNavigationDelegate(
        NavigationDelegate(
          onPageStarted: (url) {
            _currentUri = Uri.parse(url);
            _update(loading: true, failed: false);
          },
          onPageFinished: (_) => _update(loading: false, failed: _failed),
          onWebResourceError: (error) {
            if (error.isForMainFrame ?? false) {
              _update(loading: false, failed: true);
            }
          },
          onHttpError: (error) {
            if (error.request?.uri == _currentUri) {
              _update(loading: false, failed: true);
            }
          },
          onNavigationRequest: (request) {
            final uri = Uri.tryParse(request.url);
            return uri != null &&
                    (uri.scheme == 'https' || uri.scheme == 'http')
                ? NavigationDecision.navigate
                : NavigationDecision.prevent;
          },
        ),
      );
      if (!mounted) return;
      await _controller.loadRequest(widget.uri);
    } on Exception {
      _update(loading: false, failed: true);
    }
  }

  void _update({required bool loading, required bool failed}) {
    if (!mounted) return;
    setState(() {
      _loading = loading;
      _failed = failed;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppSubpageAppBar(
        title: widget.title,
        toolbarHeight: context.appSizing.appBarToolbarHeight,
      ),
      // The web page owns the full content area, including the bottom system
      // inset. Keeping a SafeArea here would expose the Scaffold background
      // as a white strip below the WebView on devices with a home indicator.
      body: ColoredBox(
        color: _backgroundColor,
        child: Stack(
          children: [
            Offstage(
              offstage: _failed,
              child: WebViewWidget(controller: _controller),
            ),
            if (_loading) const LinearProgressIndicator(),
            if (_failed) AppRetryView(onRetry: () => unawaited(_load())),
          ],
        ),
      ),
    );
  }
}
