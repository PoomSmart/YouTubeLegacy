#import "TweakHeader.h"
#import <YouTubeHeader/SRLRegistry.h>
#import <YouTubeHeader/YTICommentsResponse.h>
#import <YouTubeHeader/YTIElementRenderer.h>
#import <YouTubeHeader/YTIInsertItemSectionContentOperation.h>
#import <YouTubeHeader/YTIItemSectionRenderer.h>
#import <YouTubeHeader/YTIItemSectionSupportedRenderers.h>
#import <YouTubeHeader/YTISectionListMutationOperations.h>
#import <YouTubeHeader/YTISectionListRenderer.h>
#import <YouTubeHeader/YTISectionListSupportedRenderers.h>
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

#pragma mark - Comment replies mutation operations as item sections

static YTIItemSectionRenderer *itemSectionRendererWithElements(NSArray *elements) {
    if (elements.count == 0)
        return nil;
    YTIItemSectionRenderer *itemSectionRenderer = [[%c(YTIItemSectionRenderer) alloc] init];
    NSMutableArray *contentsArray = itemSectionRenderer.contentsArray;
    for (id element in elements) {
        if ([element isKindOfClass:%c(YTIItemSectionSupportedRenderers)]) {
            [contentsArray addObject:element];
            continue;
        }
        YTIItemSectionSupportedRenderers *supported = [[%c(YTIItemSectionSupportedRenderers) alloc] init];
        supported.elementRenderer = element;
        [contentsArray addObject:supported];
    }
    return contentsArray.count ? itemSectionRenderer : nil;
}

static void harvestSectionContent(id object, NSMutableArray *itemSectionRenderers, NSMutableArray *elements, NSHashTable *seen, NSInteger depth) {
    if (!object || depth > 8)
        return;
    if ([seen containsObject:object])
        return;
    if ([object isKindOfClass:[NSArray class]]) {
        for (id item in object)
            harvestSectionContent(item, itemSectionRenderers, elements, seen, depth + 1);
        return;
    }
    if (![object isKindOfClass:%c(GPBMessage)])
        return;
    [seen addObject:object];

    if ([object isKindOfClass:%c(YTIItemSectionRenderer)]) {
        [itemSectionRenderers addObject:object];
        return;
    }
    if ([object isKindOfClass:%c(YTIElementRenderer)]) {
        [elements addObject:object];
        return;
    }
    if ([object isKindOfClass:%c(YTIItemSectionSupportedRenderers)]) {
        YTIElementRenderer *elementRenderer = ((YTIItemSectionSupportedRenderers *)object).elementRenderer;
        if (elementRenderer)
            [elements addObject:elementRenderer];
        return;
    }
    if ([object isKindOfClass:%c(YTISectionListRenderer)]) {
        harvestSectionContent(((YTISectionListRenderer *)object).contentsArray, itemSectionRenderers, elements, seen, depth + 1);
        return;
    }
    if ([object isKindOfClass:%c(YTISectionListMutationOperations)]) {
        harvestSectionContent(((YTISectionListMutationOperations *)object).operationsArray, itemSectionRenderers, elements, seen, depth + 1);
        return;
    }
    if ([object isKindOfClass:%c(YTIInsertItemSectionContentOperation)]) {
        harvestSectionContent(((YTIInsertItemSectionContentOperation *)object).contentsArray, itemSectionRenderers, elements, seen, depth + 1);
        return;
    }
    harvestSectionContent(((GPBMessage *)object).firstSubmessage, itemSectionRenderers, elements, seen, depth + 1);
}

static NSArray *itemSectionRenderersFromObject(id object) {
    NSMutableArray *itemSectionRenderers = [NSMutableArray array];
    NSMutableArray *elements = [NSMutableArray array];
    NSHashTable *seen = [NSHashTable hashTableWithOptions:NSPointerFunctionsObjectPointerPersonality];
    harvestSectionContent(object, itemSectionRenderers, elements, seen, 0);
    YTIItemSectionRenderer *wrapped = itemSectionRendererWithElements(elements);
    if (wrapped)
        [itemSectionRenderers insertObject:wrapped atIndex:0];
    return itemSectionRenderers.count ? itemSectionRenderers : nil;
}

static NSArray *normalizedSectionRenderers(NSArray *sectionRenderers) {
    if (sectionRenderers.count == 0)
        return sectionRenderers;

    NSMutableArray *normalized = [NSMutableArray arrayWithCapacity:sectionRenderers.count];
    BOOL changed = NO;
    for (id renderer in sectionRenderers) {
        if ([renderer isKindOfClass:%c(YTIItemSectionRenderer)]) {
            [normalized addObject:renderer];
            continue;
        }
        BOOL shouldConvert = [renderer isKindOfClass:%c(YTISectionListMutationOperations)]
            || [renderer isKindOfClass:%c(YTIElementRenderer)]
            || [renderer isKindOfClass:%c(YTISectionListSupportedRenderers)];
        NSArray *converted = shouldConvert ? itemSectionRenderersFromObject(renderer) : nil;
        if (converted.count) {
            [normalized addObjectsFromArray:converted];
            changed = YES;
        } else {
            [normalized addObject:renderer];
        }
    }
    return changed ? normalized : sectionRenderers;
}

%hook YTISectionListRenderer

- (NSArray *)sectionRenderers {
    NSArray *sectionRenderers = %orig;
    return normalizedSectionRenderers(sectionRenderers);
}

%end

%hook YTICommentsResponse

- (NSArray *)sectionRenderers {
    NSArray *sectionRenderers = %orig;
    return normalizedSectionRenderers(sectionRenderers);
}

%end

%hook YTInnerTubeCollectionViewController

- (void)loadWithModel:(id)model {
    %orig;
    NSMutableArray *sectionRenderers = [self valueForKey:@"_sectionRenderers"];
    NSArray *normalized = normalizedSectionRenderers(sectionRenderers);
    BOOL hasItemSection = NO;
    for (id renderer in normalized) {
        if ([renderer isKindOfClass:%c(YTIItemSectionRenderer)]) {
            hasItemSection = YES;
            break;
        }
    }
    if (!hasItemSection && [model isKindOfClass:%c(YTISectionListRenderer)]) {
        NSArray *fromModel = itemSectionRenderersFromObject(model);
        if (fromModel.count)
            normalized = fromModel;
    }
    if (normalized != sectionRenderers)
        [self setValue:[normalized mutableCopy] forKey:@"_sectionRenderers"];
    NSDictionary *sectionControllerByRenderer = [self valueForKey:@"_sectionControllerByRenderer"];
    if (sectionControllerByRenderer.count == 0)
        [self displaySections];
}

- (void)displaySectionsWithReloadingSectionControllerByRenderer:(id)renderer {
    NSMutableArray *sectionRenderers = [self valueForKey:@"_sectionRenderers"];
    NSArray *normalized = normalizedSectionRenderers(sectionRenderers);
    if (isLegacy)
        normalized = filteredArray(normalized);
    if (normalized != sectionRenderers)
        [self setValue:[normalized mutableCopy] forKey:@"_sectionRenderers"];
    %orig;
}

- (void)addSectionsFromArray:(NSArray <YTIItemSectionRenderer *> *)array {
    array = normalizedSectionRenderers(array);
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

%ctor {
    if (!shouldEnableTweak) return;
    %init;
}
