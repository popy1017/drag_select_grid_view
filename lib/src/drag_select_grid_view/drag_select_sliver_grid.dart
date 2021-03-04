import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../auto_scroll/auto_scroller_mixin.dart';
import 'drag_select_grid_view.dart';
import 'drag_select_grid_view_controller.dart';
import 'selectable.dart';
import 'selection.dart';

///
class DragSelectSliverGrid extends StatefulWidget {
  ///
  DragSelectSliverGrid({
    Key key,
    double autoScrollHotspotHeight,
    ScrollController scrollController,
    this.gridController,
    this.unselectOnWillPop = true,
    this.reverse = false,
    this.primary,
    this.physics,
    this.shrinkWrap = false,
    this.padding,
    @required this.gridDelegate,
    @required this.delegate,
    @required this.itemBuilder,
    this.sliverAppBar,
    this.itemCount,
    this.addAutomaticKeepAlives = true,
    this.addRepaintBoundaries = true,
    this.addSemanticIndexes = true,
    this.cacheExtent,
    this.semanticChildCount,
  })  : assert(itemBuilder != null),
        autoScrollHotspotHeight =
            autoScrollHotspotHeight ?? defaultAutoScrollHotspotHeight,
        scrollController = scrollController ?? ScrollController(),
        super(key: key);

  static const defaultAutoScrollHotspotHeight = 64.0;

  /// The height of the hotspot that enables auto-scroll.
  ///
  /// This value is used for both top and bottom hotspots. The width is going to
  /// match the width of the widget.
  ///
  /// Defaults to [defaultAutoScrollHotspotHeight].
  final double autoScrollHotspotHeight;

  /// Refer to [ScrollView.controller].
  final ScrollController scrollController;

  /// Controller of the grid.
  ///
  /// Provides information that can be used to update the UI to indicate whether
  /// there are selected items and how many are selected.
  ///
  /// Also allows to directly update the selected items.
  ///
  /// This controller may not be used after [DragSelectGridViewState] disposes,
  /// since [DragSelectGridViewController.dispose] will get called and the
  /// listeners are going to be cleaned up.
  final DragSelectGridViewController gridController;

  /// Whether the items should be unselected when trying to pop the route.
  ///
  /// Normally, this is used to unselect the items when Android users tap the
  /// back-button in the navigation bar.
  ///
  /// By leaving this false, you may implement your own on-pop unselecting logic
  /// with [gridController]'s help.
  ///
  /// Defaults to true.
  final bool unselectOnWillPop;

  /// Refer to [ScrollView.reverse].
  final bool reverse;

  /// Refer to [ScrollView.primary].
  final bool primary;

  /// Refer to [ScrollView.physics].
  final ScrollPhysics physics;

  /// Refer to [ScrollView.shrinkWrap].
  final bool shrinkWrap;

  /// Refer to [BoxScrollView.padding].
  final EdgeInsetsGeometry padding;

  /// Refer to [GridView.gridDelegate].
  final SliverGridDelegate gridDelegate;

  /// refert to [SliverGrid.delegate]
  final SliverChildBuilderDelegate delegate;

  /// Called whenever a child needs to be built.
  ///
  /// The client should use this to build the children dynamically, based on
  /// the index and whether it is selected or not.
  ///
  /// Cannot be null.
  ///
  /// Also refer to [SliverChildBuilderDelegate.builder].
  final SelectableWidgetBuilder itemBuilder;

  /// sliver appbar
  final Widget sliverAppBar;

  /// Refer to [SliverChildBuilderDelegate.childCount].
  final int itemCount;

  /// Refer to [SliverChildBuilderDelegate.addAutomaticKeepAlives].
  final bool addAutomaticKeepAlives;

  /// Refer to [SliverChildBuilderDelegate.addRepaintBoundaries].
  final bool addRepaintBoundaries;

  /// Refer to [SliverChildBuilderDelegate.addSemanticIndexes].
  final bool addSemanticIndexes;

  /// Refer to [ScrollView.cacheExtent].
  final double cacheExtent;

  /// Refer to [ScrollView.semanticChildCount].
  final int semanticChildCount;

  @override
  _DragSelectSliverGridState createState() => _DragSelectSliverGridState();
}

class _DragSelectSliverGridState extends State<DragSelectSliverGrid>
    with AutoScrollerMixin<DragSelectSliverGrid> {
  final _elements = <SelectableElement>{};
  final _selectionManager = SelectionManager();
  LongPressMoveUpdateDetails _lastMoveUpdateDetails;

  DragSelectGridViewController get _gridController => widget.gridController;

  /// Indexes selected by dragging or tapping.
  Set<int> get selectedIndexes => _selectionManager.selectedIndexes;

  /// Whether any item got selected.
  bool get isSelecting => selectedIndexes.isNotEmpty;

  /// Whether drag gesture is being performed.
  bool get isDragging =>
      (_selectionManager.dragStartIndex != -1) &&
      (_selectionManager.dragEndIndex != -1);

  @override
  double get autoScrollHotspotHeight => widget.autoScrollHotspotHeight;

  @override
  ScrollController get scrollController => widget.scrollController;

  @override
  VoidCallback get scrollCallback {
    return () {
      if (_lastMoveUpdateDetails != null) {
        _handleLongPressMoveUpdate(_lastMoveUpdateDetails);
      }
    };
  }

  @override
  void initState() {
    super.initState();
    if (_gridController != null) {
      _gridController.addListener(_onSelectionChanged);
      _selectionManager.selectedIndexes = _gridController.value.selectedIndexes;
    }
  }

  @override
  void dispose() {
    _gridController?.removeListener(_onSelectionChanged);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return WillPopScope(
      onWillPop: _handleWillPop,
      child: GestureDetector(
        onTapUp: _handleTapUp,
        onLongPressStart: _handleLongPressStart,
        onLongPressMoveUpdate: _handleLongPressMoveUpdate,
        onLongPressEnd: _handleLongPressEnd,
        behavior: HitTestBehavior.translucent,
        child: IgnorePointer(
          ignoring: isDragging,
          child: CustomScrollView(
            controller: widget.scrollController,
            reverse: widget.reverse,
            primary: widget.primary,
            physics: widget.physics,
            shrinkWrap: widget.shrinkWrap,
            cacheExtent: widget.cacheExtent,
            semanticChildCount: widget.semanticChildCount,
            slivers: [
              if (widget.sliverAppBar != null) widget.sliverAppBar,
              SliverGrid(
                delegate: SliverChildBuilderDelegate(
                  (context, index) {
                    return Selectable(
                      index: index,
                      onMountElement: _elements.add,
                      onUnmountElement: _elements.remove,
                      child: widget.itemBuilder(
                        context,
                        index,
                        selectedIndexes.contains(index),
                      ),
                    );
                  },
                ),
                gridDelegate: widget.gridDelegate,
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _onSelectionChanged() {
    final controllerSelectedIndexes = _gridController.value.selectedIndexes;
    if (!setEquals(controllerSelectedIndexes, selectedIndexes)) {
      _selectionManager.selectedIndexes = controllerSelectedIndexes;
    }
  }

  Future<bool> _handleWillPop() async {
    if (isSelecting && widget.unselectOnWillPop) {
      setState(_selectionManager.clear);
      _notifySelectionChange();
      return false;
    } else {
      return true;
    }
  }

  void _handleTapUp(TapUpDetails details) {
    if (!isSelecting) return;

    final tapIndex = _findIndexOfSelectable(details.localPosition);

    if (tapIndex != -1) {
      setState(() => _selectionManager.tap(tapIndex));
      _notifySelectionChange();
    }
  }

  void _handleLongPressStart(LongPressStartDetails details) {
    final pressIndex = _findIndexOfSelectable(details.localPosition);

    if (pressIndex != -1) {
      setState(() => _selectionManager.startDrag(pressIndex));
      _notifySelectionChange();
    }
  }

  void _handleLongPressMoveUpdate(LongPressMoveUpdateDetails details) {
    if (!isDragging) return;

    _lastMoveUpdateDetails = details;
    final dragIndex = _findIndexOfSelectable(details.localPosition);

    if ((dragIndex != -1) && (dragIndex != _selectionManager.dragEndIndex)) {
      setState(() => _selectionManager.updateDrag(dragIndex));
      _notifySelectionChange();
    }

    if (isInsideUpperAutoScrollHotspot(details.localPosition)) {
      if (widget.reverse) {
        startAutoScrollingForward();
      } else {
        startAutoScrollingBackward();
      }
    } else if (isInsideLowerAutoScrollHotspot(details.localPosition)) {
      if (widget.reverse) {
        startAutoScrollingBackward();
      } else {
        startAutoScrollingForward();
      }
    } else {
      stopScrolling();
    }
  }

  void _handleLongPressEnd(LongPressEndDetails details) {
    setState(_selectionManager.endDrag);
    stopScrolling();
  }

  int _findIndexOfSelectable(Offset offset) {
    final ancestor = context.findRenderObject();
    var elementFinder = Set.of(_elements).firstWhere;

    // Conceptually, `Set.singleWhere()` is the safer option, however we're
    // avoiding to iterate over the whole `Set` to improve the performance.
    assert(() {
      elementFinder = Set.of(_elements).singleWhere;
      return true;
    }());

    final element = elementFinder(
      (element) => element.containsOffset(ancestor, offset),
      orElse: () => null,
    );

    return (element == null) ? -1 : element.widget.index;
  }

  void _notifySelectionChange() {
    _gridController?.value = Selection(_selectionManager.selectedIndexes);
  }
}
