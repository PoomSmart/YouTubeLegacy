#import "TweakHeader.h"
#import <HBLog.h>
#import <YouTubeHeader/_ASDisplayView.h>
#import <YouTubeHeader/ASEditableTextNode.h>
#import <YouTubeHeader/ELMNodeFactory.h>
#import <YouTubeHeader/ELMTextNode.h>
#import <YouTubeHeader/YTPageStyleController.h>

@interface ELMTextNode2 : ELMTextNode
- (BOOL)isLikeDislikeNode;
@end

static NSString *const YTLLegacyELMContentSizeDidChangeNotification = @"ELMContentSizeCategoryDidChangeNotification";

static UIColor *legacyForcedTextColor(void) {
    NSInteger pageStyle = [%c(YTPageStyleController) pageStyle];
    if (pageStyle == 1)
        return UIColor.whiteColor;
    return UIColor.blackColor;
}

static BOOL legacyShouldOverrideTextColorForNode(ASTextNode *textNode, NSAttributedString *attributedString) {
    if (hasElementObserverSupport)
        return NO;
    if (!textNode || !attributedString || attributedString.length == 0)
        return NO;

    return [textNode isKindOfClass:%c(ELMTextNode)] || [textNode isKindOfClass:%c(ASEditableTextNode)];
}

static void legacyOverrideTextColorInAttributedString(ASTextNode *textNode, NSMutableAttributedString *attributedString) {
    if (!legacyShouldOverrideTextColorForNode(textNode, attributedString))
        return;

    [attributedString removeAttribute:NSForegroundColorAttributeName
                                range:NSMakeRange(0, attributedString.length)];
    [attributedString addAttribute:NSForegroundColorAttributeName
                             value:legacyForcedTextColor()
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
    if (hasElementObserverSupport) return;

    UIApplication *application = [UIApplication sharedApplication];
#pragma clang diagnostic push
#pragma GCC diagnostic ignored "-Wdeprecated-declarations"
    for (UIWindow *window in application.windows)
#pragma clang diagnostic pop
        refreshLegacyAppearanceNodesInView(window);
}

static void notifyLegacyELMTextNodesForThemeRefresh(void) {
    if (hasElementObserverSupport)
        return;

    [[NSNotificationCenter defaultCenter] postNotificationName:YTLLegacyELMContentSizeDidChangeNotification object:nil];
}

static void scheduleLegacyTextNodeThemeRefresh(void) {
    if (hasElementObserverSupport) return;

    void (^refreshBlock)(void) = ^{
        notifyLegacyELMTextNodesForThemeRefresh();
        refreshVisibleLegacyAppearanceNodes();
    };

    dispatch_async(dispatch_get_main_queue(), refreshBlock);
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.05 * NSEC_PER_SEC)), dispatch_get_main_queue(), refreshBlock);
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.2 * NSEC_PER_SEC)), dispatch_get_main_queue(), refreshBlock);
}

#pragma mark - Refresh legacy appearance

%hook ASTextNode

- (void)prepareAttributedString:(NSMutableAttributedString *)attributedString isForIntrinsicSize:(BOOL)isForIntrinsicSize {
    %orig(attributedString, isForIntrinsicSize);
    legacyOverrideTextColorInAttributedString(self, attributedString);
}

- (id)drawParametersForAsyncLayer:(id)layer {
    id drawParameters = %orig(layer);
    if (hasElementObserverSupport)
        return drawParameters;
    if (![drawParameters isKindOfClass:NSDictionary.class])
        return drawParameters;

    NSAttributedString *attributedText = [(NSDictionary *)drawParameters objectForKey:@"text"];
    if (![attributedText isKindOfClass:NSAttributedString.class])
        return drawParameters;
    if (!legacyShouldOverrideTextColorForNode(self, attributedText))
        return drawParameters;

    NSMutableAttributedString *mutableAttributedText = [attributedText mutableCopy];
    legacyOverrideTextColorInAttributedString(self, mutableAttributedText);

    NSMutableDictionary *mutableDrawParameters = [(NSDictionary *)drawParameters mutableCopy];
    [mutableDrawParameters setObject:mutableAttributedText forKey:@"text"];
    return [NSDictionary dictionaryWithDictionary:mutableDrawParameters];
}

%end

%hook YTPageStyleController

- (void)setEffectivePageStyle:(NSInteger)pageStyle {
    %orig(pageStyle);
    if (hasElementObserverSupport) return;
    scheduleLegacyTextNodeThemeRefresh();
}

- (void)updatePageStyles {
    %orig;
    if (hasElementObserverSupport) return;
    scheduleLegacyTextNodeThemeRefresh();
}

%end

%hook YTSKeyboardAwareElementsViewController

- (void)pageStyleControllerPageStyleDidChange {
    %orig;
    if (hasElementObserverSupport) return;
    scheduleLegacyTextNodeThemeRefresh();
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

%ctor {
    if (!shouldEnableTweak) return;
    %init;
}
