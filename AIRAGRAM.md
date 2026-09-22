# airagram

A local fork of the official Telegram iOS client ([TelegramMessenger/Telegram-iOS](https://github.com/TelegramMessenger/Telegram-iOS)), cloned 2026-09-22.

This is a shallow clone (`--depth 1 --shallow-submodules`) — full commit history was skipped to keep the download size down. If you need full history later (e.g. to open PRs upstream), run `git fetch --unshallow` in this folder.

## Git remotes

The original repo is wired up as `upstream`, not `origin` (and its push URL is disabled), so:
- `git fetch upstream` / `git merge upstream/master` pulls in updates from the real Telegram-iOS project.
- Once you create your own GitHub repo for this fork, add it as `origin`: `git remote add origin <your-repo-url>`.

## Important: this is source-available, not a standard OSS license

There's no LICENSE file or per-file license header in this repo — Telegram distributes the source under its own terms, stated in the upstream README, not a standard MIT/GPL grant. The terms that matter for this fork:

- **Don't call the built app "Telegram"** and don't present it as official — renaming to "airagram" satisfies this.
- **Don't use Telegram's logo** (white paper plane in a blue circle) as this app's icon — you'll need your own icon/logo before shipping anywhere.
- **Get your own `api_id`/`api_hash`** from https://my.telegram.org/apps — don't reuse Telegram's own client credentials.
- **Publish your modified source** if you distribute the app, to stay compliant.

## Building — requires macOS, cannot be done on Windows

This project builds via **Bazel**, wrapped by `build-system/Make/Make.py`, and generates an Xcode project — there is no build path that works outside macOS + Xcode. That means from this Windows machine you can browse/edit the source, but actually compiling and running airagram needs a Mac. High-level steps there (see `README.md` for full detail):

1. Install Xcode.
2. Get an `api_id`/`api_hash` from https://my.telegram.org/apps.
3. Find your Team ID in Keychain Access (Certificates → your Apple Development cert → Details → Organizational Unit).
4. Fill those into [`build-system/airagram-development-configuration.json`](build-system/airagram-development-configuration.json) — already pre-filled with a generated bundle id (`org.a74d5e43279953af.airagram`) and a custom URL scheme (`airagram`, instead of `tg`) so it won't collide with a real Telegram app installed on the same device/simulator.
5. Generate the Xcode project:

   ```sh
   python3 build-system/Make/Make.py \
       --cacheDir="$HOME/telegram-bazel-cache" \
       generateProject \
       --configurationPath=build-system/airagram-development-configuration.json \
       --xcodeManagedCodesigning
   ```

6. When Xcode asks for a Product Name during any manual project-creation step, use `airagram` instead of `Telegram`.

## What was *not* renamed

The word "Telegram" still appears throughout the codebase (class names like `TelegramCore`, protocol/API references, MTProto, server domains). That's intentional — it's the network protocol and API this app talks to, not just branding, and mass-replacing it would break the build and the connection to Telegram's servers. The only renaming done here is at the product-identity layer (bundle id, product/display name, URL scheme) via the config file above, which is also how the official docs say forks are meant to rebrand.
