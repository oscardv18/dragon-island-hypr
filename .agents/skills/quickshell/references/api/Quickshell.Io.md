# Quickshell.Io

`import Quickshell.Io`

Io types

## DataStream
*class* · extends `QtObject` · uncreatable (obtained from other objects)

See also: `DataStreamParser`

**Properties**
- `parser`: DataStreamParser — The parser to stream data from this source into.
  If the parser is null no data will be read.

## DataStreamParser
*class* · extends `QtObject` · uncreatable (obtained from other objects)

See also: `DataStream`, `SplitParser`.

**Signals**
- `read(data: string)` — handler `onRead` — Emitted when data is read from the stream.

## FileView
*class* · extends `QtObject`

A reader for small to medium files that don't need seeking/cursor access,
suitable for most text files.

#### Example: Reading a JSON as text
```qml
FileView {
  id: jsonFile
  path: Qt.resolvedUrl("./your.json")
  // Forces the file to be loaded by the time we call JSON.parse().
  // see blockLoading's property documentation for details.
  blockLoading: true
}

readonly property var jsonData: JSON.parse(jsonFile.text())
```

Also see `JsonAdapter` for an alternative way to handle reading and writing JSON files.

**Properties**
- `adapter`: FileViewAdapter [default] — In addition to directly reading/writing the file as text, *adapters* can be used to
  expose a file's content in new ways.

  An adapter will automatically be given the loaded file's content.
  Its state may be saved with `writeAdapter`.

  Currently the only adapter is `JsonAdapter`.
- `blockAllReads`: bool — If `text` and `data` should block all operations while a file loads. Defaults to false.

  This is nearly identical to `blockLoading`, but will additionally block when
  a file is loaded and `path` changes.

  > [!WARNING]
  > We cannot think of a valid use case for this.
  > You almost definitely want `blockLoading`.
- `atomicWrites`: bool — If true (default), all calls to `setText` or `setData` will be performed atomically,
  meaning if the write fails for any reason, the file will not be modified.

  > [!NOTE]
  > This works by creating another file with the desired content, and renaming
  > it over the existing file if successful.
- `path`: string — The path to the file that should be read, or an empty string to unload the file.
- `preload`: bool — If the file should be loaded in the background immediately when set. Defaults to true.

  This may either increase or decrease the amount of time it takes to load the file
  depending on how large the file is, how fast its storage is, and how you access its data.
- `printErrors`: bool — If true (default), read or write errors will be printed to the quickshell logs.
  If false, all known errors will not be printed.
- `watchChanges`: bool — If true (defaule false), `fileChanged` will be called whenever the content of the file
  changes on disk, including when `setText` or `setData` are used.

  > [!NOTE]
  > You can reload the file's content whenever it changes on disk like so:
  > ```qml
  > FileView {
  >   // ...
  >   watchChanges: true
  >   onFileChanged: this.reload()
  > }
  > ```
- `blockLoading`: bool — If `text` and `data` should block all operations until the file is loaded. Defaults to false.

  If the file is already loaded, no blocking will occur.
  If a file was loaded, and `path` was changed to a new file, no blocking will occur.

  > [!WARNING]
  > Blocking operations should be used carefully to avoid stutters and other performance
  > degradations. Blocking means that your interface **WILL NOT FUNCTION** during the call.
  >
  > **We recommend you use a blocking load ONLY for files loaded before the windows of your shell
  > are loaded, which happens after `Component.onCompleted` runs for the root component of your shell.**
  >
  > The most reasonable use case would be to load things like configuration files that the program
  > must have available.
- `blockWrites`: bool — If true (default false), all calls to `setText` or `setData` will block the
  UI thread until the write succeeds or fails.

  > [!WARNING]
  > Blocking operations should be used carefully to avoid stutters and other performance
  > degradations. Blocking means that your interface **WILL NOT FUNCTION** during the call.
- `loaded`: bool [readonly] — If a file is currently loaded, which may or may not be the one currently specified by `path`.

  > [!NOTE]
  > If a file is loaded, `path` is changed, and a new file is loaded,
  > this property will stay true the whole time.
  > If `path` is set to an empty string to unload the file it will become false.

**Functions**
- `data()`:  — Returns the data of the file specified by `path` as an [ArrayBuffer].

  If `blockAllReads` is true, all changes to `path` will cause the program to block
  when this function is called.

  If `blockLoading` is true, reading this property before the file has been loaded
  will block, but changing `path` or calling `reload` will return the old data
  until the load completes.

  If neither is true, an empty buffer will be returned if no file is loaded,
  otherwise it will behave as in the case above.

  > [!NOTE]
  > Due to technical limitations, `data` could not be a property,
  > however you can treat it like a property, it will trigger property updates
  > as a property would, and the signal `dataChanged()` is present.

  [ArrayBuffer]: https://developer.mozilla.org/en-US/docs/Web/JavaScript/Reference/Global_Objects/ArrayBuffer
- `reload()`: void — Unload the loaded file and reload it, usually in response to changes.

  This will not block if `blockLoading` is set, only if `blockAllReads` is true.
  It acts the same as changing `path` to a new file, except loading the same file.
- `setData(data: )`: void — Sets the content of the file specified by `path` as an [ArrayBuffer].

  `atomicWrites` and `blockWrites` affect the behavior of this function.

  `saved` or `saveFailed` will be emitted on completion.
- `setText(text: string)`: void — Sets the content of the file specified by `path` as text.

  `atomicWrites` and `blockWrites` affect the behavior of this function.

  `saved` or `saveFailed` will be emitted on completion.

  [ArrayBuffer]: https://developer.mozilla.org/en-US/docs/Web/JavaScript/Reference/Global_Objects/ArrayBuffer
- `text()`: string — Returns the data of the file specified by `path` as text.

  If `blockAllReads` is true, all changes to `path` will cause the program to block
  when this function is called.

  If `blockLoading` is true, reading this property before the file has been loaded
  will block, but changing `path` or calling `reload` will return the old data
  until the load completes.

  If neither is true, an empty string will be returned if no file is loaded,
  otherwise it will behave as in the case above.

  > [!NOTE]
  > Due to technical limitations, `text` could not be a property,
  > however you can treat it like a property, it will trigger property updates
  > as a property would, and the signal `textChanged()` is present.
- `waitForJob()`: bool — Block all operations until the currently running load completes.

  > [!WARNING]
  > See `blockLoading` for an explanation and warning about blocking.
- `writeAdapter()`: void — Write the content of the current `adapter` to the selected file.

**Signals**
- `saved()` — handler `onSaved` — Emitted if the file was saved successfully.
- `adapterUpdated()` — handler `onAdapterUpdated` — Emitted when the active `adapter`'s data is changed.
- `saveFailed(error: FileViewError)` — handler `onSaveFailed` — Emitted if the file failed to save.
- `fileChanged()` — handler `onFileChanged` — Emitted if the file changes on disk and `watchChanges` is true.
- `loadFailed(error: FileViewError)` — handler `onLoadFailed` — Emitted if the file failed to load.
- `loaded()` — handler `onLoaded` — Emitted if the file was loaded successfully.

## FileViewAdapter
*class* · extends `QtObject` · uncreatable (obtained from other objects)

See `FileView.adapter`.

**Signals**
- `adapterUpdated()` — handler `onAdapterUpdated` — This signal is fired when data in the adapter changes, and triggers `FileView.adapterUpdated`.

## FileViewError
*enum* · extends `QtObject`

**Functions**
- `toString(value: FileViewError)`: string

**Values:** `FileViewError.PermissionDenied`, `FileViewError.FileNotFound`, `FileViewError.Success`, `FileViewError.Unknown`, `FileViewError.NotAFile`

## IpcHandler
*class* · extends `QtObject`

Each IpcHandler is registered into a per-instance map by its unique `target`.
Functions and properties defined on the IpcHandler can be accessed via `qs ipc`.

#### Handler Functions
IPC handler functions can be called by `qs ipc call` as long as they have at most 10
arguments, and all argument types along with the return type are listed below.

**Argument and return types must be explicitly specified or they will not
be registered.**

##### Arguments
- `string` will be passed to the parameter as is.
- `int` will only accept parameters that can be parsed as an integer.
- `bool` will only accept parameters that are "true", "false", or an integer,
  where 0 will be converted to false, and anything else to true.
- `real` will only accept parameters that can be parsed as a number with
  or without a decimal.
- `color` will accept [named colors] or hex strings (RGB, RRGGBB, AARRGGBB) with
  an optional `#` prefix.

[named colors]: https://doc.qt.io/qt-6/qml-color.html#svg-color-reference

##### Return Type
- `void` will return nothing.
- `string` will be returned as is.
- `int` will be converted to a string and returned.
- `bool` will be converted to "true" or "false" and returned.
- `real` will be converted to a string and returned.
- `color` will be converted to a hex string in the form `#AARRGGBB` and returned.

#### Signals
IPC handler signals can be observed remotely using `qs ipc wait` (one call)
and `qs ipc listen` (many calls). IPC signals may have zero or one argument, where
the argument is one of the types listed above, or no arguments for void.

#### Example
The following example creates ipc functions to control and retrieve the appearance
of a Rectangle.

```qml
FloatingWindow {
  Rectangle {
    id: rect
    anchors.centerIn: parent
    width: 100
    height: 100
    color: "red"
  }

  IpcHandler {
    target: "rect"

    function setColor(color: color): void { rect.color = color; }
    function getColor(): color { return rect.color; }

    function setAngle(angle: real): void { rect.rotation = angle; }
    function getAngle(): real { return rect.rotation; }

    function setRadius(radius: int): void {
      rect.radius = radius;
      this.radiusChanged(radius);
    }

    function getRadius(): int { return rect.radius; }

    signal radiusChanged(newRadius: int);
  }
}
```
The list of registered targets can be inspected using `qs ipc show`.
```sh
$ qs ipc show
target rect
  function setColor(color: color): void
  function getColor(): color
  function setAngle(angle: real): void
  function getAngle(): real
  function setRadius(radius: int): void
  function getRadius(): int
  signal radiusChanged(newRadius: int)
```

and then invoked using `qs ipc call`.
```sh
$ qs ipc call rect setColor orange
$ qs ipc call rect setAngle 40.5
$ qs ipc call rect setRadius 30
$ qs ipc call rect getColor
#ffffa500
$ qs ipc call rect getAngle
40.5
$ qs ipc call rect getRadius
30
```

#### Properties
Properties of an IpcHanlder can be read using `qs ipc prop get` as long as they are
of an IPC compatible type. See the table above for compatible types.

**Properties**
- `enabled`: bool — If the handler should be able to receive calls. Defaults to true.
- `target`: string — The target this handler should be accessible from.
  Required and must be unique. May be changed at runtime.

## JsonAdapter
*class* · extends `FileViewAdapter`

JsonAdapter is a `FileView` adapter that exposes a JSON file as a set of QML
properties that can be read and written to.

Each property defined in a JsonAdapter corresponds to a key in the JSON file.
Supported property types are:
- Primitves (`int`, `bool`, `string`, `real`)
- Sub-object adapters (`JsonObject`)
- JSON objects and arrays, as a `var` type
- Lists of any of the above (`list<string>` etc)

When the `FileView`'s data is loaded, properties of a JsonAdapter or
sub-object adapter (`JsonObject`) are updated if their values have changed.

When properties of a JsonAdapter or sub-object adapter are changed from QML,
`FileView.adapterUpdated` is emitted, which may be used to save the file's new
state (see `FileView.writeAdapter`).

### Example
```qml
FileView {
  path: "/path/to/file"

  // when changes are made on disk, reload the file's content
  watchChanges: true
  onFileChanged: reload()

  // when changes are made to properties in the adapter, save them
  onAdapterUpdated: writeAdapter()

  JsonAdapter {
    property string myStringProperty: "default value"
    onMyStringPropertyChanged: {
      console.log("myStringProperty was changed via qml or on disk")
    }

    property list<string> stringList: [ "default", "value" ]

    property JsonObject subObject: JsonObject {
      property string subObjectProperty: "default value"
      onSubObjectPropertyChanged: console.log("same as above")
    }

    // works the same way as subObject
    property var inlineJson: { "a": "b" }
  }
}
```

The above snippet produces the JSON document below:
```json
{
   "myStringProperty": "default value",
   "stringList": [
     "default",
     "value"
   ],
   "subObject": {
     "subObjectProperty": "default value"
   },
   "inlineJson": {
     "a": "b"
   }
}
```

## JsonObject
*class* · extends `QtObject`

See `JsonAdapter`.

## Process
*class* · extends `QtObject`

#### Example
```qml
Process {
  running: true
  command: [ "some-command", "arg" ]
  stdout: StdioCollector {
    onStreamFinished: console.log(`line read: ${this.text}`)
  }
}
```

**Properties**
- `stdinEnabled`: bool — If stdin is enabled. Defaults to false. If this property is false the process's stdin channel
  will be closed and `write` will do nothing, even if set back to true.
- `clearEnvironment`: bool — If the process's environment should be cleared prior to applying `environment`.
  Defaults to false.

  If true, all environment variables will be removed before the `environment`
  object is applied, meaning the variables listed will be the only ones visible to the process.
  This changes the behavior of `null` to pass in the system value of the variable if present instead
  of removing it.

  ```qml
  clearEnvironment: true
  environment: ({
    ADDED: "value",
    PASSED_FROM_SYSTEM: null,
  })
  ```

  If the process is already running changing this property will affect the next
  started process. If the property has been changed after starting a process it will
  return the new value, not the one for the currently running process.
- `running`: bool — If the process is currently running. Defaults to false.

  Setting this property to true will start the process if command has at least
  one element.
  Setting it to false will send SIGTERM. To immediately kill the process,
  use `signal` with SIGKILL. The process will be killed when
  quickshell dies.

  If you want to run the process in a loop, use the onRunningChanged signal handler
  to restart the process.
  ```qml
  Process {
    running: true
    onRunningChanged: if (!running) running = true
  }
  ```

  > [!NOTE]
  > See `startDetached` to prevent the process from being killed by Quickshell
  > if Quickshell is killed or the configuration is reloaded.
- `workingDirectory`: string — The working directory of the process. Defaults to [quickshell's working directory].

  If the process is already running changing this property will affect the next
  started process. If the property has been changed after starting a process it will
  return the new value, not the one for the currently running process.

  [quickshell's working directory]: ../../quickshell/quickshell#prop.workingDirectory
- `environment`:  — Environment of the executed process.

  This is a javascript object (json). Environment variables can be added by setting
  them to a string and removed by setting them to null (except when `clearEnvironment` is true,
  in which case this behavior is inverted, see `clearEnvironment` for details).


  ```qml
  environment: ({
    ADDED: "value",
    REMOVED: null,
    "i'm different": "value",
  })
  ```

  > [!NOTE]
  > You need to wrap the returned object in () otherwise it won't parse due to javascript ambiguity.

  If the process is already running changing this property will affect the next
  started process. If the property has been changed after starting a process it will
  return the new value, not the one for the currently running process.
- `command`: list<string> — The command to execute. Each argument is its own string, which means you don't have
  to deal with quoting anything.

  If the process is already running changing this property will affect the next
  started process. If the property has been changed after starting a process it will
  return the new value, not the one for the currently running process.

  > [!WARNING]
  > This does not run command in a shell. All arguments to the command
  > must be in separate values in the list, e.g. `["echo", "hello"]`
  > and not `["echo hello"]`.
  >
  > Additionally, shell scripts must be run by your shell,
  > e.g. `["sh", "script.sh"]` instead of `["script.sh"]` unless the script
  > has a shebang.

  > [!NOTE]
  > You can use `["sh", "-c", <your command>]` to execute your command with
  > the system shell.
- `stderr`: DataStreamParser — The parser for stderr. If the parser is null the process's stdout channel will be closed
  and no further data will be read, even if a new parser is attached.
- `processId`: variant [readonly] — The process ID of the running process or `null` if `running` is false.
- `stdout`: DataStreamParser — The parser for stdout. If the parser is null the process's stdout channel will be closed
  and no further data will be read, even if a new parser is attached.

**Functions**
- `exec(context: )`: void — Launch a process with the given arguments, stopping any currently running process.

  The context parameter can either be a list of command arguments or a JS object with the following fields:
  - `command`: A list containing the command and all its arguments. See `Process.command`.
  - `environment`: Changes to make to the process environment. See `Process.environment`.
  - `clearEnvironment`: Removes all variables from the environment if true.
  - `workingDirectory`: The working directory the command should run in.

  Passed parameters will change the values currently set in the process.

  > [!WARNING]
  > This does not run command in a shell. All arguments to the command
  > must be in separate values in the list, e.g. `["echo", "hello"]`
  > and not `["echo hello"]`.
  >
  > Additionally, shell scripts must be run by your shell,
  > e.g. `["sh", "script.sh"]` instead of `["script.sh"]` unless the script
  > has a shebang.

  > [!NOTE]
  > You can use `["sh", "-c", <your command>]` to execute your command with
  > the system shell.

  Calling this function is equivalent to running:
  ```qml
  process.running = false;
  process.command = ...
  process.environment = ...
  process.clearEnvironment = ...
  process.workingDirectory = ...
  process.running = true;
  ```
- `signal(signal: int)`: void — Sends a signal to the process if `running` is true, otherwise does nothing.
- `startDetached()`: void — Launches an instance of the process detached from Quickshell.

  The subprocess will not be tracked, `running` will be false,
  and the subprocess will not be killed by Quickshell.

  This function is equivalent to `Quickshell.execDetached`.
- `write(data: string)`: void — Writes to the process's stdin. Does nothing if `running` is false.

**Signals**
- `started()` — handler `onStarted`
- `exited(exitCode: int, exitStatus: )` — handler `onExited`

## Socket
*class* · extends `DataStream`

Unix socket listener.

**Properties**
- `connected`: bool — Returns if the socket is currently connected.

  Writing to this property will set the target connection state and will not
  update the property immediately. Setting the property to false will begin disconnecting
  the socket, and setting it to true will begin connecting the socket if path is not empty.
- `path`: string — The path to connect this socket to when `connected` is set to true.

  Changing this property will have no effect while the connection is active.

**Functions**
- `flush()`: void — Flush any queued writes to the socket.
- `write(data: string)`: void — Write data to the socket. Does nothing if not connected.

  Remember to call flush after your last write.

**Signals**
- `error(error: )` — handler `onError` — This signal is sent whenever a socket error is encountered.

## SocketServer
*class* · extends `Reloadable`

#### Example
```qml
SocketServer {
  active: true
  path: "/path/too/socket.sock"
  handler: Socket {
    onConnectedChanged: {
      console.log(connected ? "new connection!" : "connection dropped!")
    }
    parser: SplitParser {
      onRead: message => console.log(`read message from socket: ${message}`)
    }
  }
}
```

**Properties**
- `active`: bool — If the socket server is currently active. Defaults to false.

  Setting this to false will destroy all active connections and delete
  the socket file on disk.

  If path is empty setting this property will have no effect.
- `path`: string — The path to create the socket server at.

  Setting this property while the server is active will have no effect.
- `handler`: Component — Connection handler component. Must create a `Socket`.

  The created socket should not set `connected` or `path` or the incoming
  socket connection will be dropped (they will be set by the socket server.)
  Setting `connected` to false on the created socket after connection will
  close and delete it.

## SplitParser
*class* · extends `DataStreamParser`

DataStreamParser for delimited data streams. `DataStreamParser.read` is emitted once per delimited chunk of the stream.

**Properties**
- `splitMarker`: string — The delimiter for parsed data. May be multiple characters. Defaults to `\n`.

  If the delimiter is empty read lengths may be arbitrary (whatever is returned by the
  underlying read call.)

## StdioCollector
*class* · extends `DataStreamParser`

StdioCollector collects all process output into a buffer exposed as `text` or `data`.

**Properties**
- `waitForEnd`: bool — If true, `text` and `data` will not be updated until the stream ends. Defaults to true.
- `data`:  [readonly] — The stdio buffer exposed as an [ArrayBuffer]. if `waitForEnd` is true, this will not change
  until the stream ends.

  [ArrayBuffer]: https://developer.mozilla.org/en-US/docs/Web/JavaScript/Reference/Global_Objects/ArrayBuffer
- `text`: string [readonly] — The stdio buffer exposed as text. if `waitForEnd` is true, this will not change
  until the stream ends.

**Signals**
- `streamFinished()` — handler `onStreamFinished`
