import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:image_picker/image_picker.dart';

import '../features/identity/data/identity_repository.dart';
import '../features/identity/models/identity_session.dart';

class ProfilePictureScreen extends StatefulWidget {
  const ProfilePictureScreen({
    super.key,
    required this.session,
    required this.identityRepository,
    required this.onComplete,
  });

  final IdentitySession session;
  final IdentityRepository identityRepository;
  final Future<void> Function() onComplete;

  @override
  State<ProfilePictureScreen> createState() => _ProfilePictureScreenState();
}

class _ProfilePictureScreenState extends State<ProfilePictureScreen> {
  static const Duration _transitionDuration = Duration(milliseconds: 260);

  final ImagePicker _picker = ImagePicker();
  Uint8List? _selectedImageBytes;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final existing = widget.session.user.profilePhotoBase64;
    if (existing != null && existing.isNotEmpty) {
      _selectedImageBytes = base64Decode(existing);
    }
  }

  Future<void> _pickImage() async {
    if (_saving) return;

    final pickedFile = await _picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 82,
      maxWidth: 1600,
    );
    if (pickedFile == null) return;

    final bytes = await pickedFile.readAsBytes();
    if (!mounted) return;

    setState(() => _selectedImageBytes = bytes);
  }

  Future<void> _savePhoto() async {
    final bytes = _selectedImageBytes;
    if (bytes == null || _saving) return;

    setState(() => _saving = true);

    try {
      await widget.identityRepository.updateProfilePhoto(bytes);
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

  void _cancelSelection() {
    if (_saving) return;
    setState(() => _selectedImageBytes = null);
  }

  @override
  Widget build(BuildContext context) {
    final selectedImageBytes = _selectedImageBytes;

    return Scaffold(
      backgroundColor: selectedImageBytes == null
          ? const Color(0xff000000)
          : Colors.black,
      body: SafeArea(
        child: selectedImageBytes == null
            ? _buildPickerStage()
            : _buildPreviewStage(selectedImageBytes),
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
                            child: const Icon(
                              Icons.add,
                              color: Colors.white,
                            ),
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
          SizedBox(height: 34.h),
        ],
      ),
    );
  }

  Widget _buildPreviewStage(Uint8List imageBytes) {
    return Stack(
      fit: StackFit.expand,
      children: [
        Image.memory(imageBytes, fit: BoxFit.cover),
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
                ),
                SizedBox(height: 18.h),
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
              ],
            ),
          ),
        ),
      ],
    );
  }
}