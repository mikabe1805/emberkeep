import 'dart:js_interop';
import 'dart:js_interop_unsafe';

/// Whether the constructor used by audioplayers_web exists in this browser.
///
/// WebKit automation and some embedded web views can render Flutter while
/// omitting Web Audio entirely. Probing first keeps sound enhancement-only and
/// prevents every tap from creating a failed player and a console exception.
bool get browserAudioAvailable {
  try {
    return globalContext.getProperty<JSObject?>('AudioContext'.toJS) != null;
  } catch (_) {
    return false;
  }
}
