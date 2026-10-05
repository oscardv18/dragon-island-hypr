# Quickshell.Services.Polkit

`import Quickshell.Services.Polkit`

Polkit Agent

## AuthFlow
*class* · extends `QtObject` · uncreatable (obtained from other objects)

**Properties**
- `supplementaryMessage`: string [readonly] — An additional message to present to the user.

  This may be used to show errors or supplementary information.
  See `supplementaryIsError` to determine if this is an error message.
- `actionId`: string [readonly] — The action ID represents the action that is being authorized.

  This is a machine-readable identifier.
- `isCompleted`: bool [readonly] — Has the authentication request been completed.
- `identities`: list<> [readonly] — The list of identities that may be used to authenticate.

  Each identity may be a user or a group. You may select any of them to
  authenticate by setting `selectedIdentity`. By default, the first identity
  in the list is selected.
- `failed`: bool [readonly] — Indicates whether an authentication attempt has failed at least once during this authentication flow.
- `isResponseRequired`: bool [readonly] — Indicates that a response from the user is required from the user,
  typically a password.
- `isSuccessful`: bool [readonly] — Indicates whether the authentication request was successful.
- `responseVisible`: bool [readonly] — Indicates whether the user's response should be visible. (e.g. for passwords this should be false)
- `cookie`: string [readonly] — A cookie that identifies this authentication request.

  This is an internal identifier and not recommended to show to users.
- `inputPrompt`: string [readonly] — This message is used to prompt the user for required input.
- `message`: string [readonly] — The main message to present to the user.
- `supplementaryIsError`: bool [readonly] — Indicates whether the supplementary message is an error.
- `selectedIdentity`:  — The identity that will be used to authenticate.

  Changing this will abort any ongoing authentication conversations and start a new one.
- `iconName`: string [readonly] — The icon to present to the user in association with the message.

  The icon name follows the [FreeDesktop icon naming specification](https://specifications.freedesktop.org/icon-naming-spec/icon-naming-spec-latest.html).
  Use `Quickshell.iconPath` to resolve the icon name to an
  actual file path for display.
- `isCancelled`: bool [readonly] — Indicates whether the current authentication request was cancelled.

**Functions**
- `cancelAuthenticationRequest()`: void — Cancel the ongoing authentication request from the user side.
- `submit(value: string)`: void — Submit a response to a request that was previously emitted. Typically the password.

## PolkitAgent
*class* · extends `QtObject`

**Properties**
- `flow`: AuthFlow [readonly] — The current authentication state if an authentication request is active.

  Null when no authentication request is active.
- `isActive`: bool [readonly] — Indicates an ongoing authentication request.

  If this is true, other properties such as `message` and `iconName` will
  also be populated with relevant information.
- `isRegistered`: bool [readonly] — Indicates whether the agent registered successfully and is in use.
- `path`: string — The D-Bus path that this agent listener will use.

  If not set, a default of /org/quickshell/Polkit will be used.
