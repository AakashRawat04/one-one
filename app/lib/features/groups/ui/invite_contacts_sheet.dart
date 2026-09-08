import 'package:flutter_contacts/flutter_contacts.dart';
import 'package:one_one_app/one_one.dart';

/// Bottom sheet that lets a user name a new group and pick contacts to invite.
///
/// Flow:
///  1. Opens with a group-name text field and a contact list.
///  2. On first open, requests contacts permission and loads the device contacts.
///  3. User types a group name, optionally ticks contacts (for reference).
///  4. Taps "Create Group & Send Invite":
///     a. Creates the group via [GroupRepository].
///     b. Creates an invite link for that group.
///     c. Opens the system share sheet so the user can send the link via
///        WhatsApp, iMessage, or any other app.
///  5. After sharing, the sheet closes and [onGroupCreated] is called so the
///     caller can navigate to [IdentityHomeScreen].
class InviteContactsSheet extends StatefulWidget {
  const InviteContactsSheet({
    super.key,
    required this.session,
    required this.identityRepository,
    required this.onGroupCreated,
  });

  final IdentitySession session;
  final IdentityRepository identityRepository;
  /// Called after the group is created and the share sheet is dismissed.
  final VoidCallback onGroupCreated;

  @override
  State<InviteContactsSheet> createState() => _InviteContactsSheetState();
}

class _InviteContactsSheetState extends State<InviteContactsSheet> {
  final GroupRepository _groupRepository = GroupRepository();
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _searchController = TextEditingController();

  List<Contact> _contacts = [];
  List<Contact> _filtered = [];
  final Set<String> _selected = {};

  bool _loadingContacts = true;
  bool _permissionDenied = false;
  bool _busy = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_onSearch);
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadContacts());
  }

  @override
  void dispose() {
    _nameController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadContacts() async {
    // Check / request contacts permission.
    final granted = await FlutterContacts.requestPermission(readonly: true);
    if (!mounted) return;
    if (!granted) {
      setState(() {
        _permissionDenied = true;
        _loadingContacts = false;
      });
      return;
    }

    final contacts = await FlutterContacts.getContacts(withProperties: true);
    if (!mounted) return;

    // Sort alphabetically; skip contacts with no displayName.
    contacts.sort(
      (a, b) => a.displayName.toLowerCase().compareTo(b.displayName.toLowerCase()),
    );
    setState(() {
      _contacts = contacts;
      _filtered = contacts;
      _loadingContacts = false;
    });
  }

  void _onSearch() {
    final q = _searchController.text.trim().toLowerCase();
    setState(() {
      _filtered = q.isEmpty
          ? _contacts
          : _contacts
              .where(
                (c) =>
                    c.displayName.toLowerCase().contains(q) ||
                    c.phones.any((p) => p.number.contains(q)),
              )
              .toList();
    });
  }

  void _toggle(String contactId) {
    setState(() {
      if (_selected.contains(contactId)) {
        _selected.remove(contactId);
      } else {
        _selected.add(contactId);
      }
    });
  }

  Future<void> _createAndInvite() async {
    final groupName = _nameController.text.trim();
    if (groupName.isEmpty) {
      setState(() => _error = context.l10n.inviteSheetGroupNameRequired);
      return;
    }

    setState(() {
      _busy = true;
      _error = null;
    });

    try {
      // 1. Create the group.
      final group = await _groupRepository.createGroup(groupName);

      // 2. Create an invite link.
      final invite = await _groupRepository.createInvite(group.groupId);

      if (!mounted) return;

      // 3. Share via system share sheet (works for WhatsApp, iMessage, etc.).
      try {
        await InviteLinkBridge().shareInviteLink(invite.inviteUrl);
      } catch (_) {
        // Fall back to clipboard + snackbar if native share is unavailable.
        await Clipboard.setData(ClipboardData(text: invite.inviteUrl));
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(context.l10n.homeInviteLinkCopied)),
        );
      }

      if (!mounted) return;
      Navigator.of(context).pop();
      widget.onGroupCreated();
    } catch (error) {
      if (!mounted) return;
      setState(() => _error = error.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;

    return Padding(
      // Lift the sheet above the keyboard.
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: DraggableScrollableSheet(
        initialChildSize: 0.88,
        minChildSize: 0.5,
        maxChildSize: 0.96,
        expand: false,
        builder: (context, scrollController) {
          return Container(
            decoration: BoxDecoration(
              color: const Color(0xff141414),
              borderRadius: BorderRadius.vertical(top: Radius.circular(24.r)),
            ),
            child: Column(
              children: [
                // Drag handle
                SizedBox(height: 10.h),
                Container(
                  width: 40.w,
                  height: 4.h,
                  decoration: BoxDecoration(
                    color: Colors.white24,
                    borderRadius: BorderRadius.circular(2.r),
                  ),
                ),
                SizedBox(height: 16.h),

                // Title
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: 24.w),
                  child: Text(
                    l10n.inviteSheetTitle,
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 20.sp,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                SizedBox(height: 20.h),

                // Group name field
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: 24.w),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        l10n.inviteSheetGroupNameLabel,
                        style: TextStyle(
                          color: Colors.white70,
                          fontSize: 12.sp,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 0.6,
                        ),
                      ),
                      SizedBox(height: 8.h),
                      Container(
                        decoration: BoxDecoration(
                          color: const Color(0xff1f1f1f),
                          borderRadius: BorderRadius.circular(14.r),
                          border: Border.all(
                            color: _error != null && _nameController.text.trim().isEmpty
                                ? Colors.redAccent
                                : Colors.white12,
                          ),
                        ),
                        child: TextField(
                          controller: _nameController,
                          style: TextStyle(color: Colors.white, fontSize: 16.sp),
                          onChanged: (_) {
                            if (_error != null) setState(() => _error = null);
                          },
                          decoration: InputDecoration(
                            hintText: l10n.inviteSheetGroupNameHint,
                            hintStyle: TextStyle(
                              color: Colors.white38,
                              fontSize: 15.sp,
                            ),
                            border: InputBorder.none,
                            contentPadding: EdgeInsets.symmetric(
                              horizontal: 16.w,
                              vertical: 14.h,
                            ),
                          ),
                        ),
                      ),
                      if (_error != null) ...[
                        SizedBox(height: 6.h),
                        Text(
                          _error!,
                          style: TextStyle(
                            color: Colors.redAccent,
                            fontSize: 12.sp,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                SizedBox(height: 20.h),

                // Contacts section
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: 24.w),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      l10n.inviteSheetContactsHeader,
                      style: TextStyle(
                        color: Colors.white70,
                        fontSize: 12.sp,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 0.6,
                      ),
                    ),
                  ),
                ),
                SizedBox(height: 10.h),

                Expanded(child: _buildContactsBody(l10n, scrollController)),

                // Bottom send button
                _buildSendButton(l10n),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildContactsBody(AppLocalizations l10n, ScrollController scrollController) {
    if (_loadingContacts) {
      return const Center(
        child: CircularProgressIndicator(color: Color(0xffF8BE03)),
      );
    }

    if (_permissionDenied) {
      return Center(
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: 32.w),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.contacts_outlined, color: Colors.white38, size: 48.sp),
              SizedBox(height: 16.h),
              Text(
                l10n.inviteSheetPermissionDenied,
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.white54, fontSize: 14.sp),
              ),
              SizedBox(height: 20.h),
              OutlinedButton.icon(
                onPressed: () async {
                  await openAppSettings();
                  if (!mounted) return;
                  setState(() {
                    _permissionDenied = false;
                    _loadingContacts = true;
                  });
                  await _loadContacts();
                },
                icon: const Icon(Icons.settings_outlined),
                label: Text(l10n.inviteSheetPermissionButton),
                style: OutlinedButton.styleFrom(foregroundColor: Colors.white),
              ),
            ],
          ),
        ),
      );
    }

    return Column(
      children: [
        // Search field
        Padding(
          padding: EdgeInsets.symmetric(horizontal: 24.w),
          child: Container(
            decoration: BoxDecoration(
              color: const Color(0xff1f1f1f),
              borderRadius: BorderRadius.circular(12.r),
            ),
            child: TextField(
              controller: _searchController,
              style: TextStyle(color: Colors.white, fontSize: 14.sp),
              decoration: InputDecoration(
                hintText: l10n.inviteSheetSearchHint,
                hintStyle: TextStyle(color: Colors.white38, fontSize: 14.sp),
                prefixIcon: Icon(Icons.search, color: Colors.white38, size: 20.sp),
                border: InputBorder.none,
                contentPadding: EdgeInsets.symmetric(vertical: 12.h),
              ),
            ),
          ),
        ),
        SizedBox(height: 8.h),

        if (_filtered.isEmpty)
          Expanded(
            child: Center(
              child: Text(
                l10n.inviteSheetNoContacts,
                style: TextStyle(color: Colors.white38, fontSize: 14.sp),
              ),
            ),
          )
        else
          Expanded(
            child: ListView.builder(
              controller: scrollController,
              padding: EdgeInsets.symmetric(horizontal: 16.w),
              itemCount: _filtered.length,
              itemBuilder: (context, index) {
                final contact = _filtered[index];
                final isSelected = _selected.contains(contact.id);
                final subtitle = contact.phones.isNotEmpty
                    ? contact.phones.first.number
                    : (contact.emails.isNotEmpty ? contact.emails.first.address : null);

                return ListTile(
                  onTap: () => _toggle(contact.id),
                  contentPadding: EdgeInsets.symmetric(horizontal: 8.w),
                  leading: _ContactAvatar(contact: contact),
                  title: Text(
                    contact.displayName,
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 15.sp,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  subtitle: subtitle != null
                      ? Text(
                          subtitle,
                          style: TextStyle(
                            color: Colors.white38,
                            fontSize: 12.sp,
                          ),
                        )
                      : null,
                  trailing: AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    width: 24.r,
                    height: 24.r,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: isSelected
                          ? const Color(0xffF8BE03)
                          : Colors.transparent,
                      border: Border.all(
                        color: isSelected
                            ? const Color(0xffF8BE03)
                            : Colors.white30,
                        width: 2,
                      ),
                    ),
                    child: isSelected
                        ? Icon(
                            Icons.check,
                            size: 14.sp,
                            color: Colors.black,
                          )
                        : null,
                  ),
                );
              },
            ),
          ),
      ],
    );
  }

  Widget _buildSendButton(AppLocalizations l10n) {
    return BottomSystemSafeArea(
      child: Padding(
        padding: EdgeInsets.fromLTRB(24.w, 12.h, 24.w, 16.h),
        child: SizedBox(
          width: double.infinity,
          child: FilledButton.icon(
            onPressed: _busy ? null : _createAndInvite,
            icon: _busy
                ? SizedBox(
                    width: 18.r,
                    height: 18.r,
                    child: const CircularProgressIndicator(
                      color: Colors.black,
                      strokeWidth: 2,
                    ),
                  )
                : const Icon(Icons.send_rounded),
            label: Text(
              _busy ? l10n.inviteSheetCreating : l10n.inviteSheetSendButton,
            ),
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xffF8BE03),
              foregroundColor: Colors.black,
              padding: EdgeInsets.symmetric(vertical: 16.h),
              textStyle: TextStyle(
                fontSize: 15.sp,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Circular avatar showing initials or a thumbnail if available.
class _ContactAvatar extends StatelessWidget {
  const _ContactAvatar({required this.contact});
  final Contact contact;

  @override
  Widget build(BuildContext context) {
    final initials = _initials(contact.displayName);
    final thumbnail = contact.thumbnail;

    if (thumbnail != null && thumbnail.isNotEmpty) {
      return CircleAvatar(
        radius: 20.r,
        backgroundImage: MemoryImage(thumbnail),
      );
    }
    return CircleAvatar(
      radius: 20.r,
      backgroundColor: const Color(0xff2a2a2a),
      child: Text(
        initials,
        style: TextStyle(
          color: const Color(0xffF8BE03),
          fontSize: 13.sp,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }

  static String _initials(String name) {
    final parts = name.trim().split(RegExp(r'\s+'));
    if (parts.isEmpty || parts.first.isEmpty) return '?';
    if (parts.length == 1) return parts.first[0].toUpperCase();
    return '${parts.first[0]}${parts.last[0]}'.toUpperCase();
  }
}
