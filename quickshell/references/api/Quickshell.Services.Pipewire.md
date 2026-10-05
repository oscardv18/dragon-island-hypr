# Quickshell.Services.Pipewire

`import Quickshell.Services.Pipewire`

Pipewire API

## Pipewire
*singleton* · extends `QtObject`

Contains links to all pipewire objects.

**Properties**
- `ready`: bool [readonly] — This property is true if quickshell has completed its initial sync with
  the pipewire server. If true, nodes, links and sync/source preferences will be
  in a good state.

  > [!NOTE]
  > You can use the pipewire object before it is ready, but some nodes/links
  > may be missing, and preference metadata may be null.
- `links`: ObjectModel<PwLink> [readonly] — All links present in pipewire.

  Links connect pipewire nodes to each other, and can be used to determine
  their relationship.

  If you already have a node you want to check for connections to,
  use `PwNodeLinkTracker` instead of filtering this list.

  > [!NOTE]
  > Multiple links may exist between the same nodes. See `linkGroups`
  > for a deduplicated list containing only one entry per link between nodes.
- `linkGroups`: ObjectModel<PwLinkGroup> [readonly] — All link groups present in pipewire.

  The same as `links` but deduplicated.

  If you already have a node you want to check for connections to,
  use `PwNodeLinkTracker` instead of filtering this list.
- `preferredDefaultAudioSink`: PwNode — The preferred default audio sink (output) or `null`.

  This is a hint to pipewire telling it which sink should be the default when possible.
  `defaultAudioSink` may differ when it is not possible for pipewire to pick this node.

  See `defaultAudioSink` for the current default sink, regardless of preference.
- `preferredDefaultAudioSource`: PwNode — The preferred default audio source (input) or `null`.

  This is a hint to pipewire telling it which source should be the default when possible.
  `defaultAudioSource` may differ when it is not possible for pipewire to pick this node.

  See `defaultAudioSource` for the current default source, regardless of preference.
- `defaultAudioSink`: PwNode [readonly] — The default audio sink (output) or `null`.

  This is the default sink currently in use by pipewire, and the one applications
  are currently using.

  To set the default sink, use `preferredDefaultAudioSink`.

  > [!NOTE]
  > When the default sink changes, this property may breifly become null.
  > This depends on your hardware.
- `defaultAudioSource`: PwNode [readonly] — The default audio source (input) or `null`.

  This is the default source currently in use by pipewire, and the one applications
  are currently using.

  To set the default source, use `preferredDefaultAudioSource`.

  > [!NOTE]
  > When the default source changes, this property may breifly become null.
  > This depends on your hardware.
- `nodes`: ObjectModel<PwNode> [readonly] — All nodes present in pipewire.

  This list contains every node on the system.
  To find a useful subset, filtering with the following properties may be helpful:
  - `PwNode.isStream` - if the node is an application or hardware device.
  - `PwNode.isSink` - if the node is a sink or source.
  - `PwNode.audio` - if non null the node is an audio node.

## PwAudioChannel
*enum* · extends `QtObject`

See `PwNodeAudio.channels`.

**Functions**
- `toString(value: PwAudioChannel)`: string — Print a human readable representation of the given channel,
  including aux and custom channel ranges.

**Values:** `PwAudioChannel.FrontRightCenter`, `PwAudioChannel.LowFrequencyEffectsRight`, `PwAudioChannel.TopFrontRight`, `PwAudioChannel.FrontRight`, `PwAudioChannel.SideRight`, `PwAudioChannel.TopRearCenter`, `PwAudioChannel.AuxRangeStart`, `PwAudioChannel.LowFrequencyEffects`, `PwAudioChannel.FrontCenter`, `PwAudioChannel.TopSideLeft`, `PwAudioChannel.SideLeft`, `PwAudioChannel.RearLeftCenter`, `PwAudioChannel.Mono`, `PwAudioChannel.BottomRightCenter`, `PwAudioChannel.LowFrequencyEffectsLeft`, `PwAudioChannel.FrontLeftWide`, `PwAudioChannel.Unknown`, `PwAudioChannel.TopFrontLeftCenter`, `PwAudioChannel.TopFrontCenter`, `PwAudioChannel.TopFrontLeft`, `PwAudioChannel.FrontRightWide`, `PwAudioChannel.TopRearLeft`, `PwAudioChannel.RearLeft`, `PwAudioChannel.FrontRightHigh`, `PwAudioChannel.TopSideRight`, `PwAudioChannel.BottomCenter`, `PwAudioChannel.FrontCenterHigh`, `PwAudioChannel.RearCenter`, `PwAudioChannel.RearRightCenter`, `PwAudioChannel.FrontLeftHigh`, `PwAudioChannel.CustomRangeStart`, `PwAudioChannel.TopRearRight`, `PwAudioChannel.NA`, `PwAudioChannel.FrontLeft`, `PwAudioChannel.FrontLeftCenter`, `PwAudioChannel.LowFrequencyEffects2`, `PwAudioChannel.RearRight`, `PwAudioChannel.TopFrontRightCenter`, `PwAudioChannel.TopCenter`, `PwAudioChannel.AuxRangeEnd`, `PwAudioChannel.BottomLeftCenter`

## PwLink
*class* · extends `QtObject` · uncreatable (obtained from other objects)

Note that there is one link per *channel* of a connection between nodes.
You usually want `PwLinkGroup`.

**Properties**
- `state`: PwLinkState [readonly] — The current state of the link.

  > [!WARNING]
  > This property is invalid unless the node is bound using `PwObjectTracker`.
- `id`: int [readonly] — The pipewire object id of the link.

  Mainly useful for debugging. you can inspect the link directly
  with `pw-cli i <id>`.
- `source`: PwNode [readonly] — The node that is *sending* information. (the source)
- `target`: PwNode [readonly] — The node that is *receiving* information. (the sink)

## PwLinkGroup
*class* · extends `QtObject` · uncreatable (obtained from other objects)

A group of connections between pipewire nodes, one per source->target pair.

**Properties**
- `state`: PwLinkState [readonly] — The current state of the link group.

  > [!WARNING]
  > This property is invalid unless the node is bound using `PwObjectTracker`.
- `source`: PwNode [readonly] — The node that is *sending* information. (the source)
- `target`: PwNode [readonly] — The node that is *receiving* information. (the sink)

## PwLinkState
*enum* · extends `QtObject`

See `PwLink.state`.

**Functions**
- `toString(value: PwLinkState)`: string

**Values:** `PwLinkState.Unlinked`, `PwLinkState.Allocating`, `PwLinkState.Negotiating`, `PwLinkState.Init`, `PwLinkState.Active`, `PwLinkState.Error`, `PwLinkState.Paused`

## PwNode
*class* · extends `QtObject` · uncreatable (obtained from other objects)

A node in the pipewire connection graph.

**Properties**
- `nickname`: string [readonly] — The node's nickname, corresponding to the object's `node.nickname` property.

  May be empty. Generally but not always more human readable than `description`.
- `isStream`: bool [readonly] — If `true` then the node is likely to be a program, if `false` it is likely to be
  a hardware device.
- `description`: string [readonly] — The node's description, corresponding to the object's `node.description` property.

  May be empty. Generally more human readable than `name`.
- `id`: int [readonly] — The pipewire object id of the node.

  Mainly useful for debugging. You can inspect the node directly
  with `pw-cli i <id>`.
- `isSink`: bool [readonly] — If `true`, then the node accepts audio input from other nodes,
  if `false` the node outputs audio to other nodes.
- `properties`:  [readonly] — The property set present on the node, as an object containing key-value pairs.
  You can inspect this directly with `pw-cli i <id>`.

  A few properties of note, which may or may not be present:
  - `application.name` - A suggested human readable name for the node.
  - `application.icon-name` - The name of an icon recommended to display for the node.
  - `media.name` - A description of the currently playing media.
    (more likely to be present than `media.title` and `media.artist`)
  - `media.title` - The title of the currently playing media.
  - `media.artist` - The artist of the currently playing media.

  > [!WARNING]
  > This property is invalid unless the node is bound using `PwObjectTracker`.
- `name`: string [readonly] — The node's name, corresponding to the object's `node.name` property.
- `ready`: bool [readonly] — True if the node is fully bound and ready to use.

  > [!NOTE]
  > The node may be used before it is fully bound, but some data
  > may be missing or incorrect.
- `type`:  [readonly] — The type of this node. Reflects Pipewire's [media.class](https://docs.pipewire.org/page_man_pipewire-props_7.html).
- `audio`: PwNodeAudio [readonly] — Extra information present only if the node sends or receives audio.

  The presence or absence of this property can be used to determine if a node
  manages audio, regardless of if it is bound. If non null, the node is an audio node.

## PwNodeAudio
*class* · extends `QtObject` · uncreatable (obtained from other objects)

Extra properties of a `PwNode` if the node is an audio node.

See `PwNode.audio`.

**Properties**
- `volume`: real — The average volume over all channels of the node.
  Setting this property modifies the volume of all channels proportionately.

  > [!WARNING]
  > This property is invalid unless the node is bound using `PwObjectTracker`.
- `volumes`: list<real> — The volumes of each audio channel individually. Each entry corresponds to
  the volume of the channel at the same index in `channels`. `volumes` and `channels`
  will always be the same length.

  > [!WARNING]
  > This property is invalid unless the node is bound using `PwObjectTracker`.
- `channels`: list<PwAudioChannel> [readonly] — The audio channels present on the node.

  > [!WARNING]
  > This property is invalid unless the node is bound using `PwObjectTracker`.
- `muted`: bool — If the node is currently muted. Setting this property changes the mute state.

  > [!WARNING]
  > This property is invalid unless the node is bound using `PwObjectTracker`.

## PwNodeLinkTracker
*class* · extends `QtObject`

Tracks non-monitor link connections to a given node.

**Properties**
- `linkGroups`: list<PwLinkGroup> [readonly] — Link groups connected to the given node, excluding monitors.

  If the node is a sink, links which target the node will be tracked.
  If the node is a source, links which source the node will be tracked.
- `node`: PwNode — The node to track connections to.

## PwNodePeakMonitor
*class* · extends `QtObject`

Tracks volume peaks for a node across all its channels.

The peak monitor binds nodes similarly to `PwObjectTracker` when enabled.

**Properties**
- `enabled`: bool — If true, the monitor is actively capturing and computing peaks. Defaults to true.
- `peak`: real [readonly] — Maximum value of `peaks`.
- `node`: PwNode — The node to monitor. Must be an audio node.
- `peaks`: list<real> [readonly] — Per-channel peak noise levels (0.0-1.0). Length matches `channels`.

  The channel's volume does not affect this property.
- `channels`: list<PwAudioChannel> [readonly] — Channel positions for the captured format. Length matches `peaks`.

## PwNodeType
*singleton* · extends `QtObject`

Use bitwise comparisons to filter for audio, video, sink, source or stream nodes

**Functions**
- `toString(type: )`: string

## PwObjectTracker
*class* · extends `QtObject`

PwObjectTracker binds every node given in its `objects` list.

#### Object Binding
By default, pipewire objects are unbound. Unbound objects only have a subset of
information available for use or modification. **Binding an object makes all of its
properties available for use or modification if applicable.**

Properties that require their object be bound to use are clearly marked. You do not
need to bind the object unless mentioned in the description of the property you
want to use.

**Properties**
- `objects`: list<QtObject> — The list of objects to bind. May contain nulls.
