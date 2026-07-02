import 'package:flutter/material.dart';
import '../utils/app_theme.dart';

// ─────────────────────────────────────────────────────────────────────────────
// BillBook Shared Animation Toolkit
// ─────────────────────────────────────────────────────────────────────────────
//
// Quick-reference
// ───────────────
//
// SCREEN ENTRY — wrap any screen's body or a section:
//   FadeSlideIn(child: ...)
//   FadeSlideIn(delay: Duration(milliseconds: 150), child: ...)
//
// STAGGERED LIST — inside ListView.builder / SliverList:
//   1. Add `with SingleTickerProviderStateMixin` to your State
//   2. Create:  AnimationController _enter = AnimationController(vsync: this,
//                 duration: Duration(milliseconds: 600))..forward();
//   3. Wrap each item:
//      StaggeredEntry(index: i, controller: _enter, child: YourTile(...))
//
// ANIMATED NUMBER — count up from 0:
//   AnimatedCounter(value: 1234, prefix: '₹', style: ...)
//
// PULSING DOT — live / overdue indicators:
//   PulsingDot(color: AppTheme.error)   // overdue
//   PulsingDot(color: AppTheme.success) // online / active
//
// PRESS-SCALE FEEDBACK — replaces plain GestureDetector for custom buttons:
//   ScaleTap(onTap: ..., child: YourCard(...))
//
// SHIMMER SKELETON — loading placeholders:
//   ShimmerBox(width: 160, height: 16)
//   ShimmerBox(width: double.infinity, height: 56)
// ─────────────────────────────────────────────────────────────────────────────

// ── 1. FadeSlideIn ─────────────────────────────────────────────────────────────
// Self-contained entry animation.  Fade in + slide up from [beginOffset].
// Fires once when the widget is inserted.  Use [delay] to stagger sections.
//
// Example — staggered page sections:
//   FadeSlideIn(child: HeaderSection())
//   FadeSlideIn(delay: Duration(milliseconds: 120), child: StatsSection())
//   FadeSlideIn(delay: Duration(milliseconds: 240), child: ListSection())

class FadeSlideIn extends StatefulWidget {
  final Widget child;
  final Duration delay;
  final Offset beginOffset;
  final Duration duration;
  final Curve curve;

  const FadeSlideIn({
    super.key,
    required this.child,
    this.delay = Duration.zero,
    this.beginOffset = const Offset(0, 0.06),
    this.duration = const Duration(milliseconds: 420),
    this.curve = Curves.easeOutCubic,
  });

  @override
  State<FadeSlideIn> createState() => _FadeSlideInState();
}

class _FadeSlideInState extends State<FadeSlideIn>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _opacity;
  late final Animation<Offset> _position;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: widget.duration);
    final curved = CurvedAnimation(parent: _ctrl, curve: widget.curve);
    _opacity = curved;
    _position = Tween<Offset>(
      begin: widget.beginOffset,
      end: Offset.zero,
    ).animate(curved);

    if (widget.delay == Duration.zero) {
      _ctrl.forward();
    } else {
      Future.delayed(widget.delay, () {
        if (mounted) _ctrl.forward();
      });
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _opacity,
      child: SlideTransition(position: _position, child: widget.child),
    );
  }
}

// ── 2. StaggeredEntry ──────────────────────────────────────────────────────────
// Per-item stagger driven by a PARENT AnimationController (600 ms recommended).
// Each item starts its own interval based on its [index].
//
// Example:
//   class _MyListState extends State<MyList>
//       with SingleTickerProviderStateMixin {
//     late final AnimationController _enter;
//
//     @override
//     void initState() {
//       super.initState();
//       _enter = AnimationController(
//         vsync: this,
//         duration: const Duration(milliseconds: 600),
//       )..forward();
//     }
//
//     @override
//     void dispose() { _enter.dispose(); super.dispose(); }
//
//     @override
//     Widget build(BuildContext context) {
//       return ListView.builder(
//         itemBuilder: (ctx, i) => StaggeredEntry(
//           index: i,
//           controller: _enter,
//           child: MyTile(items[i]),
//         ),
//       );
//     }
//   }

class StaggeredEntry extends StatelessWidget {
  final int index;
  final Animation<double> controller;
  final Widget child;

  /// Fraction of the parent controller's range used per step.
  /// Default 0.07 → items 0-9 get clean stagger across 600 ms.
  final double stepInterval;

  const StaggeredEntry({
    super.key,
    required this.index,
    required this.controller,
    required this.child,
    this.stepInterval = 0.07,
  });

  @override
  Widget build(BuildContext context) {
    final delay = (index * stepInterval).clamp(0.0, 0.65);
    final end = (delay + 0.45).clamp(0.0, 1.0);
    final anim = CurvedAnimation(
      parent: controller,
      curve: Interval(delay, end, curve: Curves.easeOutCubic),
    );
    return FadeTransition(
      opacity: anim,
      child: SlideTransition(
        position: Tween<Offset>(
          begin: const Offset(0, 0.08),
          end: Offset.zero,
        ).animate(anim),
        child: child,
      ),
    );
  }
}

// ── 3. AnimatedCounter ─────────────────────────────────────────────────────────
// Counts up from 0 to [value] using IntTween.
// Re-triggers whenever [value] changes (keyed on the value).
//
// Example — dashboard revenue card:
//   AnimatedCounter(value: totalRevenue.toInt(), prefix: '₹', style: headingStyle)
//
// Example — invoice count badge:
//   AnimatedCounter(value: overdueCount, style: badgeStyle)

class AnimatedCounter extends StatelessWidget {
  final int value;
  final TextStyle? style;
  final String prefix;
  final String suffix;
  final Duration duration;
  final Curve curve;

  const AnimatedCounter({
    super.key,
    required this.value,
    this.style,
    this.prefix = '',
    this.suffix = '',
    this.duration = const Duration(milliseconds: 800),
    this.curve = Curves.easeOutCubic,
  });

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<int>(
      key: ValueKey(value),
      tween: IntTween(begin: 0, end: value),
      duration: duration,
      curve: curve,
      builder: (_, v, _) => Text('$prefix$v$suffix', style: style),
    );
  }
}

// ── 4. PulsingDot ──────────────────────────────────────────────────────────────
// Softly pulsing filled circle. Use as a live-status or attention indicator.
//
// Example — overdue badge next to amount:
//   Row(children: [PulsingDot(color: AppTheme.error), SizedBox(width: 4), Text('Overdue')])
//
// Example — pending-sync indicator:
//   Row(children: [PulsingDot(color: AppTheme.warning), SizedBox(width: 4), Text('Pending Sync')])

class PulsingDot extends StatefulWidget {
  final Color color;
  final double size;

  const PulsingDot({super.key, required this.color, this.size = 8});

  @override
  State<PulsingDot> createState() => _PulsingDotState();
}

class _PulsingDotState extends State<PulsingDot>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1100),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (_, _) => Container(
        width: widget.size,
        height: widget.size,
        decoration: BoxDecoration(
          color: widget.color
              .withValues(alpha: 0.4 + 0.6 * _ctrl.value),
          shape: BoxShape.circle,
        ),
      ),
    );
  }
}

// ── 5. ScaleTap ────────────────────────────────────────────────────────────────
// Scales down slightly on press and springs back on release.
// Ideal for custom card tap targets where InkWell ripple is not desired.
//
// Example — stat card:
//   ScaleTap(
//     onTap: () => Navigator.push(context, ...),
//     child: StatCard(title: 'Revenue', value: '₹1,20,000'),
//   )

class ScaleTap extends StatefulWidget {
  final Widget child;
  final VoidCallback? onTap;
  final double scale;
  final Duration duration;

  const ScaleTap({
    super.key,
    required this.child,
    this.onTap,
    this.scale = 0.96,
    this.duration = const Duration(milliseconds: 90),
  });

  @override
  State<ScaleTap> createState() => _ScaleTapState();
}

class _ScaleTapState extends State<ScaleTap>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _scaleAnim;

  @override
  void initState() {
    super.initState();
    _ctrl =
        AnimationController(vsync: this, duration: widget.duration);
    _scaleAnim = Tween<double>(begin: 1.0, end: widget.scale)
        .animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => _ctrl.forward(),
      onTapUp: (_) {
        _ctrl.reverse();
        widget.onTap?.call();
      },
      onTapCancel: () => _ctrl.reverse(),
      child: ScaleTransition(scale: _scaleAnim, child: widget.child),
    );
  }
}

// ── 6. ShimmerBox ──────────────────────────────────────────────────────────────
// Skeleton-loading placeholder with shimmer sweep animation.
// Respects dark / light mode automatically.
//
// Example — loading skeleton card:
//   Column(children: [
//     ShimmerBox(width: double.infinity, height: 20),
//     SizedBox(height: 8),
//     ShimmerBox(width: 120, height: 14),
//   ])

class ShimmerBox extends StatefulWidget {
  final double width;
  final double height;
  final BorderRadius borderRadius;

  const ShimmerBox({
    super.key,
    required this.width,
    required this.height,
    this.borderRadius = const BorderRadius.all(Radius.circular(8)),
  });

  @override
  State<ShimmerBox> createState() => _ShimmerBoxState();
}

class _ShimmerBoxState extends State<ShimmerBox>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = AppTheme.isDark(context);
    final base =
        isDark ? const Color(0xFF2D3748) : const Color(0xFFE2E8F0);
    final highlight =
        isDark ? const Color(0xFF4A5568) : const Color(0xFFF1F5F9);

    return AnimatedBuilder(
      animation: _ctrl,
      builder: (_, _) => Container(
        width: widget.width,
        height: widget.height,
        decoration: BoxDecoration(
          borderRadius: widget.borderRadius,
          gradient: LinearGradient(
            begin: Alignment(-1.5 + 3 * _ctrl.value, 0),
            end: Alignment(-1.5 + 3 * _ctrl.value + 1, 0),
            colors: [base, highlight, base],
          ),
        ),
      ),
    );
  }
}

// ── 7. CrossFadeContent ────────────────────────────────────────────────────────
// Crossfade between two widgets when [showFirst] toggles.
// Useful for show/hide sections, toggle states, loading→content transitions.
//
// Example — loading to content:
//   CrossFadeContent(
//     showFirst: isLoading,
//     first: ShimmerCard(),
//     second: RealCard(data: data),
//   )

class CrossFadeContent extends StatelessWidget {
  final bool showFirst;
  final Widget first;
  final Widget second;
  final Duration duration;

  const CrossFadeContent({
    super.key,
    required this.showFirst,
    required this.first,
    required this.second,
    this.duration = const Duration(milliseconds: 300),
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedCrossFade(
      duration: duration,
      crossFadeState:
          showFirst ? CrossFadeState.showFirst : CrossFadeState.showSecond,
      firstChild: first,
      secondChild: second,
      layoutBuilder: (top, topKey, bottom, bottomKey) => Stack(
        clipBehavior: Clip.none,
        alignment: Alignment.topCenter,
        children: [
          Positioned.fill(key: bottomKey, child: bottom),
          Positioned.fill(key: topKey, child: top),
        ],
      ),
    );
  }
}

// ── 8. AnimatedNumber (double — for currency / percentage) ─────────────────────
// Like AnimatedCounter but for double values, formatted by [formatter].
//
// Example — revenue display:
//   AnimatedAmount(
//     value: 12345.50,
//     formatter: (v) => Fmt.currencyAmount(v, 'INR'),
//     style: TextStyle(fontSize: 28, fontWeight: FontWeight.w800),
//   )

class AnimatedAmount extends StatelessWidget {
  final double value;
  final String Function(double) formatter;
  final TextStyle? style;
  final Duration duration;

  const AnimatedAmount({
    super.key,
    required this.value,
    required this.formatter,
    this.style,
    this.duration = const Duration(milliseconds: 800),
  });

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      key: ValueKey(value),
      tween: Tween<double>(begin: 0, end: value),
      duration: duration,
      curve: Curves.easeOutCubic,
      builder: (_, v, _) => Text(formatter(v), style: style),
    );
  }
}
