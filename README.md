# Dan

A nimble Fanfou client.

## Photo uploads

Only JPG, JPEG, PNG, and GIF uploads are accepted; selection and upload validate
both the filename extension and file signature. JPG/JPEG/PNG are limited to
4 MiB (4,194,304 bytes), and GIF to 3 MiB (3,145,728 bytes), matching Fanfou's
website. Files within their limit are uploaded unchanged. Oversized JPG/PNG
are converted to JPEG with reduced quality and, if needed, smaller dimensions.
Oversized GIFs are re-encoded and resized as needed while retaining animation
frames, timing, and loop count. Compression runs in a background isolate.
The original file is preserved, and temporary upload copies are removed after
success or failure. JPEG conversion flattens transparency onto white.
Unsupported formats (including HEIC and WebP) and files that cannot be prepared
are not uploaded; the composer keeps the draft for replacement or retry.

## Local configuration

Copy the example build configuration and replace its placeholder values:

```sh
cp config/fanfou.example.json config/fanfou.local.json
```

Run or build the app with the local configuration:

```sh
flutter run --dart-define-from-file=config/fanfou.local.json
```

`config/fanfou.local.json` is ignored by Git. These values are compiled into
the application binary and can still be extracted by someone with access to
the built app; build-time injection prevents accidental source-control leaks,
not reverse engineering.

Fanfou's API and OAuth services use HTTPS. Production clients are pinned to the
official `api.fanfou.com` and `fanfou.com` hosts, and the application does not
enable platform clear-text transport exceptions.

Fanfou's OAuth verifier still canonicalizes official endpoint URLs with the
legacy `http` scheme when checking OAuth 1.0a HMAC signatures. The local SDK
handles that server-side compatibility rule only while constructing the
signature base string; every network request and browser authorization URL
continues to use HTTPS.

## OAuth callback

The browser-based OAuth 1.0a flow uses this application callback:

```text
dev.yrm.dan://oauth/callback
```

Android registers the scheme in `AndroidManifest.xml`; iOS and macOS receive
it through their system authentication sessions. The callback's target,
temporary request token, and verifier are validated before an access token is
accepted. An unfinished request-token secret remains in memory only and is
discarded when authorization completes, is cancelled, or is restarted.

OAuth is an additional login method. The existing username/password form still
uses Fanfou XAuth and follows the same account persistence path after tokens are
issued.

## Authentication persistence

Account profiles and OAuth sessions are stored as one versioned JSON document
under `dan.authentication.accounts` with `SharedPreferencesAsync`. This storage is
unencrypted; tokens may be recoverable from a compromised or debug-enabled
device. Android application backups remain disabled, but that does not make
the preference value encrypted.

Each entry in the document's `accounts` array is flat: account profile fields
and OAuth token fields share one object, while the repository still exposes
typed account and session models separately.

Sessions written by earlier secure-storage or multi-key preference adapters are
not migrated. After this storage change, sign in again to create the current
single-document data.
