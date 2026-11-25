import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

import '../constants/liquid_glass_level.dart';

/// 导航玻璃的光学参数：档位越高越通透、模糊越强。
/// 底色统一用 surfaceContainer（与原版 GlassSurface 一致），避免发白。
({double blur, double alpha, double border}) liquidGlassOptics(
  LiquidGlassLevel level, {
  required bool enabled,
  bool pressed = false,
}) {
  if (!enabled || !level.usesBackdrop) {
    return (blur: 0, alpha: 1, border: .45);
  }
  return switch (level) {
    LiquidGlassLevel.low => (blur: 0, alpha: 1, border: .45),
    LiquidGlassLevel.medium => (blur: 4, alpha: .94, border: .45),
    LiquidGlassLevel.high => (blur: 10, alpha: .90, border: .55),
    LiquidGlassLevel.complete =>
      (blur: 16, alpha: .86, border: pressed ? .65 : 0),
  };
}

/// Public backend: ordinary translucent/frosted surfaces and navigation.
/// The official source assembly supplies the same API with its own renderer.
class GlassSurface extends StatelessWidget {
  const GlassSurface({
    super.key,
    required this.shader,
    required this.enabled,
    required this.extent,
    required this.depth,
    required this.dispersion,
    required this.tint,
    this.refractionHeight = 0,
    this.depthEffect = false,
    this.blur = 4,
    this.fallbackTint,
    this.level = LiquidGlassLevel.medium,
    this.press = 0,
    this.borderRadius,
    this.shadow = true,
  });

  factory GlassSurface.navigationBase({
    required ui.FragmentShader? shader,
    required bool enabled,
    required Size extent,
    required ThemeData theme,
    required LiquidGlassLevel level,
    BorderRadius? borderRadius,
    bool shadow = true,
    double press = 0,
  }) =>
      GlassSurface(
          shader: shader,
          enabled: enabled,
          extent: extent,
          depth: 0,
          dispersion: 0,
          tint: theme.colorScheme.surfaceContainer,
          level: level,
          borderRadius: borderRadius,
          shadow: shadow,
          press: press);

  factory GlassSurface.navigationLens({
    required ui.FragmentShader? shader,
    required bool enabled,
    required Size extent,
    required ThemeData theme,
    required LiquidGlassLevel level,
    required double progress,
    bool shadow = true,
    Color? tint,
  }) =>
      GlassSurface(
          shader: shader,
          enabled: enabled,
          extent: extent,
          depth: 0,
          dispersion: 0,
          tint: tint ?? theme.colorScheme.primaryContainer,
          level: level,
          depthEffect: true,
          shadow: shadow,
          press: progress);

  final ui.FragmentShader? shader;
  final bool enabled, depthEffect, shadow;
  final Size extent;
  final double depth, dispersion, refractionHeight, blur, press;
  final Color tint;
  final Color? fallbackTint;
  final LiquidGlassLevel level;
  final BorderRadius? borderRadius;

  @override
  Widget build(BuildContext context) {
    final radius = borderRadius ?? BorderRadius.circular(extent.height / 2);
    final solid = !enabled || MediaQuery.highContrastOf(context);
    final content = ColoredBox(
      color: (fallbackTint ?? tint).withValues(alpha: solid ? 1 : .9),
      child: const SizedBox.expand(),
    );
    return ClipRRect(
      borderRadius: radius,
      child: solid || level == LiquidGlassLevel.low
          ? content
          : BackdropFilter(
              filter: ui.ImageFilter.blur(sigmaX: 4, sigmaY: 4),
              child: content),
    );
  }
}

class LiquidGlassPanel extends StatelessWidget {
  const LiquidGlassPanel(
      {super.key,
      required this.child,
      required this.enabled,
      required this.level,
      this.borderRadius = const BorderRadius.all(Radius.circular(28))});
  final Widget child;
  final bool enabled;
  final LiquidGlassLevel level;
  final BorderRadius borderRadius;

  @override
  Widget build(BuildContext context) => ClipRRect(
      borderRadius: borderRadius,
      child: Stack(children: [
        Positioned.fill(
            child: IgnorePointer(
                child: LayoutBuilder(
                    builder: (context, bounds) => GlassSurface(
                        shader: null,
                        enabled: enabled,
                        extent: bounds.biggest,
                        depth: 0,
                        dispersion: 0,
                        tint: Theme.of(context).colorScheme.surfaceContainer,
                        level: level,
                        borderRadius: borderRadius)))),
        child,
      ]));
}

class LiquidGlassButton extends StatelessWidget {
  const LiquidGlassButton(
      {super.key,
      required this.child,
      required this.height,
      required this.level,
      required this.onPressed,
      required this.tooltip,
      this.width,
      this.enabled = true});
  final Widget child;
  final double height;
  final double? width;
  final LiquidGlassLevel level;
  final VoidCallback? onPressed;
  final String tooltip;
  final bool enabled;

  @override
  Widget build(BuildContext context) => SizedBox(
      width: width,
      height: height,
      child: Stack(fit: StackFit.expand, children: [
        IgnorePointer(
            child: GlassSurface.navigationBase(
                shader: null,
                enabled: enabled,
                extent: Size(width ?? height, height),
                theme: Theme.of(context),
                level: level,
                shadow: false)),
        Tooltip(
            message: tooltip,
            child: Material(
                type: MaterialType.transparency,
                child: InkWell(
                    onTap: onPressed,
                    borderRadius: BorderRadius.circular(height / 2),
                    child: Padding(
                        padding: const EdgeInsets.all(4),
                        child: Center(child: child))))),
      ]));
}

class LiquidNavigationBar extends StatefulWidget {
  const LiquidNavigationBar(
      {super.key,
      required this.selectedIndex,
      required this.onDestinationSelected,
      this.program,
      this.refract = true,
      this.direction = Axis.horizontal,
      this.level = LiquidGlassLevel.medium})
      : labels = const ['主页', '关注', '我的'],
        tabs = false;
  const LiquidNavigationBar.tabs(
      {super.key,
      required this.selectedIndex,
      required this.onDestinationSelected,
      required this.labels,
      this.program,
      this.refract = true,
      this.direction = Axis.horizontal,
      this.level = LiquidGlassLevel.medium})
      : tabs = true;
  final int selectedIndex;
  final ValueChanged<int> onDestinationSelected;
  final ui.FragmentProgram? program;
  final bool refract, tabs;
  final Axis direction;
  final LiquidGlassLevel level;
  final List<String> labels;

  @override
  State<LiquidNavigationBar> createState() => _BasicNavigationState();
}

class _BasicNavigationState extends State<LiquidNavigationBar> {
  int? _dragIndex;
  bool _pressed = false;
  bool get _vertical => widget.direction == Axis.vertical;

  // 只有「完全」档需要按住时的边缘微光，其它档位不必重建。
  void _setPressed(bool value) {
    if (widget.level != LiquidGlassLevel.complete || _pressed == value) return;
    setState(() => _pressed = value);
  }

  @override
  Widget build(BuildContext context) => SafeArea(
      top: false,
      bottom: !widget.tabs && !_vertical,
      minimum: widget.tabs || _vertical
          ? EdgeInsets.zero
          : const EdgeInsets.fromLTRB(20, 14, 20, 12),
      child: Center(
          heightFactor: 1,
          child: ConstrainedBox(
              constraints: _vertical
                  ? const BoxConstraints(maxHeight: 176, maxWidth: 128)
                  : BoxConstraints(
                      maxWidth: widget.tabs ? double.infinity : 248),
              child: LayoutBuilder(builder: (context, bounds) {
                if (widget.labels.isEmpty || bounds.maxWidth <= 0) {
                  return const SizedBox.shrink();
                }
                final theme = Theme.of(context);
                final colors = theme.colorScheme;
                final textHeight = MediaQuery.textScalerOf(context).scale(14);
                final height = widget.tabs
                    ? math.max(48.0, textHeight + 24)
                    : math.max(64.0, textHeight + 40);
                final length = _vertical ? bounds.maxHeight : bounds.maxWidth;
                final radius =
                    BorderRadius.circular(_vertical ? 28 : height / 2);
                // 档位光学参数：低档不模糊、中档柔光、高档更通透、
                // 「完全」平时无描边、按住时边缘微光。
                final optics = liquidGlassOptics(
                  widget.level,
                  enabled: widget.refract &&
                      !MediaQuery.highContrastOf(context),
                  pressed: _pressed,
                );
                final blurSigma = optics.blur;
                final tintAlpha = optics.alpha;
                final borderAlpha = optics.border;
                final selected = (_dragIndex ?? widget.selectedIndex)
                    .clamp(0, widget.labels.length - 1);
                void drag(Offset point) => setState(() => _dragIndex =
                    ((_vertical ? point.dy : point.dx) /
                            length *
                            widget.labels.length)
                        .floor()
                        .clamp(0, widget.labels.length - 1));
                return _BasicRoundHitRegion(
                    child: DecoratedBox(
                        decoration: BoxDecoration(
                          borderRadius: radius,
                          boxShadow: [
                            BoxShadow(
                              color: colors.shadow.withValues(alpha: .12),
                              blurRadius: 28,
                              offset: const Offset(0, 10),
                            ),
                          ],
                        ),
                        child: ClipRRect(
                            borderRadius: radius,
                            child: GestureDetector(
                          key: ValueKey(widget.tabs
                              ? 'liquid-tabs-surface'
                              : 'liquid-drag-surface'),
                          behavior: HitTestBehavior.opaque,
                          onHorizontalDragStart: _vertical
                              ? null
                              : (event) => drag(event.localPosition),
                          onHorizontalDragUpdate: _vertical
                              ? null
                              : (event) => drag(event.localPosition),
                          onHorizontalDragCancel: _vertical
                              ? null
                              : () => setState(() => _dragIndex = null),
                          onHorizontalDragEnd: _vertical
                              ? null
                              : (_) {
                                  final index = _dragIndex;
                                  setState(() => _dragIndex = null);
                                  if (index != null) {
                                    widget.onDestinationSelected(index);
                                  }
                                },
                          onVerticalDragStart: !_vertical
                              ? null
                              : (event) => drag(event.localPosition),
                          onVerticalDragUpdate: !_vertical
                              ? null
                              : (event) => drag(event.localPosition),
                          onVerticalDragCancel: !_vertical
                              ? null
                              : () => setState(() => _dragIndex = null),
                          onVerticalDragEnd: !_vertical
                              ? null
                              : (_) {
                                  final index = _dragIndex;
                                  setState(() => _dragIndex = null);
                                  if (index != null) {
                                    widget.onDestinationSelected(index);
                                  }
                                },
                          child: SizedBox(
                              height: _vertical ? length : height,
                              child: Stack(children: [
                                // 胶囊底色：模糊强度与通透度跟随「液态玻璃档位」。
                                Positioned.fill(
                                    child: IgnorePointer(
                                        child: ClipRRect(
                                  borderRadius: radius,
                                  child: blurSigma > 0
                                      ? BackdropFilter(
                                          filter: ui.ImageFilter.blur(
                                              sigmaX: blurSigma,
                                              sigmaY: blurSigma),
                                          child: ColoredBox(
                                            color: colors.surfaceContainer
                                                .withValues(alpha: tintAlpha),
                                            child: const SizedBox.expand(),
                                          ),
                                        )
                                      : ColoredBox(
                                          color: colors.surfaceContainer,
                                          child: const SizedBox.expand(),
                                        ),
                                ))),
                                // 前景细描边：给玻璃一圈清晰边界，避免与内容糊在一起。
                                Positioned.fill(
                                    child: IgnorePointer(
                                        child: DecoratedBox(
                                  decoration: BoxDecoration(
                                    borderRadius: radius,
                                    border: Border.all(
                                      color: colors.outlineVariant
                                          .withValues(alpha: borderAlpha),
                                      width: .6,
                                    ),
                                  ),
                                ))),
                                Flex(
                                  direction: widget.direction,
                                  children: [
                                    for (var i = 0;
                                        i < widget.labels.length;
                                        i++)
                                      Expanded(
                                          child: Semantics(
                                              label: widget.labels[i],
                                              excludeSemantics: true,
                                              selected: selected == i,
                                              button: true,
                                              inMutuallyExclusiveGroup: true,
                                              child: GestureDetector(
                                                behavior:
                                                    HitTestBehavior.opaque,
                                                // 「完全」档：按住时边缘微光。
                                                onTapDown: (_) =>
                                                    _setPressed(true),
                                                onTapUp: (_) =>
                                                    _setPressed(false),
                                                onTapCancel: () =>
                                                    _setPressed(false),
                                                onTap: () => widget
                                                    .onDestinationSelected(i),
                                                // 选中底色用一个铺满整个 tab 的
                                                // 圆角块，而不是 TextButton 自带的
                                                // 背景（后者会被按钮 shape 与最小
                                                // 尺寸切碎，看着像"被分割"）。
                                                child: Padding(
                                                  padding:
                                                      EdgeInsets.symmetric(
                                                    horizontal: 3,
                                                    vertical:
                                                        _vertical ? 3 : 5,
                                                  ),
                                                  child: AnimatedContainer(
                                                    duration: const Duration(
                                                        milliseconds: 220),
                                                    curve:
                                                        Curves.easeOutCubic,
                                                    decoration: BoxDecoration(
                                                      color: selected == i
                                                          ? colors
                                                              .primaryContainer
                                                          : Colors.transparent,
                                                      borderRadius:
                                                          BorderRadius.circular(
                                                        _vertical
                                                            ? 14
                                                            : (height - 10) / 2,
                                                      ),
                                                    ),
                                                    child: Center(
                                                      child: widget.tabs
                                                          ? Text(
                                                              widget.labels[i],
                                                              maxLines: 1,
                                                              style: TextStyle(
                                                                fontWeight: selected ==
                                                                        i
                                                                    ? FontWeight
                                                                        .w700
                                                                    : FontWeight
                                                                        .w500,
                                                                color: selected ==
                                                                        i
                                                                    ? colors
                                                                        .onPrimaryContainer
                                                                    : colors
                                                                        .onSurfaceVariant,
                                                              ),
                                                            )
                                                          : Flex(
                                                              direction: _vertical
                                                                  ? Axis.horizontal
                                                                  : Axis.vertical,
                                                              mainAxisSize:
                                                                  MainAxisSize
                                                                      .min,
                                                              children: [
                                                                Icon(
                                                                  selected ==
                                                                          i
                                                                      ? [
                                                                          Icons
                                                                              .home,
                                                                          Icons
                                                                              .feed,
                                                                          Icons
                                                                              .person
                                                                        ][i % 3]
                                                                      : [
                                                                          Icons
                                                                              .home_outlined,
                                                                          Icons
                                                                              .feed_outlined,
                                                                          Icons
                                                                              .person_outline
                                                                        ][i % 3],
                                                                  size: 22,
                                                                  color: selected ==
                                                                          i
                                                                      ? colors
                                                                          .onPrimaryContainer
                                                                      : colors
                                                                          .onSurfaceVariant,
                                                                ),
                                                                SizedBox(
                                                                    width: _vertical
                                                                        ? 10
                                                                        : 0,
                                                                    height: _vertical
                                                                        ? 0
                                                                        : 2),
                                                                Text(
                                                                  widget
                                                                      .labels[i],
                                                                  maxLines: 1,
                                                                  style:
                                                                      TextStyle(
                                                                    fontSize:
                                                                        12,
                                                                    fontWeight: selected ==
                                                                            i
                                                                        ? FontWeight
                                                                            .w700
                                                                        : FontWeight
                                                                            .w500,
                                                                    color: selected ==
                                                                            i
                                                                        ? colors
                                                                            .onPrimaryContainer
                                                                        : colors
                                                                            .onSurfaceVariant,
                                                                  ),
                                                                ),
                                                              ],
                                                            ),
                                                    ),
                                                  ),
                                                ),
                                              )))
                                  ],
                                ),
                              ])),
                        ))));
              }))));
}

class _BasicRoundHitRegion extends SingleChildRenderObjectWidget {
  const _BasicRoundHitRegion({required super.child});
  @override
  RenderObject createRenderObject(BuildContext context) => _BasicRoundHitBox();
}

class _BasicRoundHitBox extends RenderProxyBox {
  @override
  bool hitTest(BoxHitTestResult result, {required Offset position}) =>
      RRect.fromRectAndRadius(
              Offset.zero & size,
              Radius.circular(size.height > size.width ? 28 : size.height / 2))
          .contains(position) &&
      super.hitTest(result, position: position);
}

/// 顶部玻璃分类条：铺满可用宽度，标签按等分宽度用 FittedBox 缩放，
/// 任何宽度下都能完整显示分类名，不会被裁成空白；支持横向拖动切换。
class GlassTabStrip extends StatefulWidget {
  const GlassTabStrip({
    super.key,
    required this.labels,
    required this.selectedIndex,
    required this.onSelected,
    this.height = 48,
    this.enabled = true,
    this.level = LiquidGlassLevel.medium,
  });

  final List<String> labels;
  final int selectedIndex;
  final ValueChanged<int> onSelected;
  final double height;
  final bool enabled;
  final LiquidGlassLevel level;

  @override
  State<GlassTabStrip> createState() => _GlassTabStripState();
}

class _GlassTabStripState extends State<GlassTabStrip> {
  bool _pressed = false;
  int? _dragIndex;

  void _setPressed(bool value) {
    if (widget.level != LiquidGlassLevel.complete || _pressed == value) return;
    setState(() => _pressed = value);
  }

  @override
  Widget build(BuildContext context) {
    if (widget.labels.isEmpty) return const SizedBox.shrink();
    final colors = Theme.of(context).colorScheme;
    final optics = liquidGlassOptics(widget.level,
        enabled: widget.enabled, pressed: _pressed);
    final radius = BorderRadius.circular(widget.height / 2);
    final selected =
        (_dragIndex ?? widget.selectedIndex).clamp(0, widget.labels.length - 1);
    return SizedBox(
      height: widget.height,
      child: ClipRRect(
        borderRadius: radius,
        child: Stack(fit: StackFit.expand, children: [
          if (optics.blur > 0)
            BackdropFilter(
              filter: ui.ImageFilter.blur(
                  sigmaX: optics.blur, sigmaY: optics.blur),
              child: ColoredBox(
                  color:
                      colors.surfaceContainer.withValues(alpha: optics.alpha)),
            )
          else
            ColoredBox(color: colors.surfaceContainer),
          IgnorePointer(
            child: DecoratedBox(
              decoration: BoxDecoration(
                borderRadius: radius,
                border: Border.all(
                    color:
                        colors.outlineVariant.withValues(alpha: optics.border),
                    width: .6),
              ),
            ),
          ),
          Positioned.fill(
            child: LayoutBuilder(builder: (context, constraints) {
              void drag(Offset local) {
                final width = constraints.maxWidth;
                if (width <= 0) return;
                setState(() => _dragIndex =
                    (local.dx / width * widget.labels.length)
                        .floor()
                        .clamp(0, widget.labels.length - 1));
              }

              return GestureDetector(
                behavior: HitTestBehavior.opaque,
                onHorizontalDragStart: (event) => drag(event.localPosition),
                onHorizontalDragUpdate: (event) => drag(event.localPosition),
                onHorizontalDragCancel: () =>
                    setState(() => _dragIndex = null),
                onHorizontalDragEnd: (_) {
                  final index = _dragIndex;
                  setState(() => _dragIndex = null);
                  if (index != null) widget.onSelected(index);
                },
                child: Row(
                  children: [
                    for (var i = 0; i < widget.labels.length; i++)
                      Expanded(
                        child: Semantics(
                          label: widget.labels[i],
                          excludeSemantics: true,
                          selected: selected == i,
                          button: true,
                          inMutuallyExclusiveGroup: true,
                          child: GestureDetector(
                          behavior: HitTestBehavior.opaque,
                          onTapDown: (_) => _setPressed(true),
                          onTapUp: (_) => _setPressed(false),
                          onTapCancel: () => _setPressed(false),
                          onTap: () => widget.onSelected(i),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 3, vertical: 5),
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 220),
                              curve: Curves.easeOutCubic,
                              decoration: BoxDecoration(
                                color: selected == i
                                    ? colors.primaryContainer
                                    : Colors.transparent,
                                borderRadius: BorderRadius.circular(
                                    (widget.height - 10) / 2),
                              ),
                              child: Center(
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 4),
                                  // 宽度不足时整体等比缩小，保证字始终完整可见。
                                  child: FittedBox(
                                    fit: BoxFit.scaleDown,
                                    child: Text(
                                      widget.labels[i],
                                      maxLines: 1,
                                      softWrap: false,
                                      style: TextStyle(
                                        fontSize: 14,
                                        height: 1.15,
                                        fontWeight: selected == i
                                            ? FontWeight.w700
                                            : FontWeight.w500,
                                        color: selected == i
                                            ? colors.onPrimaryContainer
                                            : colors.onSurface,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                        ),
                      ),
                  ],
                ),
              );
            }),
          ),
        ]),
      ),
    );
  }
}
