import 'dart:async';

import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../app/accent_theme.dart';
import '../../../core/firebase/app_database.dart';
import '../../identity/data/identity_repository.dart';
import '../../identity/models/identity_session.dart';
import '../../identity/ui/group_action_screen.dart';
import '../../identity/ui/identity_home_screen.dart';
import '../../identity/ui/settings_screen.dart';
import '../models/group_invite_result.dart';
import '../models/group_summary.dart';

class WaitingForGroupMembersScreen extends StatefulWidget {
  const WaitingForGroupMembersScreen({
    super.key,
    required this.group,
    required this.invite,
    required this.session,
    required this.identityRepository,
  });

  final GroupSummary group;
  final GroupInviteResult invite;
  final IdentitySession session;
  final IdentityRepository identityRepository;

  @override
  State<WaitingForGroupMembersScreen> createState() =>
      _WaitingForGroupMembersScreenState();
}

class _WaitingForGroupMembersScreenState
    extends State<WaitingForGroupMembersScreen> {
  StreamSubscription<DatabaseEvent>? _membersSubscription;
  bool _navigatingHome = false;

  @override
  void initState() {
    super.initState();
    AccentThemeController.setAccentKey(widget.session.settings.accentColorKey);
    _listenForNewMembers();
    unawaited(_checkMemberCount());
  }

  @override
  void dispose() {
    unawaited(_membersSubscription?.cancel());
    super.dispose();
  }

  void _listenForNewMembers() {
    _membersSubscription = AppDatabase.instance()
        .ref('groupMembers/${widget.group.groupId}')
        .onValue
        .listen((event) {
          final count = _activeMemberCount(event.snapshot.value);
          if (count > 1) {
            unawaited(_goHome());
          }
        });
  }

  Future<void> _checkMemberCount() async {
    final snapshot = await AppDatabase.instance()
        .ref('groupMembers/${widget.group.groupId}')
        .get();
    if (!mounted) return;

    if (_activeMemberCount(snapshot.value) > 1) {
      await _goHome();
    }
  }

  int _activeMemberCount(Object? value) {
    if (value is! Map<Object?, Object?>) return 0;

    var count = 0;
    for (final entry in value.entries) {
      final raw = entry.value;
      if (raw is! Map<Object?, Object?>) continue;
      if ((raw['memberState']?.toString() ?? 'active') == 'active') {
        count++;
      }
    }
    return count;
  }

  Future<void> _goHome() async {
    if (_navigatingHome || !mounted) return;
    _navigatingHome = true;

    await Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute<void>(
        builder: (_) => IdentityHomeScreen(
          initialSession: widget.session,
          identityRepository: widget.identityRepository,
        ),
      ),
      (route) => false,
    );
  }

  Future<void> _copyPin() async {
    await Clipboard.setData(ClipboardData(text: widget.invite.inviteCode));
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('PIN copied')));
  }

  Route<void> _slideUpJoinRoute() {
    return PageRouteBuilder<void>(
      transitionDuration: const Duration(milliseconds: 320),
      reverseTransitionDuration: const Duration(milliseconds: 260),
      pageBuilder: (context, animation, secondaryAnimation) {
        return GroupActionScreen(
          mode: GroupActionMode.joinByPin,
          session: widget.session,
          identityRepository: widget.identityRepository,
        );
      },
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        final offset =
            Tween<Offset>(begin: const Offset(0, 1), end: Offset.zero).animate(
              CurvedAnimation(parent: animation, curve: Curves.easeOutCubic),
            );

        return SlideTransition(position: offset, child: child);
      },
    );
  }

  void _openJoinGroup() {
    Navigator.of(context).push(_slideUpJoinRoute());
  }

  void _openSettings() {
    unawaited(
      SettingsScreen.open(
        context,
        session: widget.session,
        identityRepository: widget.identityRepository,
        onSessionChanged: (_) {},
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xff000000),
      body: SafeArea(
        child: Stack(
          children: [
            Center(
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: 24.w),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      '⌛ waiting for someone to join your group',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 28.sp,
                        fontWeight: FontWeight.w700,
                        height: 1.15,
                      ),
                    ),
                    SizedBox(height: 28.h),
                    TextButton(
                      onPressed: _openJoinGroup,
                      child: Text(
                        'join a group instead',
                        style: TextStyle(
                          color: const Color.fromRGBO(255, 255, 255, 0.78),
                          fontSize: 15.sp,
                          fontWeight: FontWeight.w600,
                          decoration: TextDecoration.underline,
                          decorationColor: const Color.fromRGBO(
                            255,
                            255,
                            255,
                            0.78,
                          ),
                        ),
                      ),
                    ),
                    SizedBox(height: 28.h),
                    GestureDetector(
                      onTap: _copyPin,
                      child: Container(
                        padding: EdgeInsets.symmetric(
                          horizontal: 22.w,
                          vertical: 14.h,
                        ),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(28.r),
                          border: Border.all(
                            color: const Color.fromRGBO(255, 255, 255, 0.55),
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              'PIN: ${widget.invite.inviteCode}',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 16.sp,
                                fontWeight: FontWeight.w600,
                                letterSpacing: 0.4,
                              ),
                            ),
                            SizedBox(width: 12.w),
                            Icon(
                              Icons.copy_rounded,
                              color: Colors.white,
                              size: 18.sp,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            Align(
              alignment: Alignment.topLeft,
              child: Padding(
                padding: EdgeInsets.only(left: 12.w, top: 12.h),
                child: IconButton(
                  tooltip: 'Settings',
                  onPressed: _openSettings,
                  icon: Icon(Icons.settings_outlined, color: Colors.white),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
