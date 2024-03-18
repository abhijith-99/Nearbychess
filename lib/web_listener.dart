import 'dart:html' as html;
import 'dart:ui' as ui;




void setupBeforeUnloadListener(Function callback) {
  html.window.onBeforeUnload.listen((event) async {
    await callback();
    // Note: Returning a custom message is not supported in most modern browsers.
  });
}