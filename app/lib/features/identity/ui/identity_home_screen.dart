import 'dart:async';
import 'dart:ui';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:livekit_client/livekit_client.dart';
import 'package:uuid/uuid.dart';

import '../../../app/accent_theme.dart';
import '../../../core/firebase/app_database.dart';
import '../../../core/network/api_client.dart';
import '../../groups/data/group_repository.dart';
import '../../groups/data/invite_link_bridge.dart';
import '../../groups/group_service_readiness.dart';
import '../../groups/models/group_invite_result.dart';
import '../../groups/models/group_member_summary.dart';
import '../../groups/models/group_summary.dart';
import '../../online/data/online_repository.dart';
import '../../online/livekit_status.dart';
import '../../online/models/member_availability.dart';
import '../../online/models/online_session.dart';
import '../../nudges/data/android_voice_nudge_bridge.dart';
import '../../nudges/data/nudge_repository.dart';
import '../../nudges/ui/nudge_screen.dart';
import '../../talk/data/hand_raise_repository.dart';
import '../../talk/data/talk_repository.dart';
import '../../talk/models/in_call_reaction.dart';
import '../../talk/models/talk_session.dart';
import '../../talk/talk_feedback.dart';
import '../../talk/ui/in_call_reaction_overlay.dart';
import '../../talk/ui/in_call_reaction_sheet.dart';
import '../data/identity_repository.dart';
import '../models/identity_session.dart';
import 'group_action_screen.dart';
import 'no_groups_screen.dart';
import 'profile_avatar.dart';
import 'settings_screen.dart';

class IdentityHomeScreen extends StatefulWidget {
  const IdentityHomeScreen({
    super.key,
    required this.initialSession,
    required this.identityRepository,
    this.initialGroupId,
  });

  final IdentitySession initialSession;
  final IdentityRepository identityRepository;
  final String? initialGroupId;

  @override
  State<IdentityHomeScreen> createState() => _IdentityHomeScreenState();
}

class _IdentityHomeScreenState extends State<IdentityHomeScreen>
    with WidgetsBindingObserver {
  final GroupRepository _groupRepository = GroupRepository();
  final OnlineRepository _onlineRepository = OnlineRepository();
  final TalkRepository _talkRepository = TalkRepository();
  final HandRaiseRepository _handRaiseRepository = HandRaiseRepository();
  final AndroidVoiceNudgeBridge _nudgeActionBridge =
      AndroidVoiceNudgeBridge();
  final NudgeRepository _nudgeRepository = NudgeRepository();
  final InviteLinkBridge _inviteLinkBridge = InviteLinkBridge();

  late IdentitySession _session;
  List<GroupSummary> _groups = const [];
  List<GroupMemberSummary> _members = const [];
  Map<String, List<GroupMemberSummary>> _membersByGroupId = const {};
  Map<String, MemberAvailability> _availability = const {};
  Map<String, bool> _handRaises = const {};
  Set<String> _speakingUserIds = const {};
  GroupSummary? _selectedGroup;
  StreamSubscription<DatabaseEvent>? _availabilitySubscription;
  Timer? _availabilityExpiryTimer;
  StreamSubscription<DatabaseEvent>? _membersSubscription;
  StreamSubscription<DatabaseEvent>? _handRaiseSubscription;
  StreamSubscription<List<ConnectivityResult>>? _connectivitySubscription;
  StreamSubscription<void>? _nudgeActionSubscription;
  StreamSubscription<void>? _registrationRenewalSubscription;
  StreamSubscription<void>? _inviteLinkSubscription;

  OnlineSession? _onlineSession;
  TalkSession? _talkSession;
  Room? _room;
  EventsListener<RoomEvent>? _roomListener;
  Timer? _heartbeatTimer;

  int _carouselIndex = 0;

  bool _loadingGroups = true;
  bool _busy = false;
  bool _talkBusy = false;
  bool _talkPressed = false;
  bool _handRaiseBusy = false;
  bool _reactionBusy = false;
  String _state = 'away';
  String? _message;
  ConnectionQuality _localConnectionQuality = ConnectionQuality.unknown;
  Map<String, ConnectionQuality> _remoteConnectionQualityByUserId = const {};
  List<InCallReaction> _floatingReactions = const [];
  final Map<String, Timer> _reactionDismissTimers = {};
  List<ConnectivityResult> _connectivity = const [];
  bool _registrationRefreshInFlight = false;
  DateTime? _lastRegistrationRefreshAt;
  NudgeNotificationAction? _deferredNudgeAction;
  bool _nudgeActionInFlight = false;
  bool _inviteJoinInFlight = false;
  String? _preferredGroupId;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _session =
        widget.identityRepository.currentSession ?? widget.initialSession;
    _preferredGroupId = widget.initialGroupId;
    widget.identityRepository.sessionListenable.addListener(
      _onIdentitySessionChanged,
    );
    AccentThemeController.setAccentKey(_session.settings.accentColorKey);
    _nudgeActionSubscription = AndroidVoiceNudgeBridge.actionSignals.listen((_) {
      unawaited(_takePendingNudgeAction());
    });
    _registrationRenewalSubscription =
        AndroidVoiceNudgeBridge.registrationSignals.listen((_) {
          unawaited(_refreshDeviceRegistration(force: true));
        });
    _inviteLinkSubscription = InviteLinkBridge.linkSignals.listen((_) {
      unawaited(_takePendingInviteLink());
    });
    unawaited(_startConnectivityMonitoring());
    unawaited(_loadGroups());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    widget.identityRepository.sessionListenable.removeListener(
      _onIdentitySessionChanged,
    );
    _availabilitySubscription?.cancel();
    _availabilityExpiryTimer?.cancel();
    _membersSubscription?.cancel();
    _handRaiseSubscription?.cancel();
    _connectivitySubscription?.cancel();
    _nudgeActionSubscription?.cancel();
    _registrationRenewalSubscription?.cancel();
    _inviteLinkSubscription?.cancel();
    _heartbeatTimer?.cancel();
    _clearFloatingReactions();
    final activeTalk = _talkSession;
    if (activeTalk != null) {
      unawaited(_talkRepository.stopTalk(activeTalk, reason: 'screen_closed'));
    }
    unawaited(_disconnectLiveKit());
    unawaited(_clearOwnHandRaise());
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      unawaited(_refreshDeviceRegistration());
      unawaited(_takePendingNudgeAction());
      unawaited(_takePendingInviteLink());
    }
  }

  Future<void> _refreshDeviceRegistration({bool force = false}) async {
    final lastRefresh = _lastRegistrationRefreshAt;
    if (_registrationRefreshInFlight ||
        (!force &&
            lastRefresh != null &&
            DateTime.now().difference(lastRefresh) <
                const Duration(seconds: 30))) {
      return;
    }
    _registrationRefreshInFlight = true;
    try {
      await widget.identityRepository.ensureIdentity();
      _lastRegistrationRefreshAt = DateTime.now();
    } catch (error) {
      debugPrint(
        '[OneOneFCM][DART-E5] Resume-time device registration refresh failed: $error',
      );
    } finally {
      _registrationRefreshInFlight = false;
    }
  }

  void _onIdentitySessionChanged() {
    final next = widget.identityRepository.currentSession;
    if (!mounted || next == null || next.userId != _session.userId) return;
    final audioRouteChanged =
        next.settings.audioOutputPreference !=
        _session.settings.audioOutputPreference;
    setState(() => _session = next);
    AccentThemeController.setAccentKey(next.settings.accentColorKey);
    if (audioRouteChanged) unawaited(_applyPreferredAudioRoute());
  }

  Future<void> _startConnectivityMonitoring() async {
    final connectivity = Connectivity();
    try {
      final current = await connectivity.checkConnectivity();
      if (mounted) setState(() => _connectivity = current);
    } catch (_) {
      // LiveKit connection quality remains the primary signal.
    }
    _connectivitySubscription = connectivity.onConnectivityChanged.listen((
      results,
    ) {
      if (mounted) setState(() => _connectivity = results);
    });
  }

  Future<void> _loadGroups() async {
    setState(() => _loadingGroups = true);
    try {
      final resolution = await _groupRepository.resolveGroupEntry(
        _session.userId,
      );
      if (!mounted) return;

      if (resolution.kind == GroupEntryKind.noGroups &&
          (ModalRoute.of(context)?.isCurrent ?? true)) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) return;
          unawaited(_replaceWithGroupEntry(resolution));
        });
        return;
      }

      final groups = resolution.groups;
      final selected = _resolveSelectedGroup(groups);
      final membersByGroupId = await _loadAllGroupMembers(groups);
      await _precacheGroupMemberPhotos(
        membersByGroupId.values.expand((members) => members),
      );

      if (!mounted) return;
      setState(() {
        _groups = groups;
        _selectedGroup = selected;
        _membersByGroupId = membersByGroupId;
        _members = selected == null
            ? const []
            : membersByGroupId[selected.groupId] ?? const [];
        if (selected == null) {
          _availability = const {};
        }
      });
      _syncCarouselToSelectedGroup();

      // If this is the first load and the user has no groups, navigate
      // to the dedicated no-groups screen so the new UI is shown.
      if (groups.isEmpty && (ModalRoute.of(context)?.isCurrent ?? true)) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) return;
          _replaceWithGroupEntry(const GroupEntryResolution.noGroups());
        });
        return;
      }

      if (selected != null) {
        _listenToMembers(selected.groupId);
        _listenToAvailability(selected.groupId);
        _listenToHandRaises(selected.groupId);
      }
    } catch (error) {
      if (!mounted) return;
      setState(() => _message = LiveKitStatus.sanitizeError(error));
    } finally {
      if (mounted && _loadingGroups) {
        setState(() => _loadingGroups = false);
        unawaited(_takePendingNudgeAction());
        unawaited(_takePendingInviteLink());
      }
    }
  }

  Future<void> _takePendingInviteLink() async {
    if (_inviteJoinInFlight || _loadingGroups) return;
    final inviteCode = await _inviteLinkBridge.peekPendingInviteCode();
    if (inviteCode == null || !mounted) return;
    _inviteJoinInFlight = true;
    try {
      final groupId = await _groupRepository.joinInvite(inviteCode);
      await _inviteLinkBridge.clearPendingInviteCode(inviteCode);
      if (!mounted) return;
      Navigator.of(context).popUntil((route) => route.isFirst);
      if (!mounted) return;
      _preferredGroupId = groupId;
      debugPrint(
        '[OneOneInvite] Joined link while Home was active groupSuffix='
        '${groupId.length <= 6 ? groupId : groupId.substring(groupId.length - 6)}',
      );
      await _loadGroups();
      if (mounted) {
        setState(() => _message = 'Group joined from invite link.');
      }
    } catch (error) {
      debugPrint(
        '[OneOneInvite] Active invite failed ${error.runtimeType}: $error',
      );
      if (error is ApiException &&
          const {
            'invite_not_found',
            'invite_unavailable',
            'group_full',
            'group_not_active',
          }.contains(error.code)) {
        await _inviteLinkBridge.clearPendingInviteCode(inviteCode);
      }
      if (mounted) {
        setState(() {
          _message = error is ApiException
              ? error.message
              : 'Couldn’t open this invite. Check your connection.';
        });
      }
    } finally {
      _inviteJoinInFlight = false;
    }
  }

  Future<void> _takePendingNudgeAction() async {
    if (_nudgeActionInFlight) return;
    NudgeNotificationAction? action;
    try {
      action =
          _deferredNudgeAction ??
          await _nudgeActionBridge.takePendingNudgeAction();
      if (action == null || !mounted) return;
      if (_loadingGroups) {
        _deferredNudgeAction = action;
        return;
      }
      _deferredNudgeAction = null;
      _nudgeActionInFlight = true;
      await _processNudgeAction(action);
    } catch (error) {
      if (action != null) _deferredNudgeAction = action;
      if (mounted) {
        setState(() => _message = 'Couldn’t process the nudge action.');
      }
    } finally {
      _nudgeActionInFlight = false;
    }
  }

  Future<void> _processNudgeAction(NudgeNotificationAction action) async {
    final index = _groups.indexWhere(
      (group) => group.groupId == action.groupId,
    );
    if (index < 0) {
      setState(() => _message = 'That nudge group is no longer available.');
      return;
    }

    await _onGroupCarouselChanged(index);
    if (!mounted) return;
    if (!_isOnline) await _goOnline();
    if (!mounted) return;
    if (!_isOnline) {
      throw StateError('Could not enter the nudge group.');
    }
    if (action.action != 'accept') return;
    await _nudgeRepository.respond(
      groupId: action.groupId,
      eventId: action.eventId,
      action: 'accept',
    );
    debugPrint(
      '[OneOneFCM][DART-07] Accepted nudge and entered group '
      'eventSuffix=${action.eventId.length <= 6 ? action.eventId : action.eventId.substring(action.eventId.length - 6)}',
    );
  }

  Future<void> _replaceWithGroupEntry(GroupEntryResolution resolution) async {
    switch (resolution.kind) {
      case GroupEntryKind.noGroups:
        await Navigator.of(context).pushReplacement(
          MaterialPageRoute<void>(
            builder: (_) => NoGroupsScreen(
              session: _session,
              identityRepository: widget.identityRepository,
            ),
          ),
        );
      case GroupEntryKind.waiting:
        break;
      case GroupEntryKind.home:
        break;
    }
  }

  Future<void> _loadMembers(String groupId) async {
    final members = await _groupRepository.loadGroupMembers(groupId);
    if (!mounted || _selectedGroup?.groupId != groupId) return;
    setState(() {
      _members = members;
      _membersByGroupId = {..._membersByGroupId, groupId: members};
    });
  }

  Future<Map<String, List<GroupMemberSummary>>> _loadAllGroupMembers(
    List<GroupSummary> groups,
  ) async {
    final entries = await Future.wait(
      groups.map((group) async {
        final members = await _groupRepository.loadGroupMembers(group.groupId);
        return MapEntry(group.groupId, members);
      }),
    );
    return Map<String, List<GroupMemberSummary>>.fromEntries(entries);
  }

  Future<void> _precacheGroupMemberPhotos(
    Iterable<GroupMemberSummary> members,
  ) async {
    final urls = members
        .map((member) => member.profilePhotoUrl?.trim())
        .whereType<String>()
        .where((url) => url.isNotEmpty)
        .toSet();

    await Future.wait(
      urls.map((url) async {
        try {
          await precacheImage(
            CachedNetworkImageProvider(url),
            context,
            onError: (error, stackTrace) {},
          );
        } catch (_) {
          // A broken member photo falls back to initials in ProfileImage.
        }
      }),
    );
  }

  void _listenToMembers(String groupId) {
    unawaited(_membersSubscription?.cancel());
    _membersSubscription = AppDatabase.instance()
        .ref('groupMembers/$groupId')
        .onValue
        .listen((_) => unawaited(_loadMembers(groupId)));
  }

  void _listenToAvailability(String groupId) {
    unawaited(_availabilitySubscription?.cancel());
    _availabilitySubscription = AppDatabase.instance()
        .ref('memberAvailability/$groupId')
        .onValue
        .listen((event) {
          final value = event.snapshot.value;
          final next = <String, MemberAvailability>{};

          if (value is Map<Object?, Object?>) {
            for (final entry in value.entries) {
              final raw = entry.value;
              if (raw is Map<Object?, Object?>) {
                next[entry.key.toString()] = MemberAvailability.fromJson(raw);
              }
            }
          }

          if (!mounted || _selectedGroup?.groupId != groupId) return;
          setState(() => _availability = next);
          _scheduleAvailabilityExpiryRefresh();
        });
  }

  void _listenToHandRaises(String groupId) {
    unawaited(_handRaiseSubscription?.cancel());
    _handRaiseSubscription = _handRaiseRepository
        .raisesRef(groupId)
        .onValue
        .listen(
          (event) {
            if (!mounted || _selectedGroup?.groupId != groupId) return;
            final next = HandRaiseRepository.parseSnapshot(
              event.snapshot.value,
            );
            final previous = _handRaises;
            final newlyRaised = next.entries.where(
              (entry) =>
                  entry.value &&
                  entry.key != _session.userId &&
                  previous[entry.key] != true,
            );

            setState(() => _handRaises = next);

            if (newlyRaised.isNotEmpty) {
              unawaited(
                TalkFeedback.remoteHandRaised(
                  hapticsEnabled: _session.settings.hapticsEnabled,
                ),
              );
            }
          },
          onError: (Object error) {
            debugPrint('Hand raise listener error: $error');
            if (!mounted || _selectedGroup?.groupId != groupId) return;
            setState(() => _message = "Couldn't sync hand raises.");
          },
        );
  }

  Future<void> _clearOwnHandRaise({String? groupId}) async {
    final resolvedGroupId = groupId ?? _selectedGroup?.groupId;
    if (resolvedGroupId == null || _handRaises[_session.userId] != true) {
      return;
    }

    try {
      await _handRaiseRepository.clearRaised(
        groupId: resolvedGroupId,
        userId: _session.userId,
      );
    } catch (_) {
      // Best-effort cleanup when leaving or closing the screen.
    }
  }

  void _scheduleAvailabilityExpiryRefresh() {
    _availabilityExpiryTimer?.cancel();
    final now =
        DateTime.now().millisecondsSinceEpoch ~/ Duration.millisecondsPerSecond;
    final futureExpiries = _availability.values
        .map((item) => item.staleAfterAt)
        .whereType<int>()
        .where((expiry) => expiry > now);
    if (futureExpiries.isEmpty) return;

    final nextExpiry = futureExpiries.reduce((a, b) => a < b ? a : b);
    _availabilityExpiryTimer = Timer(
      Duration(seconds: nextExpiry - now + 1),
      () {
        if (!mounted) return;
        setState(() {});
        _scheduleAvailabilityExpiryRefresh();
      },
    );
  }

  Future<void> _selectGroup(String groupId) async {
    final previousGroup = _selectedGroup;
    if (previousGroup != null) {
      await _clearOwnHandRaise(groupId: previousGroup.groupId);
    }

    final group = _groups.firstWhere((item) => item.groupId == groupId);
    final cachedMembers = _membersByGroupId[groupId];
    setState(() {
      _selectedGroup = group;
      _members = cachedMembers ?? const [];
      _availability = const {};
      _handRaises = const {};
      _speakingUserIds = const {};
    });
    if (cachedMembers == null) {
      await _loadMembers(group.groupId);
    }
    _listenToMembers(group.groupId);
    _listenToAvailability(group.groupId);
    _listenToHandRaises(group.groupId);
  }

  Future<void> _onGroupCarouselChanged(int index) async {
    if (index < 0 || index >= _groups.length) return;
    final group = _groups[index];
    setState(() => _carouselIndex = index);

    if (group.groupId == _selectedGroup?.groupId) return;

    if (_isOnline) {
      await _goAway();
      if (!mounted) return;
    }

    await _selectGroup(group.groupId);
  }

  void _syncCarouselToSelectedGroup() {
    final selected = _selectedGroup;
    if (selected == null || _groups.isEmpty) return;
    final index = _groups.indexWhere(
      (group) => group.groupId == selected.groupId,
    );
    if (index < 0) return;

    _carouselIndex = index;
  }

  void _openCreateGroup() {
    _openGroupAction(GroupActionMode.createGroup);
  }

  void _openJoinGroup() {
    _openGroupAction(GroupActionMode.joinByPin);
  }

  void _openGroupAction(GroupActionMode mode) {
    Navigator.of(context).push(
      PageRouteBuilder<void>(
        transitionDuration: const Duration(milliseconds: 320),
        reverseTransitionDuration: const Duration(milliseconds: 260),
        pageBuilder: (context, animation, secondaryAnimation) {
          return GroupActionScreen(
            mode: mode,
            session: _session,
            identityRepository: widget.identityRepository,
          );
        },
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          final offset =
              Tween<Offset>(
                begin: const Offset(0, 1),
                end: Offset.zero,
              ).animate(
                CurvedAnimation(parent: animation, curve: Curves.easeOutCubic),
              );
          return SlideTransition(position: offset, child: child);
        },
      ),
    );
  }

  Future<void> _createInvite() async {
    final group = _selectedGroup;
    if (group == null) return;

    await _runBusy(() async {
      final invite = await _groupRepository.createInvite(group.groupId);
      if (!mounted) return;
      setState(() => _message = 'Invite created');
      await _showShareInviteSheet(invite);
    });
  }

  Future<void> _showShareInviteSheet(GroupInviteResult invite) async {
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: const Color(0xff141414),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24.r)),
      ),
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: EdgeInsets.fromLTRB(24.w, 20.h, 24.w, 24.h),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Invite friends',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18.sp,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                SizedBox(height: 8.h),
                Text(
                  'Share this link. Your friend will open One One and join this group automatically.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.white70, fontSize: 14.sp),
                ),
                SizedBox(height: 20.h),
                Material(
                  color: const Color(0xff1f1f1f),
                  borderRadius: BorderRadius.circular(18.r),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(18.r),
                    onTap: () async {
                      try {
                        await InviteLinkBridge().shareInviteLink(
                          invite.inviteUrl,
                        );
                      } catch (_) {
                        await Clipboard.setData(
                          ClipboardData(text: invite.inviteUrl),
                        );
                        if (!context.mounted) return;
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Invite link copied')),
                        );
                      }
                    },
                    child: Container(
                      width: double.infinity,
                      padding: EdgeInsets.symmetric(
                        horizontal: 20.w,
                        vertical: 18.h,
                      ),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(18.r),
                        border: Border.all(
                          color: const Color.fromRGBO(255, 255, 255, 0.12),
                        ),
                      ),
                      child: Column(
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.ios_share_rounded,
                                color: Colors.white,
                                size: 22.sp,
                              ),
                              SizedBox(width: 10.w),
                              Text(
                                'Share invite link',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 16.sp,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ],
                          ),
                          SizedBox(height: 8.h),
                          Text(
                            invite.inviteUrl,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: Colors.white54,
                              fontSize: 11.sp,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                SizedBox(height: 14.h),
                TextButton.icon(
                  onPressed: () async {
                    await Clipboard.setData(
                      ClipboardData(text: invite.inviteCode),
                    );
                    if (!context.mounted) return;
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Fallback PIN copied')),
                    );
                  },
                  icon: Icon(Icons.copy_rounded, size: 17.sp),
                  label: Text('Copy PIN ${invite.inviteCode}'),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _openGroupPicker() {
    if (_groups.isEmpty) return;

    showModalBottomSheet<void>(
      context: context,
      backgroundColor: const Color(0xff141414),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24.r)),
      ),
      builder: (context) {
        return SafeArea(
          child: ListView(
            shrinkWrap: true,
            padding: EdgeInsets.fromLTRB(16.w, 12.h, 16.w, 24.h),
            children: [
              Padding(
                padding: EdgeInsets.only(bottom: 8.h, left: 8.w),
                child: Text(
                  'Your groups',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18.sp,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              for (final group in _groups)
                ListTile(
                  onTap: () {
                    Navigator.of(context).pop();
                    final index = _groups.indexWhere(
                      (item) => item.groupId == group.groupId,
                    );
                    if (index >= 0) {
                      unawaited(_onGroupCarouselChanged(index));
                    }
                  },
                  title: Text(
                    group.name,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  trailing: group.groupId == _selectedGroup?.groupId
                      ? const Icon(Icons.check_rounded, color: Colors.white)
                      : null,
                ),
            ],
          ),
        );
      },
    );
  }

  void _togglePresence() {
    if (_busy) return;
    if (!_serviceReady) {
      setState(() => _message = 'Invite a friend to enable voice service.');
      return;
    }
    if (_isOnline) {
      unawaited(_goAway());
    } else {
      unawaited(_goOnline());
    }
  }

  Future<void> _goOnline() async {
    final group = _selectedGroup;
    if (group == null) {
      setState(() => _message = 'Create or join a group first.');
      return;
    }
    if (!_serviceReady) {
      setState(() => _message = 'Invite a friend to enable voice service.');
      return;
    }

    setState(() {
      _busy = true;
      _state = 'connecting';
      _message = null;
    });

    OnlineSession? createdSession;
    try {
      createdSession = await _onlineRepository.goOnline(
        identity: _session,
        group: group,
      );
      await _connectLiveKit(createdSession);
      await _onlineRepository.markLive(createdSession);
      _heartbeatTimer?.cancel();
      _heartbeatTimer = Timer.periodic(const Duration(seconds: 10), (_) {
        final activeSession = _onlineSession;
        if (activeSession != null) {
          unawaited(
            _onlineRepository.heartbeat(
              activeSession,
              isTalking: _talkSession != null,
            ),
          );
        }
      });

      if (!mounted) return;
      setState(() {
        _onlineSession = createdSession;
        _state = 'live';
        _message = LiveKitStatus.live;
      });
    } catch (error) {
      await _disconnectLiveKit();
      if (createdSession != null) {
        try {
          await _onlineRepository.goAway(createdSession);
        } catch (_) {
          // Best-effort cleanup after a failed connect.
        }
      }
      if (!mounted) return;
      setState(() {
        _state = 'away';
        _message = LiveKitStatus.sanitizeError(error);
      });
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }

  Future<void> _goAway() async {
    final session = _onlineSession;
    if (session == null) {
      setState(() => _state = 'away');
      return;
    }

    await _runBusy(() async {
      final activeTalk = _talkSession;
      if (activeTalk != null) {
        await _talkRepository.stopTalk(activeTalk, reason: 'going_away');
      }
      _heartbeatTimer?.cancel();
      _heartbeatTimer = null;
      await _disconnectLiveKit();
      await _onlineRepository.goAway(session);
      await _clearOwnHandRaise(groupId: session.groupId);
      if (!mounted) return;
      setState(() {
        _onlineSession = null;
        _talkSession = null;
        _speakingUserIds = const {};
        _floatingReactions = const [];
        _state = 'away';
        _message = LiveKitStatus.away;
      });
    });
  }

  Future<void> _startTalking() async {
    final session = _onlineSession;
    if (session == null || _talkSession != null || _talkBusy) return;

    _talkPressed = true;
    setState(() {
      _talkBusy = true;
      _message = null;
    });

    TalkSession? startedTalk;
    try {
      startedTalk = await _talkRepository.startTalk(session);
      if (!_talkPressed) {
        await _talkRepository.stopTalk(startedTalk, reason: 'released_early');
        await _setMicrophoneEnabled(false);
        if (!mounted) return;
        setState(() {
          _talkSession = null;
          _state = 'live';
        });
        return;
      }

      await _setMicrophoneEnabled(true);
      unawaited(
        TalkFeedback.talkStarted(
          hapticsEnabled: _session.settings.hapticsEnabled,
        ),
      );
      if (_handRaises[_session.userId] == true) {
        unawaited(
          _handRaiseRepository.clearRaised(
            groupId: session.groupId,
            userId: _session.userId,
          ),
        );
      }
      if (!mounted) return;

      if (!_talkPressed) {
        await _setMicrophoneEnabled(false);
        await _talkRepository.stopTalk(startedTalk, reason: 'released_early');
        setState(() {
          _talkSession = null;
          _state = 'live';
        });
        return;
      }

      setState(() {
        _talkSession = startedTalk;
        _state = 'talking';
        _message = LiveKitStatus.talking;
      });
    } catch (error) {
      if (startedTalk != null) {
        await _talkRepository.stopTalk(startedTalk, reason: 'mic_failed');
      }
      if (!mounted) return;
      setState(() {
        _talkSession = null;
        _state = _onlineSession == null ? 'away' : 'live';
        _message = LiveKitStatus.sanitizeError(error);
      });
    } finally {
      if (mounted) {
        setState(() => _talkBusy = false);
      }
    }
  }

  Future<void> _stopTalking({String reason = 'released'}) async {
    _talkPressed = false;
    final talkSession = _talkSession;
    if (talkSession == null) return;

    setState(() {
      _talkSession = null;
      _state = 'live';
      _message = LiveKitStatus.live;
    });

    Object? stopError;
    try {
      await _setMicrophoneEnabled(false);
    } catch (error) {
      stopError = error;
    }

    try {
      unawaited(
        TalkFeedback.talkStopped(
          hapticsEnabled: _session.settings.hapticsEnabled,
        ),
      );
      await _talkRepository.stopTalk(talkSession, reason: reason);
    } catch (error) {
      stopError ??= error;
    }

    if (stopError != null) {
      if (!mounted) return;
      setState(() => _message = 'Couldn’t stop talking. Try again.');
    }
  }

  Future<void> _toggleHandRaise() async {
    final group = _selectedGroup;
    if (group == null || _handRaiseBusy || !_isOnline) return;

    final nextRaised = _handRaises[_session.userId] != true;
    setState(() {
      _handRaiseBusy = true;
      _handRaises = {..._handRaises, _session.userId: nextRaised};
    });
    try {
      await _handRaiseRepository.setRaised(
        groupId: group.groupId,
        userId: _session.userId,
        raised: nextRaised,
      );
      unawaited(
        TalkFeedback.handRaiseChanged(
          raised: nextRaised,
          hapticsEnabled: _session.settings.hapticsEnabled,
        ),
      );
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _handRaises = {..._handRaises, _session.userId: !nextRaised};
        _message = 'Couldn\u2019t update hand raise.';
      });
    } finally {
      if (mounted) setState(() => _handRaiseBusy = false);
    }
  }

  int get _onlineParticipantCount {
    final onlineUserIds = <String>{if (_isOnline) _session.userId};
    for (final friend in _friends) {
      final availability = _availability[friend.userId];
      if (availability?.isLive == true ||
          _speakingUserIds.contains(friend.userId)) {
        onlineUserIds.add(friend.userId);
      }
    }
    for (final participant
        in _room?.remoteParticipants.values ?? const <RemoteParticipant>[]) {
      final userId =
          LiveKitStatus.userIdFromIdentity(participant.identity) ??
          _participantUserIdFromIdentity(participant.identity);
      if (userId != null) onlineUserIds.add(userId);
    }
    return onlineUserIds.length;
  }

  /// Emoji/short text is available whenever at least two members are online.
  bool get _canSendInCallReaction {
    return _isOnline &&
        _room?.localParticipant != null &&
        _talkSession == null &&
        _onlineParticipantCount > 1;
  }

  Future<void> _openReactionComposer() async {
    if (!_canSendInCallReaction || _reactionBusy) return;

    final text = await showInCallReactionSheet(context);
    if (!mounted || text == null) return;
    await _sendInCallReaction(text);
  }

  Future<void> _sendInCallReaction(String rawText) async {
    final text = InCallReaction.sanitizeInput(rawText);
    final participant = _room?.localParticipant;
    if (text == null || participant == null || _reactionBusy) return;

    final reaction = InCallReaction(
      id: const Uuid().v4(),
      userId: _session.userId,
      displayName: _session.user.displayName,
      text: text,
      sentAtMs: DateTime.now().millisecondsSinceEpoch,
    );

    setState(() => _reactionBusy = true);
    try {
      await participant.publishData(
        reaction.encode(),
        reliable: true,
        topic: InCallReaction.topic,
      );
      _showFloatingReaction(reaction);
      unawaited(
        TalkFeedback.reactionReceived(
          hapticsEnabled: _session.settings.hapticsEnabled,
        ),
      );
    } catch (_) {
      if (!mounted) return;
      setState(() => _message = 'Couldn’t send reaction.');
    } finally {
      if (mounted) setState(() => _reactionBusy = false);
    }
  }

  void _onDataReceived(DataReceivedEvent event) {
    if (event.topic != null && event.topic != InCallReaction.topic) return;
    final reaction = InCallReaction.tryParse(event.data);
    if (reaction == null) return;
    if (reaction.userId == _session.userId) return;
    _showFloatingReaction(reaction);
    unawaited(
      TalkFeedback.reactionReceived(
        hapticsEnabled: _session.settings.hapticsEnabled,
      ),
    );
  }

  void _showFloatingReaction(InCallReaction reaction) {
    if (!mounted) return;

    _reactionDismissTimers.remove(reaction.id)?.cancel();
    setState(() {
      final next = [
        ..._floatingReactions.where((item) => item.id != reaction.id),
        reaction,
      ];
      // Keep the stack small so the center of the screen stays readable.
      _floatingReactions = next.length <= 3
          ? next
          : next.sublist(next.length - 3);
    });

    _reactionDismissTimers[reaction.id] = Timer(
      const Duration(milliseconds: 2900),
      () {
        _reactionDismissTimers.remove(reaction.id);
        if (!mounted) return;
        setState(() {
          _floatingReactions = _floatingReactions
              .where((item) => item.id != reaction.id)
              .toList(growable: false);
        });
      },
    );
  }

  void _clearFloatingReactions() {
    for (final timer in _reactionDismissTimers.values) {
      timer.cancel();
    }
    _reactionDismissTimers.clear();
    _floatingReactions = const [];
  }

  Future<void> _connectLiveKit(OnlineSession session) async {
    await _disconnectLiveKit();
    final speakerOn = _session.settings.audioOutputPreference != 'earpiece';
    final room = Room(
      roomOptions: RoomOptions(
        adaptiveStream: false,
        dynacast: false,
        defaultAudioOutputOptions: AudioOutputOptions(speakerOn: speakerOn),
      ),
    );

    _room = room;
    _attachRoomListener(room);

    setState(() {
      _state = 'connecting';
      _message = LiveKitStatus.connecting;
    });

    await room
        .connect(
          session.livekitServerUrl,
          session.livekitToken,
          connectOptions: const ConnectOptions(autoSubscribe: true),
        )
        .timeout(const Duration(seconds: 20));

    try {
      await room.setSpeakerOn(speakerOn);
    } catch (_) {
      // Non-fatal. LiveKit can still use the platform default route.
    }

    final localParticipant = room.localParticipant;
    if (localParticipant == null) {
      throw StateError('LiveKit connected without a local participant.');
    }

    await localParticipant
        .setMicrophoneEnabled(false)
        .timeout(const Duration(seconds: 8));
  }

  Future<void> _applyPreferredAudioRoute() async {
    final room = _room;
    if (room == null) return;
    final preference =
        widget
            .identityRepository
            .currentSession
            ?.settings
            .audioOutputPreference ??
        _session.settings.audioOutputPreference;
    try {
      await room.setSpeakerOn(preference != 'earpiece');
    } catch (_) {
      // Route changes are best effort on devices without a separate earpiece.
    }
  }

  bool get _liveHapticsEnabled {
    return widget.identityRepository.currentSession?.settings.hapticsEnabled ??
        _session.settings.hapticsEnabled;
  }

  Future<void> _handleRemoteSpeakerStarted() async {
    await TalkFeedback.remoteSpeakerStarted(
      hapticsEnabled: _liveHapticsEnabled,
    );
    // Some audio-feedback implementations briefly alter the platform audio
    // session. Reassert the user's route after the tone completes.
    await _applyPreferredAudioRoute();
  }

  String? _participantUserIdFromIdentity(String identity) {
    final parts = identity.split(':');
    if (parts.length < 3) return null;
    return parts[1];
  }

  ConnectionQuality _mergeConnectionQuality(
    ConnectionQuality? existing,
    ConnectionQuality incoming,
  ) {
    if (existing == null) return incoming;

    const order = [
      ConnectionQuality.lost,
      ConnectionQuality.poor,
      ConnectionQuality.unknown,
      ConnectionQuality.good,
      ConnectionQuality.excellent,
    ];

    final existingIndex = order.indexOf(existing);
    final incomingIndex = order.indexOf(incoming);
    return existingIndex <= incomingIndex ? existing : incoming;
  }

  void _syncConnectionQualities(Room room) {
    if (!mounted) return;

    final remotes = <String, ConnectionQuality>{};
    for (final participant in room.remoteParticipants.values) {
      final userId = _participantUserIdFromIdentity(participant.identity);
      if (userId == null) continue;
      remotes[userId] = _mergeConnectionQuality(
        remotes[userId],
        participant.connectionQuality,
      );
    }

    setState(() {
      _localConnectionQuality =
          room.localParticipant?.connectionQuality ?? ConnectionQuality.unknown;
      _remoteConnectionQualityByUserId = remotes;
    });
  }

  void _updateParticipantConnectionQuality(
    Participant participant,
    ConnectionQuality quality,
  ) {
    if (!mounted) return;

    if (participant is LocalParticipant) {
      setState(() => _localConnectionQuality = quality);
      return;
    }

    final userId = _participantUserIdFromIdentity(participant.identity);
    if (userId == null) return;

    setState(() {
      _remoteConnectionQualityByUserId = {
        ..._remoteConnectionQualityByUserId,
        userId: _mergeConnectionQuality(
          _remoteConnectionQualityByUserId[userId],
          quality,
        ),
      };
    });
  }

  void _clearConnectionQualities() {
    _localConnectionQuality = ConnectionQuality.unknown;
    _remoteConnectionQualityByUserId = const {};
    if (mounted) setState(() {});
  }

  void _attachRoomListener(Room room) {
    _roomListener = room.createListener()
      ..on<RoomConnectedEvent>((_) {
        _syncConnectionQualities(room);
        _setMessage(LiveKitStatus.connected);
      })
      ..on<RoomReconnectingEvent>((_) {
        _setStateAndMessage('reconnecting', LiveKitStatus.reconnecting);
      })
      ..on<RoomReconnectedEvent>((_) {
        _syncConnectionQualities(room);
        _setStateAndMessage('live', LiveKitStatus.connected);
      })
      ..on<RoomDisconnectedEvent>((event) {
        if (!mounted) return;
        setState(() {
          _speakingUserIds = const {};
          _state = 'disconnected';
          _message = LiveKitStatus.fromDisconnectReason(event.reason);
        });
        _clearConnectionQualities();
      })
      ..on<ParticipantConnectedEvent>((event) {
        _updateParticipantConnectionQuality(
          event.participant,
          event.participant.connectionQuality,
        );
      })
      ..on<ParticipantConnectionQualityUpdatedEvent>((event) {
        _updateParticipantConnectionQuality(
          event.participant,
          event.connectionQuality,
        );
      })
      ..on<TrackSubscribedEvent>((_) {
        // Subscription is an implementation detail — keep UI status clean.
      })
      ..on<ActiveSpeakersChangedEvent>((event) {
        final previousRemoteSpeakers = _speakingUserIds.where(
          (id) => id != _session.userId,
        );
        final speaking = <String>{};
        for (final speaker in event.speakers) {
          final userId =
              LiveKitStatus.userIdFromIdentity(speaker.identity) ??
              _participantUserIdFromIdentity(speaker.identity);
          if (userId != null) speaking.add(userId);
        }
        if (!mounted) return;
        final newlySpeakingRemote = speaking
            .where((id) => id != _session.userId)
            .any((id) => !previousRemoteSpeakers.contains(id));
        if (newlySpeakingRemote && _talkSession != null) {
          unawaited(_handleRemoteSpeakerStarted());
        } else if (speaking.any((id) => id != _session.userId)) {
          // Never let active-speaker auto-routing override the stored choice.
          unawaited(_applyPreferredAudioRoute());
        }
        setState(() {
          _speakingUserIds = speaking;
          final remoteSpeaking = speaking.any((id) => id != _session.userId);
          if (remoteSpeaking && _talkSession == null) {
            _message = LiveKitStatus.receivingVoice;
          }
        });
      })
      ..on<DataReceivedEvent>(_onDataReceived);
  }

  Future<void> _disconnectLiveKit() async {
    final room = _room;
    _room = null;
    _roomListener?.dispose();
    _roomListener = null;
    _speakingUserIds = const {};
    _clearFloatingReactions();
    _clearConnectionQualities();

    try {
      final localParticipant = room?.localParticipant;
      if (localParticipant != null) {
        await localParticipant.setMicrophoneEnabled(false);
      }
    } catch (_) {
      // Ignore cleanup failures.
    }

    await room?.disconnect();
  }

  Future<void> _setMicrophoneEnabled(bool enabled) async {
    final participant = _room?.localParticipant;
    if (participant == null) {
      throw StateError('LiveKit is not connected yet.');
    }

    await participant
        .setMicrophoneEnabled(enabled)
        .timeout(const Duration(seconds: 8));
  }

  Future<void> _runBusy(Future<void> Function() action) async {
    setState(() {
      _busy = true;
      _message = null;
    });

    try {
      await action();
    } catch (error) {
      if (!mounted) return;
      setState(() => _message = LiveKitStatus.sanitizeError(error));
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }

  void _setMessage(String message) {
    if (!mounted) return;
    setState(() => _message = message);
  }

  void _setStateAndMessage(String state, String message) {
    if (!mounted) return;
    setState(() {
      _state = state;
      _message = message;
    });
  }

  GroupSummary? _resolveSelectedGroup(List<GroupSummary> groups) {
    if (groups.isEmpty) return null;

    final preferredGroupId = _preferredGroupId;
    if (preferredGroupId != null) {
      for (final group in groups) {
        if (group.groupId == preferredGroupId) return group;
      }
    }

    final currentGroup = _selectedGroup;
    if (currentGroup == null) return groups.first;

    for (final group in groups) {
      if (group.groupId == currentGroup.groupId) return group;
    }

    return groups.first;
  }

  void _openSettings() {
    unawaited(
      SettingsScreen.open(
        context,
        session: _session,
        identityRepository: widget.identityRepository,
      ),
    );
  }

  void _openNudges() {
    final group = _selectedGroup;
    if (group == null) return;
    unawaited(
      showNudgeBottomSheet(
        context,
        group: group,
        currentUserId: _session.userId,
        members: _displayMembers,
        accent: accentColorForKey(_session.settings.accentColorKey),
      ),
    );
  }

  void _openSetupWarnings() {
    final warnings = _setupWarnings();
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (context) {
        return SafeArea(
          child: ListView(
            shrinkWrap: true,
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
            children: [
              Text('Setup', style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 12),
              if (warnings.isEmpty)
                const _SetupLine(
                  ok: true,
                  text: 'Ready for foreground and closed-app voice',
                )
              else
                for (final warning in warnings)
                  _SetupLine(ok: false, text: warning),
            ],
          ),
        );
      },
    );
  }

  List<String> _setupWarnings() {
    final warnings = <String>[];
    if (_groups.isEmpty) {
      warnings.add('Create or join a group.');
    }
    if (!_session.device.micPermissionGranted && _onlineSession == null) {
      warnings.add('Microphone permission has not been confirmed.');
    }
    if (!_session.device.notificationPermissionGranted) {
      warnings.add('Notification permission is required for closed-app nudges.');
    }
    if (_session.device.fcmToken == null) {
      warnings.add('Push registration is not ready. Reopen the app while online.');
    }
    if (!_session.device.batteryOptimizationIgnored) {
      warnings.add('Battery optimization may interrupt background mode.');
    }
    return warnings;
  }

  bool get _isOnline => _onlineSession != null;

  /// Single-word presence label shown beneath the online/offline toggle.
  /// Recomputed on every `setState` that touches `_state`/`_onlineSession`,
  /// so it updates immediately as the toggle changes.
  String get _presenceStatusLabel {
    switch (_state) {
      case 'talking':
      case 'live':
        return 'Live';
      case 'connecting':
      case 'reconnecting':
        return 'Online';
      case 'disconnected':
        return 'Offline';
      case 'away':
      default:
        return 'Away';
    }
  }

  bool get _serviceReady =>
      groupHasServicePeer(members: _members, currentUserId: _session.userId);

  List<GroupMemberSummary> get _friends {
    return _members
        .where((member) => member.userId != _session.userId)
        .toList(growable: false);
  }

  List<GroupMemberSummary> get _displayMembers {
    return _displayMembersFrom(_members);
  }

  List<GroupMemberSummary> _displayMembersFrom(
    List<GroupMemberSummary> members,
  ) {
    return members
        .map((member) {
          if (member.userId != _session.userId) return member;
          return GroupMemberSummary(
            userId: member.userId,
            displayName: _session.user.displayName,
            role: member.role,
            memberState: member.memberState,
            profilePhotoUrl: _session.user.profilePhotoUrl,
            profilePhotoBase64: _session.user.profilePhotoBase64,
          );
        })
        .toList(growable: false);
  }

  ConnectionQuality get _effectiveLocalConnectionQuality {
    if (_connectivity.contains(ConnectivityResult.none)) {
      return ConnectionQuality.lost;
    }
    if (_localConnectionQuality != ConnectionQuality.unknown) {
      return _localConnectionQuality;
    }
    return _connectivity.isEmpty
        ? ConnectionQuality.unknown
        : ConnectionQuality.good;
  }

  List<_CarouselItem> get _carouselItems {
    final selfIsLive = _isOnline && (_state == 'live' || _state == 'talking');
    final selfAvailability = _isOnline
        ? MemberAvailability(
            desiredState: 'online',
            effectiveState: _state,
            canReceiveLiveAudio: selfIsLive,
          )
        : MemberAvailability.away;

    return [
      for (final group in _groups)
        _CarouselItem.group(
          group: group,
          displayName: _session.user.displayName,
          profilePhotoUrl: _session.user.profilePhotoUrl,
          profilePhotoBase64: _session.user.profilePhotoBase64,
          availability: group.groupId == _selectedGroup?.groupId
              ? selfAvailability
              : MemberAvailability.away,
          members: _displayMembersFrom(
            _membersByGroupId[group.groupId] ?? const [],
          ),
        ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final accent = accentColorForKey(_session.settings.accentColorKey);
    final warnings = _setupWarnings();
    final items = _carouselItems;
    final focusedGroup = _selectedGroup;
    // Local session is the source of truth — remote availability can lag after goAway.
    final live = _isOnline && (_state == 'live' || _state == 'talking');
    final inviteAction = _busy || focusedGroup == null
        ? null
        : () => unawaited(_createInvite());

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
        children: [
          _HomeBackdrop(
            members: _displayMembers,
            fallbackPhotoUrl: _session.user.profilePhotoUrl,
            fallbackPhotoBase64: _session.user.profilePhotoBase64,
            accent: accent,
          ),
          SafeArea(
            child: Column(
              children: [
                _TopChrome(
                  onSettings: _openSettings,
                  onNudge: _openNudges,
                  nudgeEnabled: focusedGroup != null && _friends.isNotEmpty,
                  onSetup: _openSetupWarnings,
                  hasSetupWarnings: warnings.isNotEmpty,
                  busy: _busy,
                  online: live,
                  enabled: _serviceReady,
                  onTogglePresence: _togglePresence,
                  showNetworkStrength: _isOnline,
                  localConnectionQuality: _effectiveLocalConnectionQuality,
                  statusLabel: _presenceStatusLabel,
                ),
                SizedBox(height: 8.h),
                _FriendsStrip(
                  friends: _friends,
                  availability: _availability,
                  speakingUserIds: _speakingUserIds,
                  handRaises: _handRaises,
                  connectionQualityByUserId: _remoteConnectionQualityByUserId,
                  onInvite: inviteAction,
                ),
                if (_message != null) ...[
                  SizedBox(height: 10.h),
                  Padding(
                    padding: EdgeInsets.symmetric(horizontal: 24.w),
                    child: Text(
                      _message!,
                      textAlign: TextAlign.center,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(color: Colors.white70, fontSize: 12.sp),
                    ),
                  ),
                ],
                const Spacer(),
                if (focusedGroup != null)
                  _CarouselCaption(
                    displayName: _session.user.displayName,
                    handRaised: _handRaises[_session.userId] == true,
                    handRaiseBusy: _handRaiseBusy,
                    handRaiseEnabled: _isOnline,
                    onHandRaise: _toggleHandRaise,
                    showReaction: _canSendInCallReaction,
                    reactionBusy: _reactionBusy,
                    onReaction: _openReactionComposer,
                    groupName: focusedGroup.name,
                    onTapName: _groups.length > 1 ? _openGroupPicker : null,
                  ),
                SizedBox(height: 10.h),
                SizedBox(
                  height: 200.h,
                  child: _ExperienceCarousel(
                    items: items,
                    index: _carouselIndex,
                    talkEnabled: _isOnline && !_busy,
                    talkActive: _talkSession != null,
                    talkBusy: _talkBusy,
                    accent: accent,
                    onSelected: (index) {
                      unawaited(_onGroupCarouselChanged(index));
                    },
                    onTalkStart: _startTalking,
                    onTalkStop: () => _stopTalking(),
                    onCreateGroup: _openCreateGroup,
                    onJoinGroup: _openJoinGroup,
                  ),
                ),
                if (items.length > 1) ...[
                  SizedBox(height: 8.h),
                  _CarouselDotIndicator(
                    count: items.length,
                    index: _carouselIndex.clamp(0, items.length - 1),
                  ),
                ],
                SizedBox(height: 18.h),
                Text(
                  _isOnline
                      ? 'Tap to Talk'
                      : !_serviceReady
                      ? 'invite a friend to enable voice service'
                      : 'go online to start talking',
                  style: TextStyle(
                    color: const Color.fromRGBO(255, 255, 255, 0.55),
                    fontSize: 13.sp,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                SizedBox(height: 28.h),
              ],
            ),
          ),
          if (_floatingReactions.isNotEmpty)
            InCallReactionOverlay(reactions: _floatingReactions),
          if (_loadingGroups)
            const ColoredBox(
              color: Color(0x88000000),
              child: Center(
                child: CircularProgressIndicator(color: Colors.white),
              ),
            ),
        ],
      ),
    );
  }
}

class _HomeBackdrop extends StatelessWidget {
  const _HomeBackdrop({
    required this.members,
    required this.fallbackPhotoUrl,
    required this.fallbackPhotoBase64,
    required this.accent,
  });

  final List<GroupMemberSummary> members;
  final String? fallbackPhotoUrl;
  final String? fallbackPhotoBase64;
  final Color accent;

  bool _memberHasPhoto(GroupMemberSummary member) {
    return (member.profilePhotoUrl?.trim().isNotEmpty ?? false) ||
        (member.profilePhotoBase64?.trim().isNotEmpty ?? false);
  }

  @override
  Widget build(BuildContext context) {
    final hasMemberPhotos = members.any(_memberHasPhoto);
    final hasFallbackPhoto =
        (fallbackPhotoUrl?.trim().isNotEmpty ?? false) ||
        (fallbackPhotoBase64?.trim().isNotEmpty ?? false);
    final showCollage = members.isNotEmpty ? true : hasFallbackPhoto;

    return Stack(
      fit: StackFit.expand,
      children: [
        const ColoredBox(color: Colors.black),
        if (showCollage)
          Opacity(
            opacity: hasMemberPhotos || hasFallbackPhoto ? 0.35 : 0.2,
            child: ImageFiltered(
              imageFilter: ImageFilter.blur(sigmaX: 40, sigmaY: 40),
              child: FittedBox(
                fit: BoxFit.cover,
                child: SizedBox(
                  width: 400,
                  height: 800,
                  child: _BackdropMemberCollage(
                    members: members,
                    fallbackPhotoUrl: fallbackPhotoUrl,
                    fallbackPhotoBase64: fallbackPhotoBase64,
                  ),
                ),
              ),
            ),
          ),
        DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Colors.black.withValues(alpha: 0.3),
                Colors.black.withValues(alpha: 0.55),
                Colors.black.withValues(alpha: 0.88),
                Color.lerp(Colors.black, accent, 0.14)!,
              ],
              stops: const [0, 0.35, 0.72, 1],
            ),
          ),
        ),
      ],
    );
  }
}

/// Full-bleed member photo grid for the blurred home backdrop.
class _BackdropMemberCollage extends StatelessWidget {
  const _BackdropMemberCollage({
    required this.members,
    required this.fallbackPhotoUrl,
    required this.fallbackPhotoBase64,
  });

  static const int _maxTiles = 9;

  final List<GroupMemberSummary> members;
  final String? fallbackPhotoUrl;
  final String? fallbackPhotoBase64;

  int _columnsFor(int count) {
    if (count <= 1) return 1;
    if (count <= 4) return 2;
    return 3;
  }

  Widget _tile(GroupMemberSummary member) {
    final initial = member.displayName.trim().isEmpty
        ? '?'
        : member.displayName.trim().substring(0, 1).toUpperCase();
    return ProfileImage(
      profilePhotoUrl: member.profilePhotoUrl,
      profilePhotoBase64: member.profilePhotoBase64,
      backgroundColor: const Color(0xff1a1a1a),
      fallback: Text(
        initial,
        style: const TextStyle(
          color: Colors.white54,
          fontSize: 48,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (members.isEmpty) {
      return ProfileImage(
        profilePhotoUrl: fallbackPhotoUrl,
        profilePhotoBase64: fallbackPhotoBase64,
        backgroundColor: const Color(0xff1a1a1a),
        fallback: const Icon(
          Icons.person_outline,
          color: Colors.white38,
          size: 120,
        ),
      );
    }

    final tiles = members.take(_maxTiles).toList(growable: false);
    final columns = _columnsFor(tiles.length);
    final rows = (tiles.length / columns).ceil();

    return Column(
      children: List.generate(rows, (row) {
        return Expanded(
          child: Row(
            children: List.generate(columns, (column) {
              final index = row * columns + column;
              if (index >= tiles.length) {
                return const Expanded(
                  child: ColoredBox(color: Color(0xff141414)),
                );
              }
              return Expanded(child: _tile(tiles[index]));
            }),
          ),
        );
      }),
    );
  }
}

class _TopChrome extends StatelessWidget {
  const _TopChrome({
    required this.onSettings,
    required this.onNudge,
    required this.nudgeEnabled,
    required this.onSetup,
    required this.hasSetupWarnings,
    required this.busy,
    required this.online,
    required this.enabled,
    required this.onTogglePresence,
    required this.showNetworkStrength,
    required this.localConnectionQuality,
    required this.statusLabel,
  });

  final VoidCallback onSettings;
  final VoidCallback onNudge;
  final bool nudgeEnabled;
  final VoidCallback onSetup;
  final bool hasSetupWarnings;
  final bool busy;
  final bool online;
  final bool enabled;
  final VoidCallback onTogglePresence;
  final bool showNetworkStrength;
  final ConnectionQuality localConnectionQuality;
  final String statusLabel;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(12.w, 4.h, 12.w, 0),
      child: SizedBox(
        height: 52.h,
        child: Stack(
          alignment: Alignment.center,
          children: [
            Center(
              child: Image.asset(
                'assets/logo.png',
                height: 44.h,
                fit: BoxFit.contain,
              ),
            ),
            Align(
              alignment: Alignment.centerLeft,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Stack(
                    clipBehavior: Clip.none,
                    children: [
                      _GlassIconButton(
                        tooltip: hasSetupWarnings
                            ? 'Settings / Setup'
                            : 'Settings',
                        icon: Icons.settings_outlined,
                        onPressed: onSettings,
                        onLongPress: onSetup,
                      ),
                      if (hasSetupWarnings)
                        Positioned(
                          top: -2,
                          right: -2,
                          child: GestureDetector(
                            onTap: onSetup,
                            child: Container(
                              width: 14.w,
                              height: 14.w,
                              decoration: const BoxDecoration(
                                color: Color(0xffff5a5f),
                                shape: BoxShape.circle,
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                  SizedBox(width: 6.w),
                  _GlassIconButton(
                    tooltip: 'Nudge friends',
                    icon: Icons.notifications_active_outlined,
                    onPressed: nudgeEnabled ? onNudge : null,
                  ),
                  if (showNetworkStrength) ...[
                    SizedBox(width: 6.w),
                    _NetworkStrengthIndicator(
                      quality: localConnectionQuality,
                      tooltip: 'Your network',
                    ),
                  ],
                ],
              ),
            ),
            Align(
              alignment: Alignment.centerRight,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  _StatusToggle(
                    busy: busy,
                    online: online,
                    enabled: enabled,
                    onToggle: onTogglePresence,
                  ),
                  SizedBox(height: 3.h),
                  Text(
                    statusLabel,
                    style: TextStyle(
                      color: const Color.fromRGBO(255, 255, 255, 0.65),
                      fontSize: 10.sp,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.2,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StatusToggle extends StatelessWidget {
  const _StatusToggle({
    required this.busy,
    required this.online,
    required this.enabled,
    required this.onToggle,
  });

  final bool busy;
  final bool online;
  final bool enabled;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: busy || !enabled ? 0.55 : 1,
      child: Tooltip(
        message: !enabled
            ? 'Available after another member joins'
            : online
            ? 'Tap to go away'
            : 'Tap to go online',
        child: Material(
          color: const Color.fromRGBO(255, 255, 255, 0.12),
          borderRadius: BorderRadius.circular(18.r),
          child: InkWell(
            onTap: busy || !enabled ? null : onToggle,
            borderRadius: BorderRadius.circular(18.r),
            child: Container(
              width: 72.w,
              height: 30.h,
              padding: EdgeInsets.all(2.w),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(18.r),
                border: Border.all(
                  color: const Color.fromRGBO(255, 255, 255, 0.22),
                ),
              ),
              child: Stack(
                children: [
                  AnimatedAlign(
                    duration: const Duration(milliseconds: 220),
                    curve: Curves.easeOutCubic,
                    alignment: online
                        ? Alignment.centerRight
                        : Alignment.centerLeft,
                    child: Container(
                      width: 34.w,
                      height: double.infinity,
                      decoration: BoxDecoration(
                        color: online ? const Color(0xff7CFF6B) : Colors.white,
                        borderRadius: BorderRadius.circular(14.r),
                      ),
                    ),
                  ),
                  Row(
                    children: [
                      Expanded(
                        child: Center(
                          child: Text('🌙', style: TextStyle(fontSize: 11.sp)),
                        ),
                      ),
                      Expanded(
                        child: Center(
                          child: busy
                              ? Text('…', style: TextStyle(fontSize: 11.sp))
                              : online
                              ? Text('🟢', style: TextStyle(fontSize: 11.sp))
                              : const SizedBox.shrink(),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _GlassIconButton extends StatelessWidget {
  const _GlassIconButton({
    required this.tooltip,
    required this.icon,
    required this.onPressed,
    this.onLongPress,
  });

  final String tooltip;
  final IconData icon;
  final VoidCallback? onPressed;
  final VoidCallback? onLongPress;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: onPressed,
        onLongPress: onLongPress,
        borderRadius: BorderRadius.circular(22.r),
        child: Container(
          width: 44.w,
          height: 44.w,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: onPressed == null
                ? const Color.fromRGBO(255, 255, 255, 0.06)
                : const Color.fromRGBO(0, 0, 0, 0.35),
            border: Border.all(
              color: const Color.fromRGBO(255, 255, 255, 0.18),
            ),
          ),
          child: Icon(
            icon,
            color: onPressed == null ? Colors.white38 : Colors.white,
            size: 20.sp,
          ),
        ),
      ),
    );
  }
}

class _FriendsStrip extends StatelessWidget {
  const _FriendsStrip({
    required this.friends,
    required this.availability,
    required this.speakingUserIds,
    required this.handRaises,
    required this.connectionQualityByUserId,
    required this.onInvite,
  });

  final List<GroupMemberSummary> friends;
  final Map<String, MemberAvailability> availability;
  final Set<String> speakingUserIds;
  final Map<String, bool> handRaises;
  final Map<String, ConnectionQuality> connectionQualityByUserId;
  final VoidCallback? onInvite;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: EdgeInsets.symmetric(horizontal: 20.w),
          child: Text(
            'friends',
            style: TextStyle(
              color: Colors.white,
              fontSize: 14.sp,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.2,
            ),
          ),
        ),
        SizedBox(height: 10.h),
        SizedBox(
          height: 104.h,
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: EdgeInsets.symmetric(horizontal: 16.w),
            children: [
              for (final friend in friends) ...[
                _FriendChip(
                  name: friend.displayName,
                  profilePhotoUrl: friend.profilePhotoUrl,
                  profilePhotoBase64: friend.profilePhotoBase64,
                  availability:
                      availability[friend.userId] ?? MemberAvailability.away,
                  isSpeaking:
                      speakingUserIds.contains(friend.userId) ||
                      (availability[friend.userId]?.isTalking ?? false),
                  handRaised: handRaises[friend.userId] == true,
                  connectionQuality:
                      connectionQualityByUserId[friend.userId] ??
                      ConnectionQuality.unknown,
                ),
                SizedBox(width: 12.w),
              ],
              _AddFriendChip(onTap: onInvite),
            ],
          ),
        ),
      ],
    );
  }
}

class _FriendChip extends StatelessWidget {
  const _FriendChip({
    required this.name,
    required this.profilePhotoUrl,
    required this.profilePhotoBase64,
    required this.availability,
    required this.isSpeaking,
    required this.handRaised,
    required this.connectionQuality,
  });

  final String name;
  final String? profilePhotoUrl;
  final String? profilePhotoBase64;
  final MemberAvailability availability;
  final bool isSpeaking;
  final bool handRaised;
  final ConnectionQuality connectionQuality;

  @override
  Widget build(BuildContext context) {
    final live = availability.isLive;
    final degradedNetwork =
        connectionQuality == ConnectionQuality.poor ||
        connectionQuality == ConnectionQuality.lost;
    final shortName = name.trim().split(RegExp(r'\s+')).first;
    final initial = name.trim().isEmpty
        ? '?'
        : name.trim().substring(0, 1).toUpperCase();
    final ringColor = isSpeaking
        ? const Color(0xff7CFF6B)
        : live
        ? const Color(0xff7CFF6B)
        : Colors.white24;

    return Column(
      children: [
        Stack(
          clipBehavior: Clip.none,
          alignment: Alignment.center,
          children: [
            if (isSpeaking)
              const _TalkingPulseRing(color: Color(0xff7CFF6B), size: 60),
            Container(
              width: 52.w,
              height: 52.w,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: const Color(0xff2a2a2a),
                border: Border.all(
                  color: ringColor,
                  width: isSpeaking ? 2.5 : 2,
                ),
              ),
              child: ClipOval(
                child: ProfileAvatar(
                  profilePhotoUrl: profilePhotoUrl,
                  profilePhotoBase64: profilePhotoBase64,
                  radius: 26.w,
                  backgroundColor: const Color(0xff2a2a2a),
                  fallback: Text(
                    initial,
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 18.sp,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
            ),
            Positioned(
              right: -4,
              bottom: -2,
              child: Text(
                handRaised
                    ? '✋'
                    : live
                    ? '🟢'
                    : '🌙',
                style: TextStyle(fontSize: 14.sp),
              ),
            ),
          ],
        ),
        SizedBox(height: 4.h),
        SizedBox(
          width: 72.w,
          child: Text(
            isSpeaking ? '🗣️ talking' : name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: isSpeaking ? const Color(0xff7CFF6B) : Colors.white70,
              fontSize: 10.sp,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        if (degradedNetwork && !isSpeaking) ...[
          SizedBox(height: 2.h),
          SizedBox(
            width: 72.w,
            child: Text(
              "${shortName.isEmpty ? 'Their' : shortName}'s network is low",
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: const Color(0xffffb347),
                fontSize: 8.sp,
                fontWeight: FontWeight.w600,
                height: 1.1,
              ),
            ),
          ),
        ],
      ],
    );
  }
}

class _TalkingPulseRing extends StatefulWidget {
  const _TalkingPulseRing({required this.color, required this.size});

  final Color color;
  final double size;

  @override
  State<_TalkingPulseRing> createState() => _TalkingPulseRingState();
}

class _TalkingPulseRingState extends State<_TalkingPulseRing>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1100),
  )..repeat();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        final t = _controller.value;
        final scale = 1 + (0.18 * t);
        final opacity = (1 - t).clamp(0.0, 1.0);
        return Transform.scale(
          scale: scale,
          child: Container(
            width: widget.size.w,
            height: widget.size.w,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                color: widget.color.withValues(alpha: 0.55 * opacity),
                width: 2,
              ),
            ),
          ),
        );
      },
    );
  }
}

class _NetworkStrengthIndicator extends StatelessWidget {
  const _NetworkStrengthIndicator({
    required this.quality,
    required this.tooltip,
  });

  final ConnectionQuality quality;
  final String tooltip;

  @override
  Widget build(BuildContext context) {
    final activeBars = switch (quality) {
      ConnectionQuality.excellent => 4,
      ConnectionQuality.good => 3,
      ConnectionQuality.poor => 1,
      ConnectionQuality.lost => 0,
      ConnectionQuality.unknown => 0,
    };
    final color = switch (quality) {
      ConnectionQuality.excellent => const Color(0xff7CFF6B),
      ConnectionQuality.good => Colors.white,
      ConnectionQuality.poor => const Color(0xffffb347),
      ConnectionQuality.lost => const Color(0xffff5a5f),
      ConnectionQuality.unknown => Colors.white38,
    };

    return Tooltip(
      message: tooltip,
      child: SizedBox(
        width: 26.w,
        height: 30.w,
        child: Center(
          child: quality == ConnectionQuality.lost
              ? Icon(Icons.signal_cellular_off, color: color, size: 18.sp)
              : Row(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    for (var bar = 0; bar < 4; bar++)
                      Container(
                        width: 3.w,
                        height: (6 + bar * 3).h,
                        margin: EdgeInsets.only(right: bar == 3 ? 0 : 1.5.w),
                        decoration: BoxDecoration(
                          color: bar < activeBars ? color : Colors.white24,
                          borderRadius: BorderRadius.circular(1.r),
                        ),
                      ),
                  ],
                ),
        ),
      ),
    );
  }
}

class _AddFriendChip extends StatelessWidget {
  const _AddFriendChip({required this.onTap});

  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Opacity(
        opacity: onTap == null ? 0.45 : 1,
        child: Column(
          children: [
            Container(
              width: 52.w,
              height: 52.w,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white54, width: 1.5),
              ),
              child: Icon(Icons.add, color: Colors.white, size: 24.sp),
            ),
            SizedBox(height: 4.h),
            Text(
              'invite',
              style: TextStyle(
                color: Colors.white70,
                fontSize: 10.sp,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CarouselCaption extends StatelessWidget {
  const _CarouselCaption({
    required this.displayName,
    required this.handRaised,
    required this.handRaiseBusy,
    required this.handRaiseEnabled,
    required this.onHandRaise,
    required this.showReaction,
    required this.reactionBusy,
    required this.onReaction,
    required this.groupName,
    required this.onTapName,
  });

  final String displayName;
  final bool handRaised;
  final bool handRaiseBusy;
  final bool handRaiseEnabled;
  final VoidCallback onHandRaise;
  final bool showReaction;
  final bool reactionBusy;
  final VoidCallback onReaction;
  final String? groupName;
  final VoidCallback? onTapName;

  @override
  Widget build(BuildContext context) {
    final name = displayName.trim().isEmpty ? 'you' : displayName.toLowerCase();

    return Column(
      children: [
        GestureDetector(
          onTap: onTapName,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                (groupName ?? name).toLowerCase(),
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 22.sp,
                  fontWeight: FontWeight.w800,
                ),
              ),
              if (onTapName != null) ...[
                SizedBox(width: 4.w),
                Icon(
                  Icons.keyboard_arrow_down_rounded,
                  color: Colors.white,
                  size: 22.sp,
                ),
              ],
            ],
          ),
        ),
        SizedBox(height: 2.h),
        Text(
          name,
          style: TextStyle(
            color: Colors.white54,
            fontSize: 12.sp,
            fontWeight: FontWeight.w500,
          ),
        ),
        SizedBox(height: 10.h),
        SizedBox(
          width: 330.w,
          height: 38.h,
          child: Stack(
            alignment: Alignment.center,
            children: [
              Center(
                child: Opacity(
                  opacity: handRaiseBusy || !handRaiseEnabled ? 0.45 : 1,
                  child: Material(
                    color: handRaised
                        ? const Color(0xfffff1a8)
                        : const Color.fromRGBO(255, 255, 255, 0.14),
                    borderRadius: BorderRadius.circular(18.r),
                    child: InkWell(
                      onTap: handRaiseBusy || !handRaiseEnabled
                          ? null
                          : onHandRaise,
                      borderRadius: BorderRadius.circular(18.r),
                      child: Padding(
                        padding: EdgeInsets.symmetric(
                          horizontal: 12.w,
                          vertical: 7.h,
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text('✋', style: TextStyle(fontSize: 13.sp)),
                            SizedBox(width: 6.w),
                            Text(
                              handRaised ? 'Hand raised' : 'Raise hand',
                              style: TextStyle(
                                color: handRaised ? Colors.black : Colors.white,
                                fontSize: 13.sp,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              if (showReaction)
                Align(
                  alignment: Alignment.centerRight,
                  child: Opacity(
                    opacity: reactionBusy ? 0.55 : 1,
                    child: Tooltip(
                      message: 'Send a reaction',
                      child: Material(
                        color: const Color.fromRGBO(255, 255, 255, 0.14),
                        shape: const CircleBorder(),
                        child: InkWell(
                          onTap: reactionBusy ? null : onReaction,
                          customBorder: const CircleBorder(),
                          child: SizedBox(
                            width: 38.w,
                            height: 38.w,
                            child: Icon(
                              Icons.keyboard_rounded,
                              color: Colors.white,
                              size: 20.sp,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

/// Page-indicator dots shown below the group carousel when the user has
/// more than one group, so position/count is obvious at a glance.
class _CarouselDotIndicator extends StatelessWidget {
  const _CarouselDotIndicator({required this.count, required this.index});

  final int count;
  final int index;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        for (var i = 0; i < count; i++)
          AnimatedContainer(
            duration: const Duration(milliseconds: 220),
            curve: Curves.easeOutCubic,
            margin: EdgeInsets.symmetric(horizontal: 3.w),
            width: i == index ? 16.w : 6.w,
            height: 6.w,
            decoration: BoxDecoration(
              color: i == index
                  ? Colors.white
                  : const Color.fromRGBO(255, 255, 255, 0.35),
              borderRadius: BorderRadius.circular(3.r),
            ),
          ),
      ],
    );
  }
}

class _ExperienceCarousel extends StatefulWidget {
  const _ExperienceCarousel({
    required this.items,
    required this.index,
    required this.talkEnabled,
    required this.talkActive,
    required this.talkBusy,
    required this.accent,
    required this.onSelected,
    required this.onTalkStart,
    required this.onTalkStop,
    required this.onCreateGroup,
    required this.onJoinGroup,
  });

  final List<_CarouselItem> items;
  final int index;
  final bool talkEnabled;
  final bool talkActive;
  final bool talkBusy;
  final Color accent;
  final ValueChanged<int> onSelected;
  final Future<void> Function() onTalkStart;
  final Future<void> Function() onTalkStop;
  final VoidCallback onCreateGroup;
  final VoidCallback onJoinGroup;

  @override
  State<_ExperienceCarousel> createState() => _ExperienceCarouselState();
}

class _ExperienceCarouselState extends State<_ExperienceCarousel>
    with SingleTickerProviderStateMixin {
  late final AnimationController _settleController = AnimationController(
    vsync: this,
  );
  late double _position = widget.index.toDouble();
  Animation<double>? _settleAnimation;
  double _itemSpacing = 64;
  int? _selectionAfterSettle;

  @override
  void initState() {
    super.initState();
    _settleController.addListener(_onSettleTick);
    _settleController.addStatusListener(_onSettleStatus);
  }

  @override
  void didUpdateWidget(covariant _ExperienceCarousel oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (widget.items.isEmpty) {
      _settleController.stop();
      _position = 0;
      return;
    }

    final lastIndex = widget.items.length - 1;
    _position = _position.clamp(0, lastIndex).toDouble();
    if (widget.index != oldWidget.index &&
        widget.index != _position.round() &&
        !_settleController.isAnimating) {
      _animateTo(widget.index, notifySelection: false);
    }
  }

  @override
  void dispose() {
    _settleController
      ..removeListener(_onSettleTick)
      ..removeStatusListener(_onSettleStatus)
      ..dispose();
    super.dispose();
  }

  void _onSettleTick() {
    final animation = _settleAnimation;
    if (animation == null || !mounted) return;
    setState(() => _position = animation.value);
  }

  void _onSettleStatus(AnimationStatus status) {
    if (status != AnimationStatus.completed) return;
    final selection = _selectionAfterSettle;
    _selectionAfterSettle = null;
    if (selection == null || selection == widget.index) return;
    unawaited(HapticFeedback.selectionClick());
    widget.onSelected(selection);
  }

  void _animateTo(int target, {required bool notifySelection}) {
    if (widget.items.isEmpty) return;
    final resolvedTarget = target.clamp(0, widget.items.length - 1);
    final distance = (_position - resolvedTarget).abs();

    _settleController.stop();
    _selectionAfterSettle = notifySelection ? resolvedTarget : null;
    _settleController.duration = Duration(
      milliseconds: (220 + distance * 45).clamp(220, 420).round(),
    );
    _settleAnimation =
        Tween<double>(begin: _position, end: resolvedTarget.toDouble()).animate(
          CurvedAnimation(
            parent: _settleController,
            curve: Curves.easeOutCubic,
          ),
        );
    _settleController.forward(from: 0);
  }

  void _onHorizontalDragStart(DragStartDetails details) {
    _selectionAfterSettle = null;
    _settleController.stop();
  }

  void _onHorizontalDragUpdate(DragUpdateDetails details) {
    if (widget.items.length < 2) return;
    final next = _position - details.delta.dx / _itemSpacing;
    setState(() {
      _position = next.clamp(0, widget.items.length - 1).toDouble();
    });
  }

  void _onHorizontalDragEnd(DragEndDetails details) {
    if (widget.items.isEmpty) return;
    final projected = _position - details.velocity.pixelsPerSecond.dx / 1000;
    _animateTo(projected.round(), notifySelection: true);
  }

  void _onHorizontalDragCancel() {
    if (widget.items.isEmpty) return;
    _animateTo(_position.round(), notifySelection: true);
  }

  Widget _buildGroupCircle(int itemIndex, double spacing) {
    final item = widget.items[itemIndex];
    final delta = itemIndex - _position;
    final distance = delta.abs();
    final visualFocus = _position.round().clamp(0, widget.items.length - 1);
    final visuallySelected = itemIndex == visualFocus;
    final actuallySelected = itemIndex == widget.index;
    final scale = (1 / (1 + distance * 0.46)).clamp(0.4, 1.0);
    final opacity = (1 - distance * 0.18).clamp(0.28, 1.0);
    final rotationY = (delta * -0.26).clamp(-0.62, 0.62);

    Widget circle = _MainAvatarCircle(
      item: item,
      selected: visuallySelected,
      talkEnabled: widget.talkEnabled && actuallySelected && distance < 0.45,
      talkActive: widget.talkActive && actuallySelected,
      talkBusy: widget.talkBusy,
      accent: widget.accent,
      onTalkStart: widget.onTalkStart,
      onTalkStop: widget.onTalkStop,
    );

    if (!actuallySelected) {
      circle = Semantics(
        button: true,
        label: 'Select ${item.group.name} group',
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () => _animateTo(itemIndex, notifySelection: true),
          child: circle,
        ),
      );
    }

    return Positioned.fill(
      child: Center(
        child: Transform.translate(
          offset: Offset(delta * spacing, distance * 7.h),
          child: Opacity(
            opacity: opacity,
            child: Transform(
              alignment: Alignment.center,
              transform: Matrix4.identity()
                ..setEntry(3, 2, 0.0014)
                ..rotateY(rotationY),
              child: Transform.scale(scale: scale, child: circle),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (widget.items.isEmpty) {
      return Row(
        children: [
          SizedBox(width: 16.w),
          _DashedAddCircle(
            onTap: widget.onJoinGroup,
            compact: true,
            label: '+ join\ngroup',
          ),
          const Spacer(),
          _DashedAddCircle(
            onTap: widget.onCreateGroup,
            compact: true,
            label: '+ create\nnew group',
          ),
          SizedBox(width: 16.w),
        ],
      );
    }

    return Row(
      children: [
        SizedBox(width: 12.w),
        _DashedAddCircle(
          onTap: widget.onJoinGroup,
          compact: true,
          label: '+ join\ngroup',
        ),
        SizedBox(width: 8.w),
        Expanded(
          child: LayoutBuilder(
            builder: (context, constraints) {
              final spacing = (constraints.maxWidth * 0.34).clamp(52.w, 70.w);
              _itemSpacing = spacing;
              final paintOrder =
                  List<int>.generate(
                    widget.items.length,
                    (itemIndex) => itemIndex,
                  )..sort((a, b) {
                    final aDistance = (a - _position).abs();
                    final bDistance = (b - _position).abs();
                    return bDistance.compareTo(aDistance);
                  });

              return ClipRect(
                child: Stack(
                  children: [
                    Positioned.fill(
                      child: ShaderMask(
                        blendMode: BlendMode.dstIn,
                        shaderCallback: (bounds) => const LinearGradient(
                          colors: [
                            Colors.transparent,
                            Color(0x40FFFFFF),
                            Colors.white,
                            Colors.white,
                            Color(0x40FFFFFF),
                            Colors.transparent,
                          ],
                          stops: [0, 0.08, 0.22, 0.78, 0.92, 1],
                        ).createShader(bounds),
                        child: GestureDetector(
                          behavior: HitTestBehavior.opaque,
                          onHorizontalDragStart: _onHorizontalDragStart,
                          onHorizontalDragUpdate: _onHorizontalDragUpdate,
                          onHorizontalDragEnd: _onHorizontalDragEnd,
                          onHorizontalDragCancel: _onHorizontalDragCancel,
                          child: Stack(
                            clipBehavior: Clip.hardEdge,
                            children: [
                              for (final itemIndex in paintOrder)
                                _buildGroupCircle(itemIndex, spacing),
                            ],
                          ),
                        ),
                      ),
                    ),
                    Positioned(
                      left: 0,
                      top: 0,
                      bottom: 0,
                      width: 52.w,
                      child: const _CarouselEdgeVeil(leftEdge: true),
                    ),
                    Positioned(
                      right: 0,
                      top: 0,
                      bottom: 0,
                      width: 52.w,
                      child: const _CarouselEdgeVeil(leftEdge: false),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
        SizedBox(width: 8.w),
        _DashedAddCircle(
          onTap: widget.onCreateGroup,
          compact: true,
          label: '+ create\nnew group',
        ),
        SizedBox(width: 12.w),
      ],
    );
  }
}

class _CarouselEdgeVeil extends StatelessWidget {
  const _CarouselEdgeVeil({required this.leftEdge});

  final bool leftEdge;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: ShaderMask(
        blendMode: BlendMode.dstIn,
        shaderCallback: (bounds) => LinearGradient(
          begin: leftEdge ? Alignment.centerLeft : Alignment.centerRight,
          end: leftEdge ? Alignment.centerRight : Alignment.centerLeft,
          colors: const [Colors.white, Color(0x99FFFFFF), Colors.transparent],
          stops: const [0, 0.35, 1],
        ).createShader(bounds),
        child: ClipRect(
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
            child: const ColoredBox(color: Colors.transparent),
          ),
        ),
      ),
    );
  }
}

class _MainAvatarCircle extends StatelessWidget {
  const _MainAvatarCircle({
    required this.item,
    required this.selected,
    required this.talkEnabled,
    required this.talkActive,
    required this.talkBusy,
    required this.accent,
    required this.onTalkStart,
    required this.onTalkStop,
  });

  final _CarouselItem item;
  final bool selected;
  final bool talkEnabled;
  final bool talkActive;
  final bool talkBusy;
  final Color accent;
  final Future<void> Function() onTalkStart;
  final Future<void> Function() onTalkStop;

  @override
  Widget build(BuildContext context) {
    final size = 110.w;

    Widget circle = Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(
          color: talkActive ? accent : Colors.white,
          width: selected ? 2.5 : 2,
        ),
      ),
      child: ClipOval(
        child: Stack(
          fit: StackFit.expand,
          children: [
            _MemberPhotoCollage(
              members: item.members,
              fallbackPhotoUrl: item.profilePhotoUrl,
              fallbackPhotoBase64: item.profilePhotoBase64,
              tileSize: size,
            ),
            Align(
              alignment: Alignment.bottomCenter,
              child: Padding(
                padding: EdgeInsets.only(bottom: size * 0.08),
                child: Icon(
                  Icons.mic,
                  color: talkActive ? const Color(0xffffd54f) : Colors.white,
                  size: talkActive ? size * 0.22 : size * 0.18,
                ),
              ),
            ),
          ],
        ),
      ),
    );

    if (talkEnabled) {
      circle = Semantics(
        button: true,
        label: talkActive ? 'Stop talking' : 'Tap to Talk',
        child: GestureDetector(
          onTap: talkBusy
              ? null
              : () {
                  if (talkActive) {
                    unawaited(onTalkStop());
                  } else {
                    unawaited(onTalkStart());
                  }
                },
          child: circle,
        ),
      );
    }

    return AnimatedOpacity(
      duration: const Duration(milliseconds: 180),
      opacity: talkBusy ? 0.65 : 1,
      child: circle,
    );
  }
}

/// Tiles up to [_maxTiles] group members' photos inside the connect circle
/// so it's obvious at a glance which group/members you're about to connect
/// with. Falls back to a single self-avatar when member data isn't loaded
/// yet (e.g. for a group that isn't focused in the carousel).
class _MemberPhotoCollage extends StatelessWidget {
  const _MemberPhotoCollage({
    required this.members,
    required this.fallbackPhotoUrl,
    required this.fallbackPhotoBase64,
    required this.tileSize,
  });

  static const int _maxTiles = 4;

  final List<GroupMemberSummary> members;
  final String? fallbackPhotoUrl;
  final String? fallbackPhotoBase64;
  final double tileSize;

  @override
  Widget build(BuildContext context) {
    if (members.isEmpty) {
      return ProfileImage(
        profilePhotoUrl: fallbackPhotoUrl,
        profilePhotoBase64: fallbackPhotoBase64,
        backgroundColor: const Color(0xff2a2a2a),
        fadeInDuration: Duration.zero,
        fallback: Icon(
          Icons.person_outline,
          color: Colors.white70,
          size: tileSize * 0.4,
        ),
      );
    }

    final tiles = members.take(_maxTiles).toList(growable: false);
    final overflow = members.length - tiles.length;

    Widget tile(GroupMemberSummary member) {
      final initial = member.displayName.trim().isEmpty
          ? '?'
          : member.displayName.trim().substring(0, 1).toUpperCase();
      return ProfileImage(
        profilePhotoUrl: member.profilePhotoUrl,
        profilePhotoBase64: member.profilePhotoBase64,
        backgroundColor: const Color(0xff2a2a2a),
        fadeInDuration: Duration.zero,
        fallback: Text(
          initial,
          style: TextStyle(
            color: Colors.white,
            fontSize: tileSize * 0.16,
            fontWeight: FontWeight.w700,
          ),
        ),
      );
    }

    Widget grid;
    switch (tiles.length) {
      case 1:
        grid = tile(tiles[0]);
      case 2:
        grid = Row(
          children: [
            Expanded(child: tile(tiles[0])),
            _CollageDivider(vertical: true, length: tileSize),
            Expanded(child: tile(tiles[1])),
          ],
        );
      case 3:
        grid = Column(
          children: [
            Expanded(child: tile(tiles[0])),
            _CollageDivider(vertical: false, length: tileSize),
            Expanded(
              child: Row(
                children: [
                  Expanded(child: tile(tiles[1])),
                  _CollageDivider(vertical: true, length: tileSize / 2),
                  Expanded(child: tile(tiles[2])),
                ],
              ),
            ),
          ],
        );
      default:
        grid = Column(
          children: [
            Expanded(
              child: Row(
                children: [
                  Expanded(child: tile(tiles[0])),
                  _CollageDivider(vertical: true, length: tileSize / 2),
                  Expanded(child: tile(tiles[1])),
                ],
              ),
            ),
            _CollageDivider(vertical: false, length: tileSize),
            Expanded(
              child: Row(
                children: [
                  Expanded(child: tile(tiles[2])),
                  _CollageDivider(vertical: true, length: tileSize / 2),
                  Expanded(child: tile(tiles[3])),
                ],
              ),
            ),
          ],
        );
    }

    return Stack(
      fit: StackFit.expand,
      children: [
        grid,
        if (overflow > 0)
          Positioned(
            right: tileSize * 0.06,
            bottom: tileSize * 0.06,
            child: Container(
              padding: EdgeInsets.symmetric(
                horizontal: tileSize * 0.05,
                vertical: tileSize * 0.02,
              ),
              decoration: BoxDecoration(
                color: const Color.fromRGBO(0, 0, 0, 0.7),
                borderRadius: BorderRadius.circular(tileSize * 0.08),
              ),
              child: Text(
                '+$overflow',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: tileSize * 0.09,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _CollageDivider extends StatelessWidget {
  const _CollageDivider({required this.vertical, required this.length});

  final bool vertical;
  final double length;

  @override
  Widget build(BuildContext context) {
    const color = Color.fromRGBO(0, 0, 0, 0.55);
    return vertical
        ? SizedBox(
            width: length * 0.014,
            height: length,
            child: const ColoredBox(color: color),
          )
        : SizedBox(
            width: length,
            height: length * 0.014,
            child: const ColoredBox(color: color),
          );
  }
}

class _DashedAddCircle extends StatelessWidget {
  const _DashedAddCircle({
    required this.onTap,
    required this.compact,
    required this.label,
  });

  final VoidCallback? onTap;
  final bool compact;
  final String label;

  @override
  Widget build(BuildContext context) {
    final size = compact ? 72.w : 110.w;
    return GestureDetector(
      onTap: onTap,
      child: Opacity(
        opacity: onTap == null ? 0.45 : 1,
        child: CustomPaint(
          painter: _DashedCirclePainter(
            color: const Color.fromRGBO(255, 255, 255, 0.7),
          ),
          child: SizedBox(
            width: size,
            height: size,
            child: Center(
              child: Padding(
                padding: EdgeInsets.all(10.w),
                child: Text(
                  label,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: compact ? 9.sp : 12.sp,
                    fontWeight: FontWeight.w600,
                    height: 1.15,
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

class _DashedCirclePainter extends CustomPainter {
  const _DashedCirclePainter({required this.color});

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.8;

    final radius = size.shortestSide / 2;
    const dashCount = 28;
    const dashSweep = 0.12;
    const gapSweep = (6.28318530718 / dashCount) - dashSweep;
    var start = 0.0;

    for (var i = 0; i < dashCount; i++) {
      canvas.drawArc(
        Rect.fromCircle(center: size.center(Offset.zero), radius: radius),
        start,
        dashSweep,
        false,
        paint,
      );
      start += dashSweep + gapSweep;
    }
  }

  @override
  bool shouldRepaint(covariant _DashedCirclePainter oldDelegate) {
    return oldDelegate.color != color;
  }
}

class _CarouselItem {
  const _CarouselItem({
    required this.group,
    required this.displayName,
    required this.availability,
    this.profilePhotoUrl,
    this.profilePhotoBase64,
    this.members = const [],
  });

  factory _CarouselItem.group({
    required GroupSummary group,
    required String displayName,
    required String? profilePhotoUrl,
    required String? profilePhotoBase64,
    required MemberAvailability availability,
    List<GroupMemberSummary> members = const [],
  }) {
    return _CarouselItem(
      group: group,
      displayName: displayName,
      profilePhotoUrl: profilePhotoUrl,
      profilePhotoBase64: profilePhotoBase64,
      availability: availability,
      members: members,
    );
  }

  final GroupSummary group;
  final String displayName;
  final MemberAvailability availability;
  final String? profilePhotoUrl;
  final String? profilePhotoBase64;

  /// Group members loaded for this group (only populated for the
  /// currently-selected/focused group). Used to render a photo collage on
  /// the connect circle so it's obvious at a glance who you're joining.
  final List<GroupMemberSummary> members;
}

class _SetupLine extends StatelessWidget {
  const _SetupLine({required this.ok, required this.text});

  final bool ok;
  final String text;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            ok ? Icons.check_circle : Icons.error_outline,
            color: ok ? colors.primary : colors.error,
          ),
          const SizedBox(width: 10),
          Expanded(child: Text(text)),
        ],
      ),
    );
  }
}
