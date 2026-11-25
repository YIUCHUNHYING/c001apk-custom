import 'package:c001apk_flutter/components/network_image.dart';
import 'package:flutter/material.dart';

import '../../components/self_sized_horizontal_list.dart';
import '../../logic/model/feed/entity.dart';
import '../../utils/utils.dart';

class ImageSquareScrollCard extends StatelessWidget {
  const ImageSquareScrollCard({super.key, required this.dataList});

  final List<Entity> dataList;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, constraints) {
      double width = (constraints.maxWidth - 40) / 5;
      return SelfSizedHorizontalList(
        gapSize: 10,
        padding: null,
        itemCount: dataList.length,
        childBuilder: (index) => _imageSquareScrollCardItem(
          context,
          width,
          dataList[index],
        ),
      );
    });
  }

  Widget _imageSquareScrollCardItem(
      BuildContext context, double width, Entity data) {
    final dpr = MediaQuery.devicePixelRatioOf(context);
    return SizedBox(
      width: width,
      height: width,
      child: GestureDetector(
        onTap: () =>
            Utils.onOpenLink(data.url.toString(), data.title, true, context),
        child: Stack(
          children: [
            clipNetworkImage(
              data.pic.toString(),
              radius: 12,
              width: width,
              height: width,
              fit: BoxFit.cover,
              // 按显示尺寸解码，一行五张时避免整张大图解码造成掉帧。
              memCacheWidth: (width * dpr).round().clamp(1, 4096).toInt(),
            ),
            // 用纯色叠加代替 DecorationImage 的 colorFilter，
            // 省掉每帧的滤镜合成开销。
            Positioned.fill(
              child: IgnorePointer(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: const Color(0x8D000000),
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
            Center(
              child: Text(
                data.title.toString(),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                    color: Color(0xFFEEEEEE)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
