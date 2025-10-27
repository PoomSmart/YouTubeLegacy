#import <dlfcn.h>
#import <sys/sysctl.h>
#import <version.h>
#import <HBLog.h>
#import <PSHeader/Misc.h>
#import <YouTubeHeader/_ASDisplayView.h>
#import <YouTubeHeader/ASCollectionView.h>
#import <YouTubeHeader/ELMNodeController.h>
#import <YouTubeHeader/ELMNodeFactory.h>
#import <YouTubeHeader/ELMTextNode.h>
#import <YouTubeHeader/ELMTouchCommandPropertiesHandler.h>
#import <YouTubeHeader/NSArray+YouTube.h>
#import <YouTubeHeader/SRLRegistry.h>
#import <YouTubeHeader/YTActionSheetAction.h>
#import <YouTubeHeader/YTAlertView.h>
#import <YouTubeHeader/YTAutoplayController.h>
#import <YouTubeHeader/YTCommandResponderEvent.h>
#import <YouTubeHeader/YTELMContext.h>
#import <YouTubeHeader/YTICompactVideoRenderer.h>
#import <YouTubeHeader/YTICoWatchWatchEndpointWrapperCommand.h>
#import <YouTubeHeader/YTIElementRenderer.h>
#import <YouTubeHeader/YTIInlinePlaybackRenderer.h>
#import <YouTubeHeader/YTIIosSystemShareEndpoint.h>
#import <YouTubeHeader/YTIItemSectionRenderer.h>
#import <YouTubeHeader/YTIMenuItemSupportedRenderers.h>
#import <YouTubeHeader/YTInnerTubeCollectionViewController.h>
#import <YouTubeHeader/YTIPivotBarItemRenderer.h>
#import <YouTubeHeader/YTIPlaylistPanelRenderer.h>
#import <YouTubeHeader/YTIPlaylistPanelVideoRenderer.h>
#import <YouTubeHeader/YTIPlaylistVideoListRenderer.h>
#import <YouTubeHeader/YTIPlaylistVideoRenderer.h>
#import <YouTubeHeader/YTIReelPlayerOverlayRenderer.h>
#import <YouTubeHeader/YTIShelfRenderer.h>
#import <YouTubeHeader/YTIShowFullscreenInterstitialCommand.h>
#import <YouTubeHeader/YTMainAppVideoPlayerOverlayViewController.h>
#import <YouTubeHeader/YTPivotBarItemView.h>
#import <YouTubeHeader/YTPlaylistPanelProminentThumbnailVideoCellController.h>
#import <YouTubeHeader/YTPlaylistPanelSectionController.h>
#import <YouTubeHeader/YTPlaylistVideoCellController.h>
#import <YouTubeHeader/YTPlaylistVideoListSectionController.h>
#import <YouTubeHeader/YTReelContentView.h>
#import <YouTubeHeader/YTRendererForOfflineVideo.h>
#import <YouTubeHeader/YTUIResources.h>
#import <YouTubeHeader/YTUIUtils.h>
#import <YouTubeHeader/YTVideoCellController.h>
#import <YouTubeHeader/YTVideoElementCellController.h>
#import <YouTubeHeader/YTVideoWithContextNode.h>
#import <YouTubeHeader/YTWatchTransition.h>

@interface ELMTextNode2 : ELMTextNode
- (BOOL)isLikeDislikeNode;
@end

#define DidApplyDefaultSettingsKey @"YTL_DidApplyDefaultSettings"
#define DidApplyDefaultSettings2Key @"YTL_DidApplyDefaultSettings2"
#define DidShowInformationAlertKey @"YTL_DidShowInformationAlert"
#define DidShowInformationAlert2Key @"YTL_DidShowInformationAlert2"
#define YouSpeedEnabledKey @"YTVideoOverlay-YouSpeed-Enabled"
#define YouSpeedButtonPositionKey @"YTVideoOverlay-YouSpeed-Position"
#define RYDUseItsDataKey @"RYD-USE-LIKE-DATA"

#define IOS_BUILD "19H394"

#define TweakName @"YouTubeLegacy"
#define _LOC(b, x) [b localizedStringForKey:x value:nil table:nil]
#define LOC(x) _LOC(tweakBundle, x)

NSString *realAppVersion;

#pragma mark - Spoof app version

%hook YTGlobalConfig

- (BOOL)shouldBlockUpgradeDialog { return YES; }

%end

%hook YTVersionUtils

// Works down to 17.x.x
+ (NSString *)appVersionLong {
    NSString *appVersion = %orig;
    if ([appVersion compare:@"19.01.1" options:NSNumericSearch] == NSOrderedAscending)
        return @"19.01.1";
    return appVersion;
}

+ (NSString *)appVersion {
    NSString *appVersion = %orig;
    if ([appVersion compare:@"17.10.2" options:NSNumericSearch] == NSOrderedAscending)
        return @"19.14.2";
    return appVersion;
}

%end

#pragma mark - Fix app crash on launch

%hook SRLRegistry

- (id)internalService:(struct _SRLAPIRegistrationData *)service scopeTags:(struct SRLScopeTagSet)tags {
    if (strcmp(service->name, "YTECatcherLogger_API") == 0)
        return nil;
    return %orig;
}

%end

#pragma mark - Remove app upgrade popup

%hook YTInterstitialPromoEventGroupHandler

- (void)addEventHandlers {}

%end

%hook YTPromosheetEventGroupHandler

- (void)addEventHandlers {}

%end

%hook YTIShowFullscreenInterstitialCommand

- (BOOL)shouldThrottleInterstitial {
    if (self.hasModalClientThrottlingRules && [[self.elementLoggingContainer.element.type description] containsString:@"https://itunes.apple.com/app/youtube/id544007664"])
        return YES;
    return %orig;
}

%end

#pragma mark - Add play option menu to videos

static BOOL isRelevantContainerView(UIView *view) {
    return [view.accessibilityIdentifier isEqualToString:@"eml.vwc"] || [view.accessibilityIdentifier isEqualToString:@"horizontal-video-shelf.view"];
}

static YTICommand *createRelevantCommandFromElementRenderer(YTIElementRenderer *elementRenderer, _ASDisplayView *view, id firstResponder) {
    if (elementRenderer == nil || firstResponder == nil)
        return nil;
    NSInteger preferredIndex = NSNotFound;
    NSString *videoTitle = nil;
    if (view) {
        UIView *parentView = view;
        do {
            parentView = parentView.superview;
        } while (parentView && !isRelevantContainerView(parentView));
        if (isRelevantContainerView(parentView)) {
            if ([parentView.accessibilityIdentifier isEqualToString:@"horizontal-video-shelf.view"]) {
                HBLogDebug(@"Finding preferred index in horizontal video shelf");
                ELMNodeController *nodeController = [view.keepalive_node controller];
                do {
                    nodeController = nodeController.parent;
                } while (nodeController && ![[nodeController key] isEqualToString:@"video-card-cell"]);
                ELMNodeController *containerNodeController = ((ELMNodeController *)nodeController.parent).parent;
                preferredIndex = [[containerNodeController children] indexOfObjectPassingTest:^BOOL(ELMComponent *obj, NSUInteger idx, BOOL *stop) {
                    ELMNodeController *childNodeController = [obj materializedInstance];
                    return [[[childNodeController children] firstObject] materializedInstance] == nodeController;
                }];
            } else {
                videoTitle = [[parentView.accessibilityLabel componentsSeparatedByString:@" - "] firstObject];
                preferredIndex = [parentView.superview.subviews indexOfObject:parentView];
            }
        }
    }
    YTICommand *command = nil;
    NSString *description = [elementRenderer description];
    NSString *videoSearchString = @"//www.youtube.com/watch?v=";
    NSRange range = [description rangeOfString:videoSearchString];
    if (preferredIndex != NSNotFound) {
        if (videoTitle) {
            // Find video ID range in description that appears between the first and second occurrence of the video title
            NSString *escapedVideoTitle = [videoTitle stringByReplacingOccurrencesOfString:@"'" withString:@"\\'"];
            NSRange titleRange = [description rangeOfString:escapedVideoTitle options:NSLiteralSearch];
            if (titleRange.location != NSNotFound) {
                NSRange secondSearchRange = NSMakeRange(titleRange.location + titleRange.length, description.length - (titleRange.location + titleRange.length));
                NSRange secondTitleRange = [description rangeOfString:escapedVideoTitle options:NSLiteralSearch range:secondSearchRange];
                if (secondTitleRange.location != NSNotFound) {
                    NSRange searchRange = NSMakeRange(titleRange.location + titleRange.length, secondTitleRange.location - (titleRange.location + titleRange.length));
                    range = [description rangeOfString:videoSearchString options:0 range:searchRange];
                }
            }
        } else {
            while (range.location != NSNotFound && preferredIndex-- > 0) {
                range = [description rangeOfString:videoSearchString options:0 range:NSMakeRange(range.location + videoSearchString.length, description.length - (range.location + videoSearchString.length))];
            }
        }
    }
    if (range.location != NSNotFound) {
        NSString *videoID = [description substringWithRange:NSMakeRange(range.location + videoSearchString.length, 11)];
        NSString *playlistID = nil;
        HBLogDebug(@"videoID: %@", videoID);
        NSRange listRange = [description rangeOfString:@"&list="];
        if (listRange.location != NSNotFound) {
            NSRange idRange = [description rangeOfString:@"\\" options:0 range:NSMakeRange(listRange.location + 6, description.length - (listRange.location + 6))];
            if (idRange.location != NSNotFound) {
                playlistID = [description substringWithRange:NSMakeRange(listRange.location + 6, idRange.location - (listRange.location + 6))];
                HBLogDebug(@"playlistID: %@", playlistID);
                command = [%c(YTICommand) watchNavigationEndpointWithPlaylistID:playlistID videoID:videoID index:0 watchNextToken:nil];
            }
        } else
            command = [%c(YTICommand) watchNavigationEndpointWithVideoID:videoID];
    } else {
        NSString *playlistSearchString = @"//www.youtube.com/playlist?list=";
        NSRange playlistRange = [description rangeOfString:playlistSearchString];
        if (playlistRange.location != NSNotFound) {
            NSRange idRange = [description rangeOfString:@"\\" options:0 range:NSMakeRange(playlistRange.location + playlistSearchString.length, description.length - (playlistRange.location + playlistSearchString.length))];
            if (idRange.location != NSNotFound) {
                NSString *playlistID = [description substringWithRange:NSMakeRange(playlistRange.location + playlistSearchString.length, idRange.location - (playlistRange.location + playlistSearchString.length))];
                if ([playlistID hasSuffix:@"Z"])
                    playlistID = [playlistID substringToIndex:playlistID.length - 1];
                HBLogDebug(@"playlistID: %@", playlistID);
                command = [%c(YTICommand) watchNavigationEndpointWithPlaylistID:playlistID videoID:nil index:0 watchNextToken:nil];
            }
        }
    }
    if (command == nil && [firstResponder isKindOfClass:%c(YTVideoElementCellController)]) {
        videoSearchString = @"/vi/";
        range = [description rangeOfString:videoSearchString];
        if (range.location != NSNotFound) {
            NSString *videoID = [description substringWithRange:NSMakeRange(range.location + videoSearchString.length, 11)];
            HBLogDebug(@"videoID: %@", videoID);
            command = [%c(YTICommand) watchNavigationEndpointWithVideoID:videoID];
        }
    }
    return command;
}

static YTICommand *createRelevantCommandFromPlaylistVideoRenderer(YTIPlaylistVideoRenderer *playlistVideoRenderer, id firstResponder) {
    NSString *videoID = playlistVideoRenderer.videoId;
    HBLogDebug(@"videoID: %@", videoID);
    YTPlaylistVideoCellController *cellController = (YTPlaylistVideoCellController *)firstResponder;
    YTPlaylistVideoListSectionController *sectionController = cellController.parentResponder;
    YTIPlaylistVideoListRenderer *listRenderer = (YTIPlaylistVideoListRenderer *)[sectionController renderer];
    NSUInteger index = [listRenderer.contentsArray indexOfObjectPassingTest:^BOOL(YTIPlaylistVideoListSupportedRenderers *obj, NSUInteger idx, BOOL *stop) {
        return obj.playlistVideoRenderer == playlistVideoRenderer;
    }];
    NSString *playlistID = listRenderer.playlistId;
    HBLogDebug(@"playlistID: %@", playlistID);
    return [%c(YTICommand) watchNavigationEndpointWithPlaylistID:playlistID videoID:videoID index:index watchNextToken:nil];
}

static YTICommand *createRelevantCommandFromPlaylistPanelVideoRenderer(YTIPlaylistPanelVideoRenderer *playlistPanelVideoRenderer, id firstResponder) {
    NSString *videoID = playlistPanelVideoRenderer.videoId;
    HBLogDebug(@"videoID: %@", videoID);
    YTPlaylistPanelProminentThumbnailVideoCellController *cellController = (YTPlaylistPanelProminentThumbnailVideoCellController *)firstResponder;
    YTPlaylistPanelSectionController *sectionController = cellController.parentResponder;
    YTIPlaylistPanelRenderer *panelRenderer = (YTIPlaylistPanelRenderer *)[sectionController renderer];
    NSUInteger index = [panelRenderer.contentsArray indexOfObjectPassingTest:^BOOL(YTIPlaylistPanelRenderer_PlaylistPanelVideoSupportedRenderers *obj, NSUInteger idx, BOOL *stop) {
        return obj.playlistPanelVideoRenderer == playlistPanelVideoRenderer;
    }];
    NSString *playlistID = panelRenderer.playlistId;
    HBLogDebug(@"playlistID: %@", playlistID);
    return [%c(YTICommand) watchNavigationEndpointWithPlaylistID:playlistID videoID:videoID index:index watchNextToken:nil];
}

static YTICommand *createRelevantCommandFromInlinePlaybackRenderer(YTIInlinePlaybackRenderer *inlinePlaybackRenderer) {
    NSString *videoID = inlinePlaybackRenderer.videoId;
    HBLogDebug(@"videoID: %@", videoID);
    return [%c(YTICommand) watchNavigationEndpointWithVideoID:videoID];
}

static YTICommand *createRelevantCommandFromOfflineVideoRenderer(id <YTRendererForOfflineVideo> renderer) {
    NSString *videoID = renderer.videoId;
    HBLogDebug(@"videoID: %@", videoID);
    return [%c(YTICommand) watchNavigationEndpointWithVideoID:videoID];
}

static YTIMenuItemSupportedRenderers *createMenuRenderer(YTICommand *command, NSString *text, NSString *identifier, YTIcon iconType) {
    YTIIcon *icon = [%c(YTIIcon) new];
    icon.iconType = iconType;
    YTIMenuNavigationItemRenderer *navigationItemRenderer = [%c(YTIMenuNavigationItemRenderer) new];
    if ([navigationItemRenderer respondsToSelector:@selector(setMenuItemIdentifier:)])
        navigationItemRenderer.menuItemIdentifier = identifier;
    navigationItemRenderer.navigationEndpoint = command;
    navigationItemRenderer.icon = icon;
    navigationItemRenderer.text = [%c(YTIFormattedString) formattedStringWithString:text];
    YTIMenuItemSupportedRenderers *menuItemRenderers = [%c(YTIMenuItemSupportedRenderers) new];
    menuItemRenderers.menuNavigationItemRenderer = navigationItemRenderer;
    return menuItemRenderers;
}

static void overrideMenuItem(NSMutableArray <YTIMenuItemSupportedRenderers *> *renderers, NSMutableArray <YTActionSheetAction *> *actions, NSString *menuItemIdentifier, void (^handler)(void)) {
    NSUInteger index = [renderers indexOfObjectPassingTest:^BOOL(YTIMenuItemSupportedRenderers *renderer, NSUInteger idx, BOOL *stop) {
        if (![renderer respondsToSelector:@selector(elementRenderer)]) return NO;
        YTIMenuItemSupportedRenderersElementRendererCompatibilityOptionsExtension *extension = (YTIMenuItemSupportedRenderersElementRendererCompatibilityOptionsExtension *)[renderer.elementRenderer.compatibilityOptions messageForFieldNumber:396644439];
        BOOL isMenuItem = [extension.menuItemIdentifier isEqualToString:menuItemIdentifier];
        if (isMenuItem) *stop = YES;
        return isMenuItem;
    }];
    if (index != NSNotFound) {
        YTActionSheetAction *action = actions[index];
        action.handler = handler;
        UIView *elementView = [action.button valueForKey:@"_elementView"];
        elementView.userInteractionEnabled = NO;
    }
}

%hook YTMenuController

- (NSMutableArray <YTActionSheetAction *> *)actionsForRenderers:(NSMutableArray <YTIMenuItemSupportedRenderers *> *)renderers fromView:(UIView *)view entry:(id)entry shouldLogItems:(BOOL)shouldLogItems firstResponder:(id)firstResponder {
    HBLogDebug(@"actionsForRenderers: %@", renderers);
    HBLogDebug(@"view: %@", view);
    HBLogDebug(@"entry: %@", entry);
    HBLogDebug(@"firstResponder: %@", firstResponder);
    YTICommand *command = nil;
    if ([entry isKindOfClass:%c(YTIElementRenderer)])
        command = createRelevantCommandFromElementRenderer(entry, (_ASDisplayView *)view, firstResponder);
    else if ([entry isKindOfClass:%c(YTIPlaylistVideoRenderer)])
        command = createRelevantCommandFromPlaylistVideoRenderer(entry, firstResponder);
    else if ([entry isKindOfClass:%c(YTIPlaylistPanelVideoRenderer)])
        command = createRelevantCommandFromPlaylistPanelVideoRenderer(entry, firstResponder);
    else if ([entry isKindOfClass:%c(YTIInlinePlaybackRenderer)])
        command = createRelevantCommandFromInlinePlaybackRenderer(entry);
    else if ([entry conformsToProtocol:@protocol(YTRendererForOfflineVideo)])
        command = createRelevantCommandFromOfflineVideoRenderer(entry);
    if (command) {
        NSString *playText = _LOC([NSBundle mainBundle], @"mdx.actionview.play");
        YTIMenuItemSupportedRenderers *menuItemRenderers = createMenuRenderer(command, playText, @"PlayVideo", YT_PLAY_ALL);
        [renderers insertObject:menuItemRenderers atIndex:0];
    }
    if ([firstResponder isKindOfClass:%c(YTHeaderViewController)] || [firstResponder isKindOfClass:%c(YTHeaderContentComboViewController)]) {
        NSString *switchAccountText = _LOC([NSBundle mainBundle], @"sign_in_retroactive.select_another_account");
        command = [%c(YTICommand) signInNavigationEndpoint];
        YTIMenuItemSupportedRenderers *menuItemRenderers = createMenuRenderer(command, switchAccountText, @"SwitchAccount", 182);
        [renderers insertObject:menuItemRenderers atIndex:0];
    }
    NSMutableArray <YTActionSheetAction *> *actions = %orig(renderers, view, entry, shouldLogItems, firstResponder);
    overrideMenuItem(renderers, actions, @"menu_item_audio_track", ^{
        [(YTMainAppVideoPlayerOverlayViewController *)firstResponder didPressAudioTrackSwitch:view];
    });
    return actions;
}

%end

#pragma mark - Make tapping on a video card playing the video

%hook ELMTouchCommandPropertiesHandler

- (void)handleTap {
    ELMNodeController *nodeController = [self valueForKey:@"_controller"];
    HBLogDebug(@"nodeController: %@", nodeController);
    if ([nodeController isKindOfClass:%c(ELMNodeController)] && [nodeController.node.accessibilityIdentifier isEqualToString:@"eml.overflow_button"]) {
        HBLogDebug(@"Overflow button tapped, not playing video");
        %orig;
        return;
    }
    YTELMContext *context = [self valueForKey:@"_context"];
    YTElementsCellController *cellController = [context parentResponder];
    YTIElementRenderer *renderer = [cellController elementEntry];
    YTICommand *command = createRelevantCommandFromElementRenderer(renderer, nil, cellController);
    if (command) {
        HBLogDebug(@"Playing video via command: %@", command);
        UIView *view = nodeController.node.view;
        YTCommandResponderEvent *event = [%c(YTCommandResponderEvent) eventWithCommand:command fromView:view entry:renderer sendClick:NO firstResponder:cellController];
        [event send];
        return;
    }
    %orig;
}

%end

%hook YTVideoCellController

- (void)setupClientBinding {
    %orig;
    id entry = [self entry];
    if ([entry isKindOfClass:%c(YTICompactVideoRenderer)]) {
        YTICompactVideoRenderer *videoRenderer = (YTICompactVideoRenderer *)entry;
        YTICommand *command = [%c(YTICommand) watchNavigationEndpointWithVideoID:videoRenderer.videoId];
        videoRenderer.navigationEndpoint = command;
    } else if ([entry isKindOfClass:%c(YTIPlaylistVideoRenderer)]) {
        YTIPlaylistVideoRenderer *playlistVideoRenderer = (YTIPlaylistVideoRenderer *)entry;
        YTICommand *command = createRelevantCommandFromPlaylistVideoRenderer(playlistVideoRenderer, self);
        playlistVideoRenderer.navigationEndpoint = command;
    } else if ([entry isKindOfClass:%c(YTIPlaylistPanelVideoRenderer)]) {
        YTIPlaylistPanelVideoRenderer *playlistPanelVideoRenderer = (YTIPlaylistPanelVideoRenderer *)entry;
        YTICommand *command = createRelevantCommandFromPlaylistPanelVideoRenderer(playlistPanelVideoRenderer, self);
        playlistPanelVideoRenderer.navigationEndpoint = command;
    }
}

%end

#pragma mark - Fix video like/dislike buttons not displaying numbers (17.10.2+)

%subclass ELMTextNode2 : ELMTextNode

%new(B@:)
- (BOOL)isLikeDislikeNode {
    NSString *identifier = self.yogaParent.accessibilityIdentifier;
    return [identifier isEqualToString:@"id.video.like.button"] || [identifier isEqualToString:@"id.video.dislike.button"];
}

- (void)controllerDidApplyProperties {
    if ([self isLikeDislikeNode])
        HBLogDebug(@"controllerDidApplyProperties");
    else
        %orig;
}

%end

%hook YTWatchLayerViewController

- (id)initWithParentResponder:(id)parentResponder {
    self = %orig;
    [[%c(ELMNodeFactory) sharedInstance] registerNodeClass:%c(ELMTextNode2) forTypeExtension:525000000];
    return self;
}

%end

#pragma mark - Fix You tab avatar not displaying

%hook YTHotConfig

- (BOOL)isFixAvatarFlickersEnabled { return NO; }

%end

%hook YTColdConfig

- (BOOL)mainAppCoreClientIosTopBarAvatarFix { return NO; }
- (BOOL)mainAppCoreClientIosTransientVisualGlitchInPivotBarFix { return YES; }

%end

%hook YTAppImageStyle

- (UIImage *)pivotBarItemIconImageWithIconType:(YTIcon)iconType color:(UIColor *)color useNewIcons:(BOOL)useNewIcons selected:(BOOL)selected {
    if (iconType == YT_ACCOUNT_CIRCLE)
        return [%c(YTUIResources) iconAccountCircle];
    return %orig;
}

%end

static void setYouTabIcon(YTPivotBarItemView *self, YTIPivotBarItemRenderer *renderer) {
    YTQTMButton *navigationButton = self.navigationButton;
    NSString *imageURL;
    @try {
        imageURL = [renderer.thumbnail.thumbnailsArray firstObject].URL;
    } @catch (id ex) {
        GPBMessage *message = [[renderer messageForFieldNumber:15] messageForFieldNumber:1];
        GPBUnknownFieldSet *unknownFields = [message unknownFields];
        GPBUnknownField *field = [unknownFields getField:1];
        NSData *data = [field.lengthDelimitedList firstObject];
        imageURL = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
    }
    HBLogDebug(@"imageURL: %@", imageURL);
    if (imageURL == nil) return;
    NSURL *url = [NSURL URLWithString:imageURL];
    if (url == nil) return;
    UIImage *image = [UIImage imageWithData:[NSData dataWithContentsOfURL:url]];
    if (image == nil) return;
    CGRect imageRect = CGRectMake(0, 0, 24, 24);
    UIGraphicsBeginImageContextWithOptions(imageRect.size, NO, 0);
    [image drawInRect:imageRect];
    image = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    [navigationButton setImage:image forState:UIControlStateNormal];
    [navigationButton setImage:image forState:UIControlStateHighlighted];
    navigationButton.imageView.layer.cornerRadius = 12;
    [self setNeedsLayout];
}

%hook YTPivotBarItemView

- (void)updateTitleAndIcons {
    %orig;
    if (![self.renderer.pivotIdentifier isEqualToString:@"FElibrary"] || [self respondsToSelector:@selector(setupIconsAndTitles)]) return;
    setYouTabIcon(self, self.renderer);
}

- (void)setRenderer:(YTIPivotBarItemRenderer *)renderer {
    %orig;
    if (![renderer.pivotIdentifier isEqualToString:@"FElibrary"]) return;
    setYouTabIcon(self, renderer);
}

%end

#pragma mark - Fix icons not displaying

static YTIcon getIconType(YTIIcon *self) {
    YTIcon iconType = self.iconType;
    return iconType ?: [[[self.unknownFields getField:1].varintList yt_numberAtIndex:0] intValue];
}

%hook YTIIcon

- (UIImage *)iconImageWithColor:(UIColor *)color {
    YTIcon iconType = getIconType(self);
    if (iconType == YT_CLAPPERBOARD) // Movie icon in You page
        self.iconType = YT_MOVIES;
    else if (iconType == YT_SELL) // Purchases icon in You page
        self.iconType = YT_PURCHASES;
    return %orig;
}

- (UIImage *)iconImageForContextMenu {
    switch (getIconType(self)) {
        case YT_UNSUBSCRIBE: // Context menu: Unsubscribe
        case YT_X_CIRCLE:
            return [%c(YTUIResources) xCircleOutline];
        case YT_BOOKMARK_BORDER: // Context menu: Save to playlist
            return [self iconImageWithColor:nil];
        default:
            break;
    }
    return %orig;
}

%end

#pragma mark - Fix Shorts like/dislike/comments/share buttons not displaying

%hook YTReelWatchPlaybackOverlayView

- (void)setActionBarElementRenderer:(id)renderer {}

%end

%hook YTReelContentView

- (void)setOverlayRenderer:(YTIReelPlayerOverlayRenderer *)renderer {
    // Create like/dislike button
    renderer.likeButton = renderer.doubleTapLikeButton;
    NSString *videoId = renderer.likeButton.likeButtonRenderer.target.videoId;
    NSString *shortsUrl = [NSString stringWithFormat:@"https://youtube.com/shorts/%@", videoId];

    // Create view comments button
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
        // YTIIcon *buttonIcon = [%c(YTIIcon) new];
        // buttonRenderer.text = [%c(YTIFormattedString) formattedStringWithString:@"Comments"];
    } else {
        YTIUrlEndpoint *urlEndpoint = [%c(YTIUrlEndpoint) message];
        urlEndpoint.URL = shortsUrl;
        viewCommentsCommand.URLEndpoint = urlEndpoint;
    }
    buttonRenderer.command = viewCommentsCommand;
    viewCommentsButtonRenderer.buttonRenderer = buttonRenderer;
    renderer.viewCommentsButton = viewCommentsButtonRenderer;

    // Create share button
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

    %orig;
}

- (void)showComments {
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
    NSString *accessibilityLabel = renderer.accessibility.accessibilityData.label;
    // Format: "<Title> @<Channel> <Timestamp>"
    // Example: "Some nice video #somehashtag @sometag something else @niceChannel 2 days ago"
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
    YTICommand *channelNavigationCommand = [%c(YTICommand) browseNavigationEndpointWithChannelID:channel];
    renderer.channelNavigationEndpoint = channelNavigationCommand;
    %orig;
}

%end

#pragma mark - Prevent Shorts from being activated as a separate view controller

%hook YTIReelWatchEndpoint

- (BOOL)shouldPresentModally { return NO; }

%end

#pragma mark - Fix "Play all" button in playlist not displaying

%group PlaylistPageRefresh

BOOL (*YTPlaylistPageRefreshSupported)(void) = NULL;
%hookf(BOOL, YTPlaylistPageRefreshSupported) {
    return YES;
}

%end

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
    return [endpoint hasActiveOnlineOrOfflineWatchEndpoint]
        || getWatchEndpoint(endpoint) != nil
        ? endpoint : nil;
}

// - (YTWatchTransition *)newAutoplayWatchTransition {
//     YTICommand *autoplayEndpoint = [self autoplayEndpoint];
//     if (autoplayEndpoint == nil) return nil;
//     GPBExtensionDescriptor *coWatchCommand = getCoWatchEndpointWrapperCommandDescriptor();
//     if (![autoplayEndpoint hasActiveOnlineOrOfflineWatchEndpoint] && ![autoplayEndpoint hasExtension:coWatchCommand])
//         return [[%c(YTWatchTransition) alloc] initWithNavEndpoint:autoplayEndpoint watchEndpointSource:1 forcePlayerReload:YES];
//     YTICommand *watchEndpoint = ((YTICoWatchWatchEndpointWrapperCommand *)[autoplayEndpoint getExtension:coWatchCommand]).watchEndpoint;
//     return [[%c(YTWatchTransition) alloc] initWithNavEndpoint:watchEndpoint watchEndpointSource:1 forcePlayerReload:YES];
// }

- (void)sendWatchTransitionWithNavEndpoint:(YTICommand *)navEndpoint watchEndpointSource:(int)watchEndpointSource {
    if (![navEndpoint hasActiveOnlineOrOfflineWatchEndpoint]) {
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
    return [endpoint hasActiveOnlineOrOfflineWatchEndpoint]
        || [endpoint hasExtension:getCoWatchEndpointWrapperCommandDescriptor()]
        ? endpoint : nil;
}

- (void)sendWatchTransitionWithNavEndpoint:(YTICommand *)navEndpoint watchEndpointSource:(int)watchEndpointSource {
    if (![navEndpoint hasActiveOnlineOrOfflineWatchEndpoint]) {
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

#pragma mark - Fix left side of video player not responding to double tap to seek gesture

%hook YTColdConfig

- (BOOL)isLandscapeEngagementPanelEnabled { return YES; }

%end

#pragma mark - Improve general JS element compatibility

NSBundle *TweakBundle() {
    static NSBundle *bundle = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        NSString *tweakBundlePath = [[NSBundle mainBundle] pathForResource:TweakName ofType:@"bundle"];
        bundle = [NSBundle bundleWithPath:tweakBundlePath ?: PS_ROOT_PATH_NS(@"/Library/Application Support/" TweakName ".bundle")];
    });
    return bundle;
}

%hook YTDataPushEmbeddedPayloadBundleProviderImpl

- (NSBundle *)embeddedPayloadBundle {
    NSBundle *bundle = TweakBundle();
    return bundle ?: %orig;
}

%end

#pragma mark - Remove Playables

static BOOL isPlayableGame(YTIElementRenderer *elementRenderer) {
    NSString *description = [elementRenderer description];
    return [description containsString:@"https://m.youtube.com/playables/"];
}

static NSMutableArray <YTIItemSectionRenderer *> *filteredArray(NSArray <YTIItemSectionRenderer *> *array) {
    NSMutableArray <YTIItemSectionRenderer *> *newArray = [array mutableCopy];
    NSIndexSet *removeIndexes = [newArray indexesOfObjectsPassingTest:^BOOL(YTIItemSectionRenderer *sectionRenderer, NSUInteger idx, BOOL *stop) {
        if ([sectionRenderer isKindOfClass:%c(YTIShelfRenderer)]) {
            YTIShelfSupportedRenderers *content = ((YTIShelfRenderer *)sectionRenderer).content;
            YTIHorizontalListRenderer *horizontalListRenderer = content.horizontalListRenderer;
            NSMutableArray <YTIHorizontalListSupportedRenderers *> *itemsArray = horizontalListRenderer.itemsArray;
            NSIndexSet *removeItemsArrayIndexes = [itemsArray indexesOfObjectsPassingTest:^BOOL(YTIHorizontalListSupportedRenderers *horizontalListSupportedRenderers, NSUInteger idx2, BOOL *stop2) {
                YTIElementRenderer *elementRenderer = horizontalListSupportedRenderers.elementRenderer;
                return isPlayableGame(elementRenderer);
            }];
            [itemsArray removeObjectsAtIndexes:removeItemsArrayIndexes];
        }
        if (![sectionRenderer isKindOfClass:%c(YTIItemSectionRenderer)])
            return NO;
        NSMutableArray <YTIItemSectionSupportedRenderers *> *contentsArray = sectionRenderer.contentsArray;
        if (contentsArray.count > 1) {
            NSIndexSet *removeContentsArrayIndexes = [contentsArray indexesOfObjectsPassingTest:^BOOL(YTIItemSectionSupportedRenderers *sectionSupportedRenderers, NSUInteger idx2, BOOL *stop2) {
                YTIElementRenderer *elementRenderer = sectionSupportedRenderers.elementRenderer;
                return isPlayableGame(elementRenderer);
            }];
            [contentsArray removeObjectsAtIndexes:removeContentsArrayIndexes];
        }
        YTIItemSectionSupportedRenderers *firstObject = [contentsArray firstObject];
        YTIElementRenderer *elementRenderer = firstObject.elementRenderer;
        return isPlayableGame(elementRenderer);
    }];
    [newArray removeObjectsAtIndexes:removeIndexes];
    return newArray;
}

%hook YTInnerTubeCollectionViewController

- (void)displaySectionsWithReloadingSectionControllerByRenderer:(id)renderer {
    NSMutableArray *sectionRenderers = [self valueForKey:@"_sectionRenderers"];
    [self setValue:filteredArray(sectionRenderers) forKey:@"_sectionRenderers"];
    %orig;
}

- (void)addSectionsFromArray:(NSArray <YTIItemSectionRenderer *> *)array {
    %orig(filteredArray(array));
}

%end

#pragma mark - Spoof iOS version

%group Spoofing

%hook UIDevice

- (NSString *)systemVersion {
    return @"15.8.5";
}

%end

%hook NSProcessInfo

- (NSOperatingSystemVersion)operatingSystemVersion {
    NSOperatingSystemVersion version;
    version.majorVersion = 15;
    version.minorVersion = 8;
    version.patchVersion = 5;
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

// %hook YTELMLogger

// - (void)logErrorEvent:(id)event {
//     HBLogInfo(@"logErrorEvent: %@", event);
//     %orig;
// }

// %end

// %hook YTSafeModeController

// - (void)setupAndCheckForCrashLoop {}

// %end

%ctor {
    NSString *bundlePath = [NSString stringWithFormat:@"%@/Frameworks/Module_Framework.framework", NSBundle.mainBundle.bundlePath];
    dlopen([bundlePath UTF8String], RTLD_NOW);
    MSImageRef ref = MSGetImageByName([[bundlePath stringByAppendingString:@"/Module_Framework"] UTF8String]);
    if (ref == NULL) return;
    NSBundle *moduleFrameworkBundle = [NSBundle bundleWithPath:bundlePath];
    realAppVersion = [moduleFrameworkBundle objectForInfoDictionaryKey:@"CFBundleShortVersionString"];
    if ([realAppVersion compare:@"19.01.1" options:NSNumericSearch] != NSOrderedAscending) return;
    NSBundle *mainBundle = [NSBundle mainBundle];
    NSString *mainVersion = [mainBundle objectForInfoDictionaryKey:@"CFBundleVersion"];
    NSString *mainShortVersion = [mainBundle objectForInfoDictionaryKey:@"CFBundleShortVersionString"];
    BOOL infoPlistLikelyModified = [realAppVersion compare:mainVersion options:NSNumericSearch] != NSOrderedSame
        || [realAppVersion compare:mainShortVersion options:NSNumericSearch] != NSOrderedSame;
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
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
    NSBundle *tweakBundle = TweakBundle();
    if (![defaults boolForKey:DidShowInformationAlertKey]) {
        [defaults setBool:YES forKey:DidShowInformationAlertKey];
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(3.0 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            YTAlertView *alertView = [%c(YTAlertView) infoDialog];
            alertView.title = TweakName;
            alertView.subtitle = LOC(@"TWEAK_INFORMATION");
            [alertView show];
        });
    }
    if (infoPlistLikelyModified && ![defaults boolForKey:DidShowInformationAlert2Key]) {
        [defaults setBool:YES forKey:DidShowInformationAlert2Key];
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(3.0 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            YTAlertView *alertView = [%c(YTAlertView) infoDialog];
            alertView.title = TweakName;
            alertView.subtitle = LOC(@"INCONSISTENT_VERSION_INFORMATION");
            [alertView show];
        });
    }
    if (!IS_IOS_OR_NEWER(iOS_15_0)) {
        %init(Spoofing);
    }
    YTPlaylistPageRefreshSupported = MSFindSymbol(ref, "_YTPlaylistPageRefreshSupported");
    if (YTPlaylistPageRefreshSupported) {
        %init(PlaylistPageRefresh);
    }
    %init;
}