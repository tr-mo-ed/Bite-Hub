# ربط Bite Hub بخدمة Brevo OTP

## 1. إعداد Brevo

1. من حساب Brevo افتح إعدادات **Senders & IP** وأضف بريد المرسل.
2. أكّد بريد المرسل أو وثّق النطاق الخاص بك.
3. افتح **SMTP & API > API Keys** وأنشئ مفتاح API جديداً.
4. لا تضع المفتاح داخل GitHub أو كود Flutter.

## 2. إعداد PythonAnywhere

أنشئ أو حدّث الملف:

```bash
nano /home/fooood/Bite-Hub/.env
```

وأضف:

```env
BREVO_API_KEY=xkeysib-your-real-key
BREVO_SENDER_EMAIL=your-verified-sender@example.com
BREVO_SENDER_NAME=Bite Hub
BREVO_API_URL=https://api.brevo.com/v3/smtp/email
BREVO_REQUEST_TIMEOUT_SECONDS=10
BREVO_DEBUG_EMAIL_CODES=False

EMAIL_LOGIN_CODE_TTL_MINUTES=10
EMAIL_LOGIN_RESEND_SECONDS=60
EMAIL_LOGIN_MAX_REQUESTS_PER_HOUR=5
EMAIL_LOGIN_MAX_ATTEMPTS=5
```

احمِ الملف:

```bash
chmod 600 /home/fooood/Bite-Hub/.env
```

## 3. تحديث قاعدة البيانات واختبار الإرسال

```bash
cd /home/fooood/Bite-Hub
python manage.py migrate
python manage.py check
python manage.py test_brevo_email your-inbox@example.com
```

إذا ظهر:

```text
Brevo accepted the test email
```

فقد قبل Brevo الرسالة. افحص صندوق الوارد وSpam، ثم أعد تحميل تطبيق الويب من صفحة PythonAnywhere.

## 4. التدفق داخل التطبيق

- تسجيل الدخول بالبريد يرسل رمزاً من 6 أرقام.
- إنشاء الحساب يرسل رمزاً قبل إنشاء الطالب.
- لا يتم إنشاء المستخدم أو إصدار JWT قبل نجاح التحقق.
- الرمز صالح 10 دقائق، أحادي الاستخدام، ومحدود بعدد محاولات وطلبات.
