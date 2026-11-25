import 'package:flutter/material.dart';

import '../utils/emoji_util.dart';

/// 把 `[表情]` / `#(表情)` 代码渲染成内联表情图，并支持行数限制。
///
/// 卡片里的热评需要控制行数，但 `htmlText` 走的是整段 HtmlWidget，
/// 没法按行截断，所以这里用 Text.rich + WidgetSpan 自己拼一段富文本。
class EmojiText extends StatelessWidget {
  const EmojiText(
    this.text, {
    super.key,
    required this.style,
    this.maxLines,
    this.overflow = TextOverflow.ellipsis,
  });

  final String text;
  final TextStyle style;
  final int? maxLines;
  final TextOverflow overflow;

  // `[笑哭]` 与 `#(笑哭)` 两种写法都可能出现。
  static final _pattern = RegExp(r'\[[^\]\n]+\]|#\([^)\n]+\)');

  static String _codeOf(String raw) =>
      raw.startsWith('#(') ? '[${raw.substring(2, raw.length - 1)}]' : raw;

  @override
  Widget build(BuildContext context) {
    final fontSize = style.fontSize ?? 14;
    final emojiSize = MediaQuery.textScalerOf(context).scale(fontSize) * 1.3;
    final colors = Theme.of(context).colorScheme;
    final spans = <InlineSpan>[];
    var cursor = 0;
    for (final match in _pattern.allMatches(text)) {
      if (match.start > cursor) {
        spans.add(TextSpan(text: text.substring(cursor, match.start)));
      }
      final raw = match.group(0)!;
      final asset = EmojiUtil.emojiMap[_codeOf(raw)];
      if (asset == null) {
        spans.add(TextSpan(text: raw));
      } else if (asset.endsWith('.png')) {
        spans.add(WidgetSpan(
          alignment: PlaceholderAlignment.middle,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 1),
            child: Image.asset(
              'assets/emojis/$asset',
              width: emojiSize,
              height: emojiSize,
            ),
          ),
        ));
      } else if (asset.endsWith('.icon')) {
        spans.add(WidgetSpan(
          alignment: PlaceholderAlignment.middle,
          child: Icon(Icons.photo_outlined, size: emojiSize, color: colors.primary),
        ));
      } else {
        spans.add(TextSpan(text: raw));
      }
      cursor = match.end;
    }
    if (cursor < text.length) {
      spans.add(TextSpan(text: text.substring(cursor)));
    }
    return Text.rich(
      TextSpan(children: spans, style: style),
      maxLines: maxLines,
      overflow: overflow,
    );
  }
}
