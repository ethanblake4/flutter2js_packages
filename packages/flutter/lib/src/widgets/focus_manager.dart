// Copyright 2017 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:async';

import 'package:flutter/foundation.dart';

/// A leaf node in the focus tree that can receive focus.
///
/// The focus tree keeps track of which widget is the user's current focus. The
/// focused widget often listens for keyboard events.
///
/// To request focus, find the [FocusScopeNode] for the current [BuildContext]
/// and call the [FocusScopeNode.requestFocus] method:
///
/// ```dart
/// FocusScope.of(context).requestFocus(focusNode);
/// ```
///
/// If your widget requests focus, be sure to call
/// `FocusScope.of(context).reparentIfNeeded(focusNode);` in your `build`
/// method to reparent your [FocusNode] if your widget moves from one
/// location in the tree to another.
///
/// ## Lifetime
///
/// Focus nodes are long-lived objects. For example, if a stateful widget has a
/// focusable child widget, it should create a [FocusNode] in the
/// [State.initState] method, and [dispose] it in the [State.dispose] method,
/// providing the same [FocusNode] to the focusable child each time the
/// [State.build] method is run. In particular, creating a [FocusNode] each time
/// [State.build] is invoked will cause the focus to be lost each time the
/// widget is built.
///
/// See also:
///
///  * [FocusScopeNode], which is an interior node in the focus tree.
///  * [FocusScope.of], which provides the [FocusScopeNode] for a given
///    [BuildContext].
class FocusNode extends ChangeNotifier {
  FocusScopeNode _parent;
  FocusManager _manager;
  bool _hasKeyboardToken = false;

  /// Whether this node has the overall focus.
  ///
  /// A [FocusNode] has the overall focus when the node is focused in its
  /// parent [FocusScopeNode] and [FocusScopeNode.isFirstFocus] is true for
  /// that scope and all its ancestor scopes.
  ///
  /// To request focus, find the [FocusScopeNode] for the current [BuildContext]
  /// and call the [FocusScopeNode.requestFocus] method:
  ///
  /// ```dart
  /// FocusScope.of(context).requestFocus(focusNode);
  /// ```
  ///
  /// This object notifies its listeners whenever this value changes.
  bool get hasFocus => _manager?._currentFocus == this;

  /// Removes the keyboard token from this focus node if it has one.
  ///
  /// This mechanism helps distinguish between an input control gaining focus by
  /// default and gaining focus as a result of an explicit user action.
  ///
  /// When a focus node requests the focus (either via
  /// [FocusScopeNode.requestFocus] or [FocusScopeNode.autofocus]), the focus
  /// node receives a keyboard token if it does not already have one. Later,
  /// when the focus node becomes focused, the widget that manages the
  /// [TextInputConnection] should show the keyboard (i.e., call
  /// [TextInputConnection.show]) only if it successfully consumes the keyboard
  /// token from the focus node.
  ///
  /// Returns whether this function successfully consumes a keyboard token.
  bool consumeKeyboardToken() {
    if (!_hasKeyboardToken)
      return false;
    _hasKeyboardToken = false;
    return true;
  }

  /// Cancels any outstanding requests for focus.
  ///
  /// This method is safe to call regardless of whether this node has ever
  /// requested focus.
  void unfocus() {
    _parent?._resignFocus(this);
    assert(_parent == null);
    assert(_manager == null);
  }

  @override
  void dispose() {
    _manager?._willDisposeFocusNode(this);
    _parent?._resignFocus(this);
    assert(_parent == null);
    assert(_manager == null);
    super.dispose();
  }

  void _notify() {
    notifyListeners();
  }

  @override
  String toString() => '${describeIdentity(this)}${hasFocus ? '(FOCUSED)' : ''}';
}

/// An interior node in the focus tree.
///
/// The focus tree keeps track of which widget is the user's current focus. The
/// focused widget often listens for keyboard events.
///
/// The interior nodes in the focus tree cannot themselves be focused but
/// instead remember previous focus states. A scope is currently active in its
/// parent whenever [isFirstFocus] is true. If that scope is detached from its
/// parent, its previous sibling becomes the parent's first focus.
///
/// A [FocusNode] has the overall focus when the node is focused in its
/// parent [FocusScopeNode] and [FocusScopeNode.isFirstFocus] is true for
/// that scope and all its ancestor scopes.
///
/// See also:
///
///  * [FocusNode], which is a leaf node in the focus tree that can receive
///    focus.
///  * [FocusScope.of], which provides the [FocusScopeNode] for a given
///    [BuildContext].
///  * [FocusScope], which is a widget that associates a [FocusScopeNode] with
///    its location in the tree.
class FocusScopeNode extends Object with DiagnosticableTreeMixin {
  FocusManager m_manager;
  FocusScopeNode m_parent;

  FocusScopeNode m_nextSibling;
  FocusScopeNode m_previousSibling;

  FocusScopeNode m_firstChild;
  FocusScopeNode m_lastChild;

  FocusNode m_focus;

  /// Whether this scope is currently active in its parent scope.
  bool get isFirstFocus => m_parent == null || m_parent.m_firstChild == this;

  void _prepend(FocusScopeNode child) {
    assert(child != this);
    assert(child != m_firstChild);
    assert(child != m_lastChild);
    assert(child.m_parent == null);
    assert(child.m_manager == null);
    assert(child.m_nextSibling == null);
    assert(child.m_previousSibling == null);
    assert(() {
      FocusScopeNode node = this;
      while (node.m_parent != null)
        node = node.m_parent;
      assert(node != child); // indicates we are about to create a cycle
      return true;
    }());
    child.m_parent = this;
    child.m_nextSibling = m_firstChild;
    if (m_firstChild != null)
      m_firstChild.m_previousSibling = child;
    m_firstChild = child;
    m_lastChild ??= child;
    child._updateManager(m_manager);
  }

  void _updateManager(FocusManager manager) {
    void update(FocusScopeNode child) {
      if (child.m_manager == manager)
        return;
      child.m_manager = manager;
      // We don't proactively null out the manager for FocusNodes because the
      // manager holds the currently active focus node until the end of the
      // microtask, even if that node is detached from the focus tree.
      if (manager != null)
        child.m_focus?._manager = manager;
      child._visitChildren(update);
    }

    update(this);
  }

  void _visitChildren(void visitor(FocusScopeNode child)) {
    FocusScopeNode child = m_firstChild;
    while (child != null) {
      visitor(child);
      child = child.m_nextSibling;
    }
  }

  bool _debugUltimatePreviousSiblingOf(FocusScopeNode child, { FocusScopeNode equals }) {
    while (child.m_previousSibling != null) {
      assert(child.m_previousSibling != child);
      child = child.m_previousSibling;
    }
    return child == equals;
  }

  bool _debugUltimateNextSiblingOf(FocusScopeNode child, { FocusScopeNode equals }) {
    while (child.m_nextSibling != null) {
      assert(child.m_nextSibling != child);
      child = child.m_nextSibling;
    }
    return child == equals;
  }

  void _remove(FocusScopeNode child) {
    assert(child.m_parent == this);
    assert(child.m_manager == m_manager);
    assert(_debugUltimatePreviousSiblingOf(child, equals: m_firstChild));
    assert(_debugUltimateNextSiblingOf(child, equals: m_lastChild));
    if (child.m_previousSibling == null) {
      assert(m_firstChild == child);
      m_firstChild = child.m_nextSibling;
    } else {
      child.m_previousSibling.m_nextSibling = child.m_nextSibling;
    }
    if (child.m_nextSibling == null) {
      assert(m_lastChild == child);
      m_lastChild = child.m_previousSibling;
    } else {
      child.m_nextSibling.m_previousSibling = child.m_previousSibling;
    }
    child.m_previousSibling = null;
    child.m_nextSibling = null;
    child.m_parent = null;
    child._updateManager(null);
  }

  void _didChangeFocusChain() {
    if (isFirstFocus)
      m_manager?._markNeedsUpdate();
  }

  /// Requests that the given node becomes the focus for this scope.
  ///
  /// If the given node is currently focused in another scope, the node will
  /// first be unfocused in that scope.
  ///
  /// The node will receive the overall focus if this [isFirstFocus] is true
  /// in this scope and all its ancestor scopes. The node is notified that it
  /// has received the overall focus in a microtask.
  void requestFocus(FocusNode node) {
    assert(node != null);
    if (m_focus == node)
      return;
    m_focus?.unfocus();
    node._hasKeyboardToken = true;
    _setFocus(node);
  }

  /// If this scope lacks a focus, request that the given node becomes the
  /// focus.
  ///
  /// Useful for widgets that wish to grab the focus if no other widget already
  /// has the focus.
  ///
  /// The node is notified that it has received the overall focus in a
  /// microtask.
  void autofocus(FocusNode node) {
    assert(node != null);
    if (m_focus == null) {
      node._hasKeyboardToken = true;
      _setFocus(node);
    }
  }

  /// Adopts the given node if it is focused in another scope.
  ///
  /// A widget that requests that a node is focused should call this method
  /// during its `build` method in case the widget is moved from one location
  /// in the tree to another location that has a different focus scope.
  void reparentIfNeeded(FocusNode node) {
    assert(node != null);
    if (node._parent == null || node._parent == this)
      return;
    node.unfocus();
    assert(node._parent == null);
    if (m_focus == null)
      _setFocus(node);
  }

  void _setFocus(FocusNode node) {
    assert(node != null);
    assert(node._parent == null);
    assert(m_focus == null);
    m_focus = node;
    m_focus._parent = this;
    m_focus._manager = m_manager;
    m_focus._hasKeyboardToken = true;
    _didChangeFocusChain();
  }

  void _resignFocus(FocusNode node) {
    assert(node != null);
    if (m_focus != node)
      return;
    m_focus._parent = null;
    m_focus._manager = null;
    m_focus = null;
    _didChangeFocusChain();
  }

  /// Makes the given child the first focus of this scope.
  ///
  /// If the child has another parent scope, the child is first removed from
  /// that scope. After this method returns [isFirstFocus] will be true for
  /// the child.
  void setFirstFocus(FocusScopeNode child) {
    assert(child != null);
    assert(child.m_parent == null || child.m_parent == this);
    if (m_firstChild == child)
      return;
    child.detach();
    _prepend(child);
    assert(child.m_parent == this);
    _didChangeFocusChain();
  }

  /// Adopts the given scope if it is the first focus of another scope.
  ///
  /// A widget that sets a scope as the first focus of another scope should
  /// call this method during its `build` method in case the widget is moved
  /// from one location in the tree to another location that has a different
  /// focus scope.
  ///
  /// If the given scope is not the first focus of its old parent, the scope
  /// is simply detached from its old parent.
  void reparentScopeIfNeeded(FocusScopeNode child) {
    assert(child != null);
    if (child.m_parent == null || child.m_parent == this)
      return;
    if (child.isFirstFocus)
      setFirstFocus(child);
    else
      child.detach();
  }

  /// Remove this scope from its parent child list.
  ///
  /// This method is safe to call even if this scope does not have a parent.
  ///
  /// A widget that sets a scope as the first focus of another scope should
  /// call this method during [State.dispose] to avoid leaving dangling
  /// children in their parent scope.
  void detach() {
    _didChangeFocusChain();
    m_parent?._remove(this);
    assert(m_parent == null);
  }

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    if (m_focus != null)
      properties.add(DiagnosticsProperty<FocusNode>('focus', m_focus));
  }

  @override
  List<DiagnosticsNode> debugDescribeChildren() {
    final List<DiagnosticsNode> children = <DiagnosticsNode>[];
    if (m_firstChild != null) {
      FocusScopeNode child = m_firstChild;
      int count = 1;
      while (true) {
        children.add(child.toDiagnosticsNode(name: 'child $count'));
        if (child == m_lastChild)
          break;
        child = child.m_nextSibling;
        count += 1;
      }
    }
    return children;
  }
}

/// Manages the focus tree.
///
/// The focus tree keeps track of which widget is the user's current focus. The
/// focused widget often listens for keyboard events.
///
/// The focus manager is responsible for holding the [FocusScopeNode] that is
/// the root of the focus tree and tracking which [FocusNode] has the overall
/// focus.
///
/// The [FocusManager] is held by the [WidgetsBinding] as
/// [WidgetsBinding.focusManager]. The [FocusManager] is rarely accessed
/// directly. Instead, to find the [FocusScopeNode] for a given [BuildContext],
/// use [FocusScope.of].
///
/// See also:
///
///  * [FocusNode], which is a leaf node in the focus tree that can receive
///    focus.
///  * [FocusScopeNode], which is an interior node in the focus tree.
///  * [FocusScope.of], which provides the [FocusScopeNode] for a given
///    [BuildContext].
class FocusManager {
  /// Creates an object that manages the focus tree.
  ///
  /// This constructor is rarely called directly. To access the [FocusManager],
  /// consider using [WidgetsBinding.focusManager] instead.
  FocusManager() {
    rootScope.m_manager = this;
    assert(rootScope.m_firstChild == null);
    assert(rootScope.m_lastChild == null);
  }

  /// The root [FocusScopeNode] in the focus tree.
  ///
  /// This field is rarely used direction. Instead, to find the
  /// [FocusScopeNode] for a given [BuildContext], use [FocusScope.of].
  final FocusScopeNode rootScope = FocusScopeNode();

  FocusNode _currentFocus;

  void _willDisposeFocusNode(FocusNode node) {
    assert(node != null);
    if (_currentFocus == node)
      _currentFocus = null;
  }

  bool _haveScheduledUpdate = false;
  void _markNeedsUpdate() {
    if (_haveScheduledUpdate)
      return;
    _haveScheduledUpdate = true;
    scheduleMicrotask(_update);
  }

  FocusNode _findNextFocus() {
    FocusScopeNode scope = rootScope;
    while (scope.m_firstChild != null)
      scope = scope.m_firstChild;
    return scope.m_focus;
  }

  void _update() {
    _haveScheduledUpdate = false;
    final FocusNode nextFocus = _findNextFocus();
    if (_currentFocus == nextFocus)
      return;
    final FocusNode previousFocus = _currentFocus;
    _currentFocus = nextFocus;
    previousFocus?._notify();
    _currentFocus?._notify();
  }

  @override
  String toString() {
    final String status = _haveScheduledUpdate ? ' UPDATE SCHEDULED' : '';
    const String indent = '  ';
    return '${describeIdentity(this)}$status\n'
      '${indent}currentFocus: $_currentFocus\n'
      '${rootScope.toStringDeep(prefixLineOne: indent, prefixOtherLines: indent)}';
  }
}
