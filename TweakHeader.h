#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>

#define DidApplyDefaultSettingsKey @"YTL_DidApplyDefaultSettings"
#define DidApplyDefaultSettings2Key @"YTL_DidApplyDefaultSettings2"
#define DidShowInformationAlertKey @"YTL_DidShowInformationAlert"
#define DidShowInformationAlert2Key @"YTL_DidShowInformationAlert2"
#define YouSpeedEnabledKey @"YTVideoOverlay-YouSpeed-Enabled"
#define YouSpeedButtonPositionKey @"YTVideoOverlay-YouSpeed-Position"
#define RYDUseItsDataKey @"RYD-USE-LIKE-DATA"

#define IOS_BUILD "19H411"

#define TweakName @"YouTubeLegacy"
#define _LOC(b, x) [b localizedStringForKey:x value:nil table:nil]
#define LOC(x) _LOC(tweakBundle, x)

extern NSString *realAppVersion;
extern BOOL isLegacy;
extern BOOL isYouTube18OrNewer;
extern BOOL isYouTube19OrNewer;

void YTLRebuildOpenElementsControllerIfNeeded(id controller);
NSBundle *TweakBundle(void);
