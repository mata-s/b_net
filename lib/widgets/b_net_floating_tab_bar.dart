import 'dart:ui';

import 'package:flutter/material.dart';

class BNetTabItem {
  const BNetTabItem({
    required this.label,
    required this.icon,
    this.selectedIcon,
    this.badgeCount = 0,
  });

  final String label;
  final IconData icon;
  final IconData? selectedIcon;
  final int badgeCount;
}

class BNetFloatingTabBar extends StatelessWidget {
  const BNetFloatingTabBar({
    super.key,
    required this.items,
    required this.selectedIndex,
    required this.onSelected,
  }) : assert(items.length > 1);

  final List<BNetTabItem> items;
  final int selectedIndex;
  final ValueChanged<int> onSelected;

  static const _animationDuration = Duration(milliseconds: 260);
  static const double barHeight = 84;
  static const double _bottomGap = 20;
  static const double contentClearance = barHeight + 10;

  static double bodyClearance(BuildContext _) => contentClearance;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: barHeight,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(10, 0, 10, _bottomGap),
        child: RepaintBoundary(
          child: DecoratedBox(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(30),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x240C3158),
                  blurRadius: 22,
                  offset: Offset(0, 8),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(30),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: const Color(0xC7F8FBFF),
                    borderRadius: BorderRadius.circular(30),
                    border: Border.all(color: const Color(0xE6FFFFFF)),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(5),
                    child: LayoutBuilder(
                      builder: (context, constraints) {
                        final itemWidth = constraints.maxWidth / items.length;

                        return Stack(
                          children: [
                            AnimatedPositioned(
                              duration: _animationDuration,
                              curve: Curves.easeOutCubic,
                              left: selectedIndex * itemWidth,
                              top: 0,
                              bottom: 0,
                              width: itemWidth,
                              child: Padding(
                                padding:
                                    const EdgeInsets.symmetric(horizontal: 2),
                                child: DecoratedBox(
                                  decoration: BoxDecoration(
                                    gradient: const LinearGradient(
                                      begin: Alignment.topLeft,
                                      end: Alignment.bottomRight,
                                      colors: [
                                        Color(0xFF1877D2),
                                        Color(0xFF07549E),
                                      ],
                                    ),
                                    borderRadius: BorderRadius.circular(24),
                                    boxShadow: const [
                                      BoxShadow(
                                        color: Color(0x38136BB8),
                                        blurRadius: 12,
                                        offset: Offset(0, 4),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                            Row(
                              children: [
                                for (final entry in items.indexed)
                                  Expanded(
                                    child: _BNetTabButton(
                                      item: entry.$2,
                                      isSelected: selectedIndex == entry.$1,
                                      onTap: () => onSelected(entry.$1),
                                    ),
                                  ),
                              ],
                            ),
                          ],
                        );
                      },
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _BNetTabButton extends StatefulWidget {
  const _BNetTabButton({
    required this.item,
    required this.isSelected,
    required this.onTap,
  });

  final BNetTabItem item;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  State<_BNetTabButton> createState() => _BNetTabButtonState();
}

class _BNetTabButtonState extends State<_BNetTabButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _selectionController;
  late final Animation<double> _selectionScale;
  var _isPressed = false;

  @override
  void initState() {
    super.initState();
    _selectionController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 320),
    );
    _selectionScale = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween<double>(begin: 1, end: 1.16)
            .chain(CurveTween(curve: Curves.easeOutCubic)),
        weight: 45,
      ),
      TweenSequenceItem(
        tween: Tween<double>(begin: 1.16, end: 1)
            .chain(CurveTween(curve: Curves.easeOutBack)),
        weight: 55,
      ),
    ]).animate(_selectionController);
  }

  @override
  void didUpdateWidget(covariant _BNetTabButton oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isSelected && !oldWidget.isSelected) {
      _selectionController.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _selectionController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final foregroundColor =
        widget.isSelected ? Colors.white : const Color(0xFF587089);

    return Semantics(
      button: true,
      selected: widget.isSelected,
      label: widget.item.label,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapDown: (_) => setState(() => _isPressed = true),
        onTapCancel: () => setState(() => _isPressed = false),
        onTapUp: (_) {
          setState(() => _isPressed = false);
          widget.onTap();
        },
        child: AnimatedScale(
          scale: _isPressed ? 0.9 : 1,
          duration: const Duration(milliseconds: 110),
          curve: Curves.easeOut,
          child: AnimatedSlide(
            offset: widget.isSelected ? const Offset(0, -0.04) : Offset.zero,
            duration: const Duration(milliseconds: 220),
            curve: Curves.easeOutCubic,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                ScaleTransition(
                  scale: _selectionScale,
                  child: Stack(
                    clipBehavior: Clip.none,
                    children: [
                      AnimatedSwitcher(
                        duration: const Duration(milliseconds: 180),
                        transitionBuilder: (child, animation) => FadeTransition(
                          opacity: animation,
                          child: ScaleTransition(
                            scale: animation,
                            child: child,
                          ),
                        ),
                        child: Icon(
                          widget.isSelected
                              ? widget.item.selectedIcon ?? widget.item.icon
                              : widget.item.icon,
                          key: ValueKey(widget.isSelected),
                          color: foregroundColor,
                          size: 20,
                        ),
                      ),
                      Positioned(
                        right: -8,
                        top: -7,
                        child: AnimatedScale(
                          scale: widget.item.badgeCount > 0 ? 1 : 0,
                          duration: const Duration(milliseconds: 260),
                          curve: Curves.easeOutBack,
                          child: AnimatedSwitcher(
                            duration: const Duration(milliseconds: 180),
                            child: widget.item.badgeCount > 0
                                ? Container(
                                    key: ValueKey(widget.item.badgeCount),
                                    constraints: const BoxConstraints(
                                      minWidth: 16,
                                      minHeight: 16,
                                    ),
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 4,
                                    ),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFFF3B30),
                                      borderRadius: BorderRadius.circular(9),
                                      border: Border.all(
                                        color: Colors.white,
                                        width: 1.5,
                                      ),
                                    ),
                                    alignment: Alignment.center,
                                    child: Text(
                                      widget.item.badgeCount > 99
                                          ? '99+'
                                          : '${widget.item.badgeCount}',
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 8,
                                        height: 1,
                                        fontWeight: FontWeight.w800,
                                      ),
                                    ),
                                  )
                                : const SizedBox.shrink(),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 3),
                AnimatedDefaultTextStyle(
                  duration: const Duration(milliseconds: 220),
                  curve: Curves.easeOutCubic,
                  style: TextStyle(
                    color: foregroundColor,
                    fontSize: widget.isSelected ? 9.5 : 9,
                    height: 1,
                    fontWeight:
                        widget.isSelected ? FontWeight.w700 : FontWeight.w600,
                  ),
                  child: Text(
                    widget.item.label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
