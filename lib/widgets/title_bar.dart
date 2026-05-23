import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../models/markdown_file.dart';
import '../services/export_service.dart';

class TitleBar extends StatelessWidget {
  final MarkdownFile? currentFile;
  final bool isDark;
  final bool sidebarVisible;
  final VoidCallback onOpenFile;
  final VoidCallback onToggleTheme;
  final VoidCallback onToggleSidebar;
  final VoidCallback? onRefresh;
  final List<ExportFormat> exportFormats;
  final void Function(ExportFormat)? onExport;

  const TitleBar({
    super.key,
    this.currentFile,
    required this.isDark,
    required this.sidebarVisible,
    required this.onOpenFile,
    required this.onToggleTheme,
    required this.onToggleSidebar,
    this.onRefresh,
    this.exportFormats = const [],
    this.onExport,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final barColor = isDark
        ? const Color(0xFF1A1A28)
        : const Color(0xFFEEEEEB);

    return Container(
      height: 48,
      decoration: BoxDecoration(
        color: barColor,
        border: Border(
          bottom: BorderSide(
            color: cs.onSurface.withValues(alpha: 0.08),
            width: 1,
          ),
        ),
      ),
      child: Row(
        children: [
          // macOS traffic light area spacer
          const SizedBox(width: 72),

          // Sidebar toggle
          _BarButton(
            icon: sidebarVisible
                ? Icons.view_sidebar_outlined
                : Icons.view_sidebar,
            tooltip: 'Toggle sidebar (⌘\\)',
            onTap: onToggleSidebar,
          ),

          const SizedBox(width: 4),

          // File name / title
          Expanded(
            child: Center(
              child: Text(
                currentFile?.name ?? 'Markdown Viewer',
                style: GoogleFonts.jetBrainsMono(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: cs.onSurface.withValues(
                    alpha: currentFile != null ? 0.9 : 0.4,
                  ),
                  letterSpacing: -0.3,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ),

          // Export
          if (currentFile != null && exportFormats.isNotEmpty && onExport != null)
            _ExportButton(formats: exportFormats, onExport: onExport!),

          // Refresh
          if (onRefresh != null)
            _BarButton(
              icon: Icons.refresh_rounded,
              tooltip: 'Reload file (⌘R)',
              onTap: onRefresh!,
            ),

          // Open file
          _BarButton(
            icon: Icons.folder_open_rounded,
            tooltip: 'Open file (⌘O)',
            onTap: onOpenFile,
          ),

          // Theme toggle
          _BarButton(
            icon: isDark ? Icons.light_mode_rounded : Icons.dark_mode_rounded,
            tooltip: isDark ? 'Light mode' : 'Dark mode',
            onTap: onToggleTheme,
          ),

          const SizedBox(width: 8),
        ],
      ),
    );
  }
}

class _ExportButton extends StatelessWidget {
  final List<ExportFormat> formats;
  final void Function(ExportFormat) onExport;

  const _ExportButton({required this.formats, required this.onExport});

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<ExportFormat>(
      tooltip: 'Export',
      icon: Icon(
        Icons.file_download_outlined,
        size: 16,
        color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
      ),
      itemBuilder: (_) => formats
          .map((f) => PopupMenuItem<ExportFormat>(
                value: f,
                child: Text(f.label),
              ))
          .toList(),
      onSelected: onExport,
    );
  }
}

class _BarButton extends StatefulWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;

  const _BarButton({
    required this.icon,
    required this.tooltip,
    required this.onTap,
  });

  @override
  State<_BarButton> createState() => _BarButtonState();
}

class _BarButtonState extends State<_BarButton> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Tooltip(
      message: widget.tooltip,
      child: MouseRegion(
        onEnter: (_) => setState(() => _hovered = true),
        onExit: (_) => setState(() => _hovered = false),
        child: GestureDetector(
          onTap: widget.onTap,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 120),
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: _hovered
                  ? cs.onSurface.withValues(alpha: 0.1)
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(6),
            ),
            child: Icon(
              widget.icon,
              size: 16,
              color: cs.onSurface.withValues(alpha: 0.6),
            ),
          ),
        ),
      ),
    );
  }
}
