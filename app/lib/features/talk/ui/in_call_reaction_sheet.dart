import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../models/in_call_reaction.dart';

const _quickEmojis = <String>[
  '😂',
  '❤️',
  '👍',
  '🔥',
  '👏',
  '😮',
  '🎉',
  '👀',
  '💯',
  '🙏',
];

Future<String?> showInCallReactionSheet(BuildContext context) {
  return showModalBottomSheet<String>(
    context: context,
    isScrollControlled: true,
    backgroundColor: const Color(0xff161616),
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20.r)),
    ),
    builder: (context) => const _InCallReactionSheet(),
  );
}

class _InCallReactionSheet extends StatefulWidget {
  const _InCallReactionSheet();

  @override
  State<_InCallReactionSheet> createState() => _InCallReactionSheetState();
}

class _InCallReactionSheetState extends State<_InCallReactionSheet> {
  final TextEditingController _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit([String? override]) {
    final text = InCallReaction.sanitizeInput(override ?? _controller.text);
    if (text == null) return;
    Navigator.of(context).pop(text);
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;

    return Padding(
      padding: EdgeInsets.fromLTRB(20.w, 12.h, 20.w, 16.h + bottomInset),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Center(
            child: Container(
              width: 36.w,
              height: 4.h,
              decoration: BoxDecoration(
                color: Colors.white24,
                borderRadius: BorderRadius.circular(999),
              ),
            ),
          ),
          SizedBox(height: 16.h),
          Text(
            'Send a reaction',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.white,
              fontSize: 16.sp,
              fontWeight: FontWeight.w700,
            ),
          ),
          SizedBox(height: 4.h),
          Text(
            'Emoji or a short line — floats for everyone, then fades.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.white54,
              fontSize: 12.sp,
              fontWeight: FontWeight.w500,
            ),
          ),
          SizedBox(height: 18.h),
          Wrap(
            spacing: 10.w,
            runSpacing: 10.h,
            alignment: WrapAlignment.center,
            children: [
              for (final emoji in _quickEmojis)
                InkWell(
                  onTap: () => _submit(emoji),
                  borderRadius: BorderRadius.circular(14.r),
                  child: Container(
                    width: 48.w,
                    height: 48.w,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: const Color.fromRGBO(255, 255, 255, 0.08),
                      borderRadius: BorderRadius.circular(14.r),
                      border: Border.all(
                        color: const Color.fromRGBO(255, 255, 255, 0.12),
                      ),
                    ),
                    child: Text(emoji, style: TextStyle(fontSize: 24.sp)),
                  ),
                ),
            ],
          ),
          SizedBox(height: 18.h),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _controller,
                  autofocus: false,
                  maxLength: InCallReaction.maxTextLength,
                  textInputAction: TextInputAction.send,
                  onSubmitted: (_) => _submit(),
                  style: TextStyle(color: Colors.white, fontSize: 15.sp),
                  decoration: InputDecoration(
                    hintText: 'or type a short line…',
                    hintStyle: TextStyle(color: Colors.white38, fontSize: 14.sp),
                    counterStyle: TextStyle(
                      color: Colors.white38,
                      fontSize: 10.sp,
                    ),
                    filled: true,
                    fillColor: const Color.fromRGBO(255, 255, 255, 0.08),
                    contentPadding: EdgeInsets.symmetric(
                      horizontal: 14.w,
                      vertical: 12.h,
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16.r),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
              ),
              SizedBox(width: 10.w),
              Material(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16.r),
                child: InkWell(
                  onTap: _submit,
                  borderRadius: BorderRadius.circular(16.r),
                  child: SizedBox(
                    width: 48.w,
                    height: 48.w,
                    child: Icon(
                      Icons.send_rounded,
                      color: Colors.black,
                      size: 22.sp,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
