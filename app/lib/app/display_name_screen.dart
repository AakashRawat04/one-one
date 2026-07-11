import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../features/identity/data/identity_repository.dart';
import '../features/identity/models/identity_session.dart';

class DisplayNameScreen extends StatefulWidget {
  const DisplayNameScreen({
    super.key,
    required this.session,
    required this.identityRepository,
    required this.onComplete,
  });

  final IdentitySession session;
  final IdentityRepository identityRepository;
  final Future<void> Function() onComplete;

  @override
  State<DisplayNameScreen> createState() => _DisplayNameScreenState();
}

class _DisplayNameScreenState extends State<DisplayNameScreen> {
  final TextEditingController _nameController = TextEditingController();
  final FocusNode _focusNode = FocusNode();
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _focusNode.requestFocus();
      }
    });
  }

  @override
  void dispose() {
    _nameController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  bool get _canSubmit => _nameController.text.trim().isNotEmpty && !_saving;

  Future<void> _saveName() async {
    final name = _nameController.text.trim();
    if (name.isEmpty || _saving) return;

    setState(() => _saving = true);

    try {
      await widget.identityRepository.updateDisplayName(name);
      if (!mounted) return;
      await widget.onComplete();
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error.toString())),
      );
      setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xff000000),
      resizeToAvoidBottomInset: true,
      body: SafeArea(
        child: Stack(
          children: [
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 24.w),
              child: Column(
                children: [
                  SizedBox(height: 132.h),
                  TextField(
                    controller: _nameController,
                    focusNode: _focusNode,
                    onChanged: (_) => setState(() {}),
                    onSubmitted: (_) {
                      if (_canSubmit) {
                        _saveName();
                      }
                    },
                    textInputAction: TextInputAction.done,
                    textCapitalization: TextCapitalization.words,
                    autocorrect: false,
                    maxLines: 1,
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 34.sp,
                      fontWeight: FontWeight.w700,
                      height: 1.15,
                    ),
                    textAlign: TextAlign.center,
                    cursorColor: Colors.white,
                    decoration: InputDecoration(
                      hintText: 'your name',
                      hintStyle: TextStyle(
                        color: Colors.white,
                        fontSize: 34.sp,
                        fontWeight: FontWeight.w700,
                        height: 1.15,
                      ),
                      border: InputBorder.none,
                      enabledBorder: InputBorder.none,
                      focusedBorder: InputBorder.none,
                      contentPadding: EdgeInsets.zero,
                      isDense: true,
                    ),
                  ),
                  SizedBox(height: 14.h),
                  Text(
                    'this is how your friends will see you',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 14.sp,
                      fontWeight: FontWeight.w400,
                      height: 1.35,
                    ),
                  ),
                ],
              ),
            ),
            Positioned(
              right: 24.w,
              bottom: 12.h,
              child: GestureDetector(
                onTap: _canSubmit ? _saveName : null,
                child: Container(
                  width: 52.w,
                  height: 52.w,
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    color: Color(0xff242424),
                  ),
                  child: _saving
                      ? Center(
                          child: SizedBox(
                            width: 20.w,
                            height: 20.w,
                            child: const CircularProgressIndicator(
                              strokeWidth: 2.4,
                              color: Colors.white,
                            ),
                          ),
                        )
                      : Icon(
                          Icons.arrow_forward_rounded,
                          color: _canSubmit
                              ? Colors.white
                              : const Color.fromRGBO(255, 255, 255, 0.35),
                          size: 24.sp,
                        ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
