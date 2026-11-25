import 'package:c001apk_flutter/components/network_image.dart';
import 'package:flutter/material.dart';

import '../../components/cards/title_card.dart';
import '../../components/mouse_drag_scroll.dart';
import '../../logic/model/feed/datum.dart';
import '../../logic/model/feed/entity.dart';
import '../../utils/extensions.dart';
import '../../utils/utils.dart';

/// 「优质图文」这类横向图文卡。
///
/// 以前用 SelfSizedHorizontalList 先量高度、post-frame 再 setState 重建，
/// 卡片进入视口时会多出一次整段重建与布局，滚动到这里就掉帧。这里改成
/// 直接算高度（封面 + 固定两行标题），一次布局即可完成。
class ImageTextScrollCard extends StatelessWidget {
  const ImageTextScrollCard({super.key, required this.data});

  final Datum data;

  static const double _fontSize = 14;
  static const double _titleLineHeight = 1.35;
  static const double _verticalPadding = 5;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
        builder: (BuildContext context, BoxConstraints constraints) {
      final width = constraints.maxWidth / 3 * 2;
      final imageHeight = width / 2.22;
      final scale =
          MediaQuery.textScalerOf(context).scale(_fontSize) / _fontSize;
      final cardHeight = imageHeight +
          _verticalPadding * 2 +
          _fontSize * _titleLineHeight * 2 * scale;
      return Column(
        children: [
          if (!data.title.isNullOrEmpty)
            TitleCard(
              title: data.title.toString(),
              url: data.url ?? '',
              bottomPadding: 10,
            ),
          SizedBox(
            height: cardHeight,
            child: MouseDragScroll(
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: data.entities!.length,
                itemBuilder: (context, index) =>
                    _imageTextScrollCard(context, width, data.entities![index]),
                separatorBuilder: (_, __) => const SizedBox(width: 10),
              ),
            ),
          ),
        ],
      );
    });
  }

  Widget _imageTextScrollCard(BuildContext context, double width, Entity data) {
    final dpr = MediaQuery.devicePixelRatioOf(context);
    return SizedBox(
      width: width,
      child: Material(
        color: Theme.of(context).colorScheme.onInverseSurface,
        borderRadius: const BorderRadius.all(Radius.circular(12)),
        child: InkWell(
          borderRadius: const BorderRadius.all(Radius.circular(12)),
          onTap: () =>
              Utils.onOpenLink(data.url.orEmpty, data.title, true, context),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              clipNetworkImage(
                data.pic.orEmpty,
                width: width,
                height: width / 2.22,
                fit: BoxFit.cover,
                memCacheWidth: (width * dpr).round().clamp(1, 4096).toInt(),
                clipBorderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(12),
                  topRight: Radius.circular(12),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(
                    horizontal: 10, vertical: _verticalPadding),
                child: Text(
                  data.title.orEmpty,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: _fontSize,
                    height: _titleLineHeight,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
