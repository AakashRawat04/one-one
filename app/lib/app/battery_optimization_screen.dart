import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

class BatteryOptimizationScreen extends StatefulWidget {
  const BatteryOptimizationScreen({
    super.key,
    required this.onComplete,
  });

  final Future<void> Function() onComplete;

  @override
  State<BatteryOptimizationScreen> createState() =>
      _BatteryOptimizationScreenState();
}

class _BatteryOptimizationScreenState extends State<BatteryOptimizationScreen>
    with WidgetsBindingObserver {
  bool _busy = false;
  bool _completed = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    unawaited(_completeIfAlreadyIgnoring());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      unawaited(_completeIfAlreadyIgnoring());
    }
  }

  Future<void> _completeIfAlreadyIgnoring() async {
    if (_completed || !mounted) return;

    final ignoring = await _isIgnoringBatteryOptimizations();
    if (!mounted || !ignoring || _completed) return;

    _completed = true;
    await widget.onComplete();
  }

  Future<bool> _isIgnoringBatteryOptimizations() async {
    if (!Platform.isAndroid) {
      return true;
    }

    try {
      return await FlutterForegroundTask.isIgnoringBatteryOptimizations;
    } catch (_) {
      return false;
    }
  }

  Future<void> _openBatterySettings() async {
    if (_busy || _completed) return;

    setState(() => _busy = true);

    try {
      if (Platform.isAndroid &&
          !await FlutterForegroundTask.isIgnoringBatteryOptimizations) {
        await FlutterForegroundTask.requestIgnoreBatteryOptimization();
      }

      if (!mounted) return;

      final ignoring = await _isIgnoringBatteryOptimizations();
      if (!mounted) return;

      if (ignoring) {
        _completed = true;
        await widget.onComplete();
        return;
      }

      setState(() => _busy = false);
    } catch (_) {
      if (!mounted) return;
      setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xff101725),
      body: SafeArea(
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: 24.w),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              SizedBox(height: 44.h),
              Text(
                'Allow in background',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 28.sp,
                  height: 1.05,
                  fontWeight: FontWeight.w900,
                  letterSpacing: -0.5,
                ),
              ),
              SizedBox(height: 10.h),
              Text(
                'so your friends can reach you on one one\nwith less "connecting" time',
                style: TextStyle(
                  color: const Color.fromRGBO(255, 255, 255, 0.68),
                  fontSize: 13.sp,
                  height: 1.25,
                ),
                textAlign: TextAlign.center,
              ),
              SizedBox(height: 32.h),
              Expanded(
                child: Center(
                  child: _ConnectingCard(isBusy: _busy),
                ),
              ),
              SizedBox(height: 24.h),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _busy ? null : _openBatterySettings,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: const Color(0xff384047),
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(26.r),
                    ),
                    minimumSize: Size(double.infinity, 54.h),
                  ),
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 200),
                    child: _busy
                        ? SizedBox(
                            key: const ValueKey('progress'),
                            width: 20.w,
                            height: 20.w,
                            child: const CircularProgressIndicator(
                              strokeWidth: 2.4,
                              color: Color(0xff384047),
                            ),
                          )
                        : Text(
                            'change now',
                            key: const ValueKey('label'),
                            style: TextStyle(
                              fontSize: 16.sp,
                              fontWeight: FontWeight.w600,
                              color: const Color(0xff384047),
                            ),
                          ),
                  ),
                ),
              ),
              SizedBox(height: 26.h),
            ],
          ),
        ),
      ),
    );
  }
}

class _ConnectingCard extends StatelessWidget {
  const _ConnectingCard({required this.isBusy});

  final bool isBusy;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 198.w,
      height: 280.h,
      decoration: BoxDecoration(
        color: const Color(0xffffffff).withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(28.r),
        border: Border.all(
          color: const Color.fromRGBO(255, 255, 255, 0.06),
          width: 1,
        ),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Image.asset(
            'assets/logo.png',
            width: 64.w,
            height: 64.w,
          ),
          SizedBox(height: 56.h),
          Text(
            'connecting_',
            style: TextStyle(
              color: Colors.white,
              fontSize: 15.sp,
              height: 1,
              fontWeight: FontWeight.w600,
            ),
          ),
          SizedBox(height: 14.h),
          SizedBox(
            width: 28.w,
            height: 28.w,
            child: CircularProgressIndicator(
              strokeWidth: 2.3,
              valueColor: AlwaysStoppedAnimation<Color>(
                Colors.white.withValues(alpha: isBusy ? 1 : 0.9),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
