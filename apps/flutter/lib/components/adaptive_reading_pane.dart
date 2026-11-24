import 'package:flutter/material.dart';

import 'feed_navigation.dart';
import 'keyboard_scroll_region.dart';
import 'app_navigation_history.dart';
import 'reading_presentation.dart';

enum ReadingMode { automatic, enabled, disabled }

class _ReadingSnapshot {
  const _ReadingSnapshot(
      this.trail, this.cursor, this.sidebarVisible, this.offsets);
  final List<String> trail;
  final int cursor;
  final bool sidebarVisible;
  final Map<String, List<double>> offsets;
}

/// Keeps the original page mounted while a detail is read beside it. The same
/// detail becomes full width when the window can no longer fit both panes.
class AdaptiveReadingPane extends StatefulWidget {
  const AdaptiveReadingPane(
      {super.key,
      required this.child,
      required this.detailBuilder,
      this.leadingInset = 0,
      this.mode = ReadingMode.automatic});

  final Widget child;
  final ReadingMode mode;
  final double leadingInset;
  final Widget Function(BuildContext, String, VoidCallback) detailBuilder;

  @override
  State<AdaptiveReadingPane> createState() => AdaptiveReadingPaneState();
}

class AdaptiveReadingPaneState extends State<AdaptiveReadingPane> {
  String? _selectedId;
  LocalHistoryEntry? _history;
  bool _disposing = false;
  bool _canSplit = false;
  bool _sidebarVisible = true;
  // 当前在右侧展开评论的详情 id（null 表示右侧显示信息流）。
  String? _commentsId;
  WidgetBuilder? _commentsBuilder;
  final _trail = <String>[];
  final _details = <String, Widget>{};
  final _detailKeys = <String, GlobalKey>{};
  final _savedOffsets = <String, List<double>>{};
  final _scheduledRestores = <String>{};
  final _supplements = <String, Widget>{};
  int _cursor = -1;
  AppNavigationHistory? _navigationHistory;
  ModalRoute<dynamic>? _route;
  late final _historyClient = ReadingHistoryClient(
    canGoForward: () => _cursor + 1 < _trail.length,
    goForward: _forward,
    discardForward: _discardForward,
    reset: reset,
    save: _save,
    restore: _restore,
    cancelRestore: () => _savedOffsets.remove(_selectedId),
  );

  Object _save() {
    final offsets = Map<String, List<double>>.from(_savedOffsets);
    for (final entry in _detailKeys.entries) {
      final context = entry.value.currentContext;
      if (context != null && !offsets.containsKey(entry.key)) {
        offsets[entry.key] =
            AppNavigationHistory.scrollPositions(context, skipOffstage: false)
                .map((p) => p.pixels)
                .toList();
      }
    }
    return _ReadingSnapshot(List.of(_trail), _cursor, _sidebarVisible, offsets);
  }

  void _restore(Object value) {
    if (value is! _ReadingSnapshot) return;
    _trail.addAll(value.trail);
    _cursor = value.cursor;
    _sidebarVisible = value.sidebarVisible;
    _savedOffsets.addAll(value.offsets);
    _selectedId = _cursor >= 0 ? _trail[_cursor] : null;
    if (_selectedId != null) _ensureDetail(_selectedId!);
    _ensureHistory();
  }

  void _ensureDetail(String id) {
    _details.putIfAbsent(id, () => widget.detailBuilder(context, id, close));
    _restoreDetail(id);
  }

  void _restoreDetail(String id) {
    if (!_savedOffsets.containsKey(id) || !_scheduledRestores.add(id)) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scheduledRestores.remove(id);
      if (!mounted) return;
      final context = _detailKeys[id]?.currentContext;
      final offsets = _savedOffsets[id];
      if (context == null || offsets == null) return;
      final positions =
          AppNavigationHistory.scrollPositions(context, skipOffstage: false);
      var done = positions.length >= offsets.length;
      for (var i = 0; i < positions.length && i < offsets.length; i++) {
        final position = positions[i];
        if (!position.hasContentDimensions) {
          done = false;
          continue;
        }
        if (position.maxScrollExtent < offsets[i]) done = false;
        position.jumpTo(offsets[i]
            .clamp(position.minScrollExtent, position.maxScrollExtent));
      }
      if (done) _savedOffsets.remove(id);
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final history = AppNavigationHistoryScope.maybeOf(context);
    final route = ModalRoute.of(context);
    if (_route != null) _navigationHistory?.unregister(_route!, _historyClient);
    _navigationHistory = history;
    _route = route;
    if (route != null) history?.register(route, _historyClient);
  }

  void _discardForward() {
    if (_cursor + 1 < _trail.length) {
      setState(() {
        _trail.removeRange(_cursor + 1, _trail.length);
        _details.removeWhere((id, _) => !_trail.contains(id));
        _detailKeys.removeWhere((id, _) => !_trail.contains(id));
        _savedOffsets.removeWhere((id, _) => !_trail.contains(id));
        _supplements.removeWhere((id, _) => !_trail.contains(id));
        _clearCommentsIfGone();
      });
    }
  }

  /// 若评论所属的详情已不在浏览记录中，收起右侧评论面板。
  void _clearCommentsIfGone() {
    if (_commentsId != null && !_trail.contains(_commentsId)) {
      _commentsId = null;
      _commentsBuilder = null;
    }
  }

  void _forward() {
    if (_cursor + 1 >= _trail.length) return;
    _navigationHistory?.cancelRouteRestore();
    setState(() => _selectedId = _trail[++_cursor]);
    _ensureDetail(_selectedId!);
    _ensureHistory();
  }

  void _ensureHistory() {
    if (_history != null || _route == null || _cursor < 0) return;
    _history = LocalHistoryEntry(onRemove: () {
      _history = null;
      if (!_disposing && mounted) {
        setState(() {
          _cursor--;
          _selectedId = _cursor >= 0 ? _trail[_cursor] : null;
          if (_selectedId != null) _ensureDetail(_selectedId!);
        });
        // LocalHistoryRoute finishes its dismissal bookkeeping after this
        // callback. Re-adding synchronously corrupts that bookkeeping.
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted && !_disposing) _ensureHistory();
        });
      }
    });
    _route!.addLocalHistoryEntry(_history!);
  }

  bool _open(String id) {
    if (!_canSplit || ModalRoute.of(context)?.isCurrent != true) return false;
    if (_selectedId == id) return true;
    _navigationHistory?.cancelRestore();
    _navigationHistory?.discardForward();
    _discardForward();
    setState(() {
      _trail.add(id);
      if (_trail.length > 8) _trail.removeAt(0);
      _cursor = _trail.length - 1;
      _selectedId = id;
      _details.removeWhere((id, _) => !_trail.contains(id));
      _detailKeys.removeWhere((id, _) => !_trail.contains(id));
      _savedOffsets.removeWhere((id, _) => !_trail.contains(id));
      _supplements.removeWhere((id, _) => !_trail.contains(id));
      // 打开另一条详情时收起上一条的评论面板。
      if (_commentsId != id) {
        _commentsId = null;
        _commentsBuilder = null;
      }
      _ensureDetail(id);
    });
    _ensureHistory();
    return true;
  }

  void close() => _history?.remove();

  void reset() {
    _disposing = true;
    _history?.remove();
    _disposing = false;
    if (!mounted) return;
    setState(() {
      _history = null;
      _cursor = -1;
      _selectedId = null;
      _trail.clear();
      _details.clear();
      _detailKeys.clear();
      _savedOffsets.clear();
      _supplements.clear();
      _commentsId = null;
      _commentsBuilder = null;
    });
  }

  @override
  void dispose() {
    _disposing = true;
    if (_route != null) _navigationHistory?.unregister(_route!, _historyClient);
    _history?.remove();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) =>
      LayoutBuilder(builder: (context, constraints) {
        final width = constraints.maxWidth;
        final scale =
            (MediaQuery.textScalerOf(context).scale(16) / 16).clamp(1.0, 1.5);
        final minimumWidth = widget.mode == ReadingMode.automatic &&
                MediaQuery.sizeOf(context).shortestSide < 600
            ? double.infinity
            : 720.0;
        _canSplit = widget.mode != ReadingMode.disabled &&
            width >= minimumWidth * scale;
        final reading = _selectedId != null;
        // 评论面板正在展开（含尚未布局、仅状态就绪的情况）。评论比信息流更
        // 窄也能舒适阅读，因此用它自己的判定，不套用信息流的 260px 门槛。
        final commentsReady = reading &&
            _commentsId == _selectedId &&
            _commentsBuilder != null &&
            constraints.maxHeight >= 320 * scale;
        var detailWidth = width < 720 * scale
            ? width
            : (700.0 * scale).clamp(680.0, 760.0).clamp(0.0, width);
        // Account for the navigation rail so the article follows the window's
        // center, rather than the center of the space left by the sidebar.
        var detailLeft = ((width - widget.leadingInset - detailWidth) / 2)
            .clamp(0.0, width - detailWidth);
        // On tablet landscape, centering can leave too little space on the
        // right even though both panes fit across the available width.
        // Preserve centered reading on larger windows; otherwise use the left
        // margin first, then shorten the article only as much as necessary.
        // 评论模式下把预留宽度降到 224，让中等宽度平板也能显示评论面板。
        final reserveForSide = commentsReady ? 224.0 : 280.0;
        if (_canSplit &&
            constraints.maxHeight >= 320 * scale &&
            width - detailLeft - detailWidth - 20 < reserveForSide) {
          detailWidth = detailWidth.clamp(0.0, width - reserveForSide);
          detailLeft =
              (width - detailWidth - reserveForSide).clamp(0.0, detailLeft);
        }
        final sidebarLeft = detailLeft + detailWidth + 12;
        final sidebarWidth = (width - sidebarLeft - 8).clamp(0.0, 300.0);
        final sidebarFits = width >= 720 * scale &&
            sidebarWidth >= 260 &&
            constraints.maxHeight >= 320 * scale;
        // 评论面板的门槛更宽松：只要能分栏且右侧有 200px 以上即可展示。
        final commentsFits = width >= 600 * scale &&
            sidebarWidth >= 200 &&
            constraints.maxHeight >= 320 * scale;
        // 评论面板与信息流共用右侧栏，二者互斥：评论展开时收起信息流。
        final showComments = commentsReady && commentsFits;
        final showSidebar =
            reading && sidebarFits && _sidebarVisible && !showComments;
        final supplement = _supplements[_selectedId];
        final supplementHeight = supplement == null ? 0.0 : 96.0 * scale;
        final sidebarHeaderHeight = 72.0 * scale;
        // LocalHistoryEntry alone does not notify Flutter 3.24's native back
        // bridge. PopScope keeps Android back inside the app while reading.
        // 评论面板展开时，返回键优先收起评论，再关闭详情。
        return PopScope(
            canPop: _selectedId == null,
            onPopInvokedWithResult: (didPop, _) {
              if (didPop) return;
              if (showComments) {
                setState(() {
                  _commentsId = null;
                  _commentsBuilder = null;
                });
              } else {
                close();
              }
            },
            child: ColoredBox(
                color: Theme.of(context).colorScheme.surfaceContainerLow,
                child: Stack(children: [
                  Positioned.fill(
                    left: showSidebar ? sidebarLeft : 0,
                    right: showSidebar ? width - sidebarLeft - sidebarWidth : 0,
                    top: showSidebar
                        ? supplementHeight + sidebarHeaderHeight
                        : 0,
                    child: Offstage(
                      offstage: reading && !showSidebar,
                      child: FeedNavigation(
                        compact: showSidebar,
                        openFeed: _open,
                        selectedId: _selectedId,
                        child: ExcludeFocus(
                            excluding: reading && !showSidebar,
                            child: ExcludeSemantics(
                                excluding: reading && !showSidebar,
                                child:
                                    KeyboardScrollRegion(child: widget.child))),
                      ),
                    ),
                  ),
                  for (final entry in _details.entries)
                    Positioned(
                      key: _detailKeys.putIfAbsent(entry.key, GlobalKey.new),
                      top: 0,
                      bottom: 0,
                      left: detailLeft,
                      width: detailWidth,
                      child: Offstage(
                          offstage: entry.key != _selectedId,
                          child: TickerMode(
                              enabled: entry.key == _selectedId,
                              child: ExcludeFocus(
                                  excluding: entry.key != _selectedId,
                                  child: ClipRect(
                                      child: Material(
                                    shape: Border.symmetric(
                                        vertical: BorderSide(
                                            color: Theme.of(context)
                                                .colorScheme
                                                .outlineVariant
                                                .withValues(alpha: .5))),
                                    child: KeyboardScrollRegion(
                                        autofocus: entry.key == _selectedId,
                                        child: FeedNavigation(
                                            openFeed: _open,
                                            selectedId: _selectedId,
                                            child: NotificationListener<
                                                    ScrollMetricsNotification>(
                                                onNotification: (_) {
                                                  _restoreDetail(entry.key);
                                                  return false;
                                                },
                                                child: NotificationListener<
                                                        ReadingSupplement>(
                                                    onNotification: (notice) {
                                                      if (_trail.contains(
                                                          notice.id)) {
                                                        setState(() =>
                                                            _supplements[
                                                                    notice.id] =
                                                                notice.child);
                                                      }
                                                      return true;
                                                    },
                                                    child: NotificationListener<
                                                            ReadingCommentsOpen>(
                                                        onNotification:
                                                            (notice) {
                                                          if (_commentsId ==
                                                                  notice.id &&
                                                              _commentsBuilder !=
                                                                  null) {
                                                            return true;
                                                          }
                                                          if (_trail.contains(
                                                              notice.id)) {
                                                            setState(() {
                                                              _commentsId =
                                                                  notice.id;
                                                              _commentsBuilder =
                                                                  notice
                                                                      .builder;
                                                              _sidebarVisible =
                                                                  true;
                                                            });
                                                          }
                                                          return true;
                                                        },
                                                        child:
                                                            NotificationListener<
                                                                    ReadingCommentsClose>(
                                                                onNotification:
                                                                    (notice) {
                                                                  if (_commentsId ==
                                                                      notice.id) {
                                                                    setState(() {
                                                                      _commentsId =
                                                                          null;
                                                                      _commentsBuilder =
                                                                          null;
                                                                    });
                                                                  }
                                                                  return true;
                                                                },
                                                                child:
                                                                    ReadingCommentsScope(
                                                                  active:
                                                                      showComments &&
                                                                          entry.key ==
                                                                              _selectedId,
                                                                  child: entry
                                                                      .value,
                                                                 ))))))),
                                  ))))),
                    ),
                  if (showSidebar)
                    if (supplement != null)
                      Positioned(
                        top: 12,
                        left: sidebarLeft,
                        width: sidebarWidth,
                        height: supplementHeight,
                        child: supplement,
                      ),
                  if (showSidebar)
                    Positioned(
                        top: supplementHeight,
                        height: sidebarHeaderHeight,
                        left: sidebarLeft,
                        width: sidebarWidth,
                        child: Row(children: [
                          const Expanded(
                              child: Padding(
                            padding: EdgeInsets.only(left: 12),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text('继续浏览',
                                    style: TextStyle(
                                        fontSize: 18,
                                        fontWeight: FontWeight.w700)),
                                SizedBox(height: 4),
                                Text('回到感兴趣的动态',
                                    style: TextStyle(fontSize: 12)),
                              ],
                            ),
                          )),
                          IconButton(
                            tooltip: '收起信息流',
                            onPressed: () =>
                                setState(() => _sidebarVisible = false),
                            icon: const Icon(Icons.chevron_right),
                          ),
                        ])),
                  if (reading && sidebarFits && !_sidebarVisible && !showComments)
                    Positioned(
                      top: 8,
                      right: 16,
                      child: IconButton.filledTonal(
                        tooltip: '显示信息流',
                        onPressed: () => setState(() => _sidebarVisible = true),
                        icon: const Icon(Icons.view_sidebar_outlined),
                      ),
                    ),
                  // 右侧评论面板：占据整个右侧栏，覆盖信息流。面板内容由详情页
                  // 通过 ReadingCommentsOpen 提供，共享同一批评论状态与回调。
                  if (showComments)
                    Positioned(
                      top: 0,
                      bottom: 0,
                      left: sidebarLeft,
                      width: sidebarWidth,
                      child: NotificationListener<ReadingCommentsClose>(
                        onNotification: (notice) {
                          if (_commentsId == notice.id) {
                            setState(() {
                              _commentsId = null;
                              _commentsBuilder = null;
                            });
                          }
                          return true;
                        },
                        child: Material(
                          color: Theme.of(context).colorScheme.surface,
                          shape: Border(
                            left: BorderSide(
                              color: Theme.of(context)
                                  .colorScheme
                                  .outlineVariant
                                  .withValues(alpha: .5),
                            ),
                          ),
                          child: ClipRect(
                            // 从右侧滑入并淡入，给出「弹出」手感；ClipRect 将
                            // 位移动画约束在右侧栏内，不会溢出到正文区域。
                            child: TweenAnimationBuilder<double>(
                              tween: Tween<double>(begin: 1, end: 0),
                              duration: const Duration(milliseconds: 240),
                              curve: Curves.easeOutCubic,
                              builder: (context, value, child) =>
                                  Transform.translate(
                                offset: Offset(sidebarWidth * value, 0),
                                child: Opacity(
                                  opacity: 1 - value,
                                  child: child,
                                ),
                              ),
                              child: _commentsBuilder!(context),
                            ),
                          ),
                        ),
                      ),
                    ),
                ])));
      });
}

/// Standalone detail routes use the same readable line length as embedded ones.
class ReadingContentFrame extends StatelessWidget {
  const ReadingContentFrame({super.key, required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final scale =
        (MediaQuery.textScalerOf(context).scale(16) / 16).clamp(1.0, 1.5);
    final size = MediaQuery.sizeOf(context);
    // 宽屏（可左右分栏）时占满全屏，让帖子与评论充分利用横向空间；
    // 窄屏仍限制可读行宽，避免每行文字过长。
    final isWide = size.shortestSide >= 600 || size.width >= 720;
    final maxWidth =
        isWide ? double.infinity : (700 * scale).clamp(680.0, 760.0);
    return ColoredBox(
      color: Theme.of(context).colorScheme.surfaceContainerLow,
      child: Center(
          child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth),
        child: child,
      )),
    );
  }
}
