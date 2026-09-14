import 'dart:async';
import 'package:receive_sharing_intent/receive_sharing_intent.dart';
import 'momo_sms_parser.dart';

/// iOS has no API for a third-party app to read SMS automatically. The
/// realistic workaround: the user long-presses a MoMo message in Messages,
/// taps Share, and picks this app — iOS delivers the message text to us via
/// the standard Share Sheet, which this class listens for. Works on Android
/// too as a manual fallback if auto-read isn't set up.
///
/// This requires native share-extension wiring in Xcode (adding a Share
/// Extension target) — see ios/README-share-extension.md for the steps,
/// since that part can't be done in Dart alone.
class ShareIntentService {
  static StreamSubscription? _sub;

  /// Call once at app startup. [onSharedText] fires with the raw text the
  /// user shared; parse it the same way as an auto-read SMS.
  static void start({required void Function(String sharedText) onSharedText}) {
    // Text shared while the app was already running
    _sub = ReceiveSharingIntent.instance.getMediaStream().listen((files) {
      for (final f in files) {
        if (f.type.toString().contains('text') && f.path.isNotEmpty) {
          onSharedText(f.path);
        }
      }
    });

    // Text shared that launched the app fresh (cold start)
    ReceiveSharingIntent.instance.getInitialMedia().then((files) {
      for (final f in files) {
        if (f.type.toString().contains('text') && f.path.isNotEmpty) {
          onSharedText(f.path);
        }
      }
      ReceiveSharingIntent.instance.reset();
    });
  }

  static void dispose() => _sub?.cancel();

  /// Convenience: parse shared text immediately, for screens that just want
  /// the structured result rather than handling the raw string themselves.
  static ParsedMomoMessage parseSharedText(String text) => MomoSmsParser.parse(text);
}
