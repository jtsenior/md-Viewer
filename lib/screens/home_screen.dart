import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/markdown_file.dart';
import '../services/file_service.dart';
import '../widgets/sidebar.dart';
import '../widgets/markdown_viewer.dart';
import '../widgets/empty_state.dart';
import '../widgets/title_bar.dart';

const _fileChannel = MethodChannel('com.jtsworkshop.mdViewer/file');

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
    _fileChannel.setMethodCallHandler(_handleNativeFileOpen);
    WidgetsBinding.instance.addPostFrameCallback((_) => _checkInitialFile());
  }

  // Receives openFile calls from the native side while the app is already running
  Future<void> _handleNativeFileOpen(MethodCall call) async {
    if (call.method == 'openFile') {
      final info = call.arguments as Map?;
      await _openFromNativeInfo(info);
    }
  }

  // Asks the native side for a file pending at launch (CLI arg or early Finder open)
  Future<void> _checkInitialFile() async {
    try {
      final info = await _fileChannel.invokeMethod<Map>('getInitialFile');
      await _openFromNativeInfo(info);
    } catch (e) {
      _showError('Could not retrieve initial file: $e');
    }
  }

  Future<void> _openFromNativeInfo(Map? info) async {
    if (info == null) return;
    final path = info['path'] as String?;
    final content = info['content'] as String?;
    final bookmark = info['bookmark'] as String?;
    if (path == null || path.isEmpty) return;
    await _openSpecificFile(path, prefetchedContent: content, bookmarkData: bookmark);
  }

  Future<void> _openSpecificFile(
    String path, {
    String? prefetchedContent,
    String? bookmarkData,
  }) async {
    setState(() => _loading = true);
    try {
      final file = prefetchedContent != null
          ? await _fileService.fileFromContent(path, prefetchedContent, bookmarkData: bookmarkData)
          : await _fileService.readFile(path, bookmarkData: bookmarkData);
      setState(() => _currentFile = file);
      await _loadRecentFiles();
    } catch (e) {
      _showError('Could not open file: $e');
    } finally {
      setState(() => _loading = false);
    }
  }

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), behavior: SnackBarBehavior.floating),
    );
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
      final loaded = await _fileService.readFile(file.path, bookmarkData: file.bookmarkData);
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
      final loaded = await _fileService.readFile(
        _currentFile!.path,
        bookmarkData: _currentFile!.bookmarkData,
      );
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
