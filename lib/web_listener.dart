import 'dart:html' as html;

void setupBeforeUnloadListener(Function callback) {
  html.window.addEventListener('beforeunload', (event) async {
    callback();
  });
}