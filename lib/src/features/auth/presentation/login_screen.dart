import '../../../app/app_router.dart';
import '../../../core/api/mobile_api.dart';
import '../../../core/notifications/push_messaging_service.dart';
import '../../../core/security/security_controller.dart';
import '../../../core/widgets/app_shell.dart';
import '../../../core/widgets/motion_widgets.dart';
import '../../shared/models/app_models.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  static const String lastCodeKey = 'last_login_code';
  static const String lastPhoneKey = 'last_login_phone';

  final TextEditingController phoneController = TextEditingController();
  final TextEditingController codeController = TextEditingController();
  final FocusNode phoneFocusNode = FocusNode();
  final FocusNode codeFocusNode = FocusNode();
  String? errorText;
  bool loading = false;
  String? rememberedCode;
  String? rememberedPhone;

  @override
  void initState() {
    super.initState();
    loadRememberedCode();
  }

  Future<void> loadRememberedCode() async {
    final prefs = await SharedPreferences.getInstance();
    final savedCode = prefs.getString(lastCodeKey);
    final savedPhone = prefs.getString(lastPhoneKey);
    if (!mounted) {
      return;
    }
    setState(() {
      rememberedCode = savedCode;
      rememberedPhone = savedPhone;
      if (phoneController.text.trim().isEmpty &&
          savedPhone != null &&
          savedPhone.isNotEmpty) {
        phoneController.text = savedPhone;
      }
      if (codeController.text.trim().isEmpty &&
          savedCode != null &&
          savedCode.isNotEmpty) {
        codeController.text = savedCode;
      }
    });
  }

  Future<void> persistRememberedCode(String value) async {
    final prefs = await SharedPreferences.getInstance();
    final trimmed = value.trim();
    if (trimmed.isEmpty) {
      await prefs.remove(lastCodeKey);
      if (!mounted) {
        return;
      }
      setState(() {
        rememberedCode = null;
      });
      return;
    }

    await prefs.setString(lastCodeKey, trimmed);
    if (!mounted) {
      return;
    }
    setState(() {
      rememberedCode = trimmed;
    });
  }

  Future<void> persistRememberedPhone(String value) async {
    final prefs = await SharedPreferences.getInstance();
    final trimmed = value.trim();
    if (trimmed.isEmpty) {
      await prefs.remove(lastPhoneKey);
      if (!mounted) {
        return;
      }
      setState(() {
        rememberedPhone = null;
      });
      return;
    }

    await prefs.setString(lastPhoneKey, trimmed);
    if (!mounted) {
      return;
    }
    setState(() {
      rememberedPhone = trimmed;
    });
  }

  @override
  void dispose() {
    phoneController.dispose();
    codeController.dispose();
    phoneFocusNode.dispose();
    codeFocusNode.dispose();
    super.dispose();
  }

  void submitLogin(BuildContext context) {
    if (loading) {
      return;
    }
    final String phone = phoneController.text.trim();
    final String code = codeController.text.trim();

    if (phone.isEmpty || code.isEmpty) {
      setState(() => errorText = 'Telefon raqam va code ni kiriting');
      return;
    }
    setState(() {
      errorText = null;
      loading = true;
    });

    MobileApi.instance
        .login(phone: phone, code: code)
        .then((SessionProfile profile) {
      if (!context.mounted) {
        return;
      }
      SharedPreferences.getInstance().then((prefs) {
        prefs
          ..setString(lastCodeKey, code)
          ..setString(lastPhoneKey, phone);
      });
      PushMessagingService.instance.syncCurrentToken();
      SecurityController.instance.unlockAfterLogin();
      final String route = profile.role == UserRole.supplier
          ? AppRoutes.supplierHome
          : profile.role == UserRole.werka
              ? AppRoutes.werkaHome
              : AppRoutes.adminHome;
      Navigator.of(context).pushNamedAndRemoveUntil(route, (route) => false);
    }).catchError((_) {
      if (!context.mounted) {
        return;
      }
      setState(() {
        errorText = 'Login muvaffaqiyatsiz';
        loading = false;
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    return AppShell(
      title: 'Login',
      subtitle: '',
      child: LayoutBuilder(
        builder: (context, constraints) {
          return SingleChildScrollView(
            child: ConstrainedBox(
              constraints: BoxConstraints(minHeight: constraints.maxHeight),
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 28),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      AutofillGroup(
                        child: Column(
                          children: [
                            SmoothAppear(
                              delay: const Duration(milliseconds: 30),
                              child: TextField(
                                controller: phoneController,
                                focusNode: phoneFocusNode,
                                textInputAction: TextInputAction.next,
                                keyboardType: TextInputType.phone,
                                autocorrect: false,
                                enableSuggestions: true,
                                autofillHints: const [
                                  AutofillHints.telephoneNumber
                                ],
                                onChanged: persistRememberedPhone,
                                onSubmitted: (_) =>
                                    codeFocusNode.requestFocus(),
                                decoration: InputDecoration(
                                  labelText: 'Telefon raqam',
                                  hintText: 'Masalan: +998901234567',
                                  suffixIcon: rememberedPhone != null &&
                                          rememberedPhone!.isNotEmpty
                                      ? _RememberedFieldAction(
                                          label: 'Oxirgi',
                                          onTap: () {
                                            phoneController.text =
                                                rememberedPhone!;
                                            codeFocusNode.requestFocus();
                                          },
                                        )
                                      : null,
                                ),
                              ),
                            ),
                            const SizedBox(height: 14),
                            SmoothAppear(
                              delay: const Duration(milliseconds: 40),
                              child: TextField(
                                controller: codeController,
                                focusNode: codeFocusNode,
                                textInputAction: TextInputAction.done,
                                autocorrect: false,
                                enableSuggestions: true,
                                autofillHints: const [AutofillHints.username],
                                onChanged: persistRememberedCode,
                                onSubmitted: (_) {
                                  if (!loading) {
                                    submitLogin(context);
                                  }
                                },
                                decoration: InputDecoration(
                                  labelText: 'Code',
                                  hintText: 'Masalan: 10XXXXXXXXXX',
                                  suffixIcon: rememberedCode != null &&
                                          rememberedCode!.isNotEmpty
                                      ? _RememberedFieldAction(
                                          label: 'Oxirgi',
                                          onTap: () {
                                            codeController.text =
                                                rememberedCode!;
                                            codeFocusNode.unfocus();
                                          },
                                        )
                                      : null,
                                ),
                              ),
                            ),
                            const SizedBox(height: 14),
                          ],
                        ),
                      ),
                      if (errorText != null) ...[
                        const SizedBox(height: 14),
                        SmoothAppear(
                          delay: const Duration(milliseconds: 120),
                          child: Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: const Color(0xFF0B0B0B),
                              borderRadius: BorderRadius.circular(18),
                              border:
                                  Border.all(color: const Color(0xFF2A2A2A)),
                            ),
                            child: Text(
                              errorText!,
                              style: Theme.of(context).textTheme.bodyMedium,
                            ),
                          ),
                        ),
                      ],
                      const SizedBox(height: 20),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed:
                              loading ? null : () => submitLogin(context),
                          child: Text(loading ? 'Kuting...' : 'Login'),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _RememberedFieldAction extends StatelessWidget {
  const _RememberedFieldAction({
    required this.label,
    required this.onTap,
  });

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: Center(
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: onTap,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFF2A2A2A)),
                color: const Color(0x0F888888),
              ),
              child: Text(
                label,
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
