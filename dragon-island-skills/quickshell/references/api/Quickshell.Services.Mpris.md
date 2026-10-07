# Quickshell.Services.Mpris

`import Quickshell.Services.Mpris`

Mpris Service

## Mpris
*singleton* · extends `QtObject`

**Properties**
- `players`: ObjectModel<MprisPlayer> [readonly] — All connected MPRIS players.

## MprisLoopState
*enum* · extends `QtObject`

See `MprisPlayer.loopState`.

**Functions**
- `toString(status: MprisLoopState)`: string

**Values:** `MprisLoopState.Playlist`, `MprisLoopState.Track`, `MprisLoopState.None`

## MprisPlaybackState
*enum* · extends `QtObject`

See `MprisPlayer.playbackState`.

**Functions**
- `toString(status: MprisPlaybackState)`: string

**Values:** `MprisPlaybackState.Stopped`, `MprisPlaybackState.Playing`, `MprisPlaybackState.Paused`

## MprisPlayer
*class* · extends `QtObject` · uncreatable (obtained from other objects)

A media player exposed over MPRIS.

> [!WARNING]
> Support for various functionality and general compliance to
> the MPRIS specification varies wildly by player.
> Always check the associated `canXyz` and `xyzSupported` properties if available.

> [!NOTE]
> The TrackList and Playlist interfaces were not implemented as we could not
> find any media players using them to test against.

**Properties**
- `trackAlbum`: string [readonly] — The current track's album, or `""` if none was provided.

  > [!TIP]
  > Use `player.trackAlbum || "Unknown Album"` to provide a message
  > when no album is available.
- `volumeSupported`: bool [readonly]
- `canGoNext`: bool [readonly]
- `canQuit`: bool [readonly]
- `shuffleSupported`: bool [readonly]
- `canSetFullscreen`: bool [readonly]
- `canPlay`: bool [readonly]
- `trackAlbumArtist`: string [readonly] — The current track's album artist, or `""` if none was provided.

  > [!TIP]
  > Use `player.trackAlbumArtist || "Unknown Album"` to provide a message
  > when no album artist is available.
- `uniqueId`: int [readonly] — An opaque identifier for the current track unique within the current player.

  > [!WARNING]
  > This is NOT `mpris:trackid` as that is sometimes missing or nonunique
  > in some players.
- `trackTitle`: string [readonly] — The title of the current track, or `""` if none was provided.

  > [!TIP]
  > Use `player.trackTitle || "Unknown Title"` to provide a message
  > when no title is available.
- `playbackState`: MprisPlaybackState — The playback state of the media player.

  - If `canPlay` is false, you cannot assign the `Playing` state.
  - If `canPause` is false, you cannot assign the `Paused` state.
  - If `canControl` is false, you cannot assign the `Stopped` state.
  (or any of the others, though their repsective properties will also be false)
- `maxRate`: real [readonly]
- `loopState`: MprisLoopState — The loop state of the media player, or `None` if `loopSupported` is false.

  May only be written to if `canControl` and `loopSupported` are true.
- `shuffle`: bool — If the play queue is currently being shuffled, or false if `shuffleSupported` is false.

  May only be written if `canControl` and `shuffleSupported` are true.
- `trackArtist`: string [readonly] — The current track's artist, or an `""` if none was provided.

  > [!TIP]
  > Use `player.trackArtist || "Unknown Artist"` to provide a message
  > when no artist is available.
- `desktopEntry`: string [readonly] — The name of the desktop entry for the media player, or an empty string if not provided.
- `canPause`: bool [readonly]
- `loopSupported`: bool [readonly]
- `minRate`: real [readonly]
- `canControl`: bool [readonly]
- `canGoPrevious`: bool [readonly]
- `canRaise`: bool [readonly]
- `fullscreen`: bool — If the player is currently shown in fullscreen.

  May only be written to if `canSetFullscreen` is true.
- `lengthSupported`: bool [readonly]
- `supportedUriSchemes`: list<string> [readonly] — Uri schemes supported by `openUri`.
- `positionSupported`: bool [readonly]
- `canTogglePlaying`: bool [readonly]
- `volume`: real — The volume of the playing track from 0.0 to 1.0, or 1.0 if `volumeSupported` is false.

  May only be written to if `canControl` and `volumeSupported` are true.
- `supportedMimeTypes`: list<string> [readonly] — Mime types supported by `openUri`.
- `rate`: real — The speed the song is playing at, as a multiplier.

  Only values between `minRate` and `maxRate` (inclusive) may be written to the property.
  Additionally, It is recommended that you only write common values such as `0.25`, `0.5`, `1.0`, `2.0`
  to the property, as media players are free to ignore the value, and are more likely to
  accept common ones.
- `trackArtists`: string [readonly] — > [!ERROR]
  > deprecated in favor of `trackArtist`.
- `metadata`:  [readonly] — Metadata of the current track.

  A map of common properties is available [here](https://www.freedesktop.org/wiki/Specifications/mpris-spec/metadata).
  Do not count on any of them actually being present.

  Note that the `trackTitle`, `trackAlbum`, `trackAlbumArtist`, `trackArtist` and `trackArtUrl`
  properties have extra logic to guard against bad players sending weird metadata, and should
  be used over grabbing the properties directly from the metadata.
- `position`: real — The current position in the playing track, as seconds, with millisecond precision,
  or `0` if `positionSupported` is false.

  May only be written to if `canSeek` and `positionSupported` are true.

  > [!WARNING]
  > To avoid excessive property updates wasting CPU while `position` is not
  > actively monitored, `position` usually will not update reactively, unless a nonlinear
  > change in position occurs, however reading it will always return the current position.
  >
  > If you want to actively monitor the position, the simplest way it to emit the `positionChanged`
  > signal manually for the duration you are monitoring it, Using a `FrameAnimation` if you need
  > the value to update smoothly, such as on a slider, or a `Timer` if not, as shown below.
  >
  > ```qml {filename="Using a FrameAnimation"}
  > FrameAnimation {
  >   // only emit the signal when the position is actually changing.
  >   running: player.playbackState == MprisPlaybackState.Playing
  >   // emit the positionChanged signal every frame.
  >   onTriggered: player.positionChanged()
  > }
  > ```
  >
  > ```qml {filename="Using a Timer"}
  > Timer {
  >   // only emit the signal when the position is actually changing.
  >   running: player.playbackState == MprisPlaybackState.Playing
  >   // Make sure the position updates at least once per second.
  >   interval: 1000
  >   repeat: true
  >   // emit the positionChanged signal every second.
  >   onTriggered: player.positionChanged()
  > }
  > ```
- `isPlaying`: bool — True if `playbackState` == `MprisPlaybackState.Playing`.

  Setting this property is equivalent to calling `play` or `pause`.
  You cannot set this property if `canTogglePlaying` is false.
- `dbusName`: string [readonly] — The DBus service name of the player.
- `trackArtUrl`: string [readonly] — The current track's art url, or `""` if none was provided.
- `identity`: string [readonly] — The human readable name of the media player.
- `length`: real [readonly] — The length of the playing track, as seconds, with millisecond precision,
  or the value of `position` if `lengthSupported` is false.
- `canSeek`: bool [readonly]

**Functions**
- `next()`: void — Play the next song.

  May only be called if `canGoNext` is true.
- `openUri(uri: string)`: void — Open the given URI in the media player.

  Many players will silently ignore this, especially if the uri
  does not match `supportedUriSchemes` and `supportedMimeTypes`.
- `pause()`: void — Equivalent to setting `playbackState` to `Paused`.
- `play()`: void — Equivalent to setting `playbackState` to `Playing`.
- `previous()`: void — Play the previous song, or go back to the beginning of the current one.

  May only be called if `canGoPrevious` is true.
- `quit()`: void — Quit the media player.

  May only be called if `canQuit` is true.
- `raise()`: void — Bring the media player to the front of the window stack.

  May only be called if `canRaise` is true.
- `seek(offset: real)`: void — Change `position` by an offset.

  Even if `positionSupported` is false and you cannot set `position`,
  this function may work.

  May only be called if `canSeek` is true.
- `stop()`: void — Equivalent to setting `playbackState` to `Stopped`.
- `togglePlaying()`: void — Equivalent to calling `play` if not playing or `pause` if playing.

  May only be called if `canTogglePlaying` is true, which is equivalent to
  `canPlay` or `canPause` depending on the current playback state.

**Signals**
- `postTrackChanged()` — handler `onPostTrackChanged` — Sent after track info related properties have been updated, following `trackChanged`.

  > [!WARNING]
  > It is not safe to assume all track information is up to date after
  > this signal is emitted. A large number of players will update track information,
  > particularly `trackArtUrl`, slightly after this signal.
- `trackChanged()` — handler `onTrackChanged` — The track has changed.

  All track information properties that were sent by the player
  will be updated immediately following this signal. `postTrackChanged`
  will be sent after they update.

  Track information properties: `uniqueId`, `metadata`, `trackTitle`,
  `trackArtist`, `trackAlbum`, `trackAlbumArtist`, `trackArtUrl`

  > [!WARNING]
  > Some particularly poorly behaved players will update metadata
  > *before* indicating the track has changed.
