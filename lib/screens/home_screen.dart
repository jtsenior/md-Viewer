import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/markdown_file.dart';
import '../services/file_service.dart';
import '../widgets/sidebar.dart';
import '../widgets/markdown_viewer.dart';
import '../widgets/empty_state.dart';
import '../widgets/title_bar.dart';

class HomeScreen extends StatefulWidget {
  final ThemeMode themeMode;
  final VoidCallback onToggleTheme;

  const HomeScreen({
    super.key,
    required this.themeMode,
    required this.onToggleTheme,
  });

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _fileService = FileService();
  MarkdownFile? _currentFile;
  List<MarkdownFile> _recentFiles = [];
  bool _sidebarVisible = true;
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _loadRecentFiles();
    const initialFile = String.fromEnvironment('INITIAL_FILE');
    if (initialFile.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _openSpecificFile(initialFile));
    }
  }

  Future<void> _openSpecificFile(String path) async {
    setState(() => _loading = true);
    try {
      final file = await _fileService.readFile(path);
      setState(() => _currentFile = file);
      await _loadRecentFiles();
    } finally {
      setState(() => _loading = false);
    }
  }

  Future<void> _loadRecentFiles() async {
    final files = await _fileService.getRecentFiles();
    setState(() => _recentFiles = files);
  }

  Future<void> _openFile() async {
    setState(() => _loading = true);
    try {
      final file = await _fileService.openFile();
      if (file != null) {
        setState(() => _currentFile = file);
        await _loadRecentFiles();
      }
    } finally {
      setState(() => _loading = false);
    }
  }

  Future<void> _openRecentFile(MarkdownFile file) async {
    setState(() => _loading = true);
    try {
      final loaded = await _fileService.readFile(file.path);
      setState(() => _currentFile = loaded);
      await _loadRecentFiles();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Could not open file: ${file.name}'),
            behavior: SnackBarBehavior.floating,
          ),
        );
        await _fileService.removeFromRecent(file.path);
        await _loadRecentFiles();
      }
    } finally {
      setState(() => _loading = false);
    }
  }

  Future<void> _refreshCurrentFile() async {
    if (_currentFile == null) return;
    setState(() => _loading = true);
    try {
      final loaded = await _fileService.readFile(_currentFile!.path);
      setState(() => _currentFile = loaded);
    } finally {
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = widget.themeMode == ThemeMode.dark;
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: cs.surface,
      body: CallbackShortcuts(
        bindings: {
          const SingleActivator(LogicalKeyboardKey.keyO, meta: true): _openFile,
          const SingleActivator(LogicalKeyboardKey.keyR, meta: true):
              _refreshCurrentFile,
          const SingleActivator(LogicalKeyboardKey.backslash, meta: true): () {
            setState(() => _sidebarVisible = !_sidebarVisible);
          },
        },
        child: Focus(
          autofocus: true,
          child: Column(
            children: [
              TitleBar(
                currentFile: _currentFile,
                isDark: isDark,
                sidebarVisible: _sidebarVisible,
                onOpenFile: _openFile,
                onToggleTheme: widget.onToggleTheme,
                onToggleSidebar: () =>
                    setState(() => _sidebarVisible = !_sidebarVisible),
                onRefresh: _currentFile != null ? _refreshCurrentFile : null,
              ),
              Expanded(
                child: Row(
                  children: [
                    if (_sidebarVisible)
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        curve: Curves.easeInOut,
                        width: 240,
                        child: Sidebar(
                          recentFiles: _recentFiles,
                          currentFile: _currentFile,
                          onOpenFile: _openFile,
                          onSelectFile: _openRecentFile,
                        ),
                      ),
                    Expanded(
                      child: _loading
                          ? Center(
                              child: CircularProgressIndicator(
                                color: cs.primary,
                                strokeWidth: 2,
                              ),
                            )
                          : _currentFile != null
                              ? MarkdownViewerWidget(file: _currentFile!)
                              : EmptyState(onOpenFile: _openFile),
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
