#import "TweakHeader.h"
#import <HBLog.h>
#import <YouTubeHeader/NSArray+YouTube.h>
#import <YouTubeHeader/YTICompactVideoRenderer.h>
#import <YouTubeHeader/YTIPivotBarIconOnlyItemRenderer.h>
#import <YouTubeHeader/YTIPivotBarItemRenderer.h>
#import <YouTubeHeader/YTPivotBarItemView.h>
#import <YouTubeHeader/YTUIResources.h>

#pragma mark - Fix You tab avatar not displaying

static YTIcon getIconType(YTIIcon *self) {
    YTIcon iconType = self.iconType;
    return iconType ?: [[[self.unknownFields getField:1].varintList yt_numberAtIndex:0] intValue];
}

static YTIcon normalizeIconType(YTIcon iconType) {
    if (iconType == YT_TAB_HOME_CAIRO) return YT_TAB_HOME;
    if (iconType == YT_TAB_SHORTS_CAIRO) return YT_TAB_SHORTS;
    if (iconType == YT_CREATION_TAB_LARGE_CAIRO) return YT_CREATION_TAB_LARGE;
    if (iconType == YT_TAB_SUBSCRIPTIONS_CAIRO) return YT_TAB_SUBSCRIPTIONS;
    return iconType;
}

%hook YTHotConfig

- (BOOL)isFixAvatarFlickersEnabled { return NO; }

%end

%hook YTColdConfig

- (BOOL)mainAppCoreClientIosTopBarAvatarFix { return NO; }
- (BOOL)mainAppCoreClientIosTransientVisualGlitchInPivotBarFix { return YES; }

%end

%hook YTAppImageStyle

- (UIImage *)pivotBarItemIconImageWithIconType:(YTIcon)iconType color:(UIColor *)color useNewIcons:(BOOL)useNewIcons selected:(BOOL)selected {
    if (!isYouTube18OrNewer && iconType == YT_ACCOUNT_CIRCLE)
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
    if (isYouTube18OrNewer || ![self.renderer.pivotIdentifier isEqualToString:@"FElibrary"] || [self respondsToSelector:@selector(setupIconsAndTitles)]) return;
    setYouTabIcon(self, self.renderer);
}

- (void)setRenderer:(YTIPivotBarItemRenderer *)renderer {
    YTIIcon *icon = renderer.icon;
    BOOL isYouTab = [renderer.pivotIdentifier isEqualToString:@"FElibrary"];
    if (icon.iconType == 0 && !isYouTab) {
        YTIcon realIconType = getIconType(icon);
        icon.iconType = normalizeIconType(realIconType);
    }
    %orig;
    if (isYouTube18OrNewer || !isYouTab) return;
    setYouTabIcon(self, renderer);
}

- (void)setIconOnlyItemRenderer:(YTIPivotBarIconOnlyItemRenderer *)iconOnlyItemRenderer {
    YTIIcon *icon = iconOnlyItemRenderer.icon;
    if (icon.iconType == 0) {
        YTIcon realIconType = getIconType(icon);
        icon.iconType = normalizeIconType(realIconType);
    }
    %orig;
}

%end

#pragma mark - Fix tab icons not displaying

%hook YTAppPivotBarItemStyle

- (id)pivotBarItemIconImageWithIconType:(YTIcon)iconType color:(UIColor *)color {
    iconType = normalizeIconType(iconType);
    return %orig;
}

%end

#pragma mark - Fix icons not displaying

%hook YTIIcon

- (UIImage *)iconImageWithColor:(UIColor *)color {
    if (!isLegacy) return %orig;
    YTIcon iconType = getIconType(self);
    if (iconType == YT_CLAPPERBOARD)
        self.iconType = YT_MOVIES;
    else if (iconType == YT_SELL)
        self.iconType = YT_PURCHASES;
    else if (iconType == YT_TAB_ACTIVITY_CAIRO)
        self.iconType = YT_TAB_ACTIVITY;
    else if (iconType == YT_SETTINGS_CAIRO)
        self.iconType = YT_SETTINGS;
    else if (iconType == YT_SEARCH_CAIRO)
        self.iconType = YT_SEARCH;
    return %orig;
}

- (UIImage *)iconImageForContextMenu {
    if (isYouTube19OrNewer) return %orig;
    switch (getIconType(self)) {
        case YT_UNSUBSCRIBE:
        case YT_X_CIRCLE:
            return [%c(YTUIResources) xCircleOutline];
        case YT_BOOKMARK_BORDER:
            return [self iconImageWithColor:nil];
        default:
            break;
    }
    return %orig;
}

%end

#pragma mark - Fix video swipe actions in History page not showing icon

%hook YTGridVideoView

- (void)setEntry:(id)entry {
    if (!isYouTube18OrNewer && [entry isKindOfClass:%c(YTICompactVideoRenderer)]) {
        YTICompactVideoRenderer *videoRenderer = entry;
        YTIButtonRenderer *buttonRenderer = [videoRenderer.endSwipeContentsArray firstObject].buttonRenderer;
        if (buttonRenderer.style == STYLE_BLACK_FILLED)
            buttonRenderer.style = STYLE_DESTRUCTIVE;
    }
    %orig;
}

%end
