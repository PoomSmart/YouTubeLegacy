#import <Foundation/Foundation.h>
#import <version.h>

extern int32_t NSExtensionMain(int32_t argc, char **argv);

// YouTube at least 19.x WidgetKitExtension embeds #available(iOS 16.1+) checks in its
// WidgetBundle body. iOS 15 SwiftUI fatals with "if #available in
// WidgetBundleBuilder includes an unknown OS version" instead of treating them
// as unavailable. Exit before SwiftUI initializes to avoid background crashes.

%hookf(int32_t, NSExtensionMain, int32_t argc, char **argv) {
    if (!IS_IOS_OR_NEWER(iOS_16_0))
        return 0;
    return %orig(argc, argv);
}

%ctor {
    if (![NSBundle.mainBundle.bundleIdentifier isEqualToString:@"com.google.ios.youtube.WidgetKitExtension"])
        return;
    %init;
}
