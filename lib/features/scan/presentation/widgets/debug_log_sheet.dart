import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:health_wallet/features/scan/domain/services/scan_log_buffer.dart';

class DebugLogSheet extends StatefulWidget {
  const DebugLogSheet({super.key});

  static void show(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF1E1E1E),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(12)),
      ),
      builder: (_) => const DebugLogSheet(),
    );
  }

  @override
  State<DebugLogSheet> createState() => _DebugLogSheetState();
}

class _DebugLogSheetState extends State<DebugLogSheet> {
  final ScrollController _scrollController = ScrollController();
  bool _autoScroll = true;
  String _persistedLogs = '';
  bool _showPersisted = false;

  @override
  void initState() {
    super.initState();
    ScanLogBuffer.instance.addListener(_onLogsChanged);
    _loadPersistedLogs();
  }

  Future<void> _loadPersistedLogs() async {
    final logs = await ScanLogBuffer.instance.readPersistedLogs();
    if (mounted && logs.isNotEmpty) {
      setState(() => _persistedLogs = logs);
    }
  }

  @override
  void dispose() {
    ScanLogBuffer.instance.removeListener(_onLogsChanged);
    _scrollController.dispose();
    super.dispose();
  }

  void _onLogsChanged() {
    if (!mounted) return;
    setState(() {});
    if (_autoScroll) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_scrollController.hasClients) {
          _scrollController.animateTo(
            _scrollController.position.maxScrollExtent,
            duration: const Duration(milliseconds: 150),
            curve: Curves.easeOut,
          );
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final logs = ScanLogBuffer.instance.getAll();
    final hasPersistedLogs = _persistedLogs.isNotEmpty;

    return DraggableScrollableSheet(
      initialChildSize: 0.6,
      minChildSize: 0.3,
      maxChildSize: 0.9,
      expand: false,
      builder: (context, dragController) {
        return Column(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              child: Row(
                children: [
                  const Text(
                    'Logs',
                    style: TextStyle(
                      color: Colors.white70,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    '(${logs.length})',
                    style: const TextStyle(color: Colors.white30, fontSize: 12),
                  ),
                  const Spacer(),
                  if (hasPersistedLogs)
                    GestureDetector(
                      onTap: () => setState(() => _showPersisted = !_showPersisted),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: _showPersisted
                              ? const Color(0xFF4A3000)
                              : Colors.transparent,
                          borderRadius: BorderRadius.circular(4),
                          border: Border.all(
                            color: _showPersisted
                                ? Colors.orange
                                : Colors.white24,
                          ),
                        ),
                        child: Text(
                          _showPersisted ? 'File' : 'File',
                          style: TextStyle(
                            color: _showPersisted ? Colors.orange : Colors.white38,
                            fontSize: 10,
                          ),
                        ),
                      ),
                    ),
                  const SizedBox(width: 8),
                  GestureDetector(
                    onTap: () => setState(() => _autoScroll = !_autoScroll),
                    child: Icon(
                      _autoScroll ? Icons.vertical_align_bottom : Icons.pause,
                      color: _autoScroll ? Colors.greenAccent : Colors.white38,
                      size: 16,
                    ),
                  ),
                  const SizedBox(width: 8),
                  TextButton(
                    onPressed: () {
                      final text = _showPersisted
                          ? _persistedLogs
                          : logs.join('\n');
                      Clipboard.setData(ClipboardData(text: text));
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Logs copied'),
                          duration: Duration(seconds: 1),
                        ),
                      );
                    },
                    child: const Text(
                      'Copy',
                      style: TextStyle(color: Colors.white54, fontSize: 12),
                    ),
                  ),
                  TextButton(
                    onPressed: () async {
                      ScanLogBuffer.instance.clear();
                      await ScanLogBuffer.instance.clearPersistedLogs();
                      setState(() => _persistedLogs = '');
                    },
                    child: const Text(
                      'Clear',
                      style: TextStyle(color: Colors.white54, fontSize: 12),
                    ),
                  ),
                ],
              ),
            ),
            const Divider(color: Colors.white24, height: 1),
            if (_showPersisted && hasPersistedLogs)
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(8, 8, 8, 40),
                  child: SelectableText(
                    _persistedLogs,
                    style: const TextStyle(
                      color: Color(0xFFE0C080),
                      fontSize: 10,
                      fontFamily: 'monospace',
                      height: 1.4,
                    ),
                  ),
                ),
              )
            else
              Expanded(
                child: logs.isEmpty
                    ? const Center(
                        child: Text(
                          'Waiting for logs...',
                          style: TextStyle(color: Colors.white38, fontSize: 12),
                        ),
                      )
                    : NotificationListener<ScrollNotification>(
                        onNotification: (notification) {
                          if (notification is UserScrollNotification) {
                            final atBottom = _scrollController.position.pixels >=
                                _scrollController.position.maxScrollExtent - 20;
                            if (_autoScroll != atBottom) {
                              setState(() => _autoScroll = atBottom);
                            }
                          }
                          return false;
                        },
                        child: ListView.builder(
                          controller: _scrollController,
                          padding: const EdgeInsets.fromLTRB(8, 8, 8, 40),
                          itemCount: logs.length,
                          itemBuilder: (context, index) {
                            final line = logs[index];
                            final isHeader = line.contains('===') || line.contains('---');
                            final isWarning = line.contains('WARNING') || line.contains('FAILED') || line.contains('ERROR');

                            return Padding(
                              padding: EdgeInsets.only(
                                top: isHeader ? 6 : 1,
                                bottom: 1,
                              ),
                              child: Text(
                                line,
                                style: TextStyle(
                                  color: isWarning
                                      ? const Color(0xFFFF6B6B)
                                      : isHeader
                                          ? const Color(0xFF7EC8E3)
                                          : Colors.white70,
                                  fontSize: 10,
                                  fontFamily: 'monospace',
                                  fontWeight: isHeader ? FontWeight.w600 : FontWeight.normal,
                                  height: 1.4,
                                ),
                              ),
                            );
                          },
                        ),
                      ),
              ),
          ],
        );
      },
    );
  }
}
