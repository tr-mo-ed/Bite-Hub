import 'package:flutter/material.dart';
import 'package:ionicons/ionicons.dart';

import 'package:bitehub_app/app/core/theme/app_colors.dart';

class UsagePolicyScreen extends StatelessWidget {
  const UsagePolicyScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('سياسة الاستخدام والإلغاء'),
        backgroundColor: AppColors.background,
        surfaceTintColor: Colors.transparent,
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(18, 8, 18, 32),
        children: const [
          _PolicyIntro(),
          SizedBox(height: 24),
          _PolicySection(
            number: '01',
            title: 'استخدام الحساب',
            body:
                'استخدم بيانات صحيحة وحديثة، وحافظ على كلمة المرور ورمز الدخول. الحساب شخصي ولا يجوز استخدامه لإجراء طلبات باسم شخص آخر دون إذنه.',
          ),
          _PolicySection(
            number: '02',
            title: 'إرسال الطلب',
            body:
                'راجع المقهى والأصناف والكميات وطريقة الدفع والملاحظات قبل التأكيد. يصل الطلب إلى المقهى فور إرساله، ولا تعتبر الملاحظات تعديلاً للسعر أو ضماناً لتوفر بديل غير معروض.',
          ),
          _PolicySection(
            number: '03',
            title: 'إلغاء الطلب',
            body:
                'يمكن للطالب إلغاء الطلب من التطبيق ما دام بانتظار قبول المقهى. بعد قبول الطلب وبدء تنفيذه يتوقف الإلغاء الذاتي، ويمكن التواصل مع المقهى أو الإدارة للنظر في الحالة.',
          ),
          _PolicySection(
            number: '04',
            title: 'استرداد الرصيد',
            body:
                'عند نجاح إلغاء طلب مدفوع بالمحفظة، يعاد المبلغ تلقائياً إلى المحفظة نفسها. الطلب النقدي لا ينتج عنه استرداد إلكتروني.',
          ),
          _PolicySection(
            number: '05',
            title: 'البيانات والخصوصية',
            body:
                'تستخدم بيانات الحساب والطلب والدفع لتشغيل الخدمة، تنفيذ الطلبات، حماية المحفظة، وإظهار سجل العمليات لصاحب الحساب والجهة المخولة بخدمته.',
          ),
          _PolicySection(
            number: '06',
            title: 'توفر الخدمة',
            body:
                'قد تتأثر بعض الوظائف بالاتصال بالإنترنت أو توقف المقهى أو أعمال الصيانة. حالة الطلب الظاهرة داخل التطبيق هي المرجع التشغيلي الأحدث عند توفر الاتصال.',
          ),
          _PolicySection(
            number: '07',
            title: 'الموافقة والتحديث',
            body:
                'باستخدام التطبيق فإنك توافق على هذه الضوابط التشغيلية. قد يتم تحديث السياسة عند إضافة خدمات جديدة، وسيظهر تاريخ آخر تحديث داخل هذه الصفحة.',
            isLast: true,
          ),
          SizedBox(height: 20),
          _PolicyFooter(),
        ],
      ),
    );
  }
}

class _PolicyIntro extends StatelessWidget {
  const _PolicyIntro();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: const Color(0xFFEAF4EF),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFFC9E2D8)),
      ),
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            Ionicons.document_text_outline,
            color: AppColors.brandBlue,
            size: 28,
          ),
          SizedBox(height: 14),
          Text(
            'استخدام واضح، وطلبات بلا مفاجآت',
            style: TextStyle(
              color: AppColors.textPrimary,
              fontSize: 22,
              fontWeight: FontWeight.w900,
              height: 1.25,
            ),
          ),
          SizedBox(height: 8),
          Text(
            'توضح هذه الصفحة آلية الطلب والدفع والإلغاء وحماية الحساب داخل Bite Hub.',
            style: TextStyle(
              color: AppColors.textSecondary,
              fontWeight: FontWeight.w600,
              height: 1.55,
            ),
          ),
          SizedBox(height: 16),
          Text(
            'آخر تحديث: 14 يونيو 2026',
            style: TextStyle(
              color: AppColors.brandBlue,
              fontSize: 12,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

class _PolicySection extends StatelessWidget {
  const _PolicySection({
    required this.number,
    required this.title,
    required this.body,
    this.isLast = false,
  });

  final String number;
  final String title;
  final String body;
  final bool isLast;

  @override
  Widget build(BuildContext context) {
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            width: 42,
            child: Column(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  alignment: Alignment.center,
                  decoration: const BoxDecoration(
                    color: AppColors.textPrimary,
                    shape: BoxShape.circle,
                  ),
                  child: Text(
                    number,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 11,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
                if (!isLast)
                  Expanded(
                    child: Container(
                      width: 1,
                      margin: const EdgeInsets.symmetric(vertical: 8),
                      color: AppColors.border,
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Padding(
              padding: EdgeInsets.only(bottom: isLast ? 0 : 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 5),
                  Text(
                    title,
                    style: const TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 17,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 7),
                  Text(
                    body,
                    style: const TextStyle(
                      color: AppColors.textSecondary,
                      fontWeight: FontWeight.w600,
                      height: 1.65,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PolicyFooter extends StatelessWidget {
  const _PolicyFooter();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.border),
      ),
      child: const Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            Ionicons.information_circle_outline,
            color: AppColors.textSecondary,
          ),
          SizedBox(width: 10),
          Expanded(
            child: Text(
              'لأي اعتراض على طلب أو عملية مالية، احتفظ برقم الطلب وتواصل مع إدارة المنظومة.',
              style: TextStyle(
                color: AppColors.textSecondary,
                fontWeight: FontWeight.w700,
                height: 1.5,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
