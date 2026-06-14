#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>

#define DidApplyDefaultSettingsKey @"YTL_DidApplyDefaultSettings"
#define DidApplyDefaultSettings2Key @"YTL_DidApplyDefaultSettings2"
#define DidShowInformationAlert2Key @"YTL_DidShowInformationAlert2"
#define YouSpeedEnabledKey @"YTVideoOverlay-YouSpeed-Enabled"
#define YouSpeedButtonPositionKey @"YTVideoOverlay-YouSpeed-Position"
#define RYDUseItsDataKey @"RYD-USE-LIKE-DATA"

#define IOS_BUILD "19H422"

#define TweakName @"YouTubeLegacy"
#define _LOC(b, x) [b localizedStringForKey:x value:nil table:nil]
#define LOC(x) _LOC(tweakBundle, x)

extern NSString *realAppVersion;
extern BOOL shouldEnableTweak;
extern BOOL isLegacy;
extern BOOL isYouTube18OrNewer;
extern BOOL isYouTube19OrNewer;
extern BOOL hasElementObserverSupport;
extern BOOL hasElementShortsOverlayButtonsSupport;
extern BOOL isYouTube20OrNewer;

void YTLRebuildOpenElementsControllerIfNeeded(id controller);
NSBundle *TweakBundle(void);
