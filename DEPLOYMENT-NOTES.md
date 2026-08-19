# AP Retail POS — Deployment Notes

## Published web application

The AP Retail POS static MPA is published from the root of the `main` branch via GitHub Pages.

| Item | Verified value |
|---|---|
| Repository | `apirak272543-ship-it/ap-retail-pos` |
| Git commit | `da078bc` — `feat: scaffold AP Retail POS web app and Android shell` |
| Pages source | `main` branch, `/` root |
| Public URL | https://apirak272543-ship-it.github.io/ap-retail-pos/ |
| HTTP verification | `200 OK`; document title `AP Retail POS` |

## Android WebView shell

The Android shell is committed under `android-shell/`. It loads only the published AP Retail POS GitHub Pages host and allows the central Supabase host for the authenticated web app. The shell has loading, retry, and external-link handling states. The configuration targets package identifier `com.apservice.retailpos`.

> **Build status:** The EAS cloud-build quota is unavailable until 1 September 2026. The shell configuration and tests are build-ready, but no APK/AAB cloud build has been submitted.

## Validation completed before publication

| Validation | Result |
|---|---|
| Static POS cart and image-compression contracts | Passed — 3 tests |
| Android shell URL/configuration contracts | Passed — 3 tests |
| Android shell TypeScript check | Passed |
| Live GitHub Pages HTTP probe | Passed — `200 OK` |
