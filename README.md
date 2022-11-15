### Dry Questions

---

##### Question 1

The class used to implement the controller pattern, is the `SnappingSheetController` Class.

It is used to snap a SnappingSheet to a specific position, stop the snapping, and get information from the sheet such as the `currentPosition`, `currentSnappingPosition`, `CurrentlySnapping` and `isAttached`.


##### Question 2

The parameter that controls this behavior is `snappingCurve` which gets a `Curve` and uses that animation to snap into position. The `snappingCurve` parameter is a part of the `snappingPosition` class.

For example:

```dart
 SnappingPosition.pixels(
                positionPixels: 400,
                snappingCurve: Curves.elasticOut,
                snappingDuration: Duration(milliseconds: 1750),
            ),
```

This snapping position will use the elastic out animation, and it will last 1750 miliseconds.


##### Question 3

The `GestureDetector` widget provides the developer with more control (for example, it gives more gesture detection options such as dragging and pinching).

The `InkWell` widget has a ripple effect when clicking it, but its more limited.
