#import "TweakHeader.h"
#import <HBLog.h>
#import <YouTubeHeader/_ASDisplayView.h>
#import <YouTubeHeader/ELMNodeController.h>
#import <YouTubeHeader/ELMTouchCommandPropertiesHandler.h>
#import <YouTubeHeader/YTActionSheetAction.h>
#import <YouTubeHeader/YTCommandResponderEvent.h>
#import <YouTubeHeader/YTELMContext.h>
#import <YouTubeHeader/YTICompactVideoRenderer.h>
#import <YouTubeHeader/YTIElementRenderer.h>
#import <YouTubeHeader/YTIInlinePlaybackRenderer.h>
#import <YouTubeHeader/YTIMenuItemSupportedRenderers.h>
#import <YouTubeHeader/YTMainAppVideoPlayerOverlayViewController.h>
#import <YouTubeHeader/YTIPlaylistPanelRenderer.h>
#import <YouTubeHeader/YTIPlaylistPanelVideoRenderer.h>
#import <YouTubeHeader/YTIPlaylistVideoListRenderer.h>
#import <YouTubeHeader/YTIPlaylistVideoRenderer.h>
#import <YouTubeHeader/YTPlaylistPanelProminentThumbnailVideoCellController.h>
#import <YouTubeHeader/YTPlaylistPanelSectionController.h>
#import <YouTubeHeader/YTPlaylistVideoCellController.h>
#import <YouTubeHeader/YTPlaylistVideoListSectionController.h>
#import <YouTubeHeader/YTRendererForOfflineVideo.h>
#import <YouTubeHeader/YTVideoCellController.h>
#import <YouTubeHeader/YTVideoElementCellController.h>

#pragma mark - Add play option menu to videos

static YTICommand *createRelevantCommandFromElementRenderer(YTIElementRenderer *elementRenderer, _ASDisplayView *view, id firstResponder) {
    if (elementRenderer == nil || firstResponder == nil)
        return nil;
    NSString *videoTitle = [[view.accessibilityLabel componentsSeparatedByString:@" - "] firstObject];
    HBLogDebug(@"videoTitle: %@", videoTitle);
    YTICommand *command = nil;
    NSString *description = [elementRenderer description];
    NSString *videoSearchString = @"//www.youtube.com/watch?v=";
    NSRange range = [description rangeOfString:videoSearchString];
    if (videoTitle) {
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
    if (!isLegacy) return %orig;
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

static BOOL shouldNotHandleTap(ELMNodeController *nodeController) {
    NSString *identifier = nodeController.node.accessibilityIdentifier;
    if ([identifier isEqualToString:@"eml.overflow_button"]
        || [identifier isEqualToString:@"eml.shelf_header"]
        || [identifier isEqualToString:@"eml.cpr"]
        || [nodeController.key hasPrefix:@"button_container"]) {
        return YES;
    }
    return NO;
}

%hook ELMTouchCommandPropertiesHandler

- (void)handleTap {
    if (!isLegacy) {
        %orig;
        return;
    }
    ELMNodeController *nodeController = [self valueForKey:@"_controller"];
    HBLogDebug(@"nodeController: %@", nodeController);
    if (![nodeController isKindOfClass:%c(ELMNodeController)]) {
        %orig;
        return;
    }
    if (shouldNotHandleTap(nodeController)) {
        HBLogDebug(@"Not handling tap");
        %orig;
        return;
    }
    YTELMContext *context = [self valueForKey:@"_context"];
    YTElementsCellController *cellController = [context parentResponder];
    if (![cellController isKindOfClass:%c(YTElementsCellController)]) {
        %orig;
        return;
    }
    YTIElementRenderer *renderer = [cellController elementEntry];
    UITapGestureRecognizer *tapRecognizer = [self valueForKey:@"_tapRecognizer"];
    YTICommand *command = createRelevantCommandFromElementRenderer(renderer, (_ASDisplayView *)tapRecognizer.view, cellController);
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
    if (!isLegacy) return;
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
