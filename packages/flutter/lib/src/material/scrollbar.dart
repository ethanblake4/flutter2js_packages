// Copyright 2016 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:flutter/widgets.dart';

import 'theme.dart';

const double _kScrollbarThickness = 6.0;
const Duration _kScrollbarFadeDuration = Duration(milliseconds: 300);
const Duration _kScrollbarTimeToFade = Duration(milliseconds: 600);

/// A material design scrollbar.
///
/// A scrollbar indicates which portion of a [Scrollable] widget is actually
/// visible.
///
/// Dynamically changes to an iOS style scrollbar that looks like
/// [CupertinoScrollbar] on the iOS platform.
///
/// To add a scrollbar to a [ScrollView], simply wrap the scroll view widget in
/// a [Scrollbar] widget.
///
/// See also:
///
///  * [ListView], which display a linear, scrollable list of children.
///  * [GridView], which display a 2 dimensional, scrollable array of children.
class Scrollbar extends StatefulWidget {
  /// Creates a material design scrollbar that wraps the given [child].
  ///
  /// The [child] should be a source of [ScrollNotification] notifications,
  /// typically a [Scrollable] widget.
  const Scrollbar({
    Key key,
    @required this.child,
  }) : super(key: key);

  /// The widget below this widget in the tree.
  ///
  /// The scrollbar will be stacked on top of this child. This child (and its
  /// subtree) should include a source of [ScrollNotification] notifications.
  ///
  /// Typically a [ListView] or [CustomScrollView].
  final Widget child;

  @override
  _ScrollbarState createState() => _ScrollbarState();
}


class _ScrollbarState extends State<Scrollbar> with TickerProviderStateMixin {
  ScrollbarPainter m_materialPainter;
  TargetPlatform m_currentPlatform;
  TextDirection m_textDirection;
  Color m_themeColor;

  AnimationController m_fadeoutAnimationController;
  Animation<double> m_fadeoutOpacityAnimation;
  Timer m_fadeoutTimer;

  @override
  void initState() {
    super.initState();
    m_fadeoutAnimationController = AnimationController(
      vsync: this,
      duration: _kScrollbarFadeDuration,
    );
    m_fadeoutOpacityAnimation = CurvedAnimation(
      parent: m_fadeoutAnimationController,
      curve: Curves.fastOutSlowIn
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    final ThemeData theme = Theme.of(context);
    m_currentPlatform = theme.platform;

    switch (m_currentPlatform) {
      case TargetPlatform.iOS:
        // On iOS, stop all local animations. CupertinoScrollbar has its own
        // animations.
        m_fadeoutTimer?.cancel();
        m_fadeoutTimer = null;
        m_fadeoutAnimationController.reset();
        break;
      case TargetPlatform.android:
      case TargetPlatform.fuchsia:
        m_themeColor = theme.highlightColor.withOpacity(1.0);
        m_textDirection = Directionality.of(context);
        m_materialPainter = _buildMaterialScrollbarPainter();
        break;
    }
  }

  ScrollbarPainter _buildMaterialScrollbarPainter() {
    return ScrollbarPainter(
        color: m_themeColor,
        textDirection: m_textDirection,
        thickness: _kScrollbarThickness,
        fadeoutOpacityAnimation: m_fadeoutOpacityAnimation,
      );
  }

  bool _handleScrollNotification(ScrollNotification notification) {
    // iOS sub-delegates to the CupertinoScrollbar instead and doesn't handle
    // scroll notifications here.
    if (m_currentPlatform != TargetPlatform.iOS
        && (notification is ScrollUpdateNotification
            || notification is OverscrollNotification)) {
      if (m_fadeoutAnimationController.status != AnimationStatus.forward) {
        m_fadeoutAnimationController.forward();
      }

      m_materialPainter.update(notification.metrics, notification.metrics.axisDirection);
      m_fadeoutTimer?.cancel();
      m_fadeoutTimer = Timer(_kScrollbarTimeToFade, () {
        m_fadeoutAnimationController.reverse();
        m_fadeoutTimer = null;
      });
    }
    return false;
  }

  @override
  void dispose() {
    m_fadeoutAnimationController.dispose();
    m_fadeoutTimer?.cancel();
    m_materialPainter?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    switch (m_currentPlatform) {
      case TargetPlatform.iOS:
        return CupertinoScrollbar(
          child: widget.child,
        );
      case TargetPlatform.android:
      case TargetPlatform.fuchsia:
        return NotificationListener<ScrollNotification>(
          onNotification: _handleScrollNotification,
          child: RepaintBoundary(
            child: CustomPaint(
              foregroundPainter: m_materialPainter,
              child: RepaintBoundary(
                child: widget.child,
              ),
            ),
          ),
        );
    }
    throw FlutterError('Unknown platform for scrollbar insertion');
  }
}
