import 'package:flutter/material.dart';

/// Supplies local detail context to the auxiliary pane without another request.
class ReadingSupplement extends Notification {
  ReadingSupplement(this.id, this.child);
  final String id;
  final Widget child;
}

/// 详情页请求分栏容器在右侧展示评论面板。
///
/// [builder] 由详情页提供，容器只负责摆放位置。这样评论列表仍然共享详情页的
/// `FeedController` 与各种回调，无需在容器里重建一套评论状态。
class ReadingCommentsOpen extends Notification {
  ReadingCommentsOpen(this.id, this.builder);
  final String id;
  final WidgetBuilder builder;
}

/// 详情页请求分栏容器收起右侧评论面板。
class ReadingCommentsClose extends Notification {
  ReadingCommentsClose(this.id);
  final String id;
}

/// 告知详情页：当前详情的评论是否正在右侧分栏中展示。
///
/// 展开时正文内嵌的评论列表会隐藏，避免同一批评论在两栏里重复出现。
class ReadingCommentsScope extends InheritedWidget {
  const ReadingCommentsScope({
    super.key,
    required this.active,
    required super.child,
  });

  final bool active;

  static bool activeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<ReadingCommentsScope>()?.active ??
      false;

  /// 是否处于分栏阅读容器内（此时右侧评论入口才可用）。
  static bool inPaneOf(BuildContext context) =>
      context.getInheritedWidgetOfExactType<ReadingCommentsScope>() != null;

  @override
  bool updateShouldNotify(ReadingCommentsScope oldWidget) =>
      active != oldWidget.active;
}

/// Reading typography follows the available pane, including standalone routes.
class ReadingPresentation extends InheritedWidget {
  const ReadingPresentation(
      {super.key, required this.wide, required super.child});

  final bool wide;

  static bool of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<ReadingPresentation>()?.wide ??
      false;

  @override
  bool updateShouldNotify(ReadingPresentation oldWidget) =>
      wide != oldWidget.wide;
}
