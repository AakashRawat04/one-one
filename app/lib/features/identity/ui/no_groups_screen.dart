import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../data/identity_repository.dart';
import '../models/identity_session.dart';
import 'group_action_screen.dart';
import 'settings_screen.dart';

class NoGroupsScreen extends StatelessWidget {
  const NoGroupsScreen({
    super.key,
    required this.session,
    required this.identityRepository,
  });

  final IdentitySession session;
  final IdentityRepository identityRepository;

  Route<void> _slideUpRoute(GroupActionMode mode) {
    return PageRouteBuilder<void>(
      transitionDuration: const Duration(milliseconds: 320),
      reverseTransitionDuration: const Duration(milliseconds: 260),
      pageBuilder: (context, animation, secondaryAnimation) {
        return GroupActionScreen(
          mode: mode,
          session: session,
          identityRepository: identityRepository,
        );
      },
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        final offset = Tween<Offset>(
          begin: const Offset(0, 1),
          end: Offset.zero,
        ).animate(CurvedAnimation(parent: animation, curve: Curves.easeOutCubic));

        return SlideTransition(
          position: offset,
          child: child,
        );
      },
    );
  }

  void _openCreateGroup(BuildContext context) {
    Navigator.of(context).push(_slideUpRoute(GroupActionMode.createGroup));
  }

  void _openJoinGroup(BuildContext context) {
    Navigator.of(context).push(_slideUpRoute(GroupActionMode.joinByPin));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color(0xff000000),
        foregroundColor: Colors.white,
        leading: IconButton(
          tooltip: 'Settings',
          onPressed: () {
            unawaited(
              SettingsScreen.open(
                context,
                session: session,
                identityRepository: identityRepository,
                onSessionChanged: (_) {},
              ),
            );
          },
          icon: const Icon(Icons.settings_outlined),
        ),
      ),
      backgroundColor: const Color(0xff000000),
      body: SafeArea(
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: 24.w),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'Invite at least one friend to get started',
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.headlineLarge?.copyWith(
                              fontWeight: FontWeight.w700,
                              color: Colors.white,
                            ),
                      ),
                      SizedBox(height: 10.h),
                      Text(
                        'add your besties, the ones you talk to everyday 🫶',
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                              color: Colors.white,
                            ),
                      ),
                      SizedBox(height: 42.h),
                      SizedBox(
                        width: 96.w,
                        height: 96.w,
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            shape: const CircleBorder(),
                            backgroundColor: Colors.white,
                            padding: EdgeInsets.zero,
                          ),
                          onPressed: () => _openCreateGroup(context),
                          child: Icon(Icons.add, size: 44.w, color: Colors.black),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              Column(
                children: [
                  Text(
                    'Have a group already? Use the PIN from a friend.',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                          color: Colors.white,
                        ),
                  ),
                  SizedBox(height: 18.h),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: () => _openJoinGroup(context),
                      icon: const Icon(Icons.login),
                      label: const Text('Join with PIN'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.white,
                        foregroundColor: Colors.black,
                      ),
                    ),
                  ),
                ],
              ),
              SizedBox(height: 18.h),
            ],
          ),
        ),
      ),
    );
  }
}
