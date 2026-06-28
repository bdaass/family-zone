import 'dart:js_interop';

extension type FzWindow(JSObject _) implements JSObject {
  external bool? get __FZ_IS_IOS;
  external bool? get __FZ_IS_MOBILE;
  external bool? get __FZ_IS_GECKO;
  external bool? get __FZ_IS_EDGE;
}

@JS('window')
external FzWindow get _window;

bool get isIOSUserAgent => _window.__FZ_IS_IOS == true;

bool get isMobileUserAgent => _window.__FZ_IS_MOBILE == true;

bool get isGeckoUserAgent => _window.__FZ_IS_GECKO == true;

bool get isEdgeUserAgent => _window.__FZ_IS_EDGE == true;
