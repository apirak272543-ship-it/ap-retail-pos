# AP Retail POS Android Shell

Android shell for the dedicated AP Retail POS web application. The shell loads only the published AP Retail POS GitHub Pages site and allows the shared Supabase host for the web application's authenticated data flow. All other links are routed to the device browser.

## Local validation

Install dependencies with `pnpm install`, then run `pnpm check` and `pnpm test`. The production EAS profile produces an Android App Bundle; the preview profile is configured for an installable APK.

## Release constraint

The current EAS Build quota is unavailable until **1 September 2026**. This directory is build-ready but no cloud APK build is triggered until the quota is available.
