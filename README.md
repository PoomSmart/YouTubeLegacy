# YouTubeLegacy

YouTubeLegacy makes old YouTube versions work again. It works from YouTube version 16.32.6+ on iOS 11+.

## List of mitigations

_Only applicable to very old YouTube versions._

- You may have to play a video by tapping on the vertical triple dots button and selecting "Play".
- You can select another account by tapping on the vertical triple dots button in "You" tab.

## Do I need to install this tweak?

**TL;DR:** Yes, if you are on iOS 11 - 15, or you are using the YouTube app version 20.23.3 or below.

In early 2026, YouTube made server-side changes yet again. Now the tweak spoofs the YouTube version to 20.21.6 for anything lower.

In early December 2025, YouTube made server-side changes that broke the home page and search page for older app versions. YouTube version 20.24.4 and higher support these new changes, while version 20.23.3 and lower do not. This tweak already spoofs the YouTube version to 19.14.2 for versions 17.09.1 and earlier. As a workaround for the new server-side changes, this spoofing is now also applied to versions lower than 20.24.4.

## Notes

- CydiaSubstrate is usually broken on iOS 12 jailbreaks. This can cause false positives where the tweak is not working as expected. Consider switching the tweak injection library to Substitute or Libhooker instead. Alternatively, switch to a different jailbreak that has Substitute or Libhooker built-in.
- You should not modify `Info.plist` of YouTube app while using this tweak as it may cause the tweak to not work properly.
- iOS 13 and below (YouTube app up to 17.40.5) may be approaching end-of-life for regular playback. Newer Proof-of-Origin (PoToken) flows depend on Apple App Attest, which is not available/reliable on these legacy environments.
- If you have YouTube Premium, playback can still be less affected because PoToken enforcement is often relaxed for Premium streaming paths.

## Tips

- On YouTube version 16, if you noticed that Shorts quality is very low, you can install YouChooseQuality tweak to force higher quality.
