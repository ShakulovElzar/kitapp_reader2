import 'dart:js_interop';

@JS()
external set kitappSwipeForward(JSFunction callback);

@JS()
external set kitappSwipeBackward(JSFunction callback);

void registerReaderSwipeBridge({
  required void Function() onForward,
  required void Function() onBackward,
}) {
  kitappSwipeForward = onForward.toJS;
  kitappSwipeBackward = onBackward.toJS;
}

void unregisterReaderSwipeBridge() {
  kitappSwipeForward = (() {}).toJS;
  kitappSwipeBackward = (() {}).toJS;
}
