# Trollify
Spotify controller for iPad Air 2 (iPadOS 15), installed with TrollStore.

1. developer.spotify.com/dashboard -> Create app. Redirect URI: `trollify://callback`. Tick "Web API".
2. Under the app's User Management, add your Spotify account email.
3. Paste the Client ID into `App/Config.swift`.
4. Push to GitHub, download the `Trollify-ipa` artifact, install the IPA in TrollStore.
5. Audio plays on the Spotify device you pick (button bottom right), e.g. the Spotify app on this iPad.
