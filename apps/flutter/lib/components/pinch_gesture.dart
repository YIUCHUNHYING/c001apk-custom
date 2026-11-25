import 'package:flutter/gestures.dart';
import 'package:flutter/widgets.dart';

/// 双指优先的手势识别器。
///
/// 主页内容用 TabBarView 承载，横向拖动会切换分类。双指捏合时两根手指常常
/// 同向移动，很容易被判成「翻页」，于是想捏合却切了 tab。本识别器在第二根
/// 手指按下时立刻接管整段手势，让同级的横滑识别器全部落败；一旦是单指移动
/// 就马上让位，滚动与翻页保持原样。
class PinchPriorityRecognizer extends OneSequenceGestureRecognizer {
  PinchPriorityRecognizer({VoidCallback? onStart, VoidCallback? onEnd})
      : _onStart = onStart,
        _onEnd = onEnd;

  VoidCallback? _onStart;
  VoidCallback? _onEnd;
  final Set<int> _pointers = <int>{};
  bool _claimed = false;

  set onStart(VoidCallback? value) => _onStart = value;
  set onEnd(VoidCallback? value) => _onEnd = value;

  @override
  void addAllowedPointer(PointerDownEvent event) {
    startTrackingPointer(event.pointer, event.transform);
    _pointers.add(event.pointer);
    if (_pointers.length >= 2 && !_claimed) {
      _claimed = true;
      _onStart?.call();
      resolve(GestureDisposition.accepted);
    }
  }

  @override
  void handleEvent(PointerEvent event) {
    if (event is PointerMoveEvent) {
      if (_claimed) return;
      // 单指移动说明不是捏合：立即让位，不影响滚动/翻页。
      resolve(GestureDisposition.rejected);
      _pointers.remove(event.pointer);
      stopTrackingPointer(event.pointer);
      return;
    }
    if (event is PointerUpEvent || event is PointerCancelEvent) {
      _pointers.remove(event.pointer);
      if (!_claimed) resolve(GestureDisposition.rejected);
      stopTrackingPointer(event.pointer);
    }
  }

  @override
  void didStopTrackingLastPointer(int pointer) {
    _pointers.clear();
    if (_claimed) {
      _claimed = false;
      _onEnd?.call();
    }
  }

  @override
  String get debugDescription => 'pinch priority';
}

/// 把 [PinchPriorityRecognizer] 挂到子树上，双指手势优先于横向翻页。
class PinchGestureDetector extends StatelessWidget {
  const PinchGestureDetector({
    super.key,
    required this.child,
    this.onPinchStart,
    this.onPinchEnd,
  });

  final Widget child;
  final VoidCallback? onPinchStart;
  final VoidCallback? onPinchEnd;

  @override
  Widget build(BuildContext context) {
    return RawGestureDetector(
      behavior: HitTestBehavior.translucent,
      gestures: <Type, GestureRecognizerFactory>{
        PinchPriorityRecognizer:
            GestureRecognizerFactoryWithHandlers<PinchPriorityRecognizer>(
          () => PinchPriorityRecognizer(
              onStart: onPinchStart, onEnd: onPinchEnd),
          (recognizer) {
            recognizer
              ..onStart = onPinchStart
              ..onEnd = onPinchEnd;
          },
        ),
      },
      child: child,
    );
  }
}
