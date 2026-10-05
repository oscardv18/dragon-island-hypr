# Quickshell.Widgets

`import Quickshell.Widgets`

Bundled widgets

## ClippingRectangle
*class* · extends `Item`

> [!WARNING]
> This type requires at least Qt 6.7.

This is a specialized version of `Rectangle` that clips content
inside of its border, including rounded rectangles. It costs more than
`Rectangle`, so it should not be used unless you need to clip
items inside of it to the border.

**Properties**
- `topLeftRadius`: real — Radius of the top left corner. Defaults to `radius`.
- `data`:  [default] — Data of the ClippingRectangle's `contentItem`. (`list<QtObject>`).

  See `Item.data` for details.
- `antialiasing`: bool — If the rectangle should be antialiased.

  Defaults to true if any corner has a non-zero radius, otherwise false.
- `topRightRadius`: real — Radius of the top right corner. Defaults to `radius`.
- `contentUnderBorder`: bool — If content should be displayed underneath the border.

  Defaults to false, does nothing if the border is opaque.
- `bottomLeftRadius`: real — Radius of the bottom left corner. Defaults to `radius`.
- `children`:  — Visual children of the ClippingRectangle's `contentItem`. (`list<Item>`).

  See `Item.children` for details.
- `color`: color — The background color of the rectangle, which goes under its content.
- `bottomRightRadius`: real — Radius of the bottom right corner. Defaults to `radius`.
- `contentInsideBorder`: bool — If the content item should be resized to fit inside the border.

  Defaults to `!contentUnderBorder`. Most useful when combined with
  `anchors.fill: parent` on an item passed to the ClippingRectangle.
- `contentItem`:  [readonly] — The item containing the rectangle's content.
  There is usually no reason to use this directly.
- `radius`: real — Radius of all corners. Defaults to 0.
- `border`:  — See `Rectangle.border`.

## ClippingWrapperRectangle
*class* · extends ``

This component is useful for adding a clipping border or background rectangle to
a child item. If you don't need clipping, use `WrapperRectangle`.

> [!NOTE]
> ClippingWrapperRectangle is a `MarginWrapperManager` based component.
> See its documentation for information on how margins and sizes are calculated.

> [!WARNING]
> You should not set `Item.x`, `Item.y`, `Item.width`,
> `Item.height` or `Item.anchors` on the child item, as they are used
> by WrapperItem to position it. Instead set `Item.implicitWidth` and
> `Item.implicitHeight`.

**Properties**
- `implicitWidth`: real — Overrides the implicit width of the wrapper.

  Defaults to the implicit width of the content item plus its left and right margin,
  and may be reset by assigning `undefined`.
- `child`:  — See `WrapperManager.child` for details.
- `margin`: real — The default for `topMargin`, `bottomMargin`, `leftMargin` and `rightMargin`.
  Defaults to 0.
- `resizeChild`: bool — Determines if child item should be resized larger than its implicit size if
  the parent is resized larger than its implicit size. Defaults to true.
- `rightMargin`: real — The requested right margin of the content item, not counting `extraMargin`.

  Defaults to `margin`, and may be reset by assigning `undefined`.
- `leftMargin`: real — The requested left margin of the content item, not counting `extraMargin`.

  Defaults to `margin`, and may be reset by assigning `undefined`.
- `topMargin`: real — The requested top margin of the content item, not counting `extraMargin`.

  Defaults to `margin`, and may be reset by assigning `undefined`.
- `implicitHeight`: real — Overrides the implicit height of the wrapper.

  Defaults to the implicit width of the content item plus its top and bottom margin,
  and may be reset by assigning `undefined`.
- `bottomMargin`: real — The requested bottom margin of the content item, not counting `extraMargin`.

  Defaults to `margin`, and may be reset by assigning `undefined`.
- `extraMargin`: real — An extra margin applied in addition to `topMargin`, `bottomMargin`,
  `leftMargin`, and `rightMargin`.
  If `contentInsideBorder` is true, the rectangle's border width will be added
  to this property. Defaults to 0.

## IconImage
*class* · extends `Item`

This is a specialization of `Image` configured for icon-style images,
designed to make it easier to use correctly. If you need more control, use
`Image` directly.

The image's aspect raito is assumed to be 1:1. If it is not 1:1, padding
will be added to make it 1:1. This is currently applied before the actual
aspect ratio of the image is taken into account, and may change in a future
release.

You should use it for:
- Icons for custom buttons
- Status indicator icons
- System tray icons
- Things similar to the above.

Do not use it for:
- Big images
- Images that change size frequently
- Anything that doesn't feel like an icon.

> [!NOTE]
> More information about many of these properties can be found in
> the documentation for `Image`.

**Properties**
- `mipmap`: bool — If the image should be mipmap filtered. Defaults to false.
  See `Image.mipmap`.

  Try enabling this if your image is significantly scaled down
  and looks bad because of it.
- `status`:  — The load status of the image. See `Image.status`.
- `asynchronous`: bool — If the image should be loaded asynchronously. Defaults to false.
  See `Image.asynchronous`.
- `actualSize`: real [readonly] — The actual size the image will be displayed at.
- `implicitSize`: real — The suggested size of the image. This is used as a default
  for `Item.implicitWidth` and `Item.implicitHeight`.
- `source`: string — URL of the image. Defaults to an empty string.
  See `Image.source`.
- `backer`: Image — The `Image` backing this object.

  This is useful if you need to access more functionality than
  exposed by IconImage.

## MarginWrapperManager
*class* · extends `WrapperManager`

> [!NOTE]
> MarginWrapperManager is an extension of `WrapperManager`.
> You should read its documentation to understand wrapper types.

MarginWrapperManager can be used to apply margins to a child item,
in addition to handling the size / implicit size relationship
between the parent and the child. `WrapperItem` and `WrapperRectangle`
exist for Item and Rectangle implementations respectively.

> [!WARNING]
> MarginWrapperManager based types set the child item's
> `Item.x`, `Item.y`, `Item.width`, `Item.height`
> or `Item.anchors` properties. Do not set them yourself,
> instead set `Item.implicitWidth` and `Item.implicitHeight`.

### Implementing a margin wrapper type
Follow the directions in `WrapperManager`'s documentation, and or
alias the `margin` property if you wish to expose it.

## Margin calculation
The margin of the content item is calculated based on `topMargin`, `bottomMargin`,
`leftMargin`, `rightMargin`, `extraMargin` and `resizeChild`.

If `resizeChild` is `true`, each side's margin will be the value of `<side>Margin`
plus `extraMargin`, and the content item will be stretched to match the given margin
if the wrapper is not at its implicit size.

If `resizeChild` is `false`, the `<side>Margin` properties will be interpreted as a
ratio and the content item will not be stretched if the wrapper is not at its implicit side.

The implicit size of the wrapper is the implicit size of the content item
plus all margins.

**Properties**
- `bottomMargin`: real — The requested bottom margin of the content item, not counting `extraMargin`.

  Defaults to `margin`, and may be reset by assigning `undefined`.
- `implicitWidth`: real — Overrides the implicit width of the wrapper.

  Defaults to the implicit width of the content item plus its left and right margin,
  and may be reset by assigning `undefined`.
- `leftMargin`: real — The requested left margin of the content item, not counting `extraMargin`.

  Defaults to `margin`, and may be reset by assigning `undefined`.
- `rightMargin`: real — The requested right margin of the content item, not counting `extraMargin`.

  Defaults to `margin`, and may be reset by assigning `undefined`.
- `extraMargin`: real — An extra margin applied in addition to `topMargin`, `bottomMargin`,
  `leftMargin`, and `rightMargin`. Defaults to 0.
- `resizeChild`: bool — Determines if child item should be resized larger than its implicit size if
  the parent is resized larger than its implicit size. Defaults to true.
- `margin`: real — The default for `topMargin`, `bottomMargin`, `leftMargin` and `rightMargin`.
  Defaults to 0.
- `topMargin`: real — The requested top margin of the content item, not counting `extraMargin`.

  Defaults to `margin`, and may be reset by assigning `undefined`.
- `implicitHeight`: real — Overrides the implicit height of the wrapper.

  Defaults to the implicit width of the content item plus its top and bottom margin,
  and may be reset by assigning `undefined`.

## WrapperItem
*class* · extends `Item`

This component is useful when you need to wrap a single component in
an item, or give a single component a margin. See [QtQuick.Layouts]
for positioning multiple items.

> [!NOTE]
> WrapperItem is a `MarginWrapperManager` based component.
> See its documentation for information on how margins and sizes are calculated.

### Example: Adding a margin to an item
The snippet below adds a 10px margin to all sides of the `Text` item.

```qml
WrapperItem {
  margin: 10

  Text { text: "Hello!" }
}
```

> [!NOTE]
> The child item can be specified by writing it inline in the wrapper,
> as in the example above, or by using the `child` property. See
> `WrapperManager.child` for details.

> [!WARNING]
> You should not set `Item.x`, `Item.y`, `Item.width`,
> `Item.height` or `Item.anchors` on the child item, as they are used
> by WrapperItem to position it. Instead set `Item.implicitWidth` and
> `Item.implicitHeight`.

[QtQuick.Layouts]: https://doc.qt.io/qt-6/qtquicklayouts-index.html

**Properties**
- `leftMargin`: real — The requested left margin of the content item, not counting `extraMargin`.

  Defaults to `margin`, and may be reset by assigning `undefined`.
- `bottomMargin`: real — The requested bottom margin of the content item, not counting `extraMargin`.

  Defaults to `margin`, and may be reset by assigning `undefined`.
- `implicitHeight`: real — Overrides the implicit height of the wrapper.

  Defaults to the implicit width of the content item plus its top and bottom margin,
  and may be reset by assigning `undefined`.
- `margin`: real — The default for `topMargin`, `bottomMargin`, `leftMargin` and `rightMargin`.
  Defaults to 0.
- `topMargin`: real — The requested top margin of the content item, not counting `extraMargin`.

  Defaults to `margin`, and may be reset by assigning `undefined`.
- `rightMargin`: real — The requested right margin of the content item, not counting `extraMargin`.

  Defaults to `margin`, and may be reset by assigning `undefined`.
- `child`: Item — See `WrapperManager.child` for details.
- `implicitWidth`: real — Overrides the implicit width of the wrapper.

  Defaults to the implicit width of the content item plus its left and right margin,
  and may be reset by assigning `undefined`.
- `resizeChild`: bool — Determines if child item should be resized larger than its implicit size if
  the parent is resized larger than its implicit size. Defaults to true.
- `extraMargin`: real — An extra margin applied in addition to `topMargin`, `bottomMargin`,
  `leftMargin`, and `rightMargin`. Defaults to 0.

## WrapperManager
*class* · extends `QtObject`

WrapperManager determines which child of an Item should be its visual
child, and exposes it for further operations. See `MarginWrapperManager`
for a subclass that implements automatic sizing and margins.

### Using wrapper types
WrapperManager based types have a single visual child item.
You can specify the child item using the default property, or by
setting the `child` property. You must use the `child` property if
the widget has more than one `Item` based child.

#### Example using the default property
```qml
WrapperWidget { // a widget that uses WrapperManager
  // Putting the item inline uses the default property of WrapperWidget.
  Text { text: "Hello" }

  // Scope does not extend Item, so it can be placed in the
  // default property without issue.
  Scope {}
}
```

#### Example using the child property
```qml
WrapperWidget {
  Text {
    id: text
    text: "Hello"
  }

  Text {
    id: otherText
    text: "Other Text"
  }

  // Both text and otherText extend Item, so one must be specified.
  child: text
}
```

See `child` for more details on how the child property can be used.

### Implementing wrapper types
In addition to the bundled wrapper types, you can make your own using
WrapperManager. To implement a wrapper, create a WrapperManager inside
your wrapper component 's default property, then alias a new property
to the WrapperManager's `child` property.

#### Example
```qml
Item { // your wrapper component
  WrapperManager { id: wrapperManager }

  // Allows consumers of your wrapper component to use the child property.
  property alias child: wrapperManager.child

  // The rest of your component logic. You can use
  // `wrapperManager.child` or `this.child` to refer to the selected child.
}
```

### See also
- `WrapperItem` - A `MarginWrapperManager` based component that sizes itself
  to its child.
- `WrapperRectangle` - A `MarginWrapperManager` based component that sizes
  itself to its child, and provides an option to use its border as an inset.

**Properties**
- `child`: Item — The wrapper component's selected child.

  Setting this property override's WrapperManager's default selection,
  and resolve ambiguity when more than one visual child is present.
  The property can additionally be defined inline or reference a component
  that is not already a child of the wrapper, in which case it will be
  reparented to the wrapper. Setting child to `null` will select no child,
  and `undefined` will restore the default child.

  When read, `child` will always return the (potentially null) selected child,
  and not `undefined`.
- `wrapper`: Item — The wrapper managed by this manager. Defaults to the manager's parent.
  This property may not be changed after Component.onCompleted.

## WrapperMouseArea
*class* · extends ``

This component is useful for wrapping a single component in
a mouse area. It works the same as `WrapperItem`, but with a `MouseArea`.

> [!NOTE]
> WrapperMouseArea is a `MarginWrapperManager` based component.
> See its documentation for information on how margins and sizes are calculated.

> [!NOTE]
> The child item can be specified by writing it inline in the wrapper,
> as in the example above, or by using the `child` property. See
> `WrapperManager.child` for details.

> [!WARNING]
> You should not set `Item.x`, `Item.y`, `Item.width`,
> `Item.height` or `Item.anchors` on the child item, as they are used
> by WrapperItem to position it. Instead set `Item.implicitWidth` and
> `Item.implicitHeight`.

[QtQuick.Layouts]: https://doc.qt.io/qt-6/qtquicklayouts-index.html

**Properties**
- `margin`: real — The default for `topMargin`, `bottomMargin`, `leftMargin` and `rightMargin`.
  Defaults to 0.
- `resizeChild`: bool — Determines if child item should be resized larger than its implicit size if
  the parent is resized larger than its implicit size. Defaults to true.
- `leftMargin`: real — The requested left margin of the content item, not counting `extraMargin`.

  Defaults to `margin`, and may be reset by assigning `undefined`.
- `child`: Item — See `WrapperManager.child` for details.
- `extraMargin`: real — An extra margin applied in addition to `topMargin`, `bottomMargin`,
  `leftMargin`, and `rightMargin`. Defaults to 0.
- `rightMargin`: real — The requested right margin of the content item, not counting `extraMargin`.

  Defaults to `margin`, and may be reset by assigning `undefined`.
- `topMargin`: real — The requested top margin of the content item, not counting `extraMargin`.

  Defaults to `margin`, and may be reset by assigning `undefined`.
- `bottomMargin`: real — The requested bottom margin of the content item, not counting `extraMargin`.

  Defaults to `margin`, and may be reset by assigning `undefined`.
- `implicitWidth`: real — Overrides the implicit width of the wrapper.

  Defaults to the implicit width of the content item plus its left and right margin,
  and may be reset by assigning `undefined`.
- `implicitHeight`: real — Overrides the implicit height of the wrapper.

  Defaults to the implicit width of the content item plus its top and bottom margin,
  and may be reset by assigning `undefined`.

## WrapperRectangle
*class* · extends `Rectangle`

This component is useful for adding a border or background rectangle to
a child item. If you need to clip the child item to the rectangle's
border, see `ClippingWrapperRectangle`.

> [!NOTE]
> WrapperRectangle is a `MarginWrapperManager` based component.
> See its documentation for information on how margins and sizes are calculated.

> [!WARNING]
> You should not set `Item.x`, `Item.y`, `Item.width`,
> `Item.height` or `Item.anchors` on the child item, as they are used
> by WrapperItem to position it. Instead set `Item.implicitWidth` and
> `Item.implicitHeight`.

**Properties**
- `extraMargin`: real — An extra margin applied in addition to `topMargin`, `bottomMargin`,
  `leftMargin`, and `rightMargin`.
  If `contentInsideBorder` is true, the rectangle's border width will be added
  to this property. Defaults to 0.
- `sets`: 
- `child`:  — See `WrapperManager.child` for details.
- `implicitHeight`: real — Overrides the implicit height of the wrapper.

  Defaults to the implicit width of the content item plus its top and bottom margin,
  and may be reset by assigning `undefined`.
- `implicitWidth`: real — Overrides the implicit width of the wrapper.

  Defaults to the implicit width of the content item plus its left and right margin,
  and may be reset by assigning `undefined`.
- `leftMargin`: real — The requested left margin of the content item, not counting `extraMargin`.

  Defaults to `margin`, and may be reset by assigning `undefined`.
- `bottomMargin`: real — The requested bottom margin of the content item, not counting `extraMargin`.

  Defaults to `margin`, and may be reset by assigning `undefined`.
- `rightMargin`: real — The requested right margin of the content item, not counting `extraMargin`.

  Defaults to `margin`, and may be reset by assigning `undefined`.
- `contentInsideBorder`: bool — If true (default), the rectangle's border width will be added
  to `extraMargin`.
- `margin`: real — The default for `topMargin`, `bottomMargin`, `leftMargin` and `rightMargin`.
  Defaults to 0.
- `resizeChild`: bool — Determines if child item should be resized larger than its implicit size if
  the parent is resized larger than its implicit size. Defaults to true.
- `topMargin`: real — The requested top margin of the content item, not counting `extraMargin`.

  Defaults to `margin`, and may be reset by assigning `undefined`.
