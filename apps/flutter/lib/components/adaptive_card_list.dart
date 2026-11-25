import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:c001apk_flutter/components/masonry_section.dart';
import 'package:flutter_staggered_grid_view/flutter_staggered_grid_view.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:sliver_tools/sliver_tools.dart';

import '../utils/storage_util.dart';

/// Lazy masonry cards use the shortest column without truncating content.
/// Structural cards separate masonry sections and span the available width.
class AdaptiveCardList extends StatefulWidget {
  const AdaptiveCardList({
    super.key,
    required this.itemCount,
    required this.itemBuilder,
    this.isFullWidth,
    this.controller,
    this.physics =
        const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
    this.padding = const EdgeInsets.all(10),
    this.leading,
    this.footer,
    this.minColumnWidth,
  }) : sliver = false;

  const AdaptiveCardList.sliver({
    super.key,
    required this.itemCount,
    required this.itemBuilder,
    this.isFullWidth,
    this.leading,
    this.footer,
    this.padding = const EdgeInsets.all(10),
    this.minColumnWidth,
  })  : sliver = true,
        controller = null,
        physics = const AlwaysScrollableScrollPhysics();

  final int itemCount;
  final IndexedWidgetBuilder itemBuilder;
  final bool Function(int)? isFullWidth;
  final ScrollController? controller;
  final ScrollPhysics physics;
  final EdgeInsets padding;
  final Widget? leading;
  final Widget? footer;
  final bool sliver;

  /// 小红书网格下单列的最小宽度。横向「图标 + 标题 + 数据」这类卡片
  /// （话题、应用、用户）在过窄的列里会把数字拆成竖排，给个下限后
  /// 网格会自动减少每行列数。
  final double? minColumnWidth;

  @override
  State<AdaptiveCardList> createState() => _AdaptiveCardListState();
}

class _AdaptiveCardListState extends State<AdaptiveCardList> {
  final _ownedController = ScrollController();
  final _viewportKey = GlobalKey();
  final _itemKeys = <int, GlobalKey>{};
  Widget? _cachedCards;
  double? _cachedWidth;
  double? _cachedScale;
  int? _columns;
  int? _cachedColumns;
  double _pinchStartColumns = 3;
  Listenable? _settingsListenable;
  VoidCallback? _settingsListener;
  // 当前可用宽度允许的最大列数，捏合时用它兜住目标值。
  int _maxByWidth = 4;
  // 捏合提示：只让这一小块区域重建，不牵动整个列表。
  final _hintColumns = ValueNotifier<int>(3);
  final _hintVisible = ValueNotifier<bool>(false);
  Timer? _hintTimer;
  int _pinchTarget = 3;
  int? _anchorIndex;
  double _anchorDy = 0;
  int _attempts = 0;
  int _anchorGeneration = 0;
  ScrollController get _scroll => widget.controller ?? _ownedController;
  ScrollPosition? get _position => widget.sliver
      ? Scrollable.maybeOf(context)?.position
      : _scroll.hasClients
          ? _scroll.position
          : null;

  double? _top(GlobalKey key) {
    final box = key.currentContext?.findRenderObject();
    final viewport = widget.sliver
        ? Scrollable.maybeOf(context)?.context.findRenderObject()
        : _viewportKey.currentContext?.findRenderObject();
    if (box is! RenderBox ||
        !box.hasSize ||
        viewport is! RenderBox ||
        !viewport.hasSize) return null;
    return box.localToGlobal(Offset.zero).dy -
        viewport.localToGlobal(Offset.zero).dy;
  }

  void _captureAnchor() {
    if (_position == null || _position!.pixels <= 0) return;
    final indices = _itemKeys.keys.toList()..sort();
    double? nearest;
    for (final index in indices) {
      final key = _itemKeys[index]!;
      final dy = _top(key);
      final box = key.currentContext?.findRenderObject();
      if (dy != null &&
          box is RenderBox &&
          dy + box.size.height - 10 > 0.5 &&
          dy < _position!.viewportDimension &&
          (nearest == null || dy.abs() < nearest)) {
        _anchorIndex = index;
        _anchorDy = dy;
        _attempts = 0;
        nearest = dy.abs();
      }
    }
  }

  void _restoreAnchor(int generation) {
    if (!mounted ||
        generation != _anchorGeneration ||
        _anchorIndex == null ||
        _position == null) return;
    final target = _anchorIndex!;
    if (target >= widget.itemCount || _attempts++ >= 20) {
      _anchorIndex = null;
      return;
    }
    final targetKey = _itemKeys[target];
    final dy = targetKey == null ? null : _top(targetKey);
    double? correction;
    if (dy != null) {
      correction = dy - _anchorDy;
      if (correction.abs() < 1) {
        _anchorIndex = null;
        return;
      }
    } else {
      // Seek with measured card heights, then align the actual target once
      // it is laid out. Offscreen cards remain lazy even after a column change.
      var first = target;
      while (first > 0 && widget.isFullWidth?.call(first - 1) != true) {
        first--;
      }
      var end = target + 1;
      while (end < widget.itemCount && widget.isFullWidth?.call(end) != true) {
        end++;
      }
      final indices = _itemKeys.keys
          .where((i) =>
              i >= first && i < end && widget.isFullWidth?.call(i) != true)
          .toList()
        ..sort((a, b) => (a - target).abs().compareTo((b - target).abs()));
      for (final i in indices) {
        final key = _itemKeys[i]!;
        final top = _top(key);
        final box = key.currentContext?.findRenderObject();
        if (top != null && box is RenderBox && box.size.height > 0) {
          correction =
              top - _anchorDy + (target - i) * box.size.height / _columns!;
          break;
        }
      }
    }
    if (correction == null) {
      _anchorIndex = null;
      return;
    }
    final position = _position!;
    position.jumpTo((position.pixels + correction)
        .clamp(position.minScrollExtent, position.maxScrollExtent));
    WidgetsBinding.instance
        .addPostFrameCallback((_) => _restoreAnchor(generation));
    WidgetsBinding.instance.scheduleFrame();
  }

  @override
  void initState() {
    super.initState();
    // 设置里切换「小红书网格布局」或列数变化时立即重建列表。
    try {
      _settingsListenable = GStorage.settings.listenable(
        keys: [SettingsBoxKey.xhsGridLayout, SettingsBoxKey.xhsGridColumns],
      );
      _settingsListener = () {
        if (mounted) setState(() {});
      };
      _settingsListenable!.addListener(_settingsListener!);
    } catch (_) {
      // 未初始化 Hive（如部分测试）时跳过监听，使用原始布局。
    }
  }

  @override
  void dispose() {
    _settingsListenable?.removeListener(_settingsListener!);
    _hintTimer?.cancel();
    _hintColumns.dispose();
    _hintVisible.dispose();
    _ownedController.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant AdaptiveCardList oldWidget) {
    super.didUpdateWidget(oldWidget);
    _cachedCards = null;
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _cachedCards = null;
  }

  @override
  Widget build(BuildContext context) => widget.sliver
      ? SliverLayoutBuilder(
          builder: (context, constraints) =>
              _buildCards(context, constraints.crossAxisExtent))
      : LayoutBuilder(
          builder: (context, constraints) =>
              _buildCards(context, constraints.maxWidth));

  Widget _card(BuildContext context, int index) => Padding(
        key: _itemKeys.putIfAbsent(index, () => GlobalKey()),
        padding: const EdgeInsets.only(bottom: 10),
        child: IndexedSemantics(
            index: index, child: widget.itemBuilder(context, index)),
      );

  // Separate slivers must not build pagination footers just to estimate their
  // scroll extent. Wait until they enter the viewport's cache region.
  //
  // SliverLayoutBuilder 的约束每个滚动帧都在变，builder 会逐帧执行。若每次都
  // 新建 SliverList/delegate，整段（如图文横向卡）就会逐帧重建，滚动到这里
  // 必然掉帧。这里把首次构建结果缓存下来，后续帧返回同一个 widget 实例，
  // Element 走 identical 快路径直接跳过重建。
  Widget _deferredSliver(Widget Function() builder) {
    Widget? built;
    return SliverLayoutBuilder(
      builder: (_, constraints) {
        if (constraints.remainingCacheExtent <= 0 && constraints.scrollOffset <= 0) {
          return const SliverToBoxAdapter(child: SizedBox.shrink());
        }
        return built ??= builder();
      },
    );
  }

  Iterable<Widget> _sections(int columns) sync* {
    for (var start = 0; start < widget.itemCount;) {
      final first = start;
      final fullWidth = widget.isFullWidth?.call(first) == true;
      var end = first + 1;
      while (end < widget.itemCount &&
          (widget.isFullWidth?.call(end) == true) == fullWidth) {
        end++;
      }
      final delegate = SliverChildBuilderDelegate(
        (context, i) => _card(context, first + i),
        childCount: end - first,
        addSemanticIndexes: false,
      );
      if (fullWidth) {
        yield _deferredSliver(() => SliverList(delegate: delegate));
      } else if (end - first < columns) {
        // An incomplete row has no further cards to fill its gaps. The library
        // cannot restore missing columns in such a short masonry section.
        final count = end - first;
        yield _deferredSliver(() => SliverToBoxAdapter(
                child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (var col = 0; col < columns; col++) ...[
                  if (col > 0) const SizedBox(width: 10),
                  Expanded(
                      child: col < count
                          ? _card(context, first + col)
                          : const SizedBox.shrink()),
                ],
              ],
            )));
      } else {
        yield MasonrySection(
          key: ValueKey((first, columns)),
          gridDelegate: SliverSimpleGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: columns),
          crossAxisSpacing: 10,
          delegate: delegate,
        );
      }
      start = end;
    }
  }

  Widget _buildCards(BuildContext context, double width) {
    final scale =
        (MediaQuery.textScalerOf(context).scale(16) / 16).clamp(1.0, 2.0);
    // 小红书模式使用固定列数（2~4，双指捏合可调）；最小卡片宽度按 96 逻辑像素
    // 估算，竖屏平板能捏到 4 列、手机能捏到 3 列，不再只在大屏生效。
    final xhs = _xhsEnabled;
    final minCardWidth = widget.minColumnWidth ?? 96.0;
    final maxByWidth =
        ((width - widget.padding.horizontal + 10) /
                (minCardWidth * scale + 10))
            .floor()
            .clamp(1, 4);
    _maxByWidth = maxByWidth;
    final columns = xhs
        ? _xhsColumns.clamp(2, 4).clamp(1, maxByWidth)
        : ((width - widget.padding.horizontal + 10) / (360 * scale + 10))
            .floor()
            .clamp(1, 4);
    // SliverLayoutBuilder also runs on scrolling. Reusing the child avoids
    // rebuilding unchanged delegates and invalidating measured section extents.
    if (_cachedCards != null &&
        _cachedWidth == width &&
        _cachedScale == scale &&
        _cachedColumns == columns) {
      return _wrapCards(_cachedCards!);
    }
    if (_columns != null && _columns != columns) {
      final generation = ++_anchorGeneration;
      if (_anchorIndex == null) _captureAnchor();
      if (_anchorIndex != null) {
        WidgetsBinding.instance
            .addPostFrameCallback((_) => _restoreAnchor(generation));
      }
    }
    _columns = columns;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _itemKeys.removeWhere((_, key) => key.currentContext == null);
      }
    });
    final cards = SliverPadding(
      padding: widget.padding,
      // Flutter 3.24's group drops masonry scrollOffsetCorrection. MultiSliver
      // forwards it immediately instead of laying out subsequent sections.
      sliver: MultiSliver(children: [
        if (widget.leading != null)
          SliverToBoxAdapter(
              child: Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: widget.leading)),
        ..._sections(columns),
        if (widget.footer != null)
          _deferredSliver(() => SliverToBoxAdapter(child: widget.footer!)),
      ]),
    );
    _cachedCards = cards;
    _cachedWidth = width;
    _cachedScale = scale;
    _cachedColumns = columns;
    return _wrapCards(cards);
  }

  // 双指捏合切换列数。用 Listener 直接监听指针，不参与滚动手势竞技场，
  // 因此单指滚动完全不受影响。
  final _pointers = <int, Offset>{};
  double? _pinchStartDistance;

  // 测试环境可能未初始化 Hive，安全读取设置：未就绪时退回原始布局。
  bool get _xhsEnabled {
    try {
      return GStorage.xhsGridLayout;
    } catch (_) {
      return false;
    }
  }

  int get _xhsColumns {
    try {
      return GStorage.xhsGridColumns;
    } catch (_) {
      return 3;
    }
  }

  double _pinchDistance() {
    final points = _pointers.values.toList();
    if (points.length < 2) return 0;
    return (points[0] - points[1]).distance;
  }

  int _effectiveColumns(int target) =>
      target.clamp(2, 4).clamp(1, _maxByWidth);

  void _onPinchDown(PointerDownEvent event) {
    _pointers[event.pointer] = event.position;
    if (_pointers.length != 2 || !_xhsEnabled) return;
    // 第二根手指按下：开始预览列数（横滑已由 PinchGestureDetector 让位）。
    _pinchStartDistance = _pinchDistance();
    _pinchStartColumns = _xhsColumns.toDouble();
    _pinchTarget = _pinchStartColumns.round().clamp(2, 4);
    _hintColumns.value = _effectiveColumns(_pinchTarget);
    _hintVisible.value = true;
    _hintTimer?.cancel();
  }

  void _onPinchMove(PointerMoveEvent event) {
    if (!_pointers.containsKey(event.pointer)) return;
    _pointers[event.pointer] = event.position;
    final start = _pinchStartDistance;
    if (start == null || start <= 0 || _pointers.length < 2) return;
    final distance = _pinchDistance();
    if (distance <= 0) return;
    // 往内捏（ratio<1）列数变多、卡片变小；往外捏（ratio>1）列数变少。
    final ratio = distance / start;
    if ((ratio - 1).abs() < .08) return;
    _pinchTarget = (_pinchStartColumns / ratio).round().clamp(2, 4);
    final effective = _effectiveColumns(_pinchTarget);
    if (_hintColumns.value != effective) _hintColumns.value = effective;
  }

  void _onPinchUp(PointerEvent event) {
    final pinching = _pointers.length >= 2;
    _pointers.remove(event.pointer);
    if (_pointers.length < 2) _pinchStartDistance = null;
    if (!pinching) return;
    _applyColumns(_pinchTarget);
    _scheduleHideHint();
  }

  void _onPinchCancel(PointerEvent event) {
    _pointers.remove(event.pointer);
    if (_pointers.length < 2) _pinchStartDistance = null;
    _scheduleHideHint();
  }

  void _scheduleHideHint() {
    _hintTimer?.cancel();
    _hintTimer = Timer(const Duration(milliseconds: 700), () {
      if (mounted) _hintVisible.value = false;
    });
  }

  void _applyColumns(int target) {
    if (!_xhsEnabled) return;
    final effective = _effectiveColumns(target);
    if (effective == _xhsColumns) return;
    GStorage.setXhsGridColumns(effective);
    if (mounted) setState(() {});
  }

  Widget _wrapCards(Widget cards) => widget.sliver
      ? cards
      : Listener(
          onPointerDown: _onPinchDown,
          onPointerMove: _onPinchMove,
          onPointerUp: _onPinchUp,
          onPointerCancel: _onPinchCancel,
          child: Stack(
            fit: StackFit.expand,
            children: [
              CustomScrollView(
                  key: _viewportKey,
                  controller: _scroll,
                  physics: widget.physics,
                  semanticChildCount: widget.itemCount,
                  slivers: [cards]),
              Positioned.fill(
                child: ValueListenableBuilder<bool>(
                  valueListenable: _hintVisible,
                  builder: (context, visible, _) =>
                      ValueListenableBuilder<int>(
                    valueListenable: _hintColumns,
                    builder: (context, columns, __) =>
                        _PinchColumnsHint(columns: columns, visible: visible),
                  ),
                ),
              ),
            ],
          ),
        );
}

/// 捏合时的列数提示：居中浮层，只做视觉反馈，不拦截任何点击。
class _PinchColumnsHint extends StatelessWidget {
  const _PinchColumnsHint({required this.columns, required this.visible});

  final int columns;
  final bool visible;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return IgnorePointer(
      child: Center(
        child: AnimatedOpacity(
          opacity: visible ? 1 : 0,
          duration: const Duration(milliseconds: 160),
          curve: Curves.easeOut,
          child: AnimatedScale(
            scale: visible ? 1 : .88,
            duration: const Duration(milliseconds: 160),
            curve: Curves.easeOut,
            // 淡出后不再命中任何语义/绘制区域。
            child: ExcludeSemantics(
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                decoration: BoxDecoration(
                  color: colors.inverseSurface.withValues(alpha: .88),
                  borderRadius: BorderRadius.circular(26),
                ),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  Icon(Icons.grid_view_rounded,
                      size: 18, color: colors.onInverseSurface),
                  const SizedBox(width: 8),
                  Text(
                    '$columns 列',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: colors.onInverseSurface,
                    ),
                  ),
                ]),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

