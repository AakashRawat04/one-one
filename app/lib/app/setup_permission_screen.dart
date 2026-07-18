import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:permission_handler/permission_handler.dart';

enum _SetupStep { mic, notification, background }

class SetupPermissionScreen extends StatefulWidget {
  const SetupPermissionScreen({
    super.key,
    required this.onComplete,
  });

  final Future<void> Function() onComplete;

  @override
  State<SetupPermissionScreen> createState() => _SetupPermissionScreenState();
}

class _SetupPermissionScreenState extends State<SetupPermissionScreen>
    with WidgetsBindingObserver {
  static const Duration _stageTransitionDuration = Duration(milliseconds: 320);

  _SetupStep _step = _SetupStep.mic;
  bool _micGranted = false;
  bool _notificationGranted = false;
  bool _backgroundGranted = false;
  bool _busy = false;
  bool _completed = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed &&
        _step == _SetupStep.background &&
        _busy &&
        !_completed) {
      unawaited(_finishBackgroundPermission());
    }
  }

  Future<void> _requestMicPermission() async {
    if (_busy || _step != _SetupStep.mic) return;

    setState(() => _busy = true);
    final status = await Permission.microphone.request();
    if (!mounted) return;

    if (!status.isGranted) {
      setState(() => _busy = false);
      _showDeniedSnackBar('Microphone permission is required.');
      return;
    }

    setState(() => _micGranted = true);
    await Future<void>.delayed(_stageTransitionDuration);
    if (!mounted) return;

    setState(() {
      _busy = false;
      _step = _SetupStep.notification;
    });
  }

  Future<void> _requestNotificationPermission() async {
    if (_busy || _step != _SetupStep.notification) return;

    setState(() => _busy = true);
    final status = await Permission.notification.request();
    if (!mounted) return;

    if (!status.isGranted) {
      setState(() => _busy = false);
      _showDeniedSnackBar('Notification permission is required.');
      return;
    }

    setState(() => _notificationGranted = true);
    await Future<void>.delayed(_stageTransitionDuration);
    if (!mounted) return;

    setState(() {
      _busy = false;
      _step = _SetupStep.background;
    });
  }

  Future<void> _requestBackgroundPermission() async {
    if (_busy || _step != _SetupStep.background || _completed) return;
    setState(() => _busy = true);

    try {
      if (Platform.isAndroid && !await _isBackgroundActivityAllowed()) {
        await FlutterForegroundTask.requestIgnoreBatteryOptimization();
      }
      await _finishBackgroundPermission();
    } catch (_) {
      if (!mounted || _completed) return;
      setState(() => _busy = false);
      _showDeniedSnackBar(
        'Allow background activity so nudges can reach you reliably.',
      );
    }
  }

  Future<void> _finishBackgroundPermission() async {
    if (!mounted || _completed || _step != _SetupStep.background) return;

    final granted = await _isBackgroundActivityAllowed();
    if (!mounted || _completed) return;
    if (!granted) {
      setState(() => _busy = false);
      _showDeniedSnackBar(
        'Choose unrestricted background activity, then return to One One.',
      );
      return;
    }

    _completed = true;
    setState(() => _backgroundGranted = true);
    await Future<void>.delayed(_stageTransitionDuration);
    if (!mounted) return;
    try {
      await widget.onComplete();
    } catch (_) {
      if (!mounted) return;
      _completed = false;
      setState(() => _busy = false);
      _showDeniedSnackBar('Setup could not be completed. Please try again.');
    }
  }

  Future<bool> _isBackgroundActivityAllowed() async {
    if (!Platform.isAndroid) return true;
    try {
      return await FlutterForegroundTask.isIgnoringBatteryOptimizations;
    } catch (_) {
      return false;
    }
  }

  void _showDeniedSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xff000000),
      body: SafeArea(
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: 24.w),
          child: Column(
            children: [
              SizedBox(height: 100.h),
              Text(
                'let\'s get those\nover with:',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 32.sp,
                  height: 1.05,
                  fontWeight: FontWeight.w700,
                  letterSpacing: -0.6,
                ),
              ),
              const Spacer(),
              AnimatedSwitcher(
                duration: _stageTransitionDuration,
                switchInCurve: Curves.easeOutCubic,
                switchOutCurve: Curves.easeInCubic,
                transitionBuilder: (child, animation) {
                  final offsetAnimation = Tween<Offset>(
                    begin: const Offset(0.12, 0),
                    end: Offset.zero,
                  ).animate(animation);
                  return FadeTransition(
                    opacity: animation,
                    child: SlideTransition(
                      position: offsetAnimation,
                      child: child,
                    ),
                  );
                },
                child: switch (_step) {
                  _SetupStep.mic => _PermissionCard(
                      key: const ValueKey('mic-card'),
                      iconColor: const Color(0xffffb020),
                      icon: Icons.mic_rounded,
                      title: 'mic',
                      subtitle: 'so your friends can hear you\nwhen you talk...',
                      checked: _micGranted,
                      onTap: _requestMicPermission,
                    ),
                  _SetupStep.notification => _PermissionCard(
                      key: const ValueKey('notification-card'),
                      iconColor: const Color(0xffff5a5f),
                      icon: Icons.notifications_rounded,
                      title: 'notifications',
                      subtitle: 'know when your friends are\ntalking to you',
                      checked: _notificationGranted,
                      onTap: _requestNotificationPermission,
                    ),
                  _SetupStep.background => _PermissionCard(
                      key: const ValueKey('background-card'),
                      iconColor: const Color(0xff4c8dff),
                      icon: Icons.battery_saver_rounded,
                      title: 'background activity',
                      subtitle: 'receive nudges when one one\nisn\'t open',
                      checked: _backgroundGranted,
                      onTap: _requestBackgroundPermission,
                    ),
                },
              ),
              SizedBox(height: 28.h),
              Text(
                '*we need those for one one to work',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: const Color.fromRGBO(255, 255, 255, 0.72),
                  fontSize: 11.sp,
                  height: 1.2,
                ),
              ),
              SizedBox(height: 28.h),
            ],
          ),
        ),
      ),
    );
  }
}

class _PermissionCard extends StatelessWidget {
  const _PermissionCard({
    super.key,
    required this.iconColor,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.checked,
    required this.onTap,
  });

  final Color iconColor;
  final IconData icon;
  final String title;
  final String subtitle;
  final bool checked;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 14.h),
        decoration: BoxDecoration(
          color: const Color(0xff131d28),
          borderRadius: BorderRadius.circular(24.r),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.22),
              blurRadius: 20,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Container(
              width: 34.w,
              height: 34.w,
              decoration: BoxDecoration(
                color: iconColor,
                borderRadius: BorderRadius.circular(10.r),
              ),
              child: Icon(icon, color: Colors.white, size: 20.sp),
            ),
            SizedBox(width: 12.w),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 18.sp,
                      fontWeight: FontWeight.w700,
                      height: 1,
                    ),
                  ),
                  SizedBox(height: 4.h),
                  Text(
                    subtitle,
                    style: TextStyle(
                      color: const Color.fromRGBO(255, 255, 255, 0.68),
                      fontSize: 12.sp,
                      height: 1.2,
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(width: 12.w),
            AnimatedContainer(
              duration: const Duration(milliseconds: 220),
              width: 24.w,
              height: 24.w,
              decoration: BoxDecoration(
                color: checked ? Colors.white : Colors.transparent,
                borderRadius: BorderRadius.circular(6.r),
                border: Border.all(
                  color: checked
                      ? Colors.white
                      : const Color.fromRGBO(255, 255, 255, 0.32),
                  width: 1.6,
                ),
              ),
              child: checked
                  ? Icon(
                      Icons.check_rounded,
                      size: 16.sp,
                      color: const Color(0xff131d28),
                    )
                  : null,
            ),
          ],
        ),
      ),
    );
  }
}
