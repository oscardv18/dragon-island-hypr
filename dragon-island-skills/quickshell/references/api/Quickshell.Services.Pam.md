# Quickshell.Services.Pam

`import Quickshell.Services.Pam`

Pam authentication

## PamContext
*class* · extends `QtObject`

Connection to pam. See [the module documentation](../) for pam configuration advice.

**Properties**
- `messageIsError`: bool [readonly] — If the last message should be shown as an error.
- `responseVisible`: bool [readonly] — If the user's response should be visible. Only valid when `responseRequired` is true.
- `message`: string [readonly] — The last message sent by pam.
- `user`: string — The user to authenticate as. If unset the current user will be used.

  This property may not be set while `active` is true.
- `active`: bool — If the pam context is actively performing an authentication.

  Setting this value behaves exactly the same as calling `start` and `abort`.
- `configDirectory`: string — The pam configuration directory to use. Defaults to "/etc/pam.d".

  The configuration directory is resolved relative to the current file if not an absolute path.

  On FreeBSD this property is ignored as the pam configuration directory cannot be changed.

  This property may not be set while `active` is true.
- `responseRequired`: bool [readonly] — If pam currently wants a response.

  Responses can be returned with the `respond` function.
- `config`: string — The pam configuration to use. Defaults to "login".

  The configuration should name a file inside `configDirectory`.

  This property may not be set while `active` is true.

**Functions**
- `abort()`: void — Abort a running authentication session.
- `respond(response: string)`: void — Respond to pam.

  May not be called unless `responseRequired` is true.
- `start()`: bool — Start an authentication session. Returns if the session was started successfully.

**Signals**
- `completed(result: PamResult)` — handler `onCompleted` — Emitted whenever authentication completes.
- `error(error: PamError)` — handler `onError` — Emitted if pam fails to perform authentication normally.

  A `completed(PamResult.Error)` will be emitted after this event.
- `pamMessage()` — handler `onPamMessage` — Emitted whenever pam sends a new message, after the change signals for
  `message`, `messageIsError`, and `responseRequired`.

## PamError
*enum* · extends `QtObject`

See `PamContext.error`.

**Functions**
- `toString(value: PamError)`: string

**Values:** `PamError.StartFailed`, `PamError.InternalError`, `PamError.TryAuthFailed`

## PamResult
*enum* · extends `QtObject`

See `PamContext.completed`.

**Functions**
- `toString(value: PamResult)`: string

**Values:** `PamResult.Success`, `PamResult.Failed`, `PamResult.Error`, `PamResult.MaxTries`
