import 'dart:convert';
import 'dart:typed_data';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../features/identity/data/identity_repository.dart';
import '../features/identity/models/identity_session.dart';
import '../features/identity/ui/profile_photo_editor.dart';

class ProfilePictureScreen extends StatefulWidget {
  const ProfilePictureScreen({
    super.key,
    required this.session,
    required this.identityRepository,
    required this.onComplete,
  });

  final IdentitySession session;
  final IdentityRepository identityRepository;
  final Future<void> Function(IdentitySession session) onComplete;

  @override
  State<ProfilePictureScreen> createState() => _ProfilePictureScreenState();
}

class _ProfilePictureScreenState extends State<ProfilePictureScreen> {
  static const Duration _transitionDuration = Duration(milliseconds: 260);

  Uint8List? _selectedImageBytes;
  String? _existingPhotoUrl;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final user = widget.session.user;
    _existingPhotoUrl = user.profilePhotoUrl;

    final existingBase64 = user.profilePhotoBase64;
    if (existingBase64 != null && existingBase64.isNotEmpty) {
      try {
        _selectedImageBytes = base64Decode(existingBase64);
      } catch (_) {
        _selectedImageBytes = null;
      }
    }
  }

  bool get _hasSelectedPhoto =>
      _selectedImageBytes != null ||
      (_existingPhotoUrl != null && _existingPhotoUrl!.isNotEmpty);

  Future<void> _pickImage() async {
    if (_saving) return;
    final bytes = await ProfilePhotoEditor.pickAndCrop(context);
    if (bytes == null) return;
    if (!mounted) return;

    setState(() {
      _selectedImageBytes = bytes;
      _existingPhotoUrl = null;
    });
  }

  Future<void> _editExistingPhoto() async {
    if (_saving) return;
    final photoUrl = _existingPhotoUrl;
    if (photoUrl == null || photoUrl.isEmpty) {
      await _pickImage();
      return;
    }
    try {
      final bytes = await ProfilePhotoEditor.recropNetworkPhoto(
        context,
        photoUrl,
      );
      if (bytes == null || !mounted) return;
      setState(() {
        _selectedImageBytes = bytes;
        _existingPhotoUrl = null;
      });
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.toString())));
    }
  }

  Future<void> _savePhoto() async {
    final bytes = _selectedImageBytes;
    if (bytes == null || _saving) return;

    setState(() => _saving = true);

    try {
      final updatedSession = await widget.identityRepository.updateProfilePhoto(
        bytes,
      );
      if (!mounted) return;
      setState(() {
        _existingPhotoUrl = updatedSession.user.profilePhotoUrl;
        _selectedImageBytes = null;
      });
      await widget.onComplete(updatedSession);
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.toString())));
      setState(() => _saving = false);
    }
  }

  Future<void> _skipPhoto() async {
    if (_saving) return;
    setState(() => _saving = true);

    try {
      await widget.onComplete(widget.session);
    } catch (error) {
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.toString())));
    }
  }

  void _cancelSelection() {
    if (_saving) return;
    setState(() {
      _selectedImageBytes = null;
      _existingPhotoUrl = widget.session.user.profilePhotoUrl;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _hasSelectedPhoto
          ? Colors.black
          : const Color(0xff000000),
      body: SafeArea(
        child: _hasSelectedPhoto ? _buildPreviewStage() : _buildPickerStage(),
      ),
    );
  }

  Widget _buildPickerStage() {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 24.w),
      child: Column(
        children: [
          SizedBox(height: 48.h),
          Expanded(
            child: Center(
              child: Container(
                width: 300.w,
                height: 630.h,
                padding: EdgeInsets.symmetric(horizontal: 18.w, vertical: 24.h),
                decoration: BoxDecoration(
                  color: const Color(0xff0f1824),
                  borderRadius: BorderRadius.circular(42),
                  border: Border.all(
                    color: const Color.fromRGBO(121, 145, 178, 0.35),
                    width: 1.2,
                  ),
                ),
                child: Column(
                  children: [
                    SizedBox(height: 12.h),
                    Image.asset(
                      'assets/logo.png',
                      width: 62.w,
                      height: 62.w,
                      fit: BoxFit.contain,
                    ),
                    const Spacer(),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        GestureDetector(
                          onTap: _pickImage,
                          child: Container(
                            width: 52.w,
                            height: 52.w,
                            decoration: const BoxDecoration(
                              shape: BoxShape.circle,
                              color: Color(0xff123a5e),
                            ),
                            child: const Icon(Icons.add, color: Colors.white),
                          ),
                        ),
                        SizedBox(width: 14.w),
                        Container(
                          width: 92.w,
                          height: 92.w,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: Colors.white,
                              width: 8.w / 2,
                            ),
                          ),
                          child: Stack(
                            clipBehavior: Clip.none,
                            children: [
                              Positioned(
                                right: 4.w,
                                top: 8.h,
                                child: Container(
                                  width: 10.w,
                                  height: 10.w,
                                  decoration: const BoxDecoration(
                                    color: Color(0xff3df46b),
                                    shape: BoxShape.circle,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        SizedBox(width: 14.w),
                        Container(
                          width: 58.w,
                          height: 58.w,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: const Color.fromRGBO(255, 255, 255, 0.35),
                              width: 2,
                              strokeAlign: BorderSide.strokeAlignCenter,
                            ),
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 42.h),
                  ],
                ),
              ),
            ),
          ),
          SizedBox(height: 34.h),
          SizedBox(
            width: 250.w,
            height: 52.h,
            child: ElevatedButton(
              onPressed: _pickImage,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: const Color(0xff384047),
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(26.r),
                ),
              ),
              child: Text(
                'add profile pic',
                style: TextStyle(
                  fontSize: 16.sp,
                  fontWeight: FontWeight.w600,
                  color: const Color(0xff384047),
                ),
              ),
            ),
          ),
          SizedBox(height: 10.h),
          TextButton(
            onPressed: _saving ? null : _skipPhoto,
            child: Text(
              'skip for now',
              style: TextStyle(
                color: Colors.white70,
                fontSize: 15.sp,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          SizedBox(height: 18.h),
        ],
      ),
    );
  }

  Widget _buildPreviewStage() {
    final imageBytes = _selectedImageBytes;
    final photoUrl = _existingPhotoUrl;

    return Stack(
      fit: StackFit.expand,
      children: [
        if (imageBytes != null)
          Image.memory(imageBytes, fit: BoxFit.cover)
        else if (photoUrl != null && photoUrl.isNotEmpty)
          CachedNetworkImage(imageUrl: photoUrl, fit: BoxFit.cover),
        Container(color: const Color(0x33000000)),
        Positioned(
          bottom: 24.h,
          left: 0,
          right: 0,
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: 24.w),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (imageBytes != null)
                  SizedBox(
                    width: 250.w,
                    height: 52.h,
                    child: ElevatedButton(
                      onPressed: _saving ? null : _savePhoto,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.white,
                        foregroundColor: const Color(0xff384047),
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(26.r),
                        ),
                      ),
                      child: AnimatedSwitcher(
                        duration: _transitionDuration,
                        child: _saving
                            ? SizedBox(
                                key: const ValueKey('saving'),
                                width: 20.w,
                                height: 20.w,
                                child: const CircularProgressIndicator(
                                  strokeWidth: 2.4,
                                  color: Color(0xff384047),
                                ),
                              )
                            : Text(
                                'add as profile picture',
                                key: const ValueKey('save-label'),
                                style: TextStyle(
                                  fontSize: 15.sp,
                                  fontWeight: FontWeight.w600,
                                  color: const Color(0xff384047),
                                ),
                              ),
                      ),
                    ),
                  )
                else
                  SizedBox(
                    width: 250.w,
                    height: 52.h,
                    child: ElevatedButton(
                      onPressed: _saving
                          ? null
                          : () => widget.onComplete(widget.session),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.white,
                        foregroundColor: const Color(0xff384047),
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(26.r),
                        ),
                      ),
                      child: Text(
                        'continue',
                        style: TextStyle(
                          fontSize: 15.sp,
                          fontWeight: FontWeight.w600,
                          color: const Color(0xff384047),
                        ),
                      ),
                    ),
                  ),
                SizedBox(height: 18.h),
                if (imageBytes != null)
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      TextButton(
                        onPressed: _saving ? null : _cancelSelection,
                        child: Text(
                          'cancel',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 16.sp,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      SizedBox(width: 12.w),
                      TextButton(
                        onPressed: _saving ? null : _skipPhoto,
                        child: Text(
                          'skip for now',
                          style: TextStyle(
                            color: Colors.white70,
                            fontSize: 16.sp,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  )
                else
                  TextButton(
                    onPressed: _saving ? null : _editExistingPhoto,
                    child: Text(
                      'change photo',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 16.sp,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
