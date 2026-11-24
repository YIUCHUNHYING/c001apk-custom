import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../components/cards/feed_reply_card.dart';
import '../../components/expressive_loading_indicator.dart';
import '../../components/expressive_refresh_indicator.dart';
import '../../components/footer.dart';
import '../../logic/model/feed/datum.dart';
import '../../logic/state/loading_state.dart';
import '../../pages/feed/feed_controller.dart';
import '../../pages/feed/feed_page.dart' show ReplySortType;
import '../../pages/feed/reply/reply_dialog.dart' show ReplyType;
import '../../utils/coin_reply.dart';
import '../../utils/global_data.dart';
import '../../utils/storage_util.dart';

/// 大屏阅读模式下的右侧评论弹出抽屉与侧边栏组件
class FeedCommentSideSheet extends StatefulWidget {
  const FeedCommentSideSheet({
    super.key,
    required this.controller,
    required this.onClose,
    required this.onReply,
    required this.onToggleReplyTop,
    required this.onBlockReply,
    required this.postLikeDeleteFollow,
    required this.onLike,
    required this.changeReplySort,
    this.width,
  });

  final FeedController controller;
  final VoidCallback onClose;
  final void Function(ReplyType type, dynamic id, dynamic uname, dynamic fid)
      onReply;
  final Future<void> Function(Datum reply)? onToggleReplyTop;
  final void Function(dynamic uid, dynamic fid) onBlockReply;
  final void Function(dynamic id, dynamic fid, {bool isReply})
      postLikeDeleteFollow;
  final void Function(dynamic id, dynamic like, {bool isReply}) onLike;
  final void Function(ReplySortType selection) changeReplySort;
  final double? width;

  @override
  State<FeedCommentSideSheet> createState() => _FeedCommentSideSheetState();
}

class _FeedCommentSideSheetState extends State<FeedCommentSideSheet> {
  final ScrollController _scrollController = ScrollController();
  final GlobalKey<RefreshIndicatorState> _refreshKey =
      GlobalKey<RefreshIndicatorState>();

  static const List<(ReplySortType, String)> _sortOptions = [
    (ReplySortType.def, '默认排序'),
    (ReplySortType.dateline, '按时间'),
    (ReplySortType.hot, '按热度'),
    (ReplySortType.author, '只看楼主'),
  ];

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 200) {
      final c = widget.controller;
      if (!c.repliesDeferred.value &&
          !c.isEnd &&
          !c.automaticLoadPaused &&
          !c.isLoading) {
        c.setFooterState(LoadingState.loading());
        c.onGetData(false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final textTheme = theme.textTheme;

    return Container(
      width: widget.width ?? 420,
      height: double.infinity,
      decoration: BoxDecoration(
        color: colorScheme.surface,
        border: Border(
          left: BorderSide(
            color: colorScheme.outlineVariant.withValues(alpha: 0.5),
            width: 1,
          ),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            offset: const Offset(-4, 0),
            blurRadius: 16,
          ),
        ],
      ),
      child: SafeArea(
        top: true,
        bottom: true,
        child: Column(
          children: [
            _buildHeader(context, colorScheme, textTheme),
            const Divider(height: 1),
            Expanded(
              child: Obx(() => _buildContent(context)),
            ),
            const Divider(height: 1),
            _buildBottomReplyBar(context, colorScheme),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(
      BuildContext context, ColorScheme colorScheme, TextTheme textTheme) {
    final c = widget.controller;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        children: [
          Icon(Icons.forum_outlined, size: 22, color: colorScheme.primary),
          const SizedBox(width: 8),
          Expanded(
            child: Obx(
              () => Row(
                children: [
                  Text(
                    '评论',
                    style: textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  if (c.replyNum != null && c.replyNum! > 0) ...[
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: colorScheme.primaryContainer,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        '${c.replyNum}',
                        style: textTheme.labelSmall?.copyWith(
                          color: colorScheme.onPrimaryContainer,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
          Obx(
            () => PopupMenuButton<ReplySortType>(
              tooltip: '评论排序',
              initialValue: c.replySelection.value,
              onSelected: widget.changeReplySort,
              itemBuilder: (_) => [
                for (final option in _sortOptions)
                  CheckedPopupMenuItem(
                    value: option.$1,
                    checked: option.$1 == c.replySelection.value,
                    child: Text(option.$2),
                  )
              ],
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      _sortOptions
                          .firstWhere(
                              (opt) => opt.$1 == c.replySelection.value,
                              orElse: () => _sortOptions.first)
                          .$2,
                      style: textTheme.bodySmall?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const Icon(Icons.expand_more, size: 18),
                  ],
                ),
              ),
            ),
          ),
          IconButton(
            tooltip: '刷新评论',
            icon: const Icon(Icons.refresh, size: 20),
            onPressed: () {
              widget.controller.loadReplies();
            },
          ),
          IconButton(
            tooltip: '收起侧栏',
            icon: const Icon(Icons.close, size: 20),
            onPressed: widget.onClose,
          ),
        ],
      ),
    );
  }

  Widget _buildContent(BuildContext context) {
    final c = widget.controller;
    final state = c.loadingState.value;

    if (c.repliesDeferred.value && state is! Success) {
      return _buildDeferredPrompt(context, state);
    }

    switch (state) {
      case Loading():
        return const Center(child: ExpressiveLoadingIndicator());
      case Empty():
        return _buildEmpty(context);
      case Error():
        return _buildError(context, state);
      case Success():
        return _buildSuccessList(context, state);
      default:
        return const SizedBox();
    }
    return const SizedBox();
  }

  Widget _buildSuccessList(BuildContext context, Success state) {
    final c = widget.controller;
    List<Datum> dataList = state.response;
    int coinReplies = 0;
    final showCoinReplies = c.showCoinReplies.value;

    if (GStorage.foldCoinReplies) {
      final kept = <Datum>[];
      for (final reply in dataList) {
        if (!c.isPinnedReply(reply) && isCoinOnlyReply(reply)) {
          coinReplies++;
          if (showCoinReplies) kept.add(reply);
        } else {
          kept.add(reply);
        }
      }
      dataList = kept;
    }

    final headerCount = coinReplies > 0 ? 1 : 0;
    final isFeedAuthor = GlobalData().isLogin &&
        c.feedUid != null &&
        GlobalData().uid == '${c.feedUid}';

    return ExpressiveRefreshIndicator(
      refreshKey: _refreshKey,
      onRefresh: () async {
        await c.loadReplies();
      },
      child: ListView.separated(
        controller: _scrollController,
        physics: const AlwaysScrollableScrollPhysics(
          parent: BouncingScrollPhysics(),
        ),
        padding: const EdgeInsets.symmetric(vertical: 8),
        itemCount: dataList.length + headerCount + 1,
        separatorBuilder: (_, __) => const Divider(height: 1),
        itemBuilder: (context, position) {
          if (position < headerCount) {
            return _buildCoinFoldBar(context, coinReplies, showCoinReplies);
          }
          final index = position - headerCount;
          if (index == dataList.length) {
            return Obx(
              () => c.repliesDeferred.value
                  ? _buildDeferredPrompt(context, c.footerState.value,
                      hasReplies: true)
                  : footerWidget(
                      c.footerState.value,
                      () {
                        c
                          ..isEnd = false
                          ..setFooterState(LoadingState.loading())
                          ..onGetData(false);
                      },
                    ),
            );
          }

          final reply = dataList[index];
          return FeedReplyCard(
            data: reply,
            isTopReply: c.isPinnedReply(reply),
            isPinned: c.topReply?.id == reply.id,
            onToggleTop: isFeedAuthor ? widget.onToggleReplyTop : null,
            onBlock: widget.onBlockReply,
            onReply: (id, uname, fid) {
              if (GlobalData().isLogin) {
                widget.onReply(ReplyType.reply, id, uname, fid);
              }
            },
            onDelete: (id, fid) {
              widget.postLikeDeleteFollow(id, fid, isReply: true);
            },
            onLike: (id, like) {
              widget.onLike(id, like, isReply: true);
            },
          );
        },
      ),
    );
  }

  Widget _buildCoinFoldBar(
      BuildContext context, int count, bool expanded) {
    final colors = Theme.of(context).colorScheme;
    return InkWell(
      onTap: () => widget.controller.showCoinReplies.value = !expanded,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        child: Row(
          children: [
            Icon(expanded ? Icons.unfold_less : Icons.unfold_more,
                size: 18, color: colors.outline),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                '已折叠 $count 条仅包含打赏的评论',
                style: TextStyle(fontSize: 13, color: colors.outline),
              ),
            ),
            Text(
              expanded ? '收起' : '展开',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.bold,
                color: colors.primary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmpty(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.chat_bubble_outline,
              size: 56, color: colorScheme.outlineVariant),
          const SizedBox(height: 12),
          Text(
            '暂无评论',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.bold,
              color: colorScheme.outline,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            '快来发表第一条评论吧~',
            style: TextStyle(fontSize: 13, color: colorScheme.outline),
          ),
        ],
      ),
    );
  }

  Widget _buildError(BuildContext context, Error state) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, size: 48, color: Colors.amber),
            const SizedBox(height: 12),
            Text(state.errMsg, textAlign: TextAlign.center),
            const SizedBox(height: 16),
            FilledButton.tonal(
              onPressed: widget.controller.loadReplies,
              child: const Text('重新加载评论'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDeferredPrompt(BuildContext context, LoadingState state,
      {bool hasReplies = false}) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.security, size: 48),
          const SizedBox(height: 12),
          Text(hasReplies ? '评论加载已暂停' : '评论尚未加载',
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          const SizedBox(height: 8),
          const Text(
            '设备标识尚未取得，加载评论可能需要验证码验证。可在设置中获取或导入后再加载。',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 13),
          ),
          if (state is Error) ...[
            const SizedBox(height: 8),
            Text(state.errMsg,
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.red, fontSize: 12)),
          ],
          const SizedBox(height: 16),
          FilledButton.tonalIcon(
            onPressed: widget.controller.loadReplies,
            icon: const Icon(Icons.download_outlined),
            label: const Text('加载评论并验证'),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomReplyBar(BuildContext context, ColorScheme colorScheme) {
    final c = widget.controller;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      color: colorScheme.surface,
      child: Row(
        children: [
          Expanded(
            child: Material(
              color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.6),
              borderRadius: BorderRadius.circular(24),
              child: InkWell(
                borderRadius: BorderRadius.circular(24),
                onTap: () {
                  if (GlobalData().isLogin) {
                    widget.onReply(
                      ReplyType.feed,
                      c.id,
                      c.feedUsername,
                      null,
                    );
                  } else {
                    Get.toNamed('/login');
                  }
                },
                child: Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  child: Row(
                    children: [
                      Icon(Icons.edit_note,
                          size: 18, color: colorScheme.outline),
                      const SizedBox(width: 8),
                      Text(
                        GlobalData().isLogin ? '写下你的善意评论...' : '登录后参与评论',
                        style: TextStyle(
                          fontSize: 14,
                          color: colorScheme.outline,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          IconButton.filledTonal(
            tooltip: '发送回复',
            icon: const Icon(Icons.send_rounded, size: 18),
            onPressed: () {
              if (GlobalData().isLogin) {
                widget.onReply(
                  ReplyType.feed,
                  c.id,
                  c.feedUsername,
                  null,
                );
              } else {
                Get.toNamed('/login');
              }
            },
          ),
        ],
      ),
    );
  }
}
