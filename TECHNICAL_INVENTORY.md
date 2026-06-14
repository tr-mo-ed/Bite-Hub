# Bite Hub - Technical Inventory

هذا الملف يجمع الداتا التقنية المستخدمة في مشروع Bite Hub: التقنيات، المعمارية، الـ API، قواعد البيانات، طبقات الكود، والمكونات المخطط استخدامها لاحقا.

## 1. فكرة النظام

Bite Hub هو نظام طلبات أكل داخل بيئة جامعية أو متعددة المقاهي. يتكون من:

- تطبيق موبايل Flutter للمستخدم النهائي.
- Backend باستخدام Django و Django REST Framework.
- لوحة ويب للإدارة والمقهى داخل Django Templates.
- WebSocket لتحديثات الطلبات الحية.
- نظام محفظة داخلية للدفع والتحويل والسحب.

## 2. المعمارية العامة

المشروع مقسوم إلى جزأين رئيسيين:

- `bitehub_app`: تطبيق Flutter.
- `.`: مشروع Django backend.

النمط المعماري الحالي:

- Frontend Mobile App يتصل بالـ Backend عبر REST API.
- Backend مركزي يخدم عدة مقاهٍ من قاعدة بيانات واحدة.
- Multi-Tenancy منطقي عبر `cafe_id`.
- Business Logic داخل `services.py`.
- Read Queries منظمة داخل `selectors.py`.
- WebSocket لتحديثات الطلبات حسب المقهى.

## 3. التقنيات المستخدمة حاليا

### Mobile App

| التقنية | الاستخدام |
|---|---|
| Flutter | بناء تطبيق الموبايل متعدد المنصات |
| Dart | لغة تطوير التطبيق |
| Provider | إدارة الحالة داخل التطبيق |
| HTTP Package | الاتصال بالـ REST API |
| Shared Preferences | حفظ التوكن والإعدادات محليا |
| Web Socket Channel | استقبال تحديثات الطلبات الحية |
| Awesome Notifications | إشعارات محلية لحالة الطلب |
| Connectivity Plus | معرفة حالة الاتصال بالإنترنت |
| Image Picker | اختيار صورة الملف الشخصي |
| Lottie | عرض أنيميشن مثل شاشة offline |
| Shimmer | Skeleton loading |
| Carousel Slider | عرض منتجات مميزة |
| Google Fonts / Tajawal Font | الخط والهوية البصرية |
| Intl | تنسيق الأرقام والتواريخ |
| Path Provider | التعامل مع مسارات الملفات المحلية |

### Backend

| التقنية | الاستخدام |
|---|---|
| Python | لغة الـ backend |
| Django 5.2.8 | إطار عمل backend |
| Django REST Framework | بناء REST API |
| Simple JWT | مصادقة JWT وتحديث التوكن |
| Django CORS Headers | السماح لاتصال التطبيق بالـ API |
| SQLite | قاعدة البيانات الحالية في مرحلة التطوير |
| Django Channels | WebSocket / Real-time |
| Channels Redis | Channel layer عند تفعيل Redis |
| Uvicorn / ASGI | تشغيل التطبيق بأسلوب ASGI |
| Firebase Admin / Firestore | مهيأ كخيار للإشعارات أو خدمات Firebase |
| Sentry SDK | مهيأ لتتبع أخطاء Django عند توفير DSN |
| Pillow | معالجة الصور المرفوعة |

### Web Admin / Cafe Panel

| التقنية | الاستخدام |
|---|---|
| Django Templates | صفحات لوحة الإدارة والمقهى |
| HTML/CSS/JavaScript | واجهات Dashboard |
| Static CSS/JS | ملفات dashboard/products/orders/reports |

## 4. التقنيات المخطط استخدامها لاحقا

هذه التقنيات مذكورة في قرارات التصميم وليست كلها مطبقة بالكامل حاليا:

| التقنية | الهدف |
|---|---|
| PostgreSQL | الانتقال من SQLite إلى قاعدة إنتاجية |
| PostgreSQL Row-Level Security | عزل أقوى لبيانات كل مقهى |
| Redis Cache | تقليل الضغط على قاعدة البيانات |
| Redis Channel Layer | دعم WebSocket production |
| Celery | مهام خلفية لمعالجة الصور والعمليات الثقيلة |
| S3-Compatible Object Storage | تخزين الصور والملفات خارج السيرفر |
| drf-spectacular | توليد OpenAPI / Swagger / Redoc |
| Docker | بيئة تشغيل ونشر منظمة |
| Sentry للـ Flutter | تتبع أخطاء التطبيق لاحقا |

## 5. هيكلة كود Flutter

المسارات الأساسية:

- `lib/main.dart`: نقطة تشغيل التطبيق وتعريف `MultiProvider`.
- `lib/app/data/models`: نماذج البيانات مثل المستخدم، المنتج، الطلب، المحفظة.
- `lib/app/data/providers`: إدارة الحالة باستخدام Provider.
- `lib/app/data/services`: خدمات الاتصال مثل `ApiService` و `NotificationService`.
- `lib/app/presentation`: شاشات المصادقة القديمة.
- `lib/app/presentation_v2`: الواجهات الحديثة للتطبيق.
- `lib/app/core/theme`: الألوان والثيم.
- `assets/images`: صور المنتجات والهوية.
- `assets/lottie`: ملفات الأنيميشن.
- `assets/fonts`: خط Tajawal.

أهم الـ Providers:

- `AuthProvider`: تسجيل الدخول والخروج وحالة المستخدم.
- `WalletProvider`: بيانات المحفظة.
- `CartProvider`: السلة.
- `ProductProvider`: المنتجات.
- `CollegeProvider`: المقاهي أو الكليات.
- `FavoritesProvider`: المفضلة.
- `NotificationProvider`: الإشعارات.
- `ThemeProvider`: الوضع الفاتح/الداكن.
- `ProfileImageProvider`: صورة المستخدم.

## 6. هيكلة كود Django

التطبيقات الأساسية:

- `core`: المقاهي، المنتجات، التصنيفات، الطلبات، لوحة الإدارة، WebSocket.
- `users`: المستخدم المخصص.
- `wallet`: المحفظة والمعاملات.
- `bitehub_backend`: إعدادات المشروع وملفات التشغيل.

أهم الطبقات:

- `models.py`: تعريف الجداول والعلاقات.
- `serializers.py`: تحويل البيانات إلى JSON والعكس.
- `api_views.py`: REST API لتطبيق الموبايل.
- `backoffice_views.py`: API ولوحات الإدارة والمقهى.
- `services.py`: منطق الأعمال، مثل إنشاء الطلب وتحديث حالته.
- `selectors.py`: الاستعلامات المنظمة مع `select_related` و `prefetch_related`.
- `querysets.py`: QuerySets مخصصة لعزل بيانات المقاهي.
- `consumers.py`: WebSocket consumer للطلبات الحية.
- `routing.py`: مسارات WebSocket.

## 7. قاعدة البيانات الحالية

قاعدة البيانات الحالية:

- النوع: SQLite
- الملف: `bitehub_tripoli.sqlite3`
- الاستخدام: مرحلة التطوير

قاعدة الإنتاج المخطط لها:

- PostgreSQL
- مع Row-Level Security لاحقا لعزل المقاهي.

## 8. أهم الجداول والموديلات

### Users

`User` مخصص بدلا من Django User الافتراضي:

- `email`: معرف الدخول الأساسي.
- `phone_number`: رقم الهاتف.
- `secondary_phone_number`: رقم إضافي.
- `full_name`: الاسم الكامل.
- `image`: صورة مرفوعة.
- `profile_image_url`: رابط صورة.

### Core

`Faculty`:

- يمثل كلية أو مستوى تنظيمي أعلى.

`Cafe`:

- يمثل مقهى.
- مرتبط اختياريا بكلية.
- مرتبط بمالك `owner`.

`CafeScopedModel`:

- موديل مجرد يضيف `cafe_id` للموديلات التي تحتاج عزلا حسب المقهى.

`Category`:

- تصنيف منتجات داخل مقهى.

`Product`:

- منتج غذائي.
- يحتوي على السعر، الصورة، الحالة، التقييم.

`Order`:

- طلب المستخدم.
- مرتبط بالمستخدم والمقهى.
- يحتوي على السعر الإجمالي، الحالة، طريقة الدفع، رقم الطلب.

`OrderItem`:

- عناصر الطلب.
- تربط الطلب بالمنتجات والكميات.

### Wallet

`Wallet`:

- محفظة لكل مستخدم.
- رصيد.
- كود ربط.

`Transaction`:

- معاملات مالية.
- أنواعها: `DEPOSIT`, `WITHDRAWAL`.
- مصادرها: `SYSTEM`, `APP`.
- تستخدم `transaction.atomic` و `select_for_update` لحماية الرصيد من التعارض.

## 9. حالات الطلب

حالات الطلب في النظام:

- `PENDING`: قيد الانتظار.
- `ACCEPTED`: تم القبول.
- `PREPARING`: قيد التحضير.
- `READY`: جاهز للاستلام.
- `COMPLETED`: مكتمل.
- `CANCELLED`: ملغى.

انتقالات الحالة المسموحة:

- `PENDING` إلى `ACCEPTED` أو `CANCELLED`.
- `ACCEPTED` إلى `PREPARING` أو `CANCELLED`.
- `PREPARING` إلى `READY` أو `CANCELLED`.
- `READY` إلى `COMPLETED` أو `CANCELLED`.
- `COMPLETED` و `CANCELLED` حالات نهائية.

## 10. طرق الدفع

طرق الدفع الحالية:

- `WALLET`: الدفع من المحفظة.
- `CASH`: دفع نقدي.

عند الدفع بالمحفظة:

- يتم قفل سجل المحفظة باستخدام `select_for_update`.
- يتم التحقق من الرصيد.
- يتم إنشاء Transaction من نوع `WITHDRAWAL`.
- عند إلغاء طلب مدفوع بالمحفظة يتم إرجاع المبلغ كـ `DEPOSIT`.

## 11. API المستخدمة في تطبيق الموبايل

Base URL الافتراضي:

```text
http://127.0.0.1:8000
```

يمكن تغييره من Flutter عبر:

```text
BITE_HUB_API_BASE_URL
```

### Authentication

| Method | Endpoint | الاستخدام |
|---|---|---|
| POST | `/api/v2/app/auth/login/` | تسجيل الدخول |
| POST | `/api/v2/app/auth/signup/` | إنشاء حساب |
| POST | `/api/v2/app/auth/refresh/` | تحديث JWT token |

### User

| Method | Endpoint | الاستخدام |
|---|---|---|
| GET/PATCH | `/api/v2/app/user/` | قراءة أو تحديث بيانات المستخدم |
| POST | `/api/v2/app/user/secondary-phone/` | تحديث الرقم الإضافي |

### Cafes & Products

| Method | Endpoint | الاستخدام |
|---|---|---|
| GET | `/api/v2/app/cafes/` | جلب المقاهي النشطة |
| GET | `/api/v2/app/products/` | جلب المنتجات |
| GET | `/api/v2/app/products/?cafe_id=ID` | جلب منتجات مقهى محدد |

### Orders

| Method | Endpoint | الاستخدام |
|---|---|---|
| GET/POST | `/api/v2/app/orders/` | جلب الطلبات أو إنشاء طلب |
| PATCH | `/api/v2/app/orders/<order_id>/cancel/` | إلغاء طلب |

### Wallet

| Method | Endpoint | الاستخدام |
|---|---|---|
| GET | `/api/v2/app/wallet/` | جلب المحفظة |
| POST | `/api/v2/app/wallet/link/` | ربط المحفظة بكود |
| POST | `/api/v2/app/wallet/transfer/` | تحويل رصيد |
| POST | `/api/v2/app/wallet/withdraw/` | سحب أو خصم رصيد |

## 12. API لوحة المقهى

| Method | Endpoint | الاستخدام |
|---|---|---|
| POST/PATCH | `/api/v2/cafe/orders/<order_id>/status/` | تحديث حالة الطلب |
| POST/PATCH | `/api/v2/cafe/products/<product_id>/availability/` | تغيير توفر المنتج |

## 13. API الإدارة العامة

| Method | Endpoint | الاستخدام |
|---|---|---|
| POST | `/api/v2/admin/cafes/create/` | إنشاء مقهى |
| POST/PATCH | `/api/v2/admin/cafes/<cafe_id>/toggle/` | تفعيل أو تعطيل مقهى |

## 14. WebSocket

مسار WebSocket:

```text
ws://127.0.0.1:8000/ws/cafe/<cafe_id>/orders/
```

في الإنتاج مع HTTPS:

```text
wss://domain/ws/cafe/<cafe_id>/orders/
```

يستخدم النظام مجموعة لكل مقهى:

```text
cafe_orders_<cafe_id>
```

الأحداث المرسلة:

- `order.created`: عند إنشاء طلب.
- `order.updated`: عند تحديث حالة الطلب أو إلغائه.

الـ payload يحتوي عادة على:

- `id`
- `order_number`
- `cafe_id`
- `cafe_name`
- `user_id`
- `total_price`
- `status`
- `payment_method`
- `created_at`
- `items`

## 15. المصادقة والأمان

المستخدم حاليا:

- JWT Authentication عبر `djangorestframework-simplejwt`.
- Session Authentication للوحات Django.
- تخزين access token و refresh token في `SharedPreferences`.
- CORS مفتوح حاليا: `CORS_ALLOW_ALL_ORIGINS = True`.

ملاحظات إنتاجية:

- يجب تغيير `SECRET_KEY`.
- يجب إغلاق `DEBUG`.
- يجب تحديد `ALLOWED_HOSTS`.
- يجب تضييق CORS.
- يجب استخدام HTTPS.
- يفضل نقل التوكن لتخزين آمن مخصص للموبايل لاحقا.

## 16. الأداء

التحسينات المستخدمة حاليا:

- `select_related` لجلب العلاقات المباشرة.
- `prefetch_related` لجلب عناصر الطلب.
- Indexes على حقول مهمة مثل:
  - `cafe`
  - `category`
  - `is_available`
  - `status`
  - `created_at`
  - `user`
- `LocMemCache` حاليا في Django.

المخطط لاحقا:

- Redis Cache للمنتجات، التصنيفات، المقاهي النشطة.
- PostgreSQL للأداء والإنتاج.
- Redis كـ channel layer للـ WebSocket.

## 17. الإشعارات

الإشعارات الحالية في Flutter:

- إشعارات محلية باستخدام Awesome Notifications.
- تخزين آخر الإشعارات محليا في Shared Preferences.
- توليد إشعار عند تغير حالة الطلب.

في backend:

- توجد تهيئة Firebase Admin / Firestore.
- توجد دالة `send_real_notification`.
- Firebase غير مضمون التشغيل إلا عند وجود `serviceAccountKey.json`.

## 18. الصور والملفات

الحالي:

- صور المنتجات والمقاهي والملف الشخصي تحفظ محليا عبر Django media.
- Flutter يستخدم assets محلية للصور الافتراضية والهوية.

المخطط لاحقا:

- S3-Compatible Object Storage.
- Celery لمعالجة الصور.
- توليد thumbnails وضغط الصور خارج request cycle.

## 19. الاختبارات

الموجود حاليا:

- اختبارات Django في:
  - `core/tests.py`
  - `wallet/tests.py`
  - `users/tests.py`
- اختبار Flutter افتراضي في:
  - `bitehub_app/test/widget_test.dart`

الاختبارات المذكورة في الكود تشمل:

- إنشاء المقاهي.
- سير الطلب.
- صلاحيات شحن المحفظة.
- Smoke tests لبعض صفحات Dashboard.

## 20. ملخص التقنيات بالكامل

### مستخدم حاليا

- Flutter
- Dart
- Provider
- HTTP
- Shared Preferences
- WebSocket Channel
- Awesome Notifications
- Connectivity Plus
- Image Picker
- Lottie
- Shimmer
- Carousel Slider
- Django
- Django REST Framework
- Simple JWT
- Django CORS Headers
- SQLite
- Django Channels
- ASGI
- Uvicorn
- Firebase Admin
- Sentry SDK
- Pillow
- HTML/CSS/JavaScript
- Django Templates

### مخطط استخدامه لاحقا

- PostgreSQL
- PostgreSQL RLS
- Redis Cache
- Redis Channel Layer
- Celery
- S3-Compatible Object Storage
- drf-spectacular
- Swagger UI
- Redoc
- Docker
- Sentry Flutter

## 21. أهم القرارات المعمارية

- نظام مركزي واحد بدلا من نسخة منفصلة لكل مقهى.
- عزل بيانات المقاهي باستخدام `cafe_id`.
- استخدام `CafeScopedModel` و `CafeScopedQuerySet`.
- جعل `selectors.py` مسؤولة عن القراءة المنظمة.
- جعل `services.py` مسؤولة عن منطق الأعمال.
- منع N+1 Queries باستخدام `select_related` و `prefetch_related`.
- تجهيز النظام للانتقال إلى PostgreSQL و Redis.
- استخدام WebSocket لتحديثات الطلبات بدلا من polling فقط.
- استخدام Sentry لتتبع الأخطاء عند إعداد DSN.
- التخطيط لتخزين خارجي للصور عند الانتقال للإنتاج.
