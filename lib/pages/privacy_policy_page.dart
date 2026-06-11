import 'package:flutter/material.dart';

import '../l10n/app_strings.dart';
import '../theme/app_theme.dart';

class PrivacyPolicyPage extends StatelessWidget {
  const PrivacyPolicyPage({super.key});

  static Future<void> open(BuildContext context) {
    return Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const PrivacyPolicyPage()),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isAr = S.isAr;

    return Scaffold(
      backgroundColor: AppColors.cream,
      appBar: AppBar(
        backgroundColor: AppColors.cream,
        foregroundColor: AppColors.ink,
        elevation: 0,
        title: Text(S.of('privacy_policy_title')),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
        children: [
          Text(
            S.of('privacy_policy_updated'),
            style: TextStyle(fontSize: 12, color: AppColors.inkMuted.withValues(alpha: 0.9)),
          ),
          const SizedBox(height: 20),
          ..._sections(isAr).map(
            (section) => Padding(
              padding: const EdgeInsets.only(bottom: 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    section.title,
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: AppColors.ink),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    section.body,
                    style: TextStyle(fontSize: 14, height: 1.55, color: AppColors.ink.withValues(alpha: 0.88)),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  static List<({String title, String body})> _sections(bool isAr) {
    if (isAr) {
      return [
        (
          title: 'من نحن',
          body:
              'Family Zone («نحن») يشغّل تطبيقاً وموقعاً إلكترونياً لعرض منتجات الأزياء العائلية. '
              'تشرح هذه السياسة كيف نجمع ونستخدم معلوماتك عند استخدام خدماتنا.',
        ),
        (
          title: 'البيانات التي نجمعها',
          body:
              '• بيانات الحساب: البريد الإلكتروني والاسم عند التسجيل أو تسجيل الدخول عبر Google.\n'
              '• المفضلة والسلة: تُخزَّن في حسابك لتحسين تجربة التسوق.\n'
              '• رسائل التواصل: الاسم والبريد والهاتف (اختياري) والرسالة عند إرسال نموذج الاتصال.\n'
              '• بيانات تقنية: معلومات أساسية عن الجهاز والمتصفح عبر Firebase لأغراض التشغيل والأمان.',
        ),
        (
          title: 'كيف نستخدم بياناتك',
          body:
              'نستخدم البيانات لتشغيل المتجر، إدارة الطلبات عبر واتساب، الرد على استفساراتك، '
              'وحماية الخدمة من إساءة الاستخدام. لا نبيع بياناتك الشخصية لأطراف ثالثة.',
        ),
        (
          title: 'مقدمو الخدمة',
          body:
              'نستخدم Google Firebase (المصادقة، قاعدة البيانات، التخزين، الاستضافة) لتشغيل التطبيق. '
              'تخضع بياناتك أيضاً لسياسة خصوصية Google عند استخدام خدماتهم.',
        ),
        (
          title: 'الاحتفاظ بالبيانات والحذف',
          body:
              'نحتفظ ببيانات الحساب طالما كان حسابك نشطاً. يمكنك طلب حذف حسابك وبياناتك '
              'بالتواصل معنا على البريد الإلكتروني المذكور في التطبيق.',
        ),
        (
          title: 'اتصل بنا',
          body: 'لأي سؤال حول الخصوصية: fazone2026@gmail.com',
        ),
      ];
    }

    return [
      (
        title: 'Who we are',
        body:
            'Family Zone («we») operates a mobile app and website for family fashion. '
            'This policy explains how we collect and use your information.',
      ),
      (
        title: 'Data we collect',
        body:
            '• Account data: email and name when you register or sign in with Google.\n'
            '• Favorites and cart: stored in your account to improve your shopping experience.\n'
            '• Contact messages: name, email, optional phone, and message when you use the contact form.\n'
            '• Technical data: basic device/browser information via Firebase for operation and security.',
      ),
      (
        title: 'How we use your data',
        body:
            'We use data to run the store, process orders via WhatsApp, respond to inquiries, '
            'and protect the service from abuse. We do not sell your personal data to third parties.',
      ),
      (
        title: 'Service providers',
        body:
            'We use Google Firebase (authentication, database, storage, hosting) to operate the app. '
            'Your data is also subject to Google\'s privacy policy when using their services.',
      ),
      (
        title: 'Retention and deletion',
        body:
            'We keep account data while your account is active. You may request account and data deletion '
            'by contacting us at the email shown in the app.',
      ),
      (
        title: 'Contact us',
        body: 'Privacy questions: fazone2026@gmail.com',
      ),
    ];
  }
}
