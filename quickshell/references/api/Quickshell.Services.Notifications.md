# Quickshell.Services.Notifications

`import Quickshell.Services.Notifications`

Types for implementing a notification daemon

## Notification
*class* · extends `QtObject` · uncreatable (obtained from other objects)

A notification emitted by a NotificationServer.

> [!NOTE]
> This type is `Retainable`. It
> can be retained after destruction if necessary.

**Properties**
- `appName`: string [readonly] — The sending application's name.
- `body`: string [readonly]
- `hasActionIcons`: bool [readonly] — If actions associated with this notification have icons available.

  See `NotificationAction.identifier` for details.
- `id`: int [readonly] — Id of the notification as given to the client.
- `summary`: string [readonly] — The image associated with this notification, or "" if none.
- `appIcon`: string [readonly] — The sending application's icon. If none was provided, then the icon from an associated
  desktop entry will be retrieved. If none was found then "".
- `expireTimeout`: real [readonly] — Time in seconds the notification should be valid for
- `tracked`: bool — If the notification is tracked by the notification server.

  Setting this property to false is equivalent to calling `dismiss`.
- `urgency`: NotificationUrgency [readonly]
- `transient`: bool [readonly] — If true, the notification should skip any kind of persistence function like a notification area.
- `resident`: bool [readonly] — If true, the notification will not be destroyed after an action is invoked.
- `desktopEntry`: string [readonly] — The name of the sender's desktop entry or "" if none was supplied.
- `actions`: list<NotificationAction> [readonly] — Actions that can be taken for this notification.
- `image`: string [readonly] — An image associated with the notification.

  This image is often something like a profile picture in instant messaging applications.
- `hasInlineReply`: bool [readonly] — If true, the notification has an inline reply action.

  A quick reply text field should be displayed and the reply can be sent using `sendInlineReply`.
- `lastGeneration`: bool [readonly] — If this notification was carried over from the last generation
  when quickshell reloaded.

  Notifications from the last generation will only be emitted
  if `NotificationServer.keepOnReload` is true.
- `inlineReplyPlaceholder`: string [readonly] — The placeholder text/button caption for the inline reply.
- `hints`:  [readonly] — All hints sent by the client application as a javascript object.
  Many common hints are exposed via other properties.

**Functions**
- `dismiss()`: void — Destroy the notification and hint to the remote application that it was
  explicitly closed by the user.
- `expire()`: void — Destroy the notification and hint to the remote application that it has
  timed out an expired.
- `sendInlineReply(replyText: string)`: void — Send an inline reply to the notification with an inline reply action.
  > [!WARNING]
  > This method can only be called if
  > `hasInlineReply` is true
  > and the server has `NotificationServer.inlineReplySupported` set to true.

**Signals**
- `closed(reason: NotificationCloseReason)` — handler `onClosed` — Sent when a notification has been closed.

  The notification object will be destroyed as soon as all signal handlers exit.

## NotificationAction
*class* · extends `QtObject` · uncreatable (obtained from other objects)

See `Notification.actions`.

**Properties**
- `text`: string [readonly] — The localized text that should be displayed on a button.
- `identifier`: string [readonly] — The identifier of the action.

  When `Notification.hasActionIcons` is true, this property will be an icon name.
  When it is false, this property is irrelevant.

**Functions**
- `invoke()`: void — Invoke the action. If `Notification.resident` is false it will be dismissed.

## NotificationCloseReason
*enum* · extends `QtObject`

See `Notification.closed`.

**Functions**
- `toString(value: NotificationCloseReason)`: string

**Values:** `NotificationCloseReason.Dismissed`, `NotificationCloseReason.Expired`, `NotificationCloseReason.CloseRequested`

## NotificationServer
*class* · extends `QtObject`

An implementation of the [Desktop Notifications Specification] for receiving notifications
from external applications.

The server does not advertise most capabilities by default. See the individual properties for details.

[Desktop Notifications Specification]: https://specifications.freedesktop.org/notification-spec/notification-spec-latest.html

**Properties**
- `keepOnReload`: bool — If notifications should be re-emitted when quickshell reloads. Defaults to true.

  The `Notification.lastGeneration` flag will be
  set on notifications from the prior generation for further filtering/handling.
- `bodyMarkupSupported`: bool — If notification body text should be advertised as supporting markup as described in [the specification]
  Defaults to false.

  Note that returned notifications may still contain markup if this property is false,
  as it is only a hint. By default Text objects will try to render markup. To avoid this
  if any is sent, change `Text.textFormat` to `PlainText`.
- `bodyHyperlinksSupported`: bool — If notification body text should be advertised as supporting hyperlinks as described in [the specification]
  Defaults to false.

  Note that returned notifications may still contain hyperlinks if this property is false, as it is only a hint.

  [the specification]: https://specifications.freedesktop.org/notification-spec/notification-spec-latest.html#hyperlinks
- `actionsSupported`: bool — If notification actions should be advertised as supported by the notification server. Defaults to false.
- `bodySupported`: bool — If notification body text should be advertised as supported by the notification server.
  Defaults to true.

  Note that returned notifications are likely to return body text even if this property is false,
  as it is only a hint.
- `imageSupported`: bool — If the notification server should advertise that it supports images. Defaults to false.
- `trackedNotifications`: ObjectModel<Notification> [readonly] — All notifications currently tracked by the server.
- `inlineReplySupported`: bool — If the notification server should advertise that it supports inline replies. Defaults to false.
- `persistenceSupported`: bool — If the notification server should advertise that it can persist notifications in the background
  after going offscreen. Defaults to false.
- `actionIconsSupported`: bool — If notification actions should be advertised as supporting the display of icons. Defaults to false.
- `bodyImagesSupported`: bool — If notification body text should be advertised as supporting images as described in [the specification]
  Defaults to false.

  Note that returned notifications may still contain images if this property is false, as it is only a hint.

  [the specification]: https://specifications.freedesktop.org/notification-spec/notification-spec-latest.html#images
- `extraHints`: list<string> — Extra hints to expose to notification clients.

**Signals**
- `notification(notification: Notification)` — handler `onNotification` — Sent when a notification is received by the server.

  If this notification should not be discarded, set its `tracked` property to true.

## NotificationUrgency
*enum* · extends `QtObject`

See `Notification.urgency`.

**Functions**
- `toString(value: NotificationUrgency)`: string

**Values:** `NotificationUrgency.Critical`, `NotificationUrgency.Low`, `NotificationUrgency.Normal`
