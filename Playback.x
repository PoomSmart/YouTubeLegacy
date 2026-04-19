#import "TweakHeader.h"
#import <HBLog.h>
#import <YouTubeHeader/YTAutoplayAutonavController.h>
#import <YouTubeHeader/YTAutoplayController.h>
#import <YouTubeHeader/YTICoWatchWatchEndpointWrapperCommand.h>
#import <YouTubeHeader/YTWrapperSplitViewController.h>

#pragma mark - Fix video play/pause button not working

%hook YTHotConfig

- (unsigned int)playPauseButtonTargetDimensionDP {
    return 56;
}

%end

#pragma mark - Fix video next/previous buttons not working, autoplay not working

static GPBExtensionDescriptor *getCoWatchEndpointWrapperCommandDescriptor() {
    Class coWatchCommandClass = %c(YTICoWatchWatchEndpointWrapperCommand);
    if ([coWatchCommandClass respondsToSelector:@selector(coWatchWatchEndpointWrapperCommand)])
        return [coWatchCommandClass coWatchWatchEndpointWrapperCommand];
    return [coWatchCommandClass descriptor];
}

static YTICommand *legacyGetWatchEndpoint(YTICommand *command) {
    GPBMessage *message = [[command messageForFieldNumber:462702848] messageForFieldNumber:1];
    return [%c(YTICommand) parseFromData:[message data]];
}

static YTICommand *getWatchEndpoint(YTICommand *command) {
    GPBExtensionDescriptor *coWatchCommand = getCoWatchEndpointWrapperCommandDescriptor();
    if ([command hasExtension:coWatchCommand])
        return [(YTICoWatchWatchEndpointWrapperCommand *)[command getExtension:coWatchCommand] watchEndpoint];
    return legacyGetWatchEndpoint(command);
}

%hook YTAutoplayController

- (id)navEndpointHavingWatchEndpointOrNil:(YTICommand *)endpoint {
    if (!isLegacy) return %orig;
    return [endpoint hasActiveOnlineOrOfflineWatchEndpoint]
        || getWatchEndpoint(endpoint) != nil
        ? endpoint : nil;
}

- (void)sendWatchTransitionWithNavEndpoint:(YTICommand *)navEndpoint watchEndpointSource:(int)watchEndpointSource {
    if (isLegacy && ![navEndpoint hasActiveOnlineOrOfflineWatchEndpoint]) {
        YTICommand *watchEndpoint = getWatchEndpoint(navEndpoint);
        if (watchEndpoint) {
            HBLogDebug(@"sendWatchTransitionWithNavEndpoint: %@, watchEndpointSource: %d", watchEndpoint, watchEndpointSource);
            %orig(watchEndpoint, watchEndpointSource);
            return;
        }
    }
    HBLogDebug(@"original sendWatchTransitionWithNavEndpoint: %@, watchEndpointSource: %d", navEndpoint, watchEndpointSource);
    %orig;
}

%end

%hook YTAutonavController

- (id)navEndpointHavingWatchEndpointOrNil:(YTICommand *)endpoint {
    if (!isLegacy) return %orig;
    return [endpoint hasActiveOnlineOrOfflineWatchEndpoint]
        || [endpoint hasExtension:getCoWatchEndpointWrapperCommandDescriptor()]
        ? endpoint : nil;
}

- (void)sendWatchTransitionWithNavEndpoint:(YTICommand *)navEndpoint watchEndpointSource:(int)watchEndpointSource {
    if (isLegacy && ![navEndpoint hasActiveOnlineOrOfflineWatchEndpoint]) {
        YTICommand *watchEndpoint = getWatchEndpoint(navEndpoint);
        if (watchEndpoint) {
            HBLogDebug(@"sendWatchTransitionWithNavEndpoint: %@, watchEndpointSource: %d", watchEndpoint, watchEndpointSource);
            %orig(watchEndpoint, watchEndpointSource);
            return;
        }
    }
    HBLogDebug(@"original sendWatchTransitionWithNavEndpoint: %@, watchEndpointSource: %d", navEndpoint, watchEndpointSource);
    %orig;
}

%end

%hook YTAutoplayAutonavController

- (id)nextEndpointForAutonav {
    id endpoint = %orig;
    return endpoint ?: [self nextEndpointForAutoplay];
}

- (id)previousEndpointForAutonav {
    id endpoint = %orig;
    return endpoint ?: [self previousEndpointForAutoplay];
}

%end

#pragma mark - Fix left side of video player not responding to double tap to seek gesture

%hook YTColdConfig

- (BOOL)isLandscapeEngagementPanelEnabled { return YES; }

%end

#pragma mark - Fix split view not updating properly in You tab on iPad

%hook YTWrapperSplitViewController

- (void)updateSplitPane {
    if (!isLegacy || ![self.parentViewController isKindOfClass:%c(YTScrollableNavigationController)]) {
        %orig;
        return;
    }
    [self updateSplitPane_compact];
    [self maybeSendContentUpdateWithType:2];
}

%end
