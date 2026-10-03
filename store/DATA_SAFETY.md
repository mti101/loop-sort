# Play Console - Data safety answers (guide)

Fill in Play Console > App content > Data safety with the answers below. Re-check against the AdMob SDK
documentation if you add more SDKs.

**Does your app collect or share any of the required user data types?** Yes (via the Google AdMob SDK).

**Is all of the user data collected by your app encrypted in transit?** Yes.
**Do you provide a way for users to request that their data is deleted?** No accounts exist. Data handled by
Google ads can be reset/deleted from Android ad settings. (Answer "No" and note no account/data held by you.)

| Data type | Collected | Shared | Purpose | Optional |
|---|---|---|---|---|
| Device or other IDs (Advertising ID) | Yes | Yes (Google AdMob) | Advertising or marketing, Analytics | No (consent where required) |
| Approximate location (IP-derived) | Yes | Yes (Google AdMob) | Advertising or marketing | No |
| App interactions / diagnostics (crash, performance) | Yes | Yes (Google AdMob) | Analytics, Advertising | No |
| Purchase history (via Google Play Billing) | No (Google Play handles it) | - | - | - |
| Personal info (name, email, ...) | No | - | - | - |

Data processed ephemerally / not stored by you. Mark "Data is shared with third parties: Google (AdMob)".

## Other App content forms
* **Ads:** Yes, contains ads.
* **Target audience:** 13+ (do NOT select children under 13 unless you enrol in Families + use child-safe ad setup).
* **Content rating questionnaire:** no violence, no UGC, no gambling -> expect "Everyone".
* **Advertising ID declaration:** Yes, used for advertising (the AD_ID permission is declared in the manifest).
* **News app / government / health / financial:** No.
* **Privacy policy URL:** https://mti101.github.io/loop-sort/privacy.html (enable GitHub Pages: Settings > Pages > main /docs)
