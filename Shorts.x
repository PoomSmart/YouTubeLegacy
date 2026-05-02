#import "TweakHeader.h"
#import <HBLog.h>
#import <YouTubeHeader/YTIIosSystemShareEndpoint.h>
#import <YouTubeHeader/YTIReelPlayerOverlayRenderer.h>
#import <YouTubeHeader/YTReelContentView.h>
#import <YouTubeHeader/YTUIUtils.h>

#pragma mark - Fix Shorts like/dislike/comments/share buttons not displaying

%hook YTReelWatchPlaybackOverlayView

- (void)setActionBarElementRenderer:(id)renderer {
    if (isYouTube20OrNewer) %orig;
}

%end

static void setOverlayRenderer(YTReelContentView *self, YTIReelPlayerOverlayRenderer *renderer) {
    renderer.likeButton = renderer.doubleTapLikeButton;
    NSString *videoId = renderer.likeButton.likeButtonRenderer.target.videoId;
    NSString *shortsUrl = [NSString stringWithFormat:@"https://youtube.com/shorts/%@", videoId];

    BOOL viewCommentsRendererSupported = [realAppVersion compare:@"17.10.2" options:NSNumericSearch] != NSOrderedAscending;
    YTIEngagementPanelIdentifier *identifier = [%c(YTIEngagementPanelIdentifier) message];
    if (viewCommentsRendererSupported)
        identifier.surface = 4;
    identifier.tag = @"shorts-comments-panel";
    YTICommand *viewCommentsCommand = [%c(YTICommand) message];
    YTIRenderer *viewCommentsButtonRenderer = [%c(YTIRenderer) new];
    YTIButtonRenderer *buttonRenderer = [%c(YTIButtonRenderer) new];
    if (viewCommentsRendererSupported) {
        YTIShowEngagementPanelEndpoint *commentsEndpoint = [%c(YTIShowEngagementPanelEndpoint) message];
        commentsEndpoint.identifier = identifier;
        [viewCommentsCommand setExtension:[%c(YTIShowEngagementPanelEndpoint) showEngagementPanelEndpoint] value:commentsEndpoint];
    } else {
        YTIUrlEndpoint *urlEndpoint = [%c(YTIUrlEndpoint) message];
        urlEndpoint.URL = shortsUrl;
        viewCommentsCommand.URLEndpoint = urlEndpoint;
    }
    buttonRenderer.command = viewCommentsCommand;
    viewCommentsButtonRenderer.buttonRenderer = buttonRenderer;
    renderer.viewCommentsButton = viewCommentsButtonRenderer;

    YTICommand *shareCommand = [%c(YTICommand) message];
    YTIIosSystemShareEndpoint *shareEndpoint = [%c(YTIIosSystemShareEndpoint) message];
    NSString *label = renderer.reelPlayerHeaderSupportedRenderers.reelPlayerHeaderRenderer.accessibility.accessibilityData.label;
    shareEndpoint.shareSubject = label;
    shareEndpoint.shareURL = shortsUrl;
    [shareCommand setExtension:[%c(YTIIosSystemShareEndpoint) iosSystemShareEndpoint] value:shareEndpoint];
    YTIRenderer *shareButtonRenderer = [%c(YTIRenderer) new];
    YTIButtonRenderer *shareButton = [%c(YTIButtonRenderer) new];
    shareButton.command = shareCommand;
    shareButtonRenderer.buttonRenderer = shareButton;
    renderer.shareButton = shareButtonRenderer;

    if (isYouTube19OrNewer) return;
    NSString *rendererDescription = [renderer description];
    NSRange channelBarRange = [rendererDescription rangeOfString:@"reel_channel_bar.eml"];
    if (channelBarRange.location != NSNotFound) {
        NSRange searchRange = NSMakeRange(channelBarRange.location + channelBarRange.length, rendererDescription.length - (channelBarRange.location + channelBarRange.length));
        NSRegularExpression *channelIdRegex = [NSRegularExpression regularExpressionWithPattern:@"UC[0-9A-Za-z_-]{22}" options:0 error:nil];
        NSTextCheckingResult *match = [channelIdRegex firstMatchInString:rendererDescription options:0 range:searchRange];
        if (match) {
            NSString *channelId = [rendererDescription substringWithRange:match.range];
            HBLogDebug(@"channelId: %@", channelId);
            YTICommand *channelNavigationCommand = [%c(YTICommand) message];
            YTIBrowseEndpoint *browseEndpoint = [%c(YTIBrowseEndpoint) message];
            browseEndpoint.browseId = channelId;
            channelNavigationCommand.browseEndpoint = browseEndpoint;
            renderer.reelPlayerHeaderSupportedRenderers.reelPlayerHeaderRenderer.channelNavigationEndpoint = channelNavigationCommand;
        }
    }
}

%hook YTReelContentView

- (void)setOverlayRenderer:(YTIReelPlayerOverlayRenderer *)renderer {
    if (isYouTube20OrNewer) {
        %orig;
        return;
    }
    setOverlayRenderer(self, renderer);
    %orig;
}

- (void)setOverlayRenderer:(YTIReelPlayerOverlayRenderer *)renderer isFullOverlayResponse:(BOOL)isFullOverlayResponse {
    if (isYouTube19OrNewer) {
        %orig;
        return;
    }
    setOverlayRenderer(self, renderer);
    %orig;
}

- (void)showComments {
    if (isYouTube20OrNewer) {
        %orig;
        return;
    }
    YTIButtonRenderer *viewCommentsButtonRenderer = [self valueForKey:@"_viewCommentsButtonRenderer"];
    NSString *url = viewCommentsButtonRenderer.command.URLEndpoint.URL;
    if (!url.length) {
        %orig;
        return;
    }
    [%c(YTUIUtils) openURL:[NSURL URLWithString:url]];
}

%end

#pragma mark - Fix Shorts title/channel not displaying

%hook YTReelWatchHeaderView

- (void)setHeaderRenderer:(YTIReelPlayerHeaderRenderer *)renderer {
    if (isYouTube19OrNewer) {
        %orig;
        return;
    }
    NSString *accessibilityLabel = renderer.accessibility.accessibilityData.label;
    if (!accessibilityLabel.length) {
        %orig;
        return;
    }
    NSRegularExpression *mentionRegex = [NSRegularExpression regularExpressionWithPattern:@"@\\S+" options:0 error:nil];
    NSArray<NSTextCheckingResult *> *matches = [mentionRegex matchesInString:accessibilityLabel options:0 range:NSMakeRange(0, accessibilityLabel.length)];
    NSString *title = nil;
    NSString *channel = nil;
    NSString *timestamp = nil;
    if (matches.count > 0) {
        NSTextCheckingResult *lastMatch = matches.lastObject;
        channel = [accessibilityLabel substringWithRange:lastMatch.range];
        NSUInteger start = NSMaxRange(lastMatch.range);
        if (start < accessibilityLabel.length) {
            NSString *remainder = [accessibilityLabel substringFromIndex:start];
            timestamp = [remainder stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
        }
        NSRange titleRange = NSMakeRange(0, lastMatch.range.location);
        title = [accessibilityLabel substringWithRange:titleRange];
        title = [title stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
    }
    renderer.channelTitleText = [%c(YTIFormattedString) formattedStringWithString:channel];
    renderer.reelTitleText = [%c(YTIFormattedString) formattedStringWithString:title];
    renderer.timestampText = [%c(YTIFormattedString) formattedStringWithString:timestamp];
    renderer.channelNavigationEndpoint.browseEndpoint.canonicalBaseURL = [NSString stringWithFormat:@"/%@", channel];
    %orig;
}

%end

#pragma mark - Prevent Shorts from being activated as a separate view controller

%hook YTIReelWatchEndpoint

- (BOOL)shouldPresentModally { return NO; }

%end

%ctor {
    if (!shouldEnableTweak) return;
    %init;
}
