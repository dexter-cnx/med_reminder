# iPhone Black Screen Issue

## Summary

On a physical iPhone, the application built and launched but showed a completely black screen. Earlier runs could also end with Flutter reporting that it could not connect to the Dart service protocol.

The final root cause was **not** Hive, EasyLocalization, `flutter_timezone`, `flutter_local_notifications`, or the Dart bootstrap sequence. The iOS host was configured to use the UIScene lifecycle, but UIKit could not resolve the configured `SceneDelegate` class at runtime. As a result, the Flutter engine and Dart VM could start, but no usable scene/window was attached to the main storyboard, so the device displayed a black screen.

The stable fix for this bootstrap baseline was to remove the UIScene manifest and use the classic `FlutterAppDelegate` lifecycle with `UIMainStoryboardFile`.

## User-visible symptoms

Typical symptoms were:

- the iPhone showed a black screen after launch;
- Debug and Profile builds behaved the same;
- Xcode completed the build successfully;
- Impeller/Metal initialized successfully;
- in some runs Flutter CLI later reported `Fail to connect to service protocol` / `Connection closed before full header was received`;
- no Dart exception explained the black screen.

The decisive Xcode console output was:

```text
Info.plist configuration "flutter" for UIWindowSceneSessionRoleApplication contained UISceneDelegateClassName key, but could not load class with name "Runner.SceneDelegate".

Info.plist configuration "(no name)" for UIWindowSceneSessionRoleApplication contained UISceneDelegateClassName key, but could not load class with name "Runner.SceneDelegate".

There is no scene delegate set. A scene delegate class must be specified to use a main storyboard file.

flutter: The Dart VM service is listening on http://127.0.0.1:.../
```

The important detail is the last line: **the Dart VM service was already running**. This proved that the Flutter engine and Dart isolate had started. The black screen therefore came from the native iOS scene/window lifecycle rather than from Dart initialization.

## Original iOS configuration

The generated/bootstrap iOS host used the UIScene lifecycle:

- `AppDelegate` conformed to `FlutterImplicitEngineDelegate`;
- `SceneDelegate` extended `FlutterSceneDelegate`;
- `Info.plist` contained `UIApplicationSceneManifest`;
- `UISceneDelegateClassName` referenced `$(PRODUCT_MODULE_NAME).SceneDelegate`;
- `UISceneStoryboardFile` referenced `Main`.

`SceneDelegate.swift` was also present in the Runner target Sources build phase. Even so, UIKit could not resolve the class at runtime on the tested device/toolchain.

Changing the plist reference from `Runner.SceneDelegate` to `SceneDelegate`, and exposing the Swift class through `@objc(SceneDelegate)`, did not solve the issue. That ruled out a simple module-prefix typo.

## Fix applied

For the current bootstrap baseline, the UIScene path was removed.

`ios/Runner/AppDelegate.swift` now uses the classic Flutter lifecycle:

```swift
import Flutter
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    GeneratedPluginRegistrant.register(with: self)
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }
}
```

`ios/Runner/Info.plist` no longer contains `UIApplicationSceneManifest`. The app continues to use:

```xml
<key>UIMainStoryboardFile</key>
<string>Main</string>
```

With no scene manifest, UIKit follows the classic application lifecycle and the main `FlutterViewController` from `Main.storyboard` is attached normally.

## Why the earlier Dart-focused fixes did not solve it

Several defensive changes were useful but were not the root-cause fix:

- wrapping `NotificationService.init()` in `try/catch`;
- making notification/timezone initialization lazy and bounded;
- moving notification initialization after the first Flutter frame;
- adding global `FlutterError` and `PlatformDispatcher` handlers;
- moving `runApp()` ahead of asynchronous storage/localization bootstrap;
- adding bootstrap checkpoints;
- adding iOS privacy descriptions for camera/photo-library access.

Those changes improve startup resilience and diagnostics, but the screen remained black because UIKit had no valid scene delegate/window path.

## Diagnostic procedure

When a future iOS build shows a black screen, use this order instead of assuming it is a Dart problem.

### 1. Run from Xcode

```bash
open ios/Runner.xcworkspace
```

Run the physical device and inspect the Xcode console.

### 2. Determine whether Dart actually started

If the console contains:

```text
flutter: The Dart VM service is listening on ...
```

then Dart has started. A black screen at that point should shift investigation toward the iOS host, scene/window attachment, Flutter view controller, or renderer rather than application bootstrap futures.

### 3. Search for scene errors

Look for:

```text
could not load class with name ...SceneDelegate
There is no scene delegate set
```

If present, inspect:

- `UIApplicationSceneManifest` in `Info.plist`;
- `UISceneDelegateClassName`;
- target membership / Runner Sources for `SceneDelegate.swift`;
- Swift/Objective-C runtime class exposure;
- whether the project should use UIScene at all.

### 4. Verify the classic fallback

For this project baseline, the expected configuration is:

- no `UIApplicationSceneManifest`;
- `AppDelegate: FlutterAppDelegate`;
- `GeneratedPluginRegistrant.register(with: self)` in `didFinishLaunchingWithOptions`;
- `UIMainStoryboardFile = Main`.

### 5. Clean native build artifacts after lifecycle changes

```bash
flutter clean
rm -rf ios/Pods ios/.symlinks
rm -rf ~/Library/Developer/Xcode/DerivedData/Runner-*
flutter pub get
cd ios && pod install && cd ..
```

Then run again on the target device.

## Validation result

After removing the UIScene configuration and returning to the classic `FlutterAppDelegate` lifecycle, the application rendered normally on the physical iPhone.

This incident should therefore be treated as an **iOS host lifecycle / SceneDelegate resolution issue**, not a medication-domain, storage, localization, notification, or timezone issue.

## Future consideration

UIScene support may be reintroduced later if a future native feature requires it, but it must be treated as a deliberate migration and physically validated before merging. Reintroducing the generated scene template without verifying runtime class resolution risks restoring the black-screen failure.
