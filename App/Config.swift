enum Config {
    // Create a free app at developer.spotify.com/dashboard and paste its Client ID here.
    static let clientID = "4a7c3b622127442984f1ec1a87d22b78"
    static let scheme = "trollify"
    static let redirect = "https://frenchiiifries.github.io/Trollify/callback.html" // must match the Spotify dashboard exactly
    static let scopes = "user-read-playback-state user-modify-playback-state user-read-currently-playing playlist-read-private user-library-read"
}
