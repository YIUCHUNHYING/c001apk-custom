import 'package:c001apk_flutter/components/network_image.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../logic/model/feed/datum.dart';
import '../../utils/date_util.dart';
import '../../utils/extensions.dart';
import '../../utils/utils.dart';

// ignore: constant_identifier_names
enum AppCardType { APP, PRODUCT, TOPIC, USER, CONTACTS, RECENT }

class AppCard extends StatelessWidget {
  const AppCard({
    super.key,
    required this.appCardType,
    required this.data,
    this.isHomeCard = false,
  });

  final AppCardType appCardType;
  final Datum data;
  final bool isHomeCard;

  @override
  Widget build(BuildContext context) {
    return Material(
      borderRadius: const BorderRadius.all(Radius.circular(12)),
      color: isHomeCard
          ? Theme.of(context).colorScheme.surface
          : Theme.of(context).colorScheme.onInverseSurface,
      child: InkWell(
        onTap: () {
          if (appCardType == AppCardType.CONTACTS) {
            Get.toNamed(
                '/u/${data.userInfo?.uid != null ? data.userInfo!.uid.toString() : data.fUserInfo?.uid != null ? data.fUserInfo!.uid.toString() : ''}');
          } else {
            Utils.onOpenLink(data.url.orEmpty, data.title, true, context);
          }
        },
        borderRadius: const BorderRadius.all(Radius.circular(12)),
        child: _buildBody(context),
      ),
    );
  }

  Widget _buildBody(BuildContext context) {
    return LayoutBuilder(builder: (context, constraints) {
      // 双列/四列网格里卡片很窄，字号适当收一点，避免「热度 / 讨论」被挤掉。
      final statStyle = TextStyle(
        fontSize: constraints.maxWidth < 260 ? 12.5 : 14.0,
        color: Theme.of(context).colorScheme.outline,
      );
      return Padding(
        padding: const EdgeInsets.all(10),
        child: Row(
          children: [
            clipNetworkImage(
              [
                AppCardType.APP,
                AppCardType.PRODUCT,
                AppCardType.TOPIC,
                AppCardType.RECENT
              ].contains(appCardType)
                  ? data.logo.orEmpty
                  : appCardType == AppCardType.USER
                      ? data.userAvatar.orEmpty
                      : data.userInfo?.userAvatar != null
                          ? data.userInfo!.userAvatar.toString()
                          : data.fUserInfo!.userAvatar.toString(),
              isAvatar: [AppCardType.USER, AppCardType.CONTACTS]
                      .contains(appCardType) ||
                  (appCardType == AppCardType.RECENT &&
                      data.targetType == 'user'),
              radius: 8,
              width: 40,
              height: 40,
            ),
            const SizedBox(width: 10),
            // 窄卡片里话题名与热度、讨论数容易把 Row 撑出卡片边界，
            // 这里统一用 Expanded + Flexible 收缩并省略，杜绝溢出。
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    [
                      AppCardType.APP,
                      AppCardType.PRODUCT,
                      AppCardType.TOPIC,
                    ].contains(appCardType)
                        ? data.title.orEmpty
                        : appCardType == AppCardType.USER
                            ? data.userInfo?.username ?? ''
                            : appCardType == AppCardType.RECENT
                                ? '${data.targetTypeTitle}: ${data.title}'
                                : data.userInfo?.username != null
                                    ? data.userInfo!.username.toString()
                                    : data.fUserInfo!.username.toString(),
                    // 窄卡片允许标题折成两行，避免话题名被截得看不出是什么。
                    maxLines: constraints.maxWidth < 260 ? 2 : 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  // 宽度不够时让「热度 / 讨论」自动换到第二行，而不是被裁掉，
                  // 保证具体数值始终可读。
                  Wrap(
                    spacing: 10,
                    runSpacing: 2,
                    children: [
                      Text(
                        appCardType == AppCardType.APP
                            ? '${data.commentnum}讨论'
                            : [AppCardType.PRODUCT, AppCardType.TOPIC]
                                    .contains(appCardType)
                                ? '${data.hotNumTxt}热度'
                                : appCardType == AppCardType.USER
                                    ? '${data.follow}关注'
                                    : appCardType == AppCardType.CONTACTS
                                        ? '${data.userInfo?.follow ?? data.fUserInfo?.follow}关注'
                                        : '${data.followNum}关注',
                        style: statStyle,
                      ),
                      Text(
                        appCardType == AppCardType.APP
                            ? '${data.downCount}下载'
                            : appCardType == AppCardType.PRODUCT
                                ? '${data.feedCommentNumTxt}讨论'
                                : appCardType == AppCardType.TOPIC
                                    ? '${data.commentnumTxt}讨论'
                                    : appCardType == AppCardType.USER
                                        ? '${data.fans}粉丝'
                                        : appCardType == AppCardType.CONTACTS
                                            ? '${data.userInfo?.fans ?? data.fUserInfo?.fans}粉丝'
                                            : data.targetType == 'user'
                                                ? '${data.fansNum}粉丝'
                                                : '${data.commentNum}讨论',
                        style: statStyle,
                      ),
                      if (appCardType == AppCardType.USER)
                        Text(
                          '${DateUtil.fromToday(data.logintime)}活跃',
                          style: statStyle,
                        ),
                    ],
                  ),
                ],
              ),
            )
          ],
        ),
      );
    });
  }
}
