// Copyright 2015 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'automatic_keep_alive.dart';
import 'basic.dart';
import 'debug.dart';
import 'framework.dart';
import 'gesture_detector.dart';
import 'ticker_provider.dart';
import 'transitions.dart';

const Curve _kResizeTimeCurve = Interval(0.4, 1.0, curve: Curves.ease);
const double _kMinFlingVelocity = 700.0;
const double _kMinFlingVelocityDelta = 400.0;
const double _kFlingVelocityScale = 1.0 / 300.0;
const double _kDismissThreshold = 0.4;

/// Signature used by [Dismissible] to indicate that it has been dismissed in
/// the given `direction`.
///
/// Used by [Dismissible.onDismissed].
typedef DismissDirectionCallback = void Function(DismissDirection direction);

/// The direction in which a [Dismissible] can be dismissed.
enum DismissDirection {
  /// The [Dismissible] can be dismissed by dragging either up or down.
  vertical,

  /// The [Dismissible] can be dismissed by dragging either left or right.
  horizontal,

  /// The [Dismissible] can be dismissed by dragging in the reverse of the
  /// reading direction (e.g., from right to left in left-to-right languages).
  endToStart,

  /// The [Dismissible] can be dismissed by dragging in the reading direction
  /// (e.g., from left to right in left-to-right languages).
  startToEnd,

  /// The [Dismissible] can be dismissed by dragging up only.
  up,

  /// The [Dismissible] can be dismissed by dragging down only.
  down
}

/// A widget that can be dismissed by dragging in the indicated [direction].
///
/// Dragging or flinging this widget in the [DismissDirection] causes the child
/// to slide out of view. Following the slide animation, if [resizeDuration] is
/// non-null, the Dismissible widget animates its height (or width, whichever is
/// perpendicular to the dismiss direction) to zero over the [resizeDuration].
///
/// Backgrounds can be used to implement the "leave-behind" idiom. If a background
/// is specified it is stacked behind the Dismissible's child and is exposed when
/// the child moves.
///
/// The widget calls the [onDismissed] callback either after its size has
/// collapsed to zero (if [resizeDuration] is non-null) or immediately after
/// the slide animation (if [resizeDuration] is null). If the Dismissible is a
/// list item, it must have a key that distinguishes it from the other items and
/// its [onDismissed] callback must remove the item from the list.
class Dismissible extends StatefulWidget {
  /// Creates a widget that can be dismissed.
  ///
  /// The [key] argument must not be null because [Dismissible]s are commonly
  /// used in lists and removed from the list when dismissed. Without keys, the
  /// default behavior is to sync widgets based on their index in the list,
  /// which means the item after the dismissed item would be synced with the
  /// state of the dismissed item. Using keys causes the widgets to sync
  /// according to their keys and avoids this pitfall.
  const Dismissible({
    @required Key key,
    @required this.child,
    this.background,
    this.secondaryBackground,
    this.onResize,
    this.onDismissed,
    this.direction = DismissDirection.horizontal,
    this.resizeDuration = const Duration(milliseconds: 300),
    this.dismissThresholds = const <DismissDirection, double>{},
    this.movementDuration = const Duration(milliseconds: 200),
    this.crossAxisEndOffset = 0.0,
  }) : assert(key != null),
       assert(secondaryBackground != null ? background != null : true),
       super(key: key);

  /// The widget below this widget in the tree.
  ///
  /// {@macro flutter.widgets.child}
  final Widget child;

  /// A widget that is stacked behind the child. If secondaryBackground is also
  /// specified then this widget only appears when the child has been dragged
  /// down or to the right.
  final Widget background;

  /// A widget that is stacked behind the child and is exposed when the child
  /// has been dragged up or to the left. It may only be specified when background
  /// has also been specified.
  final Widget secondaryBackground;

  /// Called when the widget changes size (i.e., when contracting before being dismissed).
  final VoidCallback onResize;

  /// Called when the widget has been dismissed, after finishing resizing.
  final DismissDirectionCallback onDismissed;

  /// The direction in which the widget can be dismissed.
  final DismissDirection direction;

  /// The amount of time the widget will spend contracting before [onDismissed] is called.
  ///
  /// If null, the widget will not contract and [onDismissed] will be called
  /// immediately after the widget is dismissed.
  final Duration resizeDuration;

  /// The offset threshold the item has to be dragged in order to be considered
  /// dismissed.
  ///
  /// Represented as a fraction, e.g. if it is 0.4 (the default), then the item
  /// has to be dragged at least 40% towards one direction to be considered
  /// dismissed. Clients can define different thresholds for each dismiss
  /// direction.
  ///
  /// Flinging is treated as being equivalent to dragging almost to 1.0, so
  /// flinging can dismiss an item past any threshold less than 1.0.
  ///
  /// See also [direction], which controls the directions in which the items can
  /// be dismissed. Setting a threshold of 1.0 (or greater) prevents a drag in
  /// the given [DismissDirection] even if it would be allowed by the
  /// [direction] property.
  final Map<DismissDirection, double> dismissThresholds;

  /// Defines the duration for card to dismiss or to come back to original position if not dismissed.
  final Duration movementDuration;

  /// Defines the end offset across the main axis after the card is dismissed.
  ///
  /// If non-zero value is given then widget moves in cross direction depending on whether
  /// it is positive or negative.
  final double crossAxisEndOffset;

  @override
  _DismissibleState createState() => _DismissibleState();
}

class _DismissibleClipper extends CustomClipper<Rect> {
  _DismissibleClipper({
    @required this.axis,
    @required this.moveAnimation
  }) : assert(axis != null),
       assert(moveAnimation != null),
       super(reclip: moveAnimation);

  final Axis axis;
  final Animation<Offset> moveAnimation;

  @override
  Rect getClip(Size size) {
    assert(axis != null);
    switch (axis) {
      case Axis.horizontal:
        final double offset = moveAnimation.value.dx * size.width;
        if (offset < 0)
          return Rect.fromLTRB(size.width + offset, 0.0, size.width, size.height);
        return Rect.fromLTRB(0.0, 0.0, offset, size.height);
      case Axis.vertical:
        final double offset = moveAnimation.value.dy * size.height;
        if (offset < 0)
          return Rect.fromLTRB(0.0, size.height + offset, size.width, size.height);
        return Rect.fromLTRB(0.0, 0.0, size.width, offset);
    }
    return null;
  }

  @override
  Rect getApproximateClipRect(Size size) => getClip(size);

  @override
  bool shouldReclip(_DismissibleClipper oldClipper) {
    return oldClipper.axis != axis
        || oldClipper.moveAnimation.value != moveAnimation.value;
  }
}

enum _FlingGestureKind { none, forward, reverse }

class _DismissibleState extends State<Dismissible> with TickerProviderStateMixin, AutomaticKeepAliveClientMixin { // ignore: MIXIN_INFERENCE_INCONSISTENT_MATCHING_CLASSES
  @override
  void initState() {
    super.initState();
    m_moveController = AnimationController(duration: widget.movementDuration, vsync: this)
      ..addStatusListener(_handleDismissStatusChanged);
    _updateMoveAnimation();
  }

  AnimationController m_moveController;
  Animation<Offset> m_moveAnimation;

  AnimationController m_resizeController;
  Animation<double> m_resizeAnimation;

  double m_dragExtent = 0.0;
  bool m_dragUnderway = false;
  Size m_sizePriorToCollapse;

  @override
  bool get wantKeepAlive => m_moveController?.isAnimating == true || m_resizeController?.isAnimating == true;

  @override
  void dispose() {
    m_moveController.dispose();
    m_resizeController?.dispose();
    super.dispose();
  }

  bool get m_directionIsXAxis {
    return widget.direction == DismissDirection.horizontal
        || widget.direction == DismissDirection.endToStart
        || widget.direction == DismissDirection.startToEnd;
  }

  DismissDirection _extentToDirection(double extent) {
    if (extent == 0.0)
      return null;
    if (m_directionIsXAxis) {
      switch (Directionality.of(context)) {
        case TextDirection.rtl:
          return extent < 0 ? DismissDirection.startToEnd : DismissDirection.endToStart;
        case TextDirection.ltr:
          return extent > 0 ? DismissDirection.startToEnd : DismissDirection.endToStart;
      }
      assert(false);
      return null;
    }
    return extent > 0 ? DismissDirection.down : DismissDirection.up;
  }

  DismissDirection get m_dismissDirection => _extentToDirection(m_dragExtent);

  bool get m_isActive {
    return m_dragUnderway || m_moveController.isAnimating;
  }

  double get m_overallDragAxisExtent {
    final Size size = context.size;
    return m_directionIsXAxis ? size.width : size.height;
  }

  void _handleDragStart(DragStartDetails details) {
    m_dragUnderway = true;
    if (m_moveController.isAnimating) {
      m_dragExtent = m_moveController.value * m_overallDragAxisExtent * m_dragExtent.sign;
      m_moveController.stop();
    } else {
      m_dragExtent = 0.0;
      m_moveController.value = 0.0;
    }
    setState(() {
      _updateMoveAnimation();
    });
  }

  void _handleDragUpdate(DragUpdateDetails details) {
    if (!m_isActive || m_moveController.isAnimating)
      return;

    final double delta = details.primaryDelta;
    final double oldDragExtent = m_dragExtent;
    switch (widget.direction) {
      case DismissDirection.horizontal:
      case DismissDirection.vertical:
        m_dragExtent += delta;
        break;

      case DismissDirection.up:
        if (m_dragExtent + delta < 0)
          m_dragExtent += delta;
        break;

      case DismissDirection.down:
        if (m_dragExtent + delta > 0)
          m_dragExtent += delta;
        break;

      case DismissDirection.endToStart:
        switch (Directionality.of(context)) {
          case TextDirection.rtl:
            if (m_dragExtent + delta > 0)
              m_dragExtent += delta;
            break;
          case TextDirection.ltr:
            if (m_dragExtent + delta < 0)
              m_dragExtent += delta;
            break;
        }
        break;

      case DismissDirection.startToEnd:
        switch (Directionality.of(context)) {
          case TextDirection.rtl:
            if (m_dragExtent + delta < 0)
              m_dragExtent += delta;
            break;
          case TextDirection.ltr:
            if (m_dragExtent + delta > 0)
              m_dragExtent += delta;
            break;
        }
        break;
    }
    if (oldDragExtent.sign != m_dragExtent.sign) {
      setState(() {
        _updateMoveAnimation();
      });
    }
    if (!m_moveController.isAnimating) {
      m_moveController.value = m_dragExtent.abs() / m_overallDragAxisExtent;
    }
  }

  void _updateMoveAnimation() {
    final double end = m_dragExtent.sign;
    m_moveAnimation = Tween<Offset>(
      begin: Offset.zero,
      end: m_directionIsXAxis
          ? Offset(end, widget.crossAxisEndOffset)
          : Offset(widget.crossAxisEndOffset, end),
    ).animate(m_moveController);
  }

  _FlingGestureKind _describeFlingGesture(Velocity velocity) {
    assert(widget.direction != null);
    if (m_dragExtent == 0.0) {
      // If it was a fling, then it was a fling that was let loose at the exact
      // middle of the range (i.e. when there's no displacement). In that case,
      // we assume that the user meant to fling it back to the center, as
      // opposed to having wanted to drag it out one way, then fling it past the
      // center and into and out the other side.
      return _FlingGestureKind.none;
    }
    final double vx = velocity.pixelsPerSecond.dx;
    final double vy = velocity.pixelsPerSecond.dy;
    DismissDirection flingDirection;
    // Verify that the fling is in the generally right direction and fast enough.
    if (m_directionIsXAxis) {
      if (vx.abs() - vy.abs() < _kMinFlingVelocityDelta || vx.abs() < _kMinFlingVelocity)
        return _FlingGestureKind.none;
      assert(vx != 0.0);
      flingDirection = _extentToDirection(vx);
    } else {
      if (vy.abs() - vx.abs() < _kMinFlingVelocityDelta || vy.abs() < _kMinFlingVelocity)
        return _FlingGestureKind.none;
      assert(vy != 0.0);
      flingDirection = _extentToDirection(vy);
    }
    assert(m_dismissDirection != null);
    if (flingDirection == m_dismissDirection)
      return _FlingGestureKind.forward;
    return _FlingGestureKind.reverse;
  }

  void _handleDragEnd(DragEndDetails details) {
    if (!m_isActive || m_moveController.isAnimating)
      return;
    m_dragUnderway = false;
    if (m_moveController.isCompleted) {
      _startResizeAnimation();
      return;
    }
    final double flingVelocity = m_directionIsXAxis ? details.velocity.pixelsPerSecond.dx : details.velocity.pixelsPerSecond.dy;
    switch (_describeFlingGesture(details.velocity)) {
      case _FlingGestureKind.forward:
        assert(m_dragExtent != 0.0);
        assert(!m_moveController.isDismissed);
        if ((widget.dismissThresholds[m_dismissDirection] ?? _kDismissThreshold) >= 1.0) {
          m_moveController.reverse();
          break;
        }
        m_dragExtent = flingVelocity.sign;
        m_moveController.fling(velocity: flingVelocity.abs() * _kFlingVelocityScale);
        break;
      case _FlingGestureKind.reverse:
        assert(m_dragExtent != 0.0);
        assert(!m_moveController.isDismissed);
        m_dragExtent = flingVelocity.sign;
        m_moveController.fling(velocity: -flingVelocity.abs() * _kFlingVelocityScale);
        break;
      case _FlingGestureKind.none:
        if (!m_moveController.isDismissed) { // we already know it's not completed, we check that above
          if (m_moveController.value > (widget.dismissThresholds[m_dismissDirection] ?? _kDismissThreshold)) {
            m_moveController.forward();
          } else {
            m_moveController.reverse();
          }
        }
        break;
    }
  }

  void _handleDismissStatusChanged(AnimationStatus status) {
    if (status == AnimationStatus.completed && !m_dragUnderway)
      _startResizeAnimation();
    updateKeepAlive();
  }

  void _startResizeAnimation() {
    assert(m_moveController != null);
    assert(m_moveController.isCompleted);
    assert(m_resizeController == null);
    assert(m_sizePriorToCollapse == null);
    if (widget.resizeDuration == null) {
      if (widget.onDismissed != null) {
        final DismissDirection direction = m_dismissDirection;
        assert(direction != null);
        widget.onDismissed(direction);
      }
    } else {
      m_resizeController = AnimationController(duration: widget.resizeDuration, vsync: this)
        ..addListener(_handleResizeProgressChanged)
        ..addStatusListener((AnimationStatus status) => updateKeepAlive());
      m_resizeController.forward();
      setState(() {
        m_sizePriorToCollapse = context.size;
        m_resizeAnimation = Tween<double>(
          begin: 1.0,
          end: 0.0
        ).animate(CurvedAnimation(
          parent: m_resizeController,
          curve: _kResizeTimeCurve
        ));
      });
    }
  }

  void _handleResizeProgressChanged() {
    if (m_resizeController.isCompleted) {
      if (widget.onDismissed != null) {
        final DismissDirection direction = m_dismissDirection;
        assert(direction != null);
        widget.onDismissed(direction);
      }
    } else {
      if (widget.onResize != null)
        widget.onResize();
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context); // See AutomaticKeepAliveClientMixin.

    assert(!m_directionIsXAxis || debugCheckHasDirectionality(context));

    Widget background = widget.background;
    if (widget.secondaryBackground != null) {
      final DismissDirection direction = m_dismissDirection;
      if (direction == DismissDirection.endToStart || direction == DismissDirection.up)
        background = widget.secondaryBackground;
    }

    if (m_resizeAnimation != null) {
      // we've been dragged aside, and are now resizing.
      assert(() {
        if (m_resizeAnimation.status != AnimationStatus.forward) {
          assert(m_resizeAnimation.status == AnimationStatus.completed);
          throw FlutterError(
            'A dismissed Dismissible widget is still part of the tree.\n'
            'Make sure to implement the onDismissed handler and to immediately remove the Dismissible\n'
            'widget from the application once that handler has fired.'
          );
        }
        return true;
      }());

      return SizeTransition(
        sizeFactor: m_resizeAnimation,
        axis: m_directionIsXAxis ? Axis.vertical : Axis.horizontal,
        child: SizedBox(
          width: m_sizePriorToCollapse.width,
          height: m_sizePriorToCollapse.height,
          child: background
        )
      );
    }

    Widget content = SlideTransition(
      position: m_moveAnimation,
      child: widget.child
    );

    if (background != null) {
      final List<Widget> children = <Widget>[];

      if (!m_moveAnimation.isDismissed) {
        children.add(Positioned.fill(
          child: ClipRect(
            clipper: _DismissibleClipper(
              axis: m_directionIsXAxis ? Axis.horizontal : Axis.vertical,
              moveAnimation: m_moveAnimation,
            ),
            child: background
          )
        ));
      }

      children.add(content);
      content = Stack(children: children);
    }

    // We are not resizing but we may be being dragging in widget.direction.
    return GestureDetector(
      onHorizontalDragStart: m_directionIsXAxis ? _handleDragStart : null,
      onHorizontalDragUpdate: m_directionIsXAxis ? _handleDragUpdate : null,
      onHorizontalDragEnd: m_directionIsXAxis ? _handleDragEnd : null,
      onVerticalDragStart: m_directionIsXAxis ? null : _handleDragStart,
      onVerticalDragUpdate: m_directionIsXAxis ? null : _handleDragUpdate,
      onVerticalDragEnd: m_directionIsXAxis ? null : _handleDragEnd,
      behavior: HitTestBehavior.opaque,
      child: content
    );
  }
}

