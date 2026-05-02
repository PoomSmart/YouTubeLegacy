#import "TweakHeader.h"
#import <HBLog.h>
#import <YouTubeHeader/_ASDisplayView.h>
#import <YouTubeHeader/ASEditableTextNode.h>
#import <YouTubeHeader/ELMNodeFactory.h>
#import <YouTubeHeader/ELMTextNode.h>
#import <YouTubeHeader/YTColorPalette.h>
#import <YouTubeHeader/YTPageStyleController.h>

@interface ELMTextNode2 : ELMTextNode
- (BOOL)isLikeDislikeNode;
@end

static NSString *const YTLLegacyFallbackColorAttributeName = @"YTL_LegacyFallbackColor";

static BOOL attributedStringHasForegroundColor(NSAttributedString *attributedString) {
    if (attributedString.length == 0)
        return NO;
    __block BOOL hasForegroundColor = NO;
    [attributedString enumerateAttribute:NSForegroundColorAttributeName
                                 inRange:NSMakeRange(0, attributedString.length)
                                 options:0
                              usingBlock:^(id value, NSRange range, BOOL *stop) {
        if (value != nil) {
            hasForegroundColor = YES;
            *stop = YES;
        }
    }];
    return hasForegroundColor;
}

static BOOL legacyTextColorsEqual(UIColor *firstColor, UIColor *secondColor) {
    if (firstColor == secondColor)
        return YES;
    if (!firstColor || !secondColor)
        return NO;
    if ([firstColor isEqual:secondColor])
        return YES;
    return CGColorEqualToColor(firstColor.CGColor, secondColor.CGColor);
}

static NSInteger currentLegacyPageStyle(void) {
    return [%c(YTPageStyleController) pageStyle];
}

static BOOL attributedStringHasLegacyFallbackColor(NSAttributedString *attributedString) {
    if (attributedString.length == 0)
        return NO;
    __block BOOL hasLegacyFallbackColor = NO;
    [attributedString enumerateAttribute:YTLLegacyFallbackColorAttributeName
                                 inRange:NSMakeRange(0, attributedString.length)
                                 options:0
                              usingBlock:^(id value, NSRange range, BOOL *stop) {
        if (value != nil) {
            hasLegacyFallbackColor = YES;
            *stop = YES;
        }
    }];
    return hasLegacyFallbackColor;
}

static BOOL attributedStringHasSingleForegroundColor(NSAttributedString *attributedString, UIColor **foregroundColor) {
    if (foregroundColor)
        *foregroundColor = nil;
    if (attributedString.length == 0)
        return NO;

    __block UIColor *resolvedColor = nil;
    __block BOOL didInspectFirstRange = NO;
    __block BOOL hasSingleForegroundColor = YES;
    [attributedString enumerateAttribute:NSForegroundColorAttributeName
                                 inRange:NSMakeRange(0, attributedString.length)
                                 options:0
                              usingBlock:^(id value, NSRange range, BOOL *stop) {
        UIColor *currentColor = [value isKindOfClass:UIColor.class] ? value : nil;
        if (!didInspectFirstRange) {
            resolvedColor = currentColor;
            didInspectFirstRange = YES;
            return;
        }

        if ((resolvedColor == nil) != (currentColor == nil) || (resolvedColor && !legacyTextColorsEqual(resolvedColor, currentColor))) {
            hasSingleForegroundColor = NO;
            *stop = YES;
        }
    }];

    if (!hasSingleForegroundColor)
        return NO;

    if (foregroundColor)
        *foregroundColor = resolvedColor;
    return resolvedColor != nil;
}

static UIColor *legacyFallbackTextColorForPageStyle(NSInteger pageStyle) {
    UIColor *fallbackTextColor = nil;
    id legacyPaletteClass = %c(YTColorPalette);
    id legacyPalette = nil;
    legacyPalette = [legacyPaletteClass colorPaletteForPageStyle:pageStyle];
    if (!legacyPalette && pageStyle == 1)
        legacyPalette = [legacyPaletteClass darkPalette];
    if (!legacyPalette && pageStyle != 1)
        legacyPalette = [legacyPaletteClass lightPalette];

    if (pageStyle == 1) {
        fallbackTextColor = [legacyPalette textPrimary];
        if (!fallbackTextColor)
            fallbackTextColor = [legacyPalette overlayTextPrimary];
        if (!fallbackTextColor)
            fallbackTextColor = [legacyPalette textPrimaryInverse];
        if (!fallbackTextColor)
            fallbackTextColor = [legacyPalette staticBrandWhite];
        if (!fallbackTextColor)
            fallbackTextColor = UIColor.whiteColor;
    } else {
        fallbackTextColor = [legacyPalette staticBrandBlack];
        if (!fallbackTextColor)
            fallbackTextColor = [legacyPalette textPrimary];
        if (!fallbackTextColor)
            fallbackTextColor = [legacyPalette overlayTextPrimary];
        if (!fallbackTextColor)
            fallbackTextColor = UIColor.blackColor;
    }

    return fallbackTextColor;
}

static BOOL shouldForceLegacyFallbackTextColorForTextNode(ASTextNode *textNode, NSAttributedString *attributedString) {
    if (!isLegacy || attributedString.length == 0)
        return NO;
    if (attributedStringHasLegacyFallbackColor(attributedString))
        return YES;
    if (!attributedStringHasForegroundColor(attributedString))
        return YES;

    if (![textNode isKindOfClass:%c(ELMTextNode)] && ![textNode isKindOfClass:%c(ASEditableTextNode)])
        return NO;

    UIColor *resolvedColor = nil;
    if (!attributedStringHasSingleForegroundColor(attributedString, &resolvedColor) || !resolvedColor)
        return NO;

    UIColor *darkThemeColor = legacyFallbackTextColorForPageStyle(1);
    UIColor *lightThemeColor = legacyFallbackTextColorForPageStyle(0);
    return legacyTextColorsEqual(resolvedColor, darkThemeColor)
        || legacyTextColorsEqual(resolvedColor, lightThemeColor)
        || legacyTextColorsEqual(resolvedColor, UIColor.whiteColor)
        || legacyTextColorsEqual(resolvedColor, UIColor.blackColor);
}

static void applyLegacyFallbackTextColorToMutableAttributedStringForTextNodeIfNeeded(ASTextNode *textNode, NSMutableAttributedString *attributedString) {
    if (!shouldForceLegacyFallbackTextColorForTextNode(textNode, attributedString))
        return;

    [attributedString removeAttribute:NSForegroundColorAttributeName range:NSMakeRange(0, attributedString.length)];
    [attributedString removeAttribute:YTLLegacyFallbackColorAttributeName range:NSMakeRange(0, attributedString.length)];

    UIColor *fallbackTextColor = legacyFallbackTextColorForPageStyle(currentLegacyPageStyle());
    [attributedString addAttribute:NSForegroundColorAttributeName
                             value:fallbackTextColor
                             range:NSMakeRange(0, attributedString.length)];
    [attributedString addAttribute:YTLLegacyFallbackColorAttributeName
                             value:@YES
                             range:NSMakeRange(0, attributedString.length)];
}

static ASDisplayNode *displayNodeForDisplayView(_ASDisplayView *displayView) {
    id node = nil;
    @try {
        node = [displayView valueForKey:@"_asyncdisplaykit_node"];
        if (!node)
            node = [displayView keepalive_node];
    } @catch (NSException *exception) {
        node = [displayView keepalive_node];
    }
    return [node isKindOfClass:%c(ASDisplayNode)] ? node : nil;
}

static void refreshLegacyAppearanceNodesInView(UIView *view) {
    if ([view isKindOfClass:%c(_ASDisplayView)]) {
        ASDisplayNode *displayNode = displayNodeForDisplayView((_ASDisplayView *)view);
        ASTextNode *textNode = [displayNode isKindOfClass:%c(ASTextNode)] ? (ASTextNode *)displayNode : nil;
        if ([textNode isKindOfClass:%c(ASTextNode)]) {
            [textNode setNeedsLayout];
            [(ASDisplayNode *)textNode setNeedsDisplay];
        }
    }

    for (UIView *subview in view.subviews)
        refreshLegacyAppearanceNodesInView(subview);
}

static void refreshVisibleLegacyAppearanceNodes(void) {
    if (!isLegacy)
        return;

    UIApplication *application = [UIApplication sharedApplication];
#pragma clang diagnostic push
#pragma GCC diagnostic ignored "-Wdeprecated-declarations"
    for (UIWindow *window in application.windows)
#pragma clang diagnostic pop
        refreshLegacyAppearanceNodesInView(window);
}

static void scheduleLegacyAppearanceRefresh(void) {
    void (^refreshBlock)(void) = ^{
        refreshVisibleLegacyAppearanceNodes();
    };

    dispatch_async(dispatch_get_main_queue(), refreshBlock);
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.05 * NSEC_PER_SEC)), dispatch_get_main_queue(), refreshBlock);
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.2 * NSEC_PER_SEC)), dispatch_get_main_queue(), refreshBlock);
}

#pragma mark - Refresh legacy appearance

%hook YTPageStyleController

- (void)setEffectivePageStyle:(NSInteger)pageStyle {
    %orig(pageStyle);
    if (!isLegacy) return;
    scheduleLegacyAppearanceRefresh();
}

- (void)updatePageStyles {
    %orig;
    if (!isLegacy) return;
    dispatch_async(dispatch_get_main_queue(), ^{
        refreshVisibleLegacyAppearanceNodes();
    });
}

%end

%hook ASTextNode

- (void)prepareAttributedString:(NSMutableAttributedString *)attributedString isForIntrinsicSize:(BOOL)isForIntrinsicSize {
    %orig(attributedString, isForIntrinsicSize);
    if (!isLegacy || attributedString.length == 0)
        return;

    applyLegacyFallbackTextColorToMutableAttributedStringForTextNodeIfNeeded(self, attributedString);
}

- (id)drawParametersForAsyncLayer:(id)layer {
    id drawParameters = %orig(layer);
    if (!isLegacy || ![drawParameters isKindOfClass:NSDictionary.class])
        return drawParameters;

    NSAttributedString *attributedText = [(NSDictionary *)drawParameters objectForKey:@"text"];
    if (![attributedText isKindOfClass:NSAttributedString.class]
        || !shouldForceLegacyFallbackTextColorForTextNode(self, attributedText)) {
        return drawParameters;
    }

    NSMutableAttributedString *mutableAttributedText = [attributedText mutableCopy];
    applyLegacyFallbackTextColorToMutableAttributedStringForTextNodeIfNeeded(self, mutableAttributedText);

    NSMutableDictionary *mutableDrawParameters = [(NSDictionary *)drawParameters mutableCopy];
    [mutableDrawParameters setObject:mutableAttributedText forKey:@"text"];

    NSDictionary *updatedDrawParameters = [NSDictionary dictionaryWithDictionary:mutableDrawParameters];
    return updatedDrawParameters;
}

%end

%hook YTSKeyboardAwareElementsViewController

- (void)pageStyleControllerPageStyleDidChange {
    %orig;
    if (!isLegacy) return;
    scheduleLegacyAppearanceRefresh();
    dispatch_async(dispatch_get_main_queue(), ^{
        YTLRebuildOpenElementsControllerIfNeeded(self);
    });
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
    if (!isYouTube18OrNewer)
        [[%c(ELMNodeFactory) sharedInstance] registerNodeClass:%c(ELMTextNode2) forTypeExtension:525000000];
    return self;
}

%end
