import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../models/in_call_reaction.dart';

/// Centered floating reaction that rises and fades out.
class InCallReactionOverlay extends StatelessWidget {
  const InCallReactionOverlay({super.key, required this.reactions});

  final List<InCallReaction> reactions;

  @override
  Widget build(BuildContext context) {
    if (reactions.isEmpty) return const SizedBox.shrink();

    return IgnorePointer(
      child: Align(
        alignment: const Alignment(0, -0.08),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (var i = 0; i < reactions.length; i++) ...[
              if (i > 0) SizedBox(height: 10.h),
              _FloatingReactionBubble(
                key: ValueKey(reactions[i].id),
                reaction: reactions[i],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _FloatingReactionBubble extends StatefulWidget {
  const _FloatingReactionBubble({super.key, required this.reaction});

  final InCallReaction reaction;

  @override
  State<_FloatingReactionBubble> createState() =>
      _FloatingReactionBubbleState();
}

class _FloatingReactionBubbleState extends State<_FloatingReactionBubble>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 2800),
  )..forward();

  late final Animation<double> _opacity = TweenSequence<double>([
    TweenSequenceItem(tween: Tween(begin: 0, end: 1), weight: 12),
    TweenSequenceItem(tween: ConstantTween(1), weight: 58),
    TweenSequenceItem(tween: Tween(begin: 1, end: 0), weight: 30),
  ]).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic));

  late final Animation<Offset> _slide = Tween<Offset>(
    begin: const Offset(0, 0.18),
    end: const Offset(0, -0.55),
  ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic));

  late final Animation<double> _scale = TweenSequence<double>([
    TweenSequenceItem(
      tween: Tween(
        begin: 0.86,
        end: 1.05,
      ).chain(CurveTween(curve: Curves.easeOutBack)),
      weight: 18,
    ),
    TweenSequenceItem(tween: Tween(begin: 1.05, end: 1), weight: 12),
    TweenSequenceItem(tween: ConstantTween(1), weight: 70),
  ]).animate(_controller);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final reaction = widget.reaction;
    final name = reaction.displayName.trim().isEmpty
        ? 'friend'
        : reaction.displayName.trim().toLowerCase();

    return FadeTransition(
      opacity: _opacity,
      child: SlideTransition(
        position: _slide,
        child: ScaleTransition(
          scale: _scale,
          child: reaction.isEmojiOnly
              ? Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      reaction.text,
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 48.sp, height: 1.05),
                    ),
                    SizedBox(height: 4.h),
                    Text(
                      name,
                      style: TextStyle(
                        color: Colors.white70,
                        fontSize: 11.sp,
                        fontWeight: FontWeight.w600,
                        shadows: const [
                          Shadow(color: Colors.black, blurRadius: 8),
                        ],
                      ),
                    ),
                  ],
                )
              : Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Container(
                      constraints: BoxConstraints(maxWidth: 280.w),
                      padding: EdgeInsets.symmetric(
                        horizontal: 15.w,
                        vertical: 10.h,
                      ),
                      decoration: BoxDecoration(
                        color: const Color.fromRGBO(25, 25, 25, 0.94),
                        borderRadius: BorderRadius.only(
                          topLeft: Radius.circular(18.r),
                          topRight: Radius.circular(18.r),
                          bottomLeft: Radius.circular(18.r),
                          bottomRight: Radius.circular(5.r),
                        ),
                        boxShadow: const [
                          BoxShadow(
                            color: Color(0x55000000),
                            blurRadius: 18,
                            offset: Offset(0, 8),
                          ),
                        ],
                      ),
                      child: Text(
                        reaction.text,
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 17.sp,
                          fontWeight: FontWeight.w600,
                          height: 1.3,
                        ),
                      ),
                    ),
                    SizedBox(height: 4.h),
                    Padding(
                      padding: EdgeInsets.only(right: 5.w),
                      child: Text(
                        name,
                        style: TextStyle(
                          color: Colors.white60,
                          fontSize: 11.sp,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
        ),
      ),
    );
  }
}
