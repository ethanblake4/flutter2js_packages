// Copyright 2016 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:flutter/widgets.dart';

import 'colors.dart';
import 'icons.dart';
import 'list_tile.dart';
import 'theme.dart';
import 'theme_data.dart';

/// This enum is deprecated. Please use [ListTileTheme] instead.
enum MaterialListType {
  /// A list tile that contains a single line of text.
  oneLine,

  /// A list tile that contains a [CircleAvatar] followed by a single line of text.
  oneLineWithAvatar,

  /// A list tile that contains two lines of text.
  twoLine,

  /// A list tile that contains three lines of text.
  threeLine,
}

/// This constant is deprecated. The [ListTile] class sizes itself based on
/// its content and [ListTileTheme].
@deprecated
Map<MaterialListType, double> kListTileExtent = const <MaterialListType, double>{
  MaterialListType.oneLine: 48.0,
  MaterialListType.oneLineWithAvatar: 56.0,
  MaterialListType.twoLine: 72.0,
  MaterialListType.threeLine: 88.0,
};

const Duration _kExpand = Duration(milliseconds: 200);

/// This class is deprecated. Please use [ListTile] instead.
@deprecated
class TwoLevelListItem extends StatelessWidget {
  /// Creates an item in a two-level list.
  const TwoLevelListItem({
    Key key,
    this.leading,
    @required this.title,
    this.trailing,
    this.enabled = true,
    this.onTap,
    this.onLongPress
  }) : assert(title != null),
       super(key: key);

  /// A widget to display before the title.
  ///
  /// Typically a [CircleAvatar] widget.
  final Widget leading;

  /// The primary content of the list item.
  ///
  /// Typically a [Text] widget.
  final Widget title;

  /// A widget to display after the title.
  ///
  /// Typically an [Icon] widget.
  final Widget trailing;

  /// Whether this list item is interactive.
  ///
  /// If false, this list item is styled with the disabled color from the
  /// current [Theme] and the [onTap] and [onLongPress] callbacks are
  /// inoperative.
  final bool enabled;

  /// Called when the user taps this list item.
  ///
  /// Inoperative if [enabled] is false.
  final GestureTapCallback onTap;

  /// Called when the user long-presses on this list item.
  ///
  /// Inoperative if [enabled] is false.
  final GestureLongPressCallback onLongPress;

  @override
  Widget build(BuildContext context) {
    final TwoLevelList parentList = context.ancestorWidgetOfExactType(TwoLevelList);
    assert(parentList != null);

    return SizedBox(
      height: kListTileExtent[parentList.type],
      child: ListTile(
        leading: leading,
        title: title,
        trailing: trailing,
        enabled: enabled,
        onTap: onTap,
        onLongPress: onLongPress
      )
    );
  }
}

/// This class is deprecated. Please use [ExpansionTile] instead.
@deprecated
class TwoLevelSublist extends StatefulWidget {
  /// Creates an item in a two-level list that can expand and collapse.
  const TwoLevelSublist({
    Key key,
    this.leading,
    @required this.title,
    this.backgroundColor,
    this.onOpenChanged,
    this.children = const <Widget>[],
  }) : super(key: key);

  /// A widget to display before the title.
  ///
  /// Typically a [CircleAvatar] widget.
  final Widget leading;

  /// The primary content of the list item.
  ///
  /// Typically a [Text] widget.
  final Widget title;

  /// Called when the sublist expands or collapses.
  ///
  /// When the sublist starts expanding, this function is called with the value
  /// true. When the sublist starts collapsing, this function is called with
  /// the value false.
  final ValueChanged<bool> onOpenChanged;

  /// The widgets that are displayed when the sublist expands.
  ///
  /// Typically [TwoLevelListItem] widgets.
  final List<Widget> children;

  /// The color to display behind the sublist when expanded.
  final Color backgroundColor;

  @override
  _TwoLevelSublistState createState() => _TwoLevelSublistState();
}

@deprecated
class _TwoLevelSublistState extends State<TwoLevelSublist> with SingleTickerProviderStateMixin {
  AnimationController mcontroller;
  CurvedAnimation measeOutAnimation;
  CurvedAnimation m_easeInAnimation;
  ColorTween m_borderColor;
  ColorTween m_headerColor;
  ColorTween m_iconColor;
  ColorTween m_backgroundColor;
  Animation<double> m_iconTurns;

  bool _isExpanded = false;

  @override
  void initState() {
    super.initState();
    mcontroller = AnimationController(duration: _kExpand, vsync: this);
    measeOutAnimation = CurvedAnimation(parent: mcontroller, curve: Curves.easeOut);
    m_easeInAnimation = CurvedAnimation(parent: mcontroller, curve: Curves.easeIn);
    m_borderColor = ColorTween(begin: Colors.transparent);
    m_headerColor = ColorTween();
    m_iconColor = ColorTween();
    m_iconTurns = Tween<double>(begin: 0.0, end: 0.5).animate(m_easeInAnimation);
    m_backgroundColor = ColorTween();

    _isExpanded = PageStorage.of(context)?.readState(context) ?? false;
    if (_isExpanded)
      mcontroller.value = 1.0;
  }

  @override
  void dispose() {
    mcontroller.dispose();
    super.dispose();
  }

  void _handleOnTap() {
    setState(() {
      _isExpanded = !_isExpanded;
      if (_isExpanded)
        mcontroller.forward();
      else
        mcontroller.reverse();
      PageStorage.of(context)?.writeState(context, _isExpanded);
    });
    if (widget.onOpenChanged != null)
      widget.onOpenChanged(_isExpanded);
  }

  Widget buildList(BuildContext context, Widget child) {
    return Container(
      decoration: BoxDecoration(
        color: m_backgroundColor.evaluate(measeOutAnimation),
        border: Border(
          top: BorderSide(color: m_borderColor.evaluate(measeOutAnimation)),
          bottom: BorderSide(color: m_borderColor.evaluate(measeOutAnimation))
        )
      ),
      child: Column(
        children: <Widget>[
          IconTheme.merge(
            data: IconThemeData(color: m_iconColor.evaluate(m_easeInAnimation)),
            child: TwoLevelListItem(
              onTap: _handleOnTap,
              leading: widget.leading,
              title: DefaultTextStyle(
                style: Theme.of(context).textTheme.subhead.copyWith(color: m_headerColor.evaluate(m_easeInAnimation)),
                child: widget.title
              ),
              trailing: RotationTransition(
                turns: m_iconTurns,
                child: const Icon(Icons.expand_more)
              )
            )
          ),
          ClipRect(
            child: Align(
              heightFactor: m_easeInAnimation.value,
              child: Column(children: widget.children)
            )
          )
        ]
      )
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
    m_backgroundColor
      ..begin = Colors.transparent
      ..end = widget.backgroundColor ?? Colors.transparent;

    return AnimatedBuilder(
      animation: mcontroller.view,
      builder: buildList
    );
  }
}

/// This class is deprecated. Please use [ListView] and [ListTileTheme] instead.
@deprecated
class TwoLevelList extends StatelessWidget {
  /// Creates a scrollable list of items that can expand and collapse.
  ///
  /// The [type] argument must not be null.
  const TwoLevelList({
    Key key,
    this.children = const <Widget>[],
    this.type = MaterialListType.twoLine,
    this.padding,
  }) : assert(type != null),
       super(key: key);

  /// The widgets to display in this list.
  ///
  /// Typically [TwoLevelListItem] or [TwoLevelSublist] widgets.
  final List<Widget> children;

  /// The kind of [ListTile] contained in this list.
  final MaterialListType type;

  /// The amount of space by which to inset the children inside the viewport.
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: padding,
      shrinkWrap: true,
      children: KeyedSubtree.ensureUniqueKeysForList(children),
    );
  }
}
