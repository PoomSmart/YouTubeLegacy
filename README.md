# YouTubeLegacy

YouTubeLegacy attempts to make old YouTube versions work again. It works from YouTube version 16.32.6+ (iOS 11+). If you are on anything older, please use [TubeRepair](https://tuberepair.bag-xml.com/) instead when supported.

## List of mitigations

- You may have to play a video by tapping on the vertical triple dots button and selecting "Play".
- You can select another account by tapping on the vertical triple dots button in "You" tab.

## Do I need to install this tweak?

**TL;DR:** Yes, if you are on iOS 13 or below, or you are using the YouTube app version 18.49.3 or below.

**2025 TL;DR:** Yes, if you are on iOS 14 or below. This is related to being able to sign in to YouTube.

At the time of writing (Jun 2025), YouTube app version 19.01.1 and higher are not affected by the YouTube server-side changes that require the app to be updated in order to use the app. The reason that iOS 13 is the cutoff is that the latest installable version of YouTube is 17.40.5. For iOS 14, users can go up to version 19.20.2.

## Notes

- CydiaSubstrate is usually broken on iOS 12 jailbreaks. This may cause false positives where the tweak is not working as expected. Consider switching to Substitute or Libhooker instead. Alternatively, switch to a different jailbreak that has Substitute or Libhooker built-in.
- You should not modify `Info.plist` of YouTube app while using this tweak as it may cause the tweak to not work properly.
