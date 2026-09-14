# Setting up the iOS Share Extension

The `receive_sharing_intent` package in `pubspec.yaml` handles the Dart/Flutter
side of receiving shared text automatically. But iOS also requires one native
step in Xcode that can't be done from Dart code — adding a **Share Extension
target** to the iOS project. This is a one-time setup:

1. Run `flutter create .` in this project root first (generates `ios/Runner.xcodeproj`).
2. Open `ios/Runner.xcworkspace` in Xcode.
3. File → New → Target → **Share Extension**. Name it e.g. `ShareExtension`.
4. In the new extension's `Info.plist`, set `NSExtensionActivationSupportsText`
   to `true` under `NSExtensionActivationRule`, so it accepts shared plain text
   (the MoMo message) — not just images/URLs.
5. Point the extension's entry point at the `receive_sharing_intent` package's
   provided share-extension view controller — follow the package's iOS setup
   section on pub.dev for the exact class name for your installed version,
   since this detail can change between releases.
6. Add the extension target to your main app's "Embedded Content" build phase.
7. Set the App Group capability (same group ID) on **both** the main app
   target and the Share Extension target — this is how they pass the shared
   text between processes. Use an ID like `group.com.yourcompany.momotracker`
   and reference the same string in the Dart-side package config.

## Why this can't be skipped
iOS sandboxes every app, including extensions, from each other. A Share
Extension is Apple's *only* sanctioned way for your app to receive content
a user explicitly chose to share from another app (like Messages) — there is
no background/automatic equivalent, by design.

## Fallback if you'd rather skip this for now
Everything else in the app works without it: the "Add transaction" screen's
paste box (copy the MoMo text manually, paste it in) gives the same parsing
result with two fewer taps of setup, at the cost of one extra manual copy
step per transaction. Ship with paste-only first, add the Share Extension
later once the core app is working end-to-end.
