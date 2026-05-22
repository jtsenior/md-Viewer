import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';

class MermaidBlock extends StatefulWidget {
  final String source;
  final bool isDark;

  const MermaidBlock({super.key, required this.source, required this.isDark});

  @override
  State<MermaidBlock> createState() => _MermaidBlockState();
}

class _MermaidBlockState extends State<MermaidBlock> {
  late final WebViewController _controller;
  double _height = 200;
  bool _loaded = false;

  @override
  void initState() {
    super.initState();
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..addJavaScriptChannel(
        'MermaidHeight',
        onMessageReceived: (msg) {
          final h = double.tryParse(msg.message);
          if (h != null && h > 0 && mounted) {
            setState(() {
              _height = h;
              _loaded = true;
            });
          }
        },
      )
      ..loadHtmlString(_buildHtml(widget.source, widget.isDark));
  }

  @override
  void didUpdateWidget(MermaidBlock old) {
    super.didUpdateWidget(old);
    if (old.isDark != widget.isDark || old.source != widget.source) {
      setState(() {
        _loaded = false;
        _height = 200;
      });
      _controller.loadHtmlString(_buildHtml(widget.source, widget.isDark));
    }
  }

  String _buildHtml(String source, bool isDark) {
    final jsonSource = jsonEncode(source);
    final theme = isDark ? 'dark' : 'default';
    final bg = isDark ? '#1E1E2E' : '#EAEAE8';

    return '''
<!DOCTYPE html>
<html>
<head>
  <meta charset="utf-8">
  <style>
    * { margin: 0; padding: 0; box-sizing: border-box; }
    body { background: $bg; }
    #diagram { padding: 20px; display: flex; justify-content: center; align-items: flex-start; }
    svg { max-width: 100%; height: auto; display: block; }
  </style>
</head>
<body>
  <div id="diagram"></div>
  <script src="https://cdn.jsdelivr.net/npm/mermaid@11/dist/mermaid.min.js"></script>
  <script>
    mermaid.initialize({ startOnLoad: false, theme: '$theme', securityLevel: 'loose' });

    function reportHeight() {
      var h = document.getElementById('diagram').getBoundingClientRect().height;
      MermaidHeight.postMessage(String(Math.ceil(h)));
    }

    mermaid.render('mermaid-svg', $jsonSource)
      .then(function(r) {
        var el = document.getElementById('diagram');
        el.innerHTML = r.svg;

        // Remove Mermaid's hardcoded width/height so CSS controls sizing.
        var svg = el.querySelector('svg');
        if (svg) {
          svg.removeAttribute('width');
          svg.removeAttribute('height');
          svg.style.width = '100%';
          svg.style.height = 'auto';
        }

        requestAnimationFrame(function() {
          requestAnimationFrame(function() {
            reportHeight();
            // Re-report on every resize (window or layout change).
            var debounce;
            new ResizeObserver(function() {
              clearTimeout(debounce);
              debounce = setTimeout(reportHeight, 50);
            }).observe(el);
          });
        });
      })
      .catch(function(err) {
        var p = document.createElement('pre');
        p.style.cssText = 'color:#e74c3c;font-size:12px;white-space:pre-wrap;padding:8px';
        p.textContent = 'Mermaid error: ' + err.message;
        document.getElementById('diagram').appendChild(p);
        reportHeight();
      });
  </script>
</body>
</html>''';
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final bg = widget.isDark
        ? const Color(0xFF1E1E2E)
        : const Color(0xFFEAEAE8);

    return AnimatedContainer(
      duration: const Duration(milliseconds: 120),
      height: _height,
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: cs.onSurface.withValues(alpha: 0.08),
          width: 1,
        ),
      ),
      clipBehavior: Clip.hardEdge,
      child: Stack(
        children: [
          WebViewWidget(controller: _controller),
          if (!_loaded)
            Center(
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: cs.primary,
                ),
              ),
            ),
        ],
      ),
    );
  }
}