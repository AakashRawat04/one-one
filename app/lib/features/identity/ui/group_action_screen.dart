import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../app/accent_theme.dart';
import '../../groups/data/group_repository.dart';
import '../../groups/ui/waiting_for_group_members_screen.dart';
import '../data/identity_repository.dart';
import '../models/identity_session.dart';
import 'identity_home_screen.dart';

enum GroupActionMode { createGroup, joinByPin }

class GroupActionScreen extends StatefulWidget {
  const GroupActionScreen({
    super.key,
    required this.mode,
    required this.session,
    required this.identityRepository,
  });

  final GroupActionMode mode;
  final IdentitySession session;
  final IdentityRepository identityRepository;

  @override
  State<GroupActionScreen> createState() => _GroupActionScreenState();
}

class _GroupActionScreenState extends State<GroupActionScreen>
    with SingleTickerProviderStateMixin {
  final GroupRepository _groupRepository = GroupRepository();
  final TextEditingController _textController = TextEditingController();
  late final AnimationController _gradientController = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 3600),
  );
  bool _busy = false;
  String? _message;

  bool get _isCreateMode => widget.mode == GroupActionMode.createGroup;
  bool get _hasInput => _textController.text.trim().isNotEmpty;
  bool get _canSubmit => _hasInput && !_busy;

  @override
  void initState() {
    super.initState();
    _textController.addListener(_handleTextChanged);
  }

  void _handleTextChanged() {
    if (_hasInput) {
      if (!_gradientController.isAnimating) {
        _gradientController.repeat();
      }
    } else {
      _gradientController
        ..stop()
        ..reset();
    }
    setState(() {});
  }

  @override
  void dispose() {
    _textController
      ..removeListener(_handleTextChanged)
      ..dispose();
    _gradientController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final value = _textController.text.trim();
    if (value.isEmpty) return;

    setState(() {
      _busy = true;
      _message = null;
    });

    try {
      if (_isCreateMode) {
        final group = await _groupRepository.createGroup(value);
        final invite = await _groupRepository.createInvite(group.groupId);

        if (!mounted) return;
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute<void>(
            builder: (_) => WaitingForGroupMembersScreen(
              group: group,
              invite: invite,
              session: widget.session,
              identityRepository: widget.identityRepository,
            ),
          ),
          (route) => false,
        );
      } else {
        await _groupRepository.joinInvite(value);
      }

      if (_isCreateMode) return;

      if (!mounted) return;
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(
          builder: (_) => IdentityHomeScreen(
            initialSession: widget.session,
            identityRepository: widget.identityRepository,
          ),
        ),
        (route) => false,
      );
    } catch (error) {
      if (!mounted) return;
      setState(() => _message = error.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final title = _isCreateMode ? 'create group' : 'join by pin';
    final subtitle = _isCreateMode
        ? 'name the group you want to start'
        : 'ask your friend for their pin';
    final hintText = _isCreateMode ? 'Group name' : 'Invite PIN';
    final accentColor = accentColorForKey(widget.session.settings.accentColorKey);

    return Scaffold(
      backgroundColor: const Color(0xff000000),
      resizeToAvoidBottomInset: true,
      body: SafeArea(
        child: Padding(
          padding: EdgeInsets.fromLTRB(24.w, 12.h, 24.w, 24.h),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Align(
                alignment: Alignment.centerLeft,
                child: IconButton(
                  tooltip: 'Back',
                  onPressed: _busy ? null : () => Navigator.of(context).maybePop(),
                  icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
                ),
              ),
              SizedBox(height: 4.h),
              Text(
                title,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                    ),
              ),
              SizedBox(height: 8.h),
              Text(
                subtitle,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: const Color.fromRGBO(255, 255, 255, 0.7),
                    ),
              ),
              SizedBox(height: 24.h),
              Container(
                padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 12.h),
                decoration: BoxDecoration(
                  color: const Color(0xff101822),
                  borderRadius: BorderRadius.circular(22.r),
                  border: Border.all(
                    color: const Color.fromRGBO(255, 255, 255, 0.08),
                  ),
                ),
                child: TextField(
                  controller: _textController,
                  autofocus: true,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18.sp,
                    fontWeight: FontWeight.w600,
                  ),
                  textCapitalization:
                      _isCreateMode ? TextCapitalization.words : TextCapitalization.characters,
                  decoration: InputDecoration(
                    border: InputBorder.none,
                    isDense: true,
                    hintText: hintText,
                    hintStyle: TextStyle(
                      color: const Color.fromRGBO(255, 255, 255, 0.45),
                      fontSize: 18.sp,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
              SizedBox(height: 12.h),
              if (_message != null) ...[
                Text(
                  _message!,
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
                SizedBox(height: 8.h),
              ],
              const Spacer(),
              Align(
                alignment: Alignment.bottomRight,
                child: _AnimatedGradientSubmitButton(
                  active: _hasInput,
                  busy: _busy,
                  accentColor: accentColor,
                  animation: _gradientController,
                  onPressed: _canSubmit ? _submit : null,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AnimatedGradientSubmitButton extends StatelessWidget {
  const _AnimatedGradientSubmitButton({
    required this.active,
    required this.busy,
    required this.accentColor,
    required this.animation,
    required this.onPressed,
  });

  final bool active;
  final bool busy;
  final Color accentColor;
  final Animation<double> animation;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final glow = Color.lerp(accentColor, Colors.white, 0.22)!;
    final blend = Color.lerp(accentColor, const Color(0xff8b5cf6), 0.48)!;

    return SizedBox(
      width: 90.w,
      height: 52.h,
      child: AnimatedBuilder(
        animation: animation,
        builder: (context, child) {
          return Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: onPressed,
              borderRadius: BorderRadius.circular(26.r),
              child: Ink(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(26.r),
                  color: active ? null : const Color(0xff3a3a3a),
                  boxShadow: active
                      ? [
                          BoxShadow(
                            color: accentColor.withValues(alpha: 0.28),
                            blurRadius: 18.r,
                            spreadRadius: -4.r,
                          ),
                        ]
                      : null,
                  gradient: active
                      ? LinearGradient(
                          begin: Alignment.centerLeft,
                          end: Alignment.centerRight,
                          colors: [
                            accentColor,
                            glow,
                            blend,
                            accentColor,
                          ],
                          stops: const [0.0, 0.34, 0.66, 1.0],
                          tileMode: TileMode.repeated,
                          transform: _LiquidGradientTransform(animation.value),
                        )
                      : null,
                ),
                child: child,
              ),
            ),
          );
        },
        child: Center(
          child: busy
              ? SizedBox(
                  width: 20.w,
                  height: 20.w,
                  child: const CircularProgressIndicator(
                    strokeWidth: 2.4,
                    color: Colors.white,
                  ),
                )
              : Icon(
                  Icons.arrow_forward_rounded,
                  color: active
                      ? Colors.white
                      : const Color.fromRGBO(255, 255, 255, 0.45),
                  size: 24.sp,
                ),
        ),
      ),
    );
  }
}

class _LiquidGradientTransform extends GradientTransform {
  const _LiquidGradientTransform(this.slide, {this.periodFactor = 3.0});

  final double slide;
  final double periodFactor;

  @override
  Matrix4? transform(Rect bounds, {TextDirection? textDirection}) {
    final period = bounds.width * periodFactor;
    final scale = period / bounds.width;

    return Matrix4.identity()
      ..translateByDouble(-period * slide, 0.0, 0.0, 1.0)
      ..scaleByDouble(scale, 1.0, 1.0, 1.0);
  }
}
