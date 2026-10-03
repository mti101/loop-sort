# Release checklist — Loop Sort (`com.ajoy.loop.puzzle.sort.game`)

## 1. GitHub secrets (Settings → Secrets and variables → Actions)
| Secret | Value |
|---|---|
| `KEYSTORE_B64` | contents of `upload-keystore.b64.txt` (delivered separately) |
| `KEYSTORE_PASSWORD` | store password (delivered separately) |
| `KEY_PASSWORD` | same as store password |
| `KEY_ALIAS` | `upload` |
| `ADMOB_APP_ID` | your real AdMob App ID `ca-app-pub-XXXX~YYYY` |

Real ad unit IDs: add repo **Variables** or edit the workflow `--dart-define` lines:
`ADMOB_BANNER`, `ADMOB_INTERSTITIAL`, `ADMOB_REWARDED`.
Until set, Google **test** IDs are used (safe, but earn nothing). Never click your own live ads.

## 2. Build
Push to `main` → Actions builds a signed `app-release.aab` + APK → branch `ci-output`.

## 3. Play Console
- Create app, upload AAB (enable Play App Signing).
- Privacy policy URL: enable GitHub Pages (Settings → Pages → `main` / `/docs`) → `https://mti101.github.io/loop-sort/privacy.html`. (Pages on a private repo needs a paid plan; otherwise host `docs/privacy.html` elsewhere and update `lib/config.dart`.)
- Listing text: `store/listing/en-US.md`; icon/feature graphic: `store/`.
- Data safety / ads / target audience: `store/DATA_SAFETY.md`.
- In-app product: managed product id `remove_ads`.
- Link AdMob app to the Play listing; add `app-ads.txt` if you have a developer site.

## 4. Before going live
- Replace test AdMob IDs; confirm support email `support@terafort.com` in `docs/` and listing.
- Back up the keystore safely. Revoke the GitHub token used during development.
