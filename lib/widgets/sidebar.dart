import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:path/path.dart' as p;
import '../models/markdown_file.dart';

class Sidebar extends StatelessWidget {
  final List<MarkdownFile> recentFiles;
  final MarkdownFile? currentFile;
  final VoidCallback onOpenFile;
  final Function(MarkdownFile) onSelectFile;

  const Sidebar({
    super.key,
    required this.recentFiles,
    this.currentFile,
    required this.onOpenFile,
    required this.onSelectFile,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final sidebarBg = isDark
        ? const Color(0xFF161622)
        : const Color(0xFFEEEEEB);

    return Container(
      decoration: BoxDecoration(
        color: sidebarBg,
        border: Border(
          right: BorderSide(
            color: cs.onSurface.withValues(alpha: 0.08),
            width: 1,
          ),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Open button
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
            child: _OpenButton(onTap: onOpenFile),
          ),

          // Recent files section
          if (recentFiles.isNotEmpty) ...[
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 6),
              child: Text(
                'RECENT',
                style: GoogleFonts.inter(
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 1.2,
                  color: cs.onSurface.withValues(alpha: 0.35),
                ),
              ),
            ),
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                itemCount: recentFiles.length,
                itemBuilder: (context, i) {
                  final file = recentFiles[i];
                  final isActive = currentFile?.path == file.path;
                  return _FileItem(
                    file: file,
                    isActive: isActive,
                    onTap: () => onSelectFile(file),
                  );
                },
              ),
            ),
          ] else
            Expanded(
              child: Center(
                child: Text(
                  'No recent files',
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    color: cs.onSurface.withValues(alpha: 0.3),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _OpenButton extends StatefulWidget {
  final VoidCallback onTap;
  const _OpenButton({required this.onTap});

  @override
  State<_OpenButton> createState() => _OpenButtonState();
}

class _OpenButtonState extends State<_OpenButton> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 120),
          width: double.infinity,
          height: 36,
          decoration: BoxDecoration(
            color: _hovered
                ? cs.primary.withValues(alpha: 0.15)
                : cs.primary.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: cs.primary.withValues(alpha: 0.25),
              width: 1,
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.add_rounded, size: 15, color: cs.primary),
              const SizedBox(width: 6),
              Text(
                'Open file',
                style: GoogleFonts.inter(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: cs.primary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _FileItem extends StatefulWidget {
  final MarkdownFile file;
  final bool isActive;
  final VoidCallback onTap;

  const _FileItem({
    required this.file,
    required this.isActive,
    required this.onTap,
  });

  @override
  State<_FileItem> createState() => _FileItemState();
}

class _FileItemState extends State<_FileItem> {
  bool _hovered = false;

  String _formatDate(DateTime dt) {
    final now = DateTime.now();
    final diff = now.difference(dt);
    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inHours < 1) return '${diff.inMinutes}m ago';
    if (diff.inDays < 1) return '${diff.inHours}h ago';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    return '${dt.day}/${dt.month}/${dt.year}';
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final dirName = p.dirname(widget.file.path).split('/').last;

    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 100),
          margin: const EdgeInsets.only(bottom: 2),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          decoration: BoxDecoration(
            color: widget.isActive
                ? cs.primary.withValues(alpha: isDark ? 0.2 : 0.12)
                : _hovered
                    ? cs.onSurface.withValues(alpha: 0.06)
                    : Colors.transparent,
            borderRadius: BorderRadius.circular(7),
            border: widget.isActive
                ? Border.all(
                    color: cs.primary.withValues(alpha: 0.3),
                    width: 1,
                  )
                : null,
          ),
          child: Row(
            children: [
              Icon(
                Icons.article_outlined,
                size: 15,
                color: widget.isActive
                    ? cs.primary
                    : cs.onSurface.withValues(alpha: 0.4),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.file.name,
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        fontWeight: widget.isActive
                            ? FontWeight.w600
                            : FontWeight.w400,
                        color: cs.onSurface.withValues(
                          alpha: widget.isActive ? 0.95 : 0.75,
                        ),
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      '${_formatDate(widget.file.lastOpened)} · $dirName',
                      style: GoogleFonts.inter(
                        fontSize: 10,
                        color: cs.onSurface.withValues(alpha: 0.35),
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
