# Quickshell.Services.Greetd

`import Quickshell.Services.Greetd`

Greetd integration

## Greetd
*singleton* · extends `QtObject`

This object provides access to a running greetd instance if present.
With it you can authenticate a user and launch a session.

See [the greetd wiki] for instructions on how to set up a graphical greeter.

[the greetd wiki]: https://man.sr.ht/~kennylevinsen/greetd/#setting-up-greetd-with-gtkgreet

**Properties**
- `available`: bool [readonly] — If the greetd socket is available.
- `state`: GreetdState [readonly] — The current state of the greetd connection.
- `user`: string [readonly] — The currently authenticating user.

**Functions**
- `cancelSession()`: void — Cancel the active greetd session.
- `createSession(user: string)`: void — Create a greetd session for the given user.
- `launch(command: list<string>)`: void — Launch the session, exiting quickshell.
  `state` must be `GreetdState.ReadyToLaunch` to call this function.
- `launch(command: list<string>, environment: list<string>)`: void — Launch the session, exiting quickshell.
  `state` must be `GreetdState.ReadyToLaunch` to call this function.
- `launch(command: list<string>, environment: list<string>, quit: bool)`: void — Launch the session, exiting quickshell if `quit` is true.
  `state` must be `GreetdState.ReadyToLaunch` to call this function.

  The `launched` signal can be used to perform an action after greetd has acknowledged
  the desired session.

  > [!WARNING]
  > Note that greetd expects the greeter to terminate as soon as possible
  > after setting a target session, and waiting too long may lead to unexpected behavior
  > such as the greeter restarting.
  >
  > Performing animations and such should be done *before* calling `launch`.
- `respond(response: string)`: void — Respond to an authentication message.

  May only be called in response to an `authMessage` with `responseRequired` set to true.

**Signals**
- `launched()` — handler `onLaunched` — Greetd has acknowledged the launch request and the greeter should quit as soon as possible.

  This signal is sent right before quickshell exits automatically if the launch was not specifically
  requested not to exit. You usually don't need to use this signal.
- `authFailure(message: string)` — handler `onAuthFailure` — Authentication has failed an the session has terminated.

  Usually this is something like a timeout or a failed password entry.
- `error(error: string)` — handler `onError` — Greetd has encountered an error.
- `readyToLaunch()` — handler `onReadyToLaunch` — Authentication has finished successfully and greetd can now launch a session.
- `authMessage(message: string, error: bool, responseRequired: bool, echoResponse: bool)` — handler `onAuthMessage` — An authentication message has been sent by greetd.
  - `message` - the text of the message
  - `error` - if the message should be displayed as an error
  - `responseRequired` - if a response via `respond()` is required for this message
  - `echoResponse` - if the response should be displayed in clear text to the user

  Note that `error` and `responseRequired` are mutually exclusive.

  Errors are sent through `authMessage` when they are recoverable, such as a fingerprint scanner
  not being able to read a finger correctly, while definite failures such as a bad password are
  sent through `authFailure`.

## GreetdState
*enum* · extends `QtObject`

See `Greetd.state`.

**Functions**
- `toString(value: GreetdState)`: string

**Values:** `GreetdState.Launching`, `GreetdState.Authenticating`, `GreetdState.Inactive`, `GreetdState.ReadyToLaunch`, `GreetdState.Launched`
