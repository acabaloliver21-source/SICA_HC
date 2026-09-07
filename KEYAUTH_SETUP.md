# KeyAuth setup

The Moon Place login screen supports two providers. The app automatically uses
**KeyAuth** when its credentials are filled in; otherwise it falls back to
Supabase. This guide covers connecting KeyAuth.

## 1. Create the KeyAuth account and application

1. Sign up / log in at https://keyauth.cc.
2. Generate a **Seller Key** on the seller page so the panel lets you create an
   application.
3. Create your application at https://keyauth.cc/app/. After creation, copy:
   - **App Name** — the name you gave the application.
   - **Owner ID** — the 10-character ID for your account.

## 2. Put the credentials in the app

Open `ThreeOneOSFive/helpers/KeyAuthClient.swift` and fill `shared`:

```text
struct KeyAuthConfiguration {
    static let shared = KeyAuthConfiguration(
        appName: "YOUR_APP_NAME",   // <- your app name
        ownerID: "YOUR_OWNER_ID",   // <- your 10-character owner ID
        version: ...,               // optional, used for the "invalid version" check
        apiURL: URL(string: "https://keyauth.win/api/1.2/")!
    )
}
```

- `appName` must no longer contain `YOUR_APP_NAME`.
- `ownerID` must be exactly 10 characters.
- The app detects this and switches the login screen to KeyAuth automatically
  (`KeyAuthConfiguration.isConfigured`).

## 3. Create license keys

In the KeyAuth panel, open your application → **Keys** and generate a test
license key (for example `MOON-TEST`).

## 4. Register a user (first time)

In the app's **Register** screen use:

```text
Username: <any>
Password: <6+ characters>
License:  <the license key from the panel>
Phone:    <optional, ignored by KeyAuth>
```

Registering binds the account to this device's HWID automatically.

## 5. Login (next times)

Use the same username and password. The license key field is ignored by KeyAuth
for existing accounts.

## What the app does

- Calls `init` (validates the app, gets a session ID), then `login`/`register`
  with the device HWID.
- Stores the profile + license expiry locally, so the session is restored
  without prompting until the license expires.
- Logs `keyauth: transport error <code> ...` to the built-in Log view on
  connection problems.

## 6. Troubleshooting

| Symptom | Fix |
| --- | --- |
| "KeyAuth application does not exist" / "KeyAuth initialization failed" | Wrong app name, or the application is not active in the panel. Recheck the two credentials. |
| "KeyAuth returned an invalid response" | Check that the panel has **API response encryption OFF** (default). Verify app name/owner ID. |
| "Secure connection to keyauth.win failed (TLS)" | Same TLS checklist as Supabase: device date/time correct, network is not intercepting TLS (try Wi-Fi vs cellular), and the URL is `https://keyauth.win/api/1.2/`. |
| Login says wrong password/username | The account does not exist or the password is wrong; register first. |
| "There is no Internet connection" | Device is offline. |

## SWITCHING BACK TO SUPABASE

Restore the `YOUR_APP_NAME` / `YOUR_OWNER_ID` placeholders (or leave them wrong)
and the app will use the Supabase configuration
(`ThreeOneOSFive/helpers/KeyAuthConfiguration.swift`, `SupabaseConfiguration`)
instead.