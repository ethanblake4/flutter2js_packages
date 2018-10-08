// Copyright 2017 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:flutter/widgets.dart';

import 'colors.dart';
import 'icons.dart';
import 'list_tile.dart';
import 'theme.dart';
import 'theme_data.dart';

const Duration _kExpand = Duration(milliseconds: 200);

/// A single-line [ListTile] with a trailing button that expands or collapses
/// the tile to reveal or hide the [children].
///
/// This widget is typically used with [ListView] to create an
/// "expand / collapse" list entry. When used with scrolling widgets like
/// [ListView], a unique [PageStorageKey] must be specified to enable the
/// [ExpansionTile] to save and restore its expanded state when it is scrolled
/// in and out of view.
///
/// See also:
///
///  * [ListTile], useful for creating expansion tile [children] when the
///    expansion tile represents a sublist.
///  * The "Expand/collapse" section of
///    <https://material.io/guidelines/components/lists-controls.html>.
class ExpansionTile extends StatefulWidget {
  /// Creates a single-line [ListTile] with a trailing button that expands or collapses
  /// the tile to reveal or hide the [children]. The [initiallyExpanded] property must
  /// be non-null.
  const ExpansionTile({
    Key key,
    this.leading,
    @required this.title,
    this.backgroundColor,
    this.onExpansionChanged,
    this.children = const <Widget>[],
    this.trailing,
    this.initiallyExpanded = false,
  }) : assert(initiallyExpanded != null),
       super(key: key);

  /// A widget to display before the title.
  ///
  /// Typically a [CircleAvatar] widget.
  final Widget leading;

  /// The primary content of the list item.
  ///
  /// Typically a [Text] widget.
  final Widget title;

  /// Called when the tile expands or collapses.
  ///
  /// When the tile starts expanding, this function is called with the value
  /// true. When the tile starts collapsing, this function is called with
  /// the value false.
  final ValueChanged<bool> onExpansionChanged;

  /// The widgets that are displayed when the tile expands.
  ///
  /// Typically [ListTile] widgets.
  final List<Widget> children;

  /// The color to display behind the sublist when expanded.
  final Color backgroundColor;

  /// A widget to display instead of a rotating arrow icon.
  final Widget trailing;

  /// Specifies if the list tile is initially expanded (true) or collapsed (false, the default).
  final bool initiallyExpanded;

  @override
  _ExpansionTileState createState() => _ExpansionTileState();
}

class _ExpansionTileState extends State<ExpansionTile> with SingleTickerProviderStateMixin {
  AnimationController m_controller;
  CurvedAnimation m_easeOutAnimation;
  CurvedAnimation m_easeInAnimation;
  ColorTween m_borderColor;
  ColorTween m_headerColor;
  ColorTween m_iconColor;
  ColorTween m_backgroundColor;
  Animation<double> m_iconTurns;

  bool m_isExpanded = false;

  @override
  void initState() {
    super.initState();
    m_controller = AnimationController(duration: _kExpand, vsync: this);
    m_easeOutAnimation = CurvedAnimation(parent: m_controller, curve: Curves.easeOut);
    m_easeInAnimation = CurvedAnimation(parent: m_controller, curve: Curves.easeIn);
    m_borderColor = ColorTween();
    m_headerColor = ColorTween();
    m_iconColor = ColorTween();
    m_iconTurns = Tween<double>(begin: 0.0, end: 0.5).animate(m_easeInAnimation);
    m_backgroundColor = ColorTween();

    m_isExpanded = PageStorage.of(context)?.readState(context) ?? widget.initiallyExpanded;
    if (m_isExpanded)
      m_controller.value = 1.0;
  }

  @override
  void dispose() {
    m_controller.dispose();
    super.dispose();
  }

  void _handleTap() {
    setState(() {
      m_isExpanded = !m_isExpanded;
      if (m_isExpanded)
        m_controller.forward();
      else
        m_controller.reverse().then<void>((Null value) {
          setState(() {
            // Rebuild without widget.children.
          });
        });
      PageStorage.of(context)?.writeState(context, m_isExpanded);
    });
    if (widget.onExpansionChanged != null)
      widget.onExpansionChanged(m_isExpanded);
  }

  Widget _buildChildren(BuildContext context, Widget child) {
    final Color borderSideColor = m_borderColor.evaluate(m_easeOutAnimation) ?? Colors.transparent;
    final Color titleColor = m_headerColor.evaluate(m_easeInAnimation);

    return Container(
      decoration: BoxDecoration(
        color: m_backgroundColor.evaluate(m_easeOutAnimation) ?? Colors.transparent,
        border: Border(
          top: BorderSide(color: borderSideColor),
          bottom: BorderSide(color: borderSideColor),
        )
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          IconTheme.merge(
            data: IconThemeData(color: m_iconColor.evaluate(m_easeInAnimation)),
            child: ListTile(
              onTap: _handleTap,
              leading: widget.leading,
              title: DefaultTextStyle(
                style: Theme.of(context).textTheme.subhead.copyWith(color: titleColor),
                child: widget.title,
              ),
              trailing: widget.trailing ?? RotationTransition(
                turns: m_iconTurns,
                child: const Icon(Icons.expand_more),
              ),
            ),
          ),
          ClipRect(
            child: Align(
              heightFactor: m_easeInAnimation.value,
              child: child,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    m_borderColor.end = theme.dividerColor;
    m_headerColor
      ..begin = theme.textTheme.subhead.color
      ..end = theme.accentColor;
    m_iconColor
      ..begin = theme.unselectedWidgetColor
      ..end = theme.accentColor;
    m_backgroundColor.end = widget.backgroundColor;

    final bool closed = !m_isExpanded && m_controller.isDismissed;
    return AnimatedBuilder(
      animation: m_controller.view,
      builder: _buildChildren,
      child: closed ? null : Column(children: widget.children),
    );

  }
}
