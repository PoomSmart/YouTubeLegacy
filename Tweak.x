#import "TweakHeader.h"
#import <dlfcn.h>
#import <sys/sysctl.h>
#import <version.h>
#import <PSHeader/Misc.h>
#import <YouTubeHeader/ELMView.h>
#import <YouTubeHeader/ELMNodeController.h>
#import <YouTubeHeader/YTAlertView.h>
#import <YouTubeHeader/YTIOpenElementsScreenCommand.h>
#import <YouTubeHeader/YTPageStyleController.h>

NSString *realAppVersion;
BOOL isLegacy = NO;
BOOL isYouTube18OrNewer = NO;
BOOL isYouTube19OrNewer = NO;
BOOL isYouTube20OrNewer = NO;
static id (*ELMMakeElementFunc)(id data, id context) = NULL;

static ELMNodeController *nodeControllerForELMView(ELMView *elmView) {
    id controller = nil;
    @try {
        controller = [elmView valueForKey:@"_strongRootController"];
        if (!controller)
            controller = [elmView valueForKey:@"_rootController"];
    } @catch (NSException *exception) {
        return nil;
    }
    if ([controller respondsToSelector:@selector(materializedInstance)]) {
        id materializedInstance = [controller materializedInstance];
        if (materializedInstance)
            controller = materializedInstance;
    }
    return [controller isKindOfClass:%c(ELMNodeController)] ? controller : nil;
}

void YTLRebuildOpenElementsControllerIfNeeded(id controller) {
    if (!isLegacy || !ELMMakeElementFunc)
        return;

    id command = nil;
    id context = nil;
    ELMView *elementView = nil;
    @try {
        command = [controller valueForKey:@"_command"];
        context = [controller valueForKey:@"_context"];
        elementView = [controller valueForKey:@"_elementView"];
    } @catch (NSException *exception) {
        return;
    }

    if (!command || !context || !elementView)
        return;

    NSInteger pageStyle = [%c(YTPageStyleController) pageStyle];
    BOOL shouldForceDarkTheme = pageStyle == 1;
    [(YTIOpenElementsScreenCommand *)command setForceDarkTheme:shouldForceDarkTheme];

    id commandElement = [(YTIOpenElementsScreenCommand *)command element];
    if (!commandElement)
        return;

    id elementData = [(YTIOpenElementsScreenCommandElement *)commandElement data];
    if (!elementData)
        return;

    id newElement = ELMMakeElementFunc(elementData, context);
    if (!newElement)
        return;

    ELMNodeController *nodeController = nodeControllerForELMView(elementView);
    if (nodeController)
        [nodeController updateWithElement:newElement];
}

#pragma mark - Spoof app version

%hook YTGlobalConfig

- (BOOL)shouldBlockUpgradeDialog { return YES; }

%end

%hook YTVersionUtils

+ (NSString *)appVersionLong {
    NSString *appVersion = %orig;
    if ([appVersion compare:@"20.21.6" options:NSNumericSearch] == NSOrderedAscending)
        return @"20.21.6";
    return appVersion;
}

+ (NSString *)appVersion {
    NSString *appVersion = %orig;
    if ([appVersion compare:@"20.21.6" options:NSNumericSearch] == NSOrderedAscending)
        return @"20.21.6";
    return appVersion;
}

%end

#pragma mark - Fix "Play all" button in playlist not displaying

%group PlaylistPageRefresh

BOOL (*YTPlaylistPageRefreshSupported)(void) = NULL;
%hookf(BOOL, YTPlaylistPageRefreshSupported) {
    return YES;
}

%end

#pragma mark - Improve general JS element compatibility

NSBundle *TweakBundle(void) {
    static NSBundle *bundle = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        NSString *tweakBundlePath = [[NSBundle mainBundle] pathForResource:TweakName ofType:@"bundle"];
        bundle = [NSBundle bundleWithPath:tweakBundlePath ?: PS_ROOT_PATH_NS(@"/Library/Application Support/" TweakName ".bundle")];
    });
    return bundle;
}

#pragma mark - Spoof iOS version

%group Spoofing

%hook UIDevice

- (NSString *)systemVersion {
    return @"15.8.7";
}

%end

%hook NSProcessInfo

- (NSOperatingSystemVersion)operatingSystemVersion {
    NSOperatingSystemVersion version;
    version.majorVersion = 15;
    version.minorVersion = 8;
    version.patchVersion = 7;
    return version;
}

%end

%hookf(int, sysctlbyname, const char *name, void *oldp, size_t *oldlenp, void *newp, size_t newlen) {
    if (strcmp(name, "kern.osversion") == 0) {
        int ret = %orig;
        if (oldp) {
            strcpy((char *)oldp, IOS_BUILD);
            *oldlenp = strlen(IOS_BUILD);
        }
        return ret;
    }
    return %orig;
}

%end

#pragma mark - Debug

// static void debugURLRequest(NSMutableURLRequest *request, NSString *method) {
//     HBLogInfo(@"YTL %@: %@", method, request);
// }

// %hook YTAccountScopedInnerTubeServiceImpl

// - (NSMutableURLRequest *)URLRequestWithRequest:(id)arg1 method:(NSString *)method timeoutInterval:(NSTimeInterval)arg3 {
//     NSMutableURLRequest *request = %orig;
//     debugURLRequest(request, method);
//     return request;
// }

// - (NSMutableURLRequest *)URLRequestWithRequest:(id)arg1 method:(NSString *)method timeoutInterval:(NSTimeInterval)arg3 cacheKeysForStreamingResponsesFoundInCache:(id)arg4 {
//     NSMutableURLRequest *request = %orig;
//     debugURLRequest(request, method);
//     return request;
// }

// %end

// %hook YTELMLogger

// - (void)logErrorEvent:(id)event {
//     HBLogInfo(@"logErrorEvent: %@", event);
//     %orig;
// }

// %end

// %hook YTELMErrorHandler

// - (void)didNotFindTemplate {
//     HBLogInfo(@"didNotFindTemplate");
//     %orig;
// }

// %end

// %hook YTColdConfig

// - (BOOL)elementsLogNilMaterializedElement {
//     return YES;
// }

// - (BOOL)elementsSharedComponentLogNilMaterializedElement {
//     return YES;
// }

// %end

// %hook YTSafeModeController

// - (void)setupAndCheckForCrashLoop {}

// %end

%ctor {
    NSString *bundlePath = [NSString stringWithFormat:@"%@/Frameworks/Module_Framework.framework", NSBundle.mainBundle.bundlePath];
    dlopen([bundlePath UTF8String], RTLD_NOW);
    MSImageRef ref = MSGetImageByName([[bundlePath stringByAppendingString:@"/Module_Framework"] UTF8String]);
    NSBundle *tweakBundle = TweakBundle();
    NSBundle *moduleFrameworkBundle = [NSBundle bundleWithPath:bundlePath];
    NSBundle *mainBundle = [NSBundle mainBundle];
    NSString *mainVersion = [mainBundle objectForInfoDictionaryKey:@"CFBundleVersion"];
    NSString *mainShortVersion = [mainBundle objectForInfoDictionaryKey:@"CFBundleShortVersionString"];
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    if (moduleFrameworkBundle) {
        realAppVersion = [moduleFrameworkBundle objectForInfoDictionaryKey:@"CFBundleShortVersionString"];
        if ([realAppVersion compare:@"20.24.4" options:NSNumericSearch] != NSOrderedAscending) return;
        isLegacy = YES;
        if ([realAppVersion compare:@"18.00.0" options:NSNumericSearch] != NSOrderedAscending)
            isYouTube18OrNewer = YES;
        BOOL infoPlistLikelyModified = [realAppVersion compare:mainVersion options:NSNumericSearch] != NSOrderedSame
            || [realAppVersion compare:mainShortVersion options:NSNumericSearch] != NSOrderedSame;
        if (infoPlistLikelyModified && ![defaults boolForKey:DidShowInformationAlert2Key]) {
            [defaults setBool:YES forKey:DidShowInformationAlert2Key];
            dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(3.0 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
                YTAlertView *alertView = [%c(YTAlertView) infoDialog];
                alertView.title = TweakName;
                alertView.subtitle = LOC(@"INCONSISTENT_VERSION_INFORMATION");
                [alertView show];
            });
        }
        if (![defaults boolForKey:DidApplyDefaultSettingsKey]) {
            [defaults setBool:YES forKey:DidApplyDefaultSettingsKey];
            [defaults setBool:YES forKey:YouSpeedEnabledKey];
            [defaults setInteger:1 forKey:YouSpeedButtonPositionKey];
            [defaults synchronize];
        }
        if (![defaults boolForKey:DidApplyDefaultSettings2Key]) {
            [defaults setBool:YES forKey:DidApplyDefaultSettings2Key];
            [defaults setBool:YES forKey:RYDUseItsDataKey];
            [defaults synchronize];
        }
        if (![defaults boolForKey:DidShowInformationAlertKey]) {
            [defaults setBool:YES forKey:DidShowInformationAlertKey];
            dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(3.0 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
                YTAlertView *alertView = [%c(YTAlertView) infoDialog];
                alertView.title = TweakName;
                alertView.subtitle = LOC(@"TWEAK_INFORMATION");
                [alertView show];
            });
        }
        if (ref) {
            ELMMakeElementFunc = (id (*)(id, id))MSFindSymbol(ref, "_ELMMakeElement");
            YTPlaylistPageRefreshSupported = MSFindSymbol(ref, "_YTPlaylistPageRefreshSupported");
            if (YTPlaylistPageRefreshSupported) {
                %init(PlaylistPageRefresh);
            }
        }
    } else {
        realAppVersion = mainVersion;
        if ([realAppVersion compare:@"20.24.4" options:NSNumericSearch] != NSOrderedAscending) return;
        if ([realAppVersion compare:@"19.00.0" options:NSNumericSearch] != NSOrderedAscending)
            isYouTube19OrNewer = YES;
        if ([realAppVersion compare:@"20.00.0" options:NSNumericSearch] != NSOrderedAscending)
            isYouTube20OrNewer = YES;
    }
    if (!IS_IOS_OR_NEWER(iOS_15_0)) {
        %init(Spoofing);
    }
    %init;
}
