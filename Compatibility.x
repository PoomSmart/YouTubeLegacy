#import "TweakHeader.h"
#import <YouTubeHeader/SRLRegistry.h>
#import <YouTubeHeader/YTIElementRenderer.h>
#import <YouTubeHeader/YTIItemSectionRenderer.h>
#import <YouTubeHeader/YTInnerTubeCollectionViewController.h>
#import <YouTubeHeader/YTIShelfRenderer.h>
#import <YouTubeHeader/YTIShowFullscreenInterstitialCommand.h>

#pragma mark - Fix possible app crash on launch

%hook SRLRegistry

- (id)internalService:(struct _SRLAPIRegistrationData *)service scopeTags:(struct SRLScopeTagSet)tags {
    if (isLegacy && strcmp(service->name, "YTECatcherLogger_API") == 0)
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

#pragma mark - Improve general JS element compatibility

%hook YTDataPushEmbeddedPayloadBundleProviderImpl

- (NSBundle *)embeddedPayloadBundle {
    if (!isLegacy) return %orig;
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
    if (isLegacy) {
        NSMutableArray *sectionRenderers = [self valueForKey:@"_sectionRenderers"];
        [self setValue:filteredArray(sectionRenderers) forKey:@"_sectionRenderers"];
    }
    %orig;
}

- (void)addSectionsFromArray:(NSArray <YTIItemSectionRenderer *> *)array {
    if (isLegacy)
        array = filteredArray(array);
    %orig(array);
}

%end

#pragma mark - Avoid app crash around decoding CADPCastErrorInfo

%hook GCKRuntimeConfiguration

- (BOOL)boolForKey:(NSString *)key withDefaultValue:(BOOL)defaultValue {
    if (isLegacy && [key isEqualToString:@"enable_error_info_report_logging"])
        return NO;
    return %orig;
}

%end
