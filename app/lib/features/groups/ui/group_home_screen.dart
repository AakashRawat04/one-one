import 'package:flutter/material.dart';

import '../../identity/models/identity_session.dart';
import '../../online/ui/online_screen.dart';
import '../data/group_repository.dart';
import '../models/group_invite_result.dart';
import '../models/group_member_summary.dart';
import '../models/group_summary.dart';

class GroupHomeScreen extends StatefulWidget {
  const GroupHomeScreen({
    super.key,
    required this.session,
    this.groupRepository,
  });

  final IdentitySession session;
  final GroupRepository? groupRepository;

  @override
  State<GroupHomeScreen> createState() => _GroupHomeScreenState();
}

class _GroupHomeScreenState extends State<GroupHomeScreen> {
  late final GroupRepository _groupRepository =
      widget.groupRepository ?? GroupRepository();
  late Future<List<GroupSummary>> _groupsFuture = _loadGroups();

  final TextEditingController _groupNameController = TextEditingController(
    text: 'Friends',
  );
  final TextEditingController _inviteCodeController = TextEditingController();

  GroupSummary? _selectedGroup;
  GroupInviteResult? _latestInvite;
  List<GroupMemberSummary> _members = const [];
  bool _busy = false;
  String? _message;

  @override
  void dispose() {
    _groupNameController.dispose();
    _inviteCodeController.dispose();
    super.dispose();
  }

  Future<List<GroupSummary>> _loadGroups() async {
    final groups = await _groupRepository.loadGroupsForUser(
      widget.session.userId,
    );

    if (groups.isNotEmpty) {
      _selectedGroup ??= groups.first;
      await _loadMembers(_selectedGroup!.groupId);
    }

    return groups;
  }

  Future<void> _reloadGroups() async {
    setState(() {
      _groupsFuture = _loadGroups();
    });
  }

  Future<void> _loadMembers(String groupId) async {
    final members = await _groupRepository.loadGroupMembers(groupId);
    if (!mounted) return;
    setState(() {
      _members = members;
    });
  }

  Future<void> _createGroup() async {
    await _runBusy(() async {
      final group = await _groupRepository.createGroup(
        _groupNameController.text.trim(),
      );
      setState(() {
        _selectedGroup = group;
        _latestInvite = null;
        _message = 'Group created';
      });
      await _reloadGroups();
      await _loadMembers(group.groupId);
    });
  }

  Future<void> _createInvite() async {
    final group = _selectedGroup;
    if (group == null) {
      setState(() => _message = 'Create or join a group first.');
      return;
    }

    await _runBusy(() async {
      final invite = await _groupRepository.createInvite(group.groupId);
      setState(() {
        _latestInvite = invite;
        _message = 'Invite created';
      });
    });
  }

  Future<void> _joinInvite() async {
    await _runBusy(() async {
      final groupId = await _groupRepository.joinInvite(
        _inviteCodeController.text.trim(),
      );
      setState(() {
        _latestInvite = null;
        _message = 'Joined group';
      });
      await _reloadGroups();
      await _loadMembers(groupId);
    });
  }

  void _openOnlineMode() {
    final group = _selectedGroup;
    if (group == null) {
      setState(() => _message = 'Select a group first.');
      return;
    }

    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => OnlineScreen(identity: widget.session, group: group),
      ),
    );
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
      setState(() => _message = error.toString());
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Group'),
        backgroundColor: colors.inversePrimary,
      ),
      body: SafeArea(
        child: FutureBuilder<List<GroupSummary>>(
          future: _groupsFuture,
          builder: (context, snapshot) {
            final groups = snapshot.data ?? const <GroupSummary>[];

            return ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Text('Create', style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 12),
                TextField(
                  controller: _groupNameController,
                  decoration: const InputDecoration(
                    labelText: 'Group name',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                FilledButton.icon(
                  onPressed: _busy ? null : _createGroup,
                  icon: const Icon(Icons.group_add_outlined),
                  label: const Text('Create group'),
                ),
                const SizedBox(height: 24),
                Text('Join', style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 12),
                TextField(
                  controller: _inviteCodeController,
                  textCapitalization: TextCapitalization.characters,
                  decoration: const InputDecoration(
                    labelText: 'Invite code',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  onPressed: _busy ? null : _joinInvite,
                  icon: const Icon(Icons.login),
                  label: const Text('Join group'),
                ),
                const SizedBox(height: 24),
                Text(
                  'Your groups',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 8),
                if (snapshot.connectionState != ConnectionState.done)
                  const LinearProgressIndicator()
                else if (groups.isEmpty)
                  const Text('No groups yet.')
                else
                  DropdownButtonFormField<String>(
                    initialValue: _selectedGroup?.groupId,
                    items: [
                      for (final group in groups)
                        DropdownMenuItem(
                          value: group.groupId,
                          child: Text(group.name),
                        ),
                    ],
                    onChanged: _busy
                        ? null
                        : (groupId) async {
                            final group = groups.firstWhere(
                              (item) => item.groupId == groupId,
                            );
                            setState(() {
                              _selectedGroup = group;
                              _latestInvite = null;
                            });
                            await _loadMembers(group.groupId);
                          },
                    decoration: const InputDecoration(
                      border: OutlineInputBorder(),
                    ),
                  ),
                const SizedBox(height: 12),
                FilledButton.icon(
                  onPressed: _busy || _selectedGroup == null
                      ? null
                      : _createInvite,
                  icon: const Icon(Icons.ios_share),
                  label: const Text('Create invite'),
                ),
                const SizedBox(height: 12),
                FilledButton.icon(
                  onPressed: _busy || _selectedGroup == null
                      ? null
                      : _openOnlineMode,
                  icon: const Icon(Icons.wifi_tethering),
                  label: const Text('Online mode'),
                ),
                if (_latestInvite != null) ...[
                  const SizedBox(height: 12),
                  SelectableText(
                    'Invite link: ${_latestInvite!.inviteUrl}\nFallback PIN: ${_latestInvite!.inviteCode}',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ],
                if (_message != null) ...[
                  const SizedBox(height: 12),
                  Text(_message!),
                ],
                const SizedBox(height: 24),
                Text('Members', style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 8),
                if (_members.isEmpty)
                  const Text('No members loaded.')
                else
                  for (final member in _members)
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text(member.displayName),
                      subtitle: Text('${member.role} | ${member.memberState}'),
                    ),
              ],
            );
          },
        ),
      ),
    );
  }
}
