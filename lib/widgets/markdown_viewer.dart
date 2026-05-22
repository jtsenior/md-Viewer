import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/markdown_file.dart';
import '../utils/markdown_splitter.dart';
import 'mermaid_block.dart';

class MarkdownViewerWidget extends StatelessWidget {
  final MarkdownFile file;

  const MarkdownViewerWidget({super.key, required this.file});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final segments = MarkdownSplitter.split(file.content);

    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 64, vertical: 48),
      itemCount: segments.length,
      itemBuilder: (context, i) {
        final seg = segments[i];
        if (seg.isMermaid) {
          return MermaidBlock(source: seg.content, isDark: isDark);
        }
        return MarkdownBody(
          data: seg.content,
          selectable: true,
          onTapLink: (text, href, title) async {
            if (href != null) {
              final uri = Uri.tryParse(href);
              if (uri != null && await canLaunchUrl(uri)) {
                await launchUrl(uri);
              }
            }
          },
          styleSheet: _buildStyleSheet(context, isDark, cs),
        );
      },
    );
  }

  MarkdownStyleSheet _buildStyleSheet(
    BuildContext context,
    bool isDark,
    ColorScheme cs,
  ) {
    final baseColor = cs.onSurface;
    final codeBackground = isDark
        ? const Color(0xFF1E1E2E)
        : const Color(0xFFEAEAE8);
    final blockquoteBg = isDark
        ? const Color(0xFF1A1A2E)
        : const Color(0xFFF0F0ED);

    final bodyStyle = GoogleFonts.merriweather(
      fontSize: 15.5,
      height: 1.75,
      color: baseColor.withValues(alpha: 0.88),
    );

    final codeStyle = GoogleFonts.jetBrainsMono(
      fontSize: 13,
      color: isDark ? const Color(0xFF89DDFF) : const Color(0xFF2563EB),
    );

    return MarkdownStyleSheet(
      // Body
      p: bodyStyle,
      pPadding: const EdgeInsets.only(bottom: 16),

      // Headings
      h1: GoogleFonts.inter(
        fontSize: 32,
        fontWeight: FontWeight.w700,
        height: 1.25,
        color: baseColor,
        letterSpacing: -0.5,
      ),
      h1Padding: const EdgeInsets.only(top: 8, bottom: 16),
      h2: GoogleFonts.inter(
        fontSize: 24,
        fontWeight: FontWeight.w600,
        height: 1.3,
        color: baseColor,
        letterSpacing: -0.3,
      ),
      h2Padding: const EdgeInsets.only(top: 24, bottom: 12),
      h3: GoogleFonts.inter(
        fontSize: 18,
        fontWeight: FontWeight.w600,
        height: 1.35,
        color: baseColor,
      ),
      h3Padding: const EdgeInsets.only(top: 20, bottom: 10),
      h4: GoogleFonts.inter(
        fontSize: 15,
        fontWeight: FontWeight.w600,
        color: baseColor,
      ),
      h5: GoogleFonts.inter(
        fontSize: 14,
        fontWeight: FontWeight.w600,
        color: baseColor.withValues(alpha: 0.8),
      ),
      h6: GoogleFonts.inter(
        fontSize: 13,
        fontWeight: FontWeight.w600,
        color: baseColor.withValues(alpha: 0.65),
      ),

      // Code
      code: codeStyle,
      codeblockDecoration: BoxDecoration(
        color: codeBackground,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: baseColor.withValues(alpha: 0.08),
          width: 1,
        ),
      ),
      codeblockPadding: const EdgeInsets.all(20),

      // Blockquote
      blockquote: GoogleFonts.merriweather(
        fontSize: 15,
        fontStyle: FontStyle.italic,
        color: baseColor.withValues(alpha: 0.65),
        height: 1.7,
      ),
      blockquoteDecoration: BoxDecoration(
        color: blockquoteBg,
        borderRadius: BorderRadius.circular(4),
        border: Border(
          left: BorderSide(
            color: cs.primary.withValues(alpha: 0.5),
            width: 3,
          ),
        ),
      ),
      blockquotePadding: const EdgeInsets.symmetric(
        horizontal: 16,
        vertical: 12,
      ),

      // Links
      a: GoogleFonts.merriweather(
        fontSize: 15.5,
        height: 1.75,
        color: cs.primary,
        decoration: TextDecoration.underline,
        decorationColor: cs.primary.withValues(alpha: 0.4),
      ),

      // Lists
      listBullet: bodyStyle,
      listBulletPadding: const EdgeInsets.only(right: 8),
      listIndent: 24,

      // Horizontal rule
      horizontalRuleDecoration: BoxDecoration(
        border: Border(
          top: BorderSide(
            color: baseColor.withValues(alpha: 0.12),
            width: 1,
          ),
        ),
      ),

      // Table
      tableHead: GoogleFonts.inter(
        fontSize: 13,
        fontWeight: FontWeight.w600,
        color: baseColor,
      ),
      tableBody: GoogleFonts.inter(
        fontSize: 13,
        color: baseColor.withValues(alpha: 0.8),
      ),
      tableBorder: TableBorder.all(
        color: baseColor.withValues(alpha: 0.1),
        width: 1,
        borderRadius: BorderRadius.circular(6),
      ),
      tableHeadAlign: TextAlign.left,
      tableCellsPadding: const EdgeInsets.symmetric(
        horizontal: 12,
        vertical: 8,
      ),
      tableColumnWidth: const FlexColumnWidth(),

      // Checkbox
      checkbox: bodyStyle,
    );
  }
}
