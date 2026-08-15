import 'dart:async';

import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';

import '../services/news/news_models.dart';

/// Polished bottom-sheet WebView reader used by the Explore
/// screen's trending news carousel.
///
/// Tap a card → the sheet animates in with a Material draggable
/// handle, the article title is pinned in the header, and a
/// progress bar reports page load progress. Users can pull the
/// handle down to dismiss.
///
/// The WebView is given a mobile-friendly User-Agent so
/// publishers serve their responsive layout instead of a
/// "Download our app" interstitial.
class ArticleReaderSheet extends StatefulWidget {
  const ArticleReaderSheet({super.key, required this.article});

  /// Article to display. The full publisher URL is loaded into
  /// the WebView; the title / source / image are used for the
  /// header.
  final NewsArticle article;

  /// Convenience launcher used by the carousel.
  static Future<void> show(BuildContext context, NewsArticle article) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black.withValues(alpha: 0.55),
      useSafeArea: true,
      // Drag-to-dismiss interferes with WebView scroll
      // gestures — the sheet's drag handler captures vertical
      // drags before the WebView can. Users close via the X
      // button instead.
      enableDrag: false,
      builder: (_) => ArticleReaderSheet(article: article),
    );
  }

  @override
  State<ArticleReaderSheet> createState() => _ArticleReaderSheetState();
}

class _ArticleReaderSheetState extends State<ArticleReaderSheet> {
  late final WebViewController _controller;
  Timer? _dragDebounce;
  int _progress = 0;
  bool _canGoBack = false;

  @override
  void initState() {
    super.initState();
    _controller = WebViewController()
      // We disable JavaScript because:
      //   * the article is read-only HTML, no app JS is needed;
      //   * many publishers inject scripts that post messages
      //     back into a JS channel which we never set up —
      //     that triggers `Null check operator used on a null
      //     value` inside webview_flutter_android's pigeon
      //     bridge (see
      //     https://github.com/flutter/flutter/issues/150339).
      // Disabling JS avoids the crash and still renders the
      // article text + images correctly.
      ..setJavaScriptMode(JavaScriptMode.disabled)
      ..setBackgroundColor(const Color(0xFF0E0F14))
      ..setUserAgent(
        'Mozilla/5.0 (iPhone; CPU iPhone OS 17_0 like Mac OS X) '
        'AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.0 '
        'Mobile/15E148 Safari/604.1',
      )
      ..setNavigationDelegate(
        NavigationDelegate(
          onProgress: (p) {
            if (!mounted) return;
            setState(() => _progress = p);
          },
          onPageStarted: (url) {
            if (!mounted) return;
            setState(() {
              _progress = 5;
            });
          },
          onPageFinished: (url) async {
            if (!mounted) return;
            final canBack = await _controller.canGoBack();
            setState(() {
              _progress = 100;
              _canGoBack = canBack;
            });
          },
        ),
      )
      ..loadRequest(Uri.parse(widget.article.url));
  }

  @override
  void dispose() {
    _dragDebounce?.cancel();
    super.dispose();
  }

  Future<void> _goBack() async {
    if (await _controller.canGoBack()) {
      await _controller.goBack();
    }
  }

  Future<void> _reload() async {
    setState(() => _progress = 5);
    await _controller.reload();
  }

  @override
  Widget build(BuildContext context) {
    final viewInsets = MediaQuery.of(context).viewInsets;
    // Pin the sheet to ~92% of the available height. Using a
    // SizedBox with an explicit height (instead of
    // FractionallySizedBox inside a Column) guarantees the
    // child gets a definite bounded size — without that,
    // the WebView can refuse to scroll.
    final screenH = MediaQuery.of(context).size.height;
    final sheetH = (screenH * 0.92) - viewInsets.bottom;
    return AnimatedPadding(
      duration: const Duration(milliseconds: 120),
      curve: Curves.easeOut,
      padding: EdgeInsets.only(bottom: viewInsets.bottom),
      child: SizedBox(
        height: sheetH,
        child: Material(
          color: const Color(0xFF0E0F14),
          elevation: 12,
          shadowColor: Colors.black.withValues(alpha: 0.6),
          borderRadius: const BorderRadius.vertical(
            top: Radius.circular(24),
          ),
          clipBehavior: Clip.antiAlias,
          child: Column(
            mainAxisSize: MainAxisSize.max,
            children: [
              _buildHandle(),
              _buildHeader(),
              _buildProgressBar(),
              Expanded(child: _buildWebView()),
            ],
          ),
        ),
      ),
    );
  }

  /// The little draggable handle at the very top of the sheet.
  Widget _buildHandle() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8),
      alignment: Alignment.center,
      child: Container(
        width: 40,
        height: 4,
        decoration: BoxDecoration(
          color: const Color(0xFF2A2D38),
          borderRadius: BorderRadius.circular(2),
        ),
      ),
    );
  }

  /// Compact header containing only the action buttons. We
  /// intentionally leave the article title and source name
  /// out — they're already visible in the carousel card and
  /// add visual noise to the reader.
  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 6, 12, 8),
      decoration: const BoxDecoration(
        border: Border(
          bottom: BorderSide(color: Color(0xFF1A1D24), width: 1),
        ),
      ),
      child: Row(
        children: [
          const Spacer(),
          _HeaderIconButton(
            icon: Icons.arrow_back_rounded,
            enabled: _canGoBack,
            onTap: _goBack,
            tooltip: 'Back',
          ),
          const SizedBox(width: 6),
          _HeaderIconButton(
            icon: Icons.refresh_rounded,
            onTap: _reload,
            tooltip: 'Reload',
          ),
          const SizedBox(width: 6),
          _HeaderIconButton(
            icon: Icons.close_rounded,
            onTap: () => Navigator.of(context).pop(),
            tooltip: 'Close',
          ),
        ],
      ),
    );
  }

  /// Slim top progress bar that animates as the page loads.
  Widget _buildProgressBar() {
    return SizedBox(
      height: 2,
      child: AnimatedOpacity(
        duration: const Duration(milliseconds: 200),
        opacity: _progress >= 100 ? 0.0 : 1.0,
        child: LinearProgressIndicator(
          value: (_progress.clamp(0, 100)) / 100.0,
          backgroundColor: const Color(0xFF1A1D24),
          valueColor: const AlwaysStoppedAnimation(Color(0xFFD4A33A)),
          minHeight: 2,
        ),
      ),
    );
  }

  /// The WebView itself. Wrapped in a Stack so we can show an
  /// error placeholder when the load fails.
  Widget _buildWebView() {
    return Stack(
      children: [
        Positioned.fill(
          // GestureDetector with `opaque` ensures the WebView
          // receives pointer events even when nested inside the
          // bottom-sheet's gesture arena.
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () {},
            child: WebViewWidget(controller: _controller),
          ),
        ),
        // Initial loading indicator until the page actually paints.
        if (_progress < 30)
          const Positioned.fill(
            child: ColoredBox(
              color: Color(0xFF0E0F14),
              child: Center(
                child: SizedBox(
                  width: 28,
                  height: 28,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.4,
                    valueColor:
                        AlwaysStoppedAnimation(Color(0xFFD4A33A)),
                  ),
                ),
              ),
            ),
          ),
        // Empty state — never triggered normally, but helpful if
        // the URL is malformed.
        if (widget.article.url.isEmpty)
          const Positioned.fill(
            child: ColoredBox(
              color: Color(0xFF0E0F14),
              child: Center(
                child: Padding(
                  padding: EdgeInsets.all(24),
                  child: Text(
                    'This article has no URL to display.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Color(0xFF9AA0A6),
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

/// Small circular icon button used in the header. Disabled state
/// is dimmed so the user knows the action is unavailable.
class _HeaderIconButton extends StatelessWidget {
  const _HeaderIconButton({
    required this.icon,
    required this.onTap,
    required this.tooltip,
    this.enabled = true,
  });
  final IconData icon;
  final VoidCallback onTap;
  final String tooltip;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final color = enabled ? const Color(0xFFD4A33A) : const Color(0xFF555A66);
    return Tooltip(
      message: tooltip,
      child: InkResponse(
        onTap: enabled ? onTap : null,
        radius: 24,
        child: Container(
          width: 40,
          height: 40,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: color, width: 1.2),
          ),
          child: Icon(icon, color: color, size: 20),
        ),
      ),
    );
  }
}