import '../../../core/api/mobile_api.dart';
import '../../../core/session/app_session.dart';
import '../../../core/widgets/app_shell.dart';
import '../../../core/widgets/common_widgets.dart';
import '../data/profile_avatar_cache.dart';
import '../models/app_models.dart';
import '../../supplier/presentation/widgets/supplier_dock.dart';
import '../../werka/presentation/widgets/werka_dock.dart';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final TextEditingController nicknameController = TextEditingController();
  bool savingNickname = false;
  bool uploadingAvatar = false;
  String? errorMessage;
  File? cachedAvatar;

  SessionProfile get profile => AppSession.instance.profile!;

  @override
  void initState() {
    super.initState();
    nicknameController.text = profile.displayName;
    _loadCachedAvatar();
  }

  Future<void> _loadCachedAvatar() async {
    final file = await ProfileAvatarCache.ensureCached(profile);
    if (!mounted) {
      return;
    }
    setState(() {
      cachedAvatar = file;
    });
  }

  Future<void> _saveNickname() async {
    final nickname = nicknameController.text.trim();
    setState(() {
      savingNickname = true;
      errorMessage = null;
    });
    try {
      final updated = await MobileApi.instance.updateNickname(nickname);
      nicknameController.text = updated.displayName;
      if (!mounted) {
        return;
      }
      setState(() {});
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        errorMessage = 'Nickname saqlanmadi';
      });
    } finally {
      if (mounted) {
        setState(() {
          savingNickname = false;
        });
      }
    }
  }

  Future<void> _pickAvatar() async {
    setState(() {
      uploadingAvatar = true;
      errorMessage = null;
    });
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.image,
        withData: true,
      );
      if (result == null || result.files.isEmpty) {
        return;
      }
      final picked = result.files.single;
      final bytes = picked.bytes;
      if (bytes == null || bytes.isEmpty) {
        throw Exception('empty avatar');
      }

      final updated = await MobileApi.instance.uploadAvatar(
        bytes: bytes,
        filename: picked.name,
      );
      final file = await ProfileAvatarCache.cacheFromBytes(
        updated,
        bytes,
        picked.name,
      );
      if (!mounted) {
        return;
      }
      setState(() {
        cachedAvatar = file;
      });
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        errorMessage = 'Rasm yuklanmadi';
      });
    } finally {
      if (mounted) {
        setState(() {
          uploadingAvatar = false;
        });
      }
    }
  }

  @override
  void dispose() {
    nicknameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final current = profile;
    final role = current.role;
    final subtitle = role == UserRole.supplier
        ? 'Jo‘natish va statuslarni boshqaradi'
        : 'Pending qabul qilish va tasdiqlash bilan ishlaydi';

    return AppShell(
      title: 'Profile',
      subtitle: 'Account va session boshqaruvi.',
      bottom: role == UserRole.supplier
          ? const SupplierDock(activeTab: SupplierDockTab.profile)
          : const WerkaDock(activeTab: WerkaDockTab.profile),
      child: Column(
        children: [
          SoftCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Stack(
                    children: [
                      CircleAvatar(
                        radius: 42,
                        backgroundColor: const Color(0xFF121212),
                        backgroundImage: cachedAvatar != null
                            ? FileImage(cachedAvatar!)
                            : null,
                        child: cachedAvatar == null
                            ? Text(
                                (current.displayName.isNotEmpty
                                        ? current.displayName[0]
                                        : 'U')
                                    .toUpperCase(),
                                style:
                                    Theme.of(context).textTheme.headlineMedium,
                              )
                            : null,
                      ),
                      Positioned(
                        right: 0,
                        bottom: 0,
                        child: GestureDetector(
                          onTap: uploadingAvatar ? null : _pickAvatar,
                          child: Container(
                            height: 30,
                            width: 30,
                            decoration: BoxDecoration(
                              color: Colors.white,
                              shape: BoxShape.circle,
                              border: Border.all(color: Colors.black, width: 2),
                            ),
                            child: uploadingAvatar
                                ? const Padding(
                                    padding: EdgeInsets.all(7),
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: Colors.black,
                                    ),
                                  )
                                : const Icon(
                                    Icons.camera_alt_rounded,
                                    size: 16,
                                    color: Colors.black,
                                  ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 18),
                Text(
                  current.displayName,
                  style: Theme.of(context)
                      .textTheme
                      .displaySmall
                      ?.copyWith(fontSize: 30),
                ),
                const SizedBox(height: 10),
                Text(subtitle, style: Theme.of(context).textTheme.bodyLarge),
                const SizedBox(height: 16),
                Text(
                  role == UserRole.supplier
                      ? 'Supplier account'
                      : 'Werka account',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),
          SoftCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Nickname', style: Theme.of(context).textTheme.titleLarge),
                const SizedBox(height: 10),
                TextField(
                  controller: nicknameController,
                  decoration: const InputDecoration(
                    labelText: 'Nickname',
                    hintText: 'O‘zingizga ko‘rinadigan ism',
                  ),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: savingNickname ? null : _saveNickname,
                    child: savingNickname
                        ? const SizedBox(
                            height: 18,
                            width: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.black,
                            ),
                          )
                        : const Text('Nickname saqlash'),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),
          SoftCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Telefon', style: Theme.of(context).textTheme.titleLarge),
                const SizedBox(height: 10),
                TextField(
                  enabled: false,
                  decoration: const InputDecoration(
                    labelText: 'Telefon raqam',
                  ),
                  controller: TextEditingController.fromValue(
                    TextEditingValue(text: current.phone),
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  'Telefon raqam faqat ko‘rish uchun. Uni ilovadan o‘zgartirib bo‘lmaydi.',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),
          SoftCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Asl ism', style: Theme.of(context).textTheme.titleLarge),
                const SizedBox(height: 8),
                Text(
                  current.legalName.isEmpty
                      ? current.displayName
                      : current.legalName,
                ),
                const SizedBox(height: 18),
                Text('Session', style: Theme.of(context).textTheme.titleLarge),
                const SizedBox(height: 8),
                Text(
                  'Bu yerdan hisobdan chiqishingiz mumkin. Keyingi login bilan role qayta tanlanadi.',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ],
            ),
          ),
          if (errorMessage != null) ...[
            const SizedBox(height: 14),
            SoftCard(
              child: Text(errorMessage!),
            ),
          ],
          const Spacer(),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton(
              onPressed: () async {
                final navigator = Navigator.of(context);
                await MobileApi.instance.logout();
                if (!mounted) {
                  return;
                }
                navigator.pushNamedAndRemoveUntil(
                  '/',
                  (route) => false,
                );
              },
              child: const Text('Logout'),
            ),
          ),
        ],
      ),
    );
  }
}
