import 'package:flutter/material.dart';

import '../theme/costa_norte_brand.dart';

ButtonStyle operationalTimelineSegmentStyle() => ButtonStyle(
  foregroundColor: WidgetStateProperty.resolveWith<Color>(
    (Set<WidgetState> states) => states.contains(WidgetState.selected)
        ? CostaNorteBrand.royalBlueDeep
        : CostaNorteBrand.mutedInk,
  ),
  backgroundColor: WidgetStateProperty.resolveWith<Color>(
    (Set<WidgetState> states) => states.contains(WidgetState.selected)
        ? CostaNorteBrand.gold.withValues(alpha: 0.22)
        : Colors.white,
  ),
  side: const WidgetStatePropertyAll<BorderSide>(
    BorderSide(color: CostaNorteBrand.line),
  ),
);

class OperationalTimelineEvent<T> {
  const OperationalTimelineEvent({
    required this.value,
    required this.date,
    required this.startMinutes,
    required this.endMinutes,
    required this.label,
    required this.color,
    required this.draggable,
  });

  final T value;
  final DateTime date;
  final int startMinutes;
  final int endMinutes;
  final String label;
  final Color color;
  final bool draggable;
}

class OperationalTimeline<T> extends StatelessWidget {
  const OperationalTimeline({
    required this.days,
    required this.selectedDate,
    required this.events,
    required this.onDayTap,
    required this.onEventTap,
    required this.onEventMove,
    this.onEmptySlotDoubleTap,
    this.openingHour = 6,
    this.closingHour = 23,
    this.snapMinutes = 30,
    super.key,
  });

  static const double _labelWidth = 108;
  static const double _timelineWidth = 932;
  static const List<String> _weekdays = <String>[
    'Seg',
    'Ter',
    'Qua',
    'Qui',
    'Sex',
    'Sab',
    'Dom',
  ];

  final List<DateTime> days;
  final DateTime selectedDate;
  final List<OperationalTimelineEvent<T>> events;
  final ValueChanged<DateTime> onDayTap;
  final ValueChanged<T> onEventTap;
  final void Function(T event, DateTime date, int startMinutes) onEventMove;
  final void Function(DateTime date, int startMinutes)? onEmptySlotDoubleTap;
  final int openingHour;
  final int closingHour;
  final int snapMinutes;

  int get _openingMinutes => openingHour * 60;
  int get _totalMinutes => (closingHour - openingHour) * 60;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: SizedBox(
        width: _labelWidth + _timelineWidth,
        child: Column(
          children: <Widget>[
            _buildHeader(context),
            ...days.map((DateTime day) => _buildDayRow(context, day)),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    final int hourCount = closingHour - openingHour;
    return SizedBox(
      height: 34,
      child: Row(
        children: <Widget>[
          const SizedBox(width: _labelWidth),
          SizedBox(
            width: _timelineWidth,
            child: Stack(
              children: List<Widget>.generate(hourCount + 1, (int index) {
                final double left = index * (_timelineWidth / hourCount);
                return Positioned(
                  left: index == hourCount ? left - 34 : left,
                  top: 4,
                  child: Text(
                    '${(openingHour + index).toString().padLeft(2, '0')}:00',
                    style: Theme.of(context).textTheme.labelMedium,
                  ),
                );
              }),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDayRow(BuildContext context, DateTime day) {
    final List<OperationalTimelineEvent<T>> dayEvents = events
        .where((OperationalTimelineEvent<T> event) => _sameDay(event.date, day))
        .toList();
    return Container(
      height: 68,
      decoration: BoxDecoration(
        color: _sameDay(day, selectedDate)
            ? CostaNorteBrand.sand.withValues(alpha: 0.65)
            : Colors.white,
        border: const Border(top: BorderSide(color: CostaNorteBrand.line)),
      ),
      child: Row(
        children: <Widget>[
          SizedBox(
            width: _labelWidth,
            child: InkWell(
              onTap: () => onDayTap(day),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 10),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      _weekdays[day.weekday - 1],
                      style: Theme.of(context).textTheme.labelLarge,
                    ),
                    Text(
                      '${day.day.toString().padLeft(2, '0')}/${day.month.toString().padLeft(2, '0')}',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
            ),
          ),
          SizedBox(
            width: _timelineWidth,
            height: 52,
            child: Builder(
              builder: (BuildContext timelineContext) {
                return DragTarget<OperationalTimelineEvent<T>>(
                  onWillAcceptWithDetails:
                      (
                        DragTargetDetails<OperationalTimelineEvent<T>> details,
                      ) => details.data.draggable,
                  onAcceptWithDetails:
                      (DragTargetDetails<OperationalTimelineEvent<T>> details) {
                        final RenderBox box =
                            timelineContext.findRenderObject()! as RenderBox;
                        final double localX = box
                            .globalToLocal(details.offset)
                            .dx;
                        final int duration =
                            details.data.endMinutes - details.data.startMinutes;
                        final int latestStart =
                            _openingMinutes + _totalMinutes - duration;
                        final int raw =
                            _openingMinutes +
                            (localX / _timelineWidth * _totalMinutes).round();
                        final int snapped =
                            ((raw / snapMinutes).round() * snapMinutes).clamp(
                              _openingMinutes,
                              latestStart,
                            );
                        onEventMove(details.data.value, day, snapped);
                      },
                  builder:
                      (
                        BuildContext context,
                        List<OperationalTimelineEvent<T>?> candidates,
                        List<dynamic> rejected,
                      ) {
                        return DecoratedBox(
                          decoration: BoxDecoration(
                            color: candidates.isNotEmpty
                                ? CostaNorteBrand.mint
                                : Colors.transparent,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Stack(
                            children: <Widget>[
                              if (onEmptySlotDoubleTap != null)
                                Positioned.fill(
                                  child: GestureDetector(
                                    behavior: HitTestBehavior.translucent,
                                    onDoubleTapDown: (TapDownDetails details) {
                                      final int raw =
                                          _openingMinutes +
                                          (details.localPosition.dx /
                                                  _timelineWidth *
                                                  _totalMinutes)
                                              .round();
                                      final int snapped =
                                          ((raw / snapMinutes).round() *
                                                  snapMinutes)
                                              .clamp(
                                                _openingMinutes,
                                                _openingMinutes +
                                                    _totalMinutes -
                                                    snapMinutes,
                                              );
                                      final bool occupied = dayEvents.any(
                                        (OperationalTimelineEvent<T> event) =>
                                            snapped >= event.startMinutes &&
                                            snapped < event.endMinutes,
                                      );
                                      if (!occupied) {
                                        onEmptySlotDoubleTap!(day, snapped);
                                      }
                                    },
                                  ),
                                ),
                              ...List<Widget>.generate(
                                closingHour - openingHour + 1,
                                (int index) => Positioned(
                                  left:
                                      index *
                                      (_timelineWidth /
                                          (closingHour - openingHour)),
                                  top: 0,
                                  bottom: 0,
                                  child: Container(
                                    width: 1,
                                    color: CostaNorteBrand.line,
                                  ),
                                ),
                              ),
                              ...dayEvents.map(_buildBar),
                            ],
                          ),
                        );
                      },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBar(OperationalTimelineEvent<T> event) {
    final int start = event.startMinutes.clamp(
      _openingMinutes,
      _openingMinutes + _totalMinutes,
    );
    final int end = event.endMinutes.clamp(
      _openingMinutes,
      _openingMinutes + _totalMinutes,
    );
    final double left =
        (start - _openingMinutes) / _totalMinutes * _timelineWidth;
    final double width = ((end - start) / _totalMinutes * _timelineWidth).clamp(
      4,
      _timelineWidth - left,
    );
    final Widget bar = Material(
      color: event.color,
      borderRadius: BorderRadius.circular(8),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => onEventTap(event.value),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 7),
          child: Align(
            alignment: Alignment.centerLeft,
            child: Text(
              event.label,
              maxLines: 1,
              overflow: TextOverflow.clip,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 11,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ),
      ),
    );
    return Positioned(
      left: left,
      top: 8,
      width: width,
      height: 36,
      child: Tooltip(
        message: event.draggable
            ? '${event.label}\nArraste para remarcar'
            : event.label,
        child: event.draggable
            ? Draggable<OperationalTimelineEvent<T>>(
                data: event,
                dragAnchorStrategy: pointerDragAnchorStrategy,
                feedback: SizedBox(width: width, height: 36, child: bar),
                childWhenDragging: Opacity(opacity: 0.3, child: bar),
                child: MouseRegion(cursor: SystemMouseCursors.grab, child: bar),
              )
            : bar,
      ),
    );
  }

  bool _sameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;
}

class OperationalTimelineLegend extends StatelessWidget {
  const OperationalTimelineLegend({
    required this.color,
    required this.label,
    this.selected = false,
    this.onTap,
    super.key,
  });

  final Color color;
  final String label;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final Widget content = Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
      decoration: BoxDecoration(
        color: selected ? color.withValues(alpha: 0.12) : Colors.transparent,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color: selected ? color : Colors.transparent,
          width: 1.4,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Container(
            width: 12,
            height: 12,
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(4),
            ),
          ),
          const SizedBox(width: 6),
          Text(
            label,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: selected ? color : null,
              fontWeight: selected ? FontWeight.w700 : null,
            ),
          ),
          if (selected) ...<Widget>[
            const SizedBox(width: 5),
            Icon(Icons.check_rounded, size: 15, color: color),
          ],
        ],
      ),
    );
    if (onTap == null) {
      return content;
    }
    return Tooltip(
      message: selected
          ? 'Clique para mostrar todos'
          : 'Clique para mostrar somente $label',
      child: Semantics(
        button: true,
        selected: selected,
        child: Material(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(999),
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(999),
            child: content,
          ),
        ),
      ),
    );
  }
}
