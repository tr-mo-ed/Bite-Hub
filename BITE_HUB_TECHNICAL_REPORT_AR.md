# التقرير الفني الشامل لمنظومة Bite Hub

تاريخ التقرير: 2026-05-09  
المشروع: Bite Hub  
نوع النظام: تطبيق طلبات أكل جامعي مع تطبيق موبايل، لوحة سوبر أدمن، ولوحة إدارة مقاهٍ.

---
 
## 1. الملخص التنفيذي

منظومة Bite Hub تتكون من ثلاثة أجزاء رئيسية:

1. تطبيق المستخدم النهائي Mobile App.
2. لوحة السوبر أدمن Super Admin Dashboard.
3. منظومة المقاهي Cafe Panel / Cafe Mini System.

المنظومة تعتمد على Backend مركزي واحد يخدم أكثر من مقهى، مع عزل منطقي للبيانات حسب `cafe_id`. التطبيق يتعامل مع الـ Backend عبر REST API، بينما تحديثات الطلبات الحية تعتمد على WebSocket.

الاختيار المعماري الحالي مناسب للمشروع:

- REST API للعمليات التقليدية مثل تسجيل الدخول، المنتجات، الطلبات، المحفظة.
- WebSocket للعمليات الحية مثل تحديث حالة الطلب.
- Multi-Tenancy منطقي داخل قاعدة بيانات واحدة.
- فصل منطق الأعمال في `services.py`.
- فصل الاستعلامات في `selectors.py`.
- واجهات إدارة مبنية داخل Django Templates.

---

## 2. الإصدارات الأساسية للبيئة

| العنصر | الإصدار الحالي | الاستخدام |
|---|---:|---|
| Flutter | 3.35.6 | بناء تطبيق الموبايل |
| Dart | 3.9.2 | لغة تطبيق Flutter |
| Flutter DevTools | 2.48.0 | أدوات الفحص والتطوير |
| Python | 3.14.0a7 | لغة الـ Backend الحالية في البيئة |
| Django | 5.2.8 | إطار عمل الـ Backend |
| Django REST Framework | 3.16.1 | بناء REST API |
| SQLite | مدمج مع Python/Django | قاعدة بيانات التطوير الحالية |
| Gradle | 8.12 | بناء Android |
| Android Gradle Plugin | 8.9.1 | بناء تطبيق Android |
| Kotlin Android Plugin | 2.1.0 | دعم Kotlin في Android |
| Google Services Gradle Plugin | 4.3.15 | تجهيز تكامل Google/Firebase |
| Android compileSdk | 36 | بناء Android |
| Android targetSdk | 36 | استهداف Android |
| Java Compatibility | 1.8 | إعدادات build Android |

ملاحظة مهمة: إصدار Python الحالي `3.14.0a7` هو إصدار alpha. للإنتاج يفضل استخدام إصدار Python مستقر مثل 3.12 أو 3.13 حسب توافق الاستضافة والحزم.

---

## 3. هيكلة المستودع

المشروع مقسم إلى:

```text
Bite Hub/
  bitehub_app/
    lib/
    assets/
    android/
    ios/
    web/
  bitehub_backend_workspace/
    bitehub_backend_workspace/
      bitehub_backend/
      core/
      users/
      wallet/
      templates/
      static/
```

### التطبيق

```text
bitehub_app
```

يحتوي تطبيق Flutter للمستخدم النهائي، ويشمل Android و iOS و Web و Windows scaffolding.

### الباكند

```text
bitehub_backend_workspace/bitehub_backend_workspace
```

يحتوي مشروع Django، وداخله:

- `core`: المقاهي، المنتجات، الطلبات، السوبر أدمن، لوحة المقاهي، WebSocket.
- `users`: المستخدم المخصص.
- `wallet`: المحفظة والمعاملات.
- `bitehub_backend`: إعدادات Django، urls، ASGI، WSGI.
- `templates`: واجهات HTML للسوبر أدمن ولوحة المقهى.
- `static`: CSS و JavaScript للوحة الإدارة.

---

## 4. معمارية التطبيق العامة

المعمارية الحالية يمكن وصفها كالتالي:

```text
Flutter Mobile App
        |
        | REST API / JSON
        v
Django REST Framework API
        |
        | ORM
        v
SQLite حاليا / PostgreSQL لاحقا

Flutter Live Order Screen
        |
        | WebSocket
        v
Django Channels / ASGI
        |
        v
Cafe-specific WebSocket Group
```

### النمط المعماري

- Client-Server Architecture.
- RESTful API للعمليات الأساسية.
- Real-time Architecture عبر WebSocket.
- Multi-Tenant Backend عبر `cafe_id`.
- Layered Backend Architecture.
- Provider-based State Management في Flutter.

---

## 5. معمارية Multi-Tenancy

المنظومة لا تنشئ نسخة مستقلة لكل مقهى. بدلا من ذلك تستخدم نظام مركزي واحد.

وحدة العزل الأساسية:

```text
cafe_id
```

الموديلات التي تحتاج عزلا حسب المقهى ترث من:

```python
CafeScopedModel
```

وهذا يضيف علاقة:

```python
cafe = ForeignKey(Cafe)
```

### فوائد هذا القرار

- تقليل تكرار الكود.
- تقليل تكلفة التشغيل.
- سهولة إضافة مقهى جديد.
- مصدر بيانات مركزي واحد.
- قابلية توسع أفضل.

### عناصر العزل

- `CafeScopedModel`
- `CafeScopedQuerySet`
- `CafeScopedManager`
- `selectors.py`
- فلاتر `for_cafe(cafe_id)`

---

## 6. تطبيق المستخدم النهائي

### الوظائف الرئيسية

- تسجيل الدخول.
- إنشاء حساب.
- عرض المقاهي.
- عرض المنتجات.
- إضافة منتجات للسلة.
- إنشاء طلب.
- متابعة الطلب.
- إلغاء الطلب.
- إدارة المحفظة.
- تحويل رصيد.
- تعديل الملف الشخصي.
- إشعارات محلية عند تغير حالة الطلب.

### أهم شاشات التطبيق

| الشاشة | المسار |
|---|---|
| Welcome/Login/Signup/OTP | `lib/app/presentation/screens/auth` |
| Home | `lib/app/presentation_v2/screens/home` |
| Cart | `lib/app/presentation_v2/screens/cart` |
| Orders | `lib/app/presentation_v2/screens/orders` |
| Live Order Tracking | `lib/app/presentation_v2/screens/orders/live_order_tracking_screen_v2.dart` |
| Wallet | `lib/app/presentation_v2/screens/wallet` |
| Profile | `lib/app/presentation_v2/screens/profile` |
| Cafe Dashboard داخل التطبيق | `lib/app/presentation_v2/screens/cafe` |

---

## 7. تقنيات Flutter المستخدمة

| التقنية / الحزمة | الإصدار | الاستخدام |
|---|---:|---|
| Flutter SDK | 3.35.6 | إطار بناء التطبيق |
| Dart SDK | 3.9.2 | لغة التطبيق |
| provider | 6.1.5+1 | إدارة الحالة |
| http | 1.6.0 | REST API requests |
| flutter_secure_storage | 9.2.4 | تخزين التوكنات بشكل آمن |
| shared_preferences | 2.5.4 | تخزين إعدادات غير حساسة وإشعارات محلية |
| web_socket_channel | 3.0.3 | WebSocket |
| awesome_notifications | 0.11.0 | إشعارات محلية |
| connectivity_plus | 6.1.5 | كشف حالة الاتصال |
| image_picker | 1.2.1 | اختيار صور المستخدم |
| lottie | 3.3.3 | أنيميشن |
| shimmer | 3.0.0 | Skeleton loading |
| carousel_slider | 5.1.2 | كاروسيل المنتجات |
| google_fonts | 6.3.3 | الخطوط |
| flutter_svg | 2.2.3 | SVG assets |
| ionicons | 0.2.2 | أيقونات |
| pinput | 6.0.1 | إدخال OTP |
| sms_autofill | 2.4.1 | OTP/SMS autofill |
| intl | 0.20.2 | تنسيق أرقام وتواريخ |
| path_provider | 2.1.5 | مسارات الملفات |
| persistent_bottom_nav_bar_v2 | 6.3.2 | Bottom navigation |
| animated_bottom_navigation_bar | 1.4.0 | Bottom navigation animations |
| cupertino_icons | 1.0.8 | أيقونات iOS |

### حزم التطوير في Flutter

| الحزمة | الإصدار | الاستخدام |
|---|---:|---|
| flutter_test | SDK | اختبارات Flutter |
| flutter_lints | 3.0.2 | قواعد lint |
| flutter_launcher_icons | 0.13.1 | توليد أيقونات التطبيق |

---

## 8. معمارية كود Flutter

تطبيق Flutter مقسم إلى طبقات:

```text
lib/
  main.dart
  app/
    auth_widget_builder.dart
    core/
      theme/
      utils/
      enums/
    data/
      models/
      providers/
      services/
    presentation/
    presentation_v2/
```

### طبقة Models

المسار:

```text
lib/app/data/models
```

تحتوي نماذج:

- `UserModel`
- `ProductModel`
- `OrderModel`
- `WalletModel`
- `TransactionModel`
- `CollegeModel`
- `NotificationModel`
- `CartItemModel`

### طبقة Providers

المسار:

```text
lib/app/data/providers
```

تستخدم `ChangeNotifier` و Provider:

- `AuthProvider`
- `WalletProvider`
- `CartProvider`
- `ProductProvider`
- `CollegeProvider`
- `FavoritesProvider`
- `NotificationProvider`
- `NavigationProvider`
- `ThemeProvider`
- `ProfileImageProvider`

### طبقة Services

المسار:

```text
lib/app/data/services
```

أهم الخدمات:

- `ApiService`: الاتصال بالـ REST API، إدارة JWT، رفع صورة الملف الشخصي.
- `NotificationService`: الإشعارات المحلية وتخزين سجل الإشعارات.

### طبقة Presentation

تحتوي الواجهات:

- `presentation`: شاشات قديمة/أساسية للمصادقة.
- `presentation_v2`: الواجهات الحديثة للتطبيق.

---

## 9. السوبر أدمن Super Admin

السوبر أدمن هو أعلى صلاحية في النظام.

### وظائف السوبر أدمن

- عرض لوحة رئيسية عامة.
- عرض مؤشرات KPIs عامة.
- عرض مبيعات النظام.
- عرض المقاهي النشطة.
- إنشاء مقهى جديد.
- تفعيل أو تعطيل مقهى.
- ربط مقهى بمالك.
- عرض تقسيم المبيعات حسب المقهى.
- متابعة أخطاء النظام بشكل مبدئي.

### ملفات السوبر أدمن

| الملف | الدور |
|---|---|
| `core/backoffice_views.py` | Views للسوبر أدمن ولوحة المقهى |
| `core/backoffice_services.py` | منطق إنشاء المقاهي وتفعيلها |
| `core/backoffice_selectors.py` | جلب بيانات dashboard و KPIs |
| `templates/admin_v2/super_admin_dashboard.html` | واجهة السوبر أدمن |
| `templates/admin_v2/base.html` | القالب الأساسي |
| `static/admin_v2/super_admin_dashboard.js` | JavaScript للوحة |
| `core/api_v2_admin_urls.py` | API السوبر أدمن |

### API السوبر أدمن

| Method | Endpoint | الوظيفة |
|---|---|---|
| POST | `/api/v2/admin/cafes/create/` | إنشاء مقهى |
| POST | `/api/v2/admin/cafes/<cafe_id>/toggle/` | تفعيل/تعطيل مقهى |

### صلاحية الوصول

تعتمد على:

```python
user.is_superuser
```

---

## 10. منظومة المقاهي Cafe Panel

منظومة المقاهي مخصصة لصاحب أو مدير المقهى.

### وظائف لوحة المقهى

- عرض الطلبات حسب الحالة.
- تحديث حالة الطلب.
- تغيير توفر المنتجات.
- عرض مؤشرات المقهى.
- استقبال تحديثات WebSocket.
- إدارة الطلبات الحية.

### ملفات منظومة المقاهي

| الملف | الدور |
|---|---|
| `templates/admin_v2/cafe_panel.html` | واجهة لوحة المقهى |
| `static/admin_v2/cafe_panel.js` | تفاعل لوحة المقهى |
| `core/backoffice_views.py` | APIs و Views الخاصة بالمقهى |
| `core/backoffice_selectors.py` | Snapshot للوحة المقهى |
| `core/backoffice_services.py` | تغيير حالة المنتج وربط المقهى |
| `core/services.py` | تحديث حالة الطلب |
| `core/consumers.py` | WebSocket للطلبات |
| `core/routing.py` | مسارات WebSocket |
| `core/api_v2_cafe_urls.py` | API لوحة المقهى |

### API لوحة المقهى

| Method | Endpoint | الوظيفة |
|---|---|---|
| POST | `/api/v2/cafe/orders/<order_id>/status/` | تحديث حالة طلب |
| POST | `/api/v2/cafe/products/<product_id>/availability/` | تغيير توفر منتج |

### عزل صلاحيات المقهى

مدير المقهى لا يرى ولا يعدل إلا مقهاه. العزل يتم عبر:

- علاقة `Cafe.owner`.
- `resolve_backoffice_cafe`.
- `Order.objects.for_cafe(cafe_id)`.
- فحص داخل `update_order_status`.

---

## 11. Backend Technologies

| التقنية / الحزمة | الإصدار | الاستخدام |
|---|---:|---|
| Python | 3.14.0a7 | لغة الـ Backend في البيئة الحالية |
| Django | 5.2.8 | Framework أساسي |
| djangorestframework | 3.16.1 | REST API |
| djangorestframework-simplejwt | 5.4.0 | JWT Authentication |
| django-cors-headers | 4.9.0 | CORS |
| channels | 4.2.0 | WebSocket / ASGI |
| channels-redis | 4.2.0 | Redis channel layer |
| asgiref | 3.10.0 | ASGI utilities |
| uvicorn | 0.32.1 | ASGI server |
| drf-spectacular | 0.28.0 | OpenAPI / Swagger / Redoc |
| python-decouple | 3.8 | Environment variables |
| psycopg[binary] | 3.2.9 | PostgreSQL driver |
| firebase_admin | 7.1.0 | Firebase Admin SDK |
| google-cloud-firestore | 2.21.0 | Firestore |
| google-cloud-storage | 3.6.0 | Google Cloud Storage |
| sentry-sdk[django] | 2.18.0 | Error monitoring |
| pillow | 12.0.0 | معالجة الصور |
| PyJWT | 2.10.1 | JWT support |
| requests | 2.32.5 | HTTP client |
| pytest | 8.3.5 | Testing |
| sqlparse | 0.5.3 | SQL parsing used by Django |
| tzdata | 2025.2 | Timezone data |

### حزم موجودة لكن ليست جوهرية حاليا

| الحزمة | الإصدار | ملاحظة |
|---|---:|---|
| Flask | 3.1.0 | موجودة في requirements لكنها ليست إطار المشروع الأساسي |
| Pyrebase4 | 4.8.0 | موجودة لتكامل Firebase قديم/محتمل |
| gcloud | 0.18.3 | تكامل Google Cloud قديم |
| git-filter-repo | 2.47.0 | أداة Git وليست runtime أساسي |

---

## 12. معمارية كود Django

طبقات Django الأساسية:

```text
bitehub_backend/
  settings.py
  urls.py
  asgi.py
  wsgi.py

core/
  models.py
  serializers.py
  api_views.py
  services.py
  selectors.py
  querysets.py
  backoffice_views.py
  backoffice_services.py
  backoffice_selectors.py
  consumers.py
  routing.py

users/
  models.py
  serializers.py
  signals.py

wallet/
  models.py
  serializers.py
  api_views.py
```

### دور كل طبقة

| الطبقة | الدور |
|---|---|
| Models | تعريف الجداول والعلاقات |
| Serializers | تحويل البيانات من وإلى JSON |
| API Views | استقبال طلبات REST API |
| Services | منطق الأعمال والعمليات الحساسة |
| Selectors | استعلامات القراءة المنظمة |
| QuerySets | فلاتر مخصصة مثل `for_cafe` |
| Backoffice Views | صفحات ولوحات الإدارة |
| Consumers | WebSocket consumers |
| Routing | مسارات WebSocket |

---

## 13. قاعدة البيانات

### قاعدة البيانات الحالية

| العنصر | القيمة |
|---|---|
| النوع | SQLite |
| الاستخدام | تطوير محلي |
| المسار | `bitehub_tripoli.sqlite3` |

### قاعدة البيانات المخطط لها للإنتاج

| العنصر | التقنية |
|---|---|
| DBMS | PostgreSQL |
| Driver | psycopg 3.2.9 |
| الربط | `DATABASE_URL` |
| عزل أقوى مستقبلا | PostgreSQL Row-Level Security |

### أهم الموديلات

| الموديل | الدور |
|---|---|
| `User` | المستخدم المخصص |
| `Faculty` | كلية/جهة تنظيمية |
| `Cafe` | مقهى |
| `Category` | تصنيف منتجات |
| `Product` | منتج غذائي |
| `Order` | طلب |
| `OrderItem` | عنصر داخل طلب |
| `Wallet` | محفظة المستخدم |
| `Transaction` | معاملة مالية |

---

## 14. نظام المستخدمين

المشروع يستخدم User مخصص بدلا من User الافتراضي.

المعرف الأساسي:

```python
USERNAME_FIELD = "email"
```

الحقول المهمة:

- `email`
- `phone_number`
- `secondary_phone_number`
- `full_name`
- `image`
- `profile_image_url`

طرق الدخول المدعومة في API:

- رقم الهاتف الأساسي.
- الرقم الإضافي.
- البريد الإلكتروني.

---

## 15. نظام الطلبات

### حالات الطلب

| الحالة | المعنى |
|---|---|
| `PENDING` | قيد الانتظار |
| `ACCEPTED` | تم القبول |
| `PREPARING` | قيد التحضير |
| `READY` | جاهز |
| `COMPLETED` | مكتمل |
| `CANCELLED` | ملغى |

### انتقالات الحالة المسموحة

```text
PENDING   -> ACCEPTED, CANCELLED
ACCEPTED  -> PREPARING, CANCELLED
PREPARING -> READY, CANCELLED
READY     -> COMPLETED, CANCELLED
COMPLETED -> لا انتقالات
CANCELLED -> لا انتقالات
```

### منطق الطلبات

يتم تنفيذ منطق إنشاء الطلب داخل:

```text
core/services.py
```

ويشمل:

- التحقق من المنتجات.
- التأكد أن المنتجات تتبع نفس المقهى.
- التحقق من توفر المنتج.
- حساب السعر من السيرفر.
- مقارنة السعر المرسل من العميل بالسعر المحسوب.
- خصم المحفظة إن كانت طريقة الدفع Wallet.
- إنشاء `Order`.
- إنشاء `OrderItem`.
- بث WebSocket event.

---

## 16. نظام المحفظة

### الموديلات

```text
Wallet
Transaction
```

### أنواع المعاملات

| النوع | المعنى |
|---|---|
| `DEPOSIT` | إيداع |
| `WITHDRAWAL` | سحب/خصم |

### مصادر المعاملات

| المصدر | المعنى |
|---|---|
| `SYSTEM` | عملية من النظام |
| `APP` | عملية من التطبيق |

### حماية الرصيد

يستخدم النظام:

```python
transaction.atomic()
select_for_update()
```

لمنع مشاكل التزامن عند الخصم أو الإيداع.

### عمليات المحفظة

- عرض المحفظة.
- ربط المحفظة بكود.
- شحن المحفظة من staff/admin.
- تحويل رصيد.
- سحب/خصم.
- استرجاع مبلغ الطلب عند الإلغاء.

---

## 17. REST API

Base URL الافتراضي:

```text
http://127.0.0.1:8000
```

في Flutter يمكن تغييره عبر:

```text
BITE_HUB_API_BASE_URL
```

### App API

| Method | Endpoint | الاستخدام |
|---|---|---|
| POST | `/api/v2/app/auth/login/` | تسجيل الدخول |
| POST | `/api/v2/app/auth/signup/` | إنشاء حساب |
| POST | `/api/v2/app/auth/refresh/` | تحديث JWT |
| GET/PATCH | `/api/v2/app/user/` | بيانات المستخدم |
| POST | `/api/v2/app/user/secondary-phone/` | تحديث الرقم الإضافي |
| GET | `/api/v2/app/cafes/` | قائمة المقاهي |
| GET | `/api/v2/app/products/` | قائمة المنتجات |
| GET/POST | `/api/v2/app/orders/` | عرض أو إنشاء طلب |
| POST | `/api/v2/app/orders/create/` | مسار قديم متوافق، deprecated |
| POST/PATCH | `/api/v2/app/orders/<order_id>/cancel/` | إلغاء طلب |
| GET | `/api/v2/app/wallet/` | عرض المحفظة |
| POST | `/api/v2/app/wallet/link/` | ربط محفظة |
| POST | `/api/v2/app/wallet/topup/` | شحن محفظة |
| POST | `/api/v2/app/wallet/transfer/` | تحويل رصيد |
| POST | `/api/v2/app/wallet/withdraw/` | سحب/خصم |

### Cafe API

| Method | Endpoint | الاستخدام |
|---|---|---|
| POST | `/api/v2/cafe/orders/<order_id>/status/` | تحديث حالة طلب |
| POST | `/api/v2/cafe/products/<product_id>/availability/` | تغيير توفر منتج |

### Admin API

| Method | Endpoint | الاستخدام |
|---|---|---|
| POST | `/api/v2/admin/cafes/create/` | إنشاء مقهى |
| POST | `/api/v2/admin/cafes/<cafe_id>/toggle/` | تفعيل/تعطيل مقهى |

### API Documentation

تم تجهيز:

| Endpoint | الاستخدام |
|---|---|
| `/api/schema/` | OpenAPI schema |
| `/api/docs/` | Swagger UI |
| `/api/redoc/` | Redoc |

التقنية:

```text
drf-spectacular 0.28.0
```

---

## 18. WebSocket / Real-time

التقنية:

- Django Channels 4.2.0
- ASGI
- `web_socket_channel` في Flutter

مسار WebSocket:

```text
ws://127.0.0.1:8000/ws/cafe/<cafe_id>/orders/
```

مع HTTPS:

```text
wss://domain/ws/cafe/<cafe_id>/orders/
```

كل مقهى له group خاص:

```text
cafe_orders_<cafe_id>
```

الأحداث:

| الحدث | متى يحدث |
|---|---|
| `order.created` | عند إنشاء طلب |
| `order.updated` | عند تحديث حالة الطلب أو إلغائه |

---

## 19. المصادقة والأمان

### Backend Authentication

التقنيات:

- JWT عبر `djangorestframework-simplejwt`.
- Session Authentication للوحات Django.

إعدادات DRF:

- `JWTAuthentication`
- `SessionAuthentication`

### Frontend Token Storage

التقنية الحالية:

```text
flutter_secure_storage 9.2.4
```

الاستخدام:

- حفظ access token.
- حفظ refresh token.
- نقل التوكنات القديمة من SharedPreferences تلقائيا.

### CORS و CSRF

تم تجهيز الإعدادات عبر env:

- `DJANGO_CORS_ALLOW_ALL_ORIGINS`
- `DJANGO_CORS_ALLOWED_ORIGINS`
- `DJANGO_CSRF_TRUSTED_ORIGINS`

### متغيرات البيئة

ملف المثال:

```text
bitehub_backend_workspace/bitehub_backend_workspace/.env.example
```

أهم المتغيرات:

- `DJANGO_SECRET_KEY`
- `DJANGO_DEBUG`
- `DJANGO_ALLOWED_HOSTS`
- `DATABASE_URL`
- `REDIS_URL`
- `SENTRY_DSN`

---

## 20. الواجهات الإدارية Web Dashboard

### التقنيات

| التقنية | الاستخدام |
|---|---|
| Django Templates | توليد صفحات HTML |
| CSS | تنسيق لوحات الإدارة |
| JavaScript | التفاعل داخل اللوحات |
| Django Sessions | جلسات تسجيل الدخول |
| Django Auth | صلاحيات الدخول |

### ملفات Static

```text
static/css/
static/js/
static/admin_v2/
```

ملفات مهمة:

- `static/admin_v2/super_admin_dashboard.js`
- `static/admin_v2/cafe_panel.js`
- `static/css/dashboard.css`
- `static/css/orders.css`
- `static/css/products.css`
- `static/css/reports.css`

### Node.js

يوجد ملف:

```text
bitehub_backend_workspace/package-lock.json
```

لكنه لا يحتوي حزم Node فعلية حاليا:

```json
"packages": {}
```

أي أن لوحة الإدارة الحالية لا تعتمد على npm packages مثبتة.

---

## 21. الصور والملفات

### Flutter Assets

```text
assets/images/
assets/lottie/
assets/fonts/
```

الخط المستخدم:

```text
Tajawal
```

### Django Media

الإعدادات:

```python
MEDIA_URL = "/media/"
MEDIA_ROOT = BASE_DIR / "media"
```

الصور المستخدمة:

- صور المقاهي.
- صور المنتجات.
- صور الملف الشخصي.

### التطوير المستقبلي

يوصى بالانتقال إلى:

- S3-Compatible Object Storage.
- Cloudflare R2 أو AWS S3 أو DigitalOcean Spaces.
- Celery لمعالجة الصور.

---

## 22. المراقبة والتتبع

### Sentry

الحزمة:

```text
sentry-sdk[django] 2.18.0
```

الاستخدام:

- تتبع أخطاء Django.
- إرسال stack traces.
- دعم بيئات متعددة عبر `SENTRY_ENVIRONMENT`.

### Firebase

الحزم:

- `firebase_admin 7.1.0`
- `google-cloud-firestore 2.21.0`
- `google-cloud-storage 3.6.0`

الاستخدام الحالي:

- تهيئة Firebase Admin إذا توفر `serviceAccountKey.json`.
- Firestore client اختياري.
- إشعارات فعلية مهيأة بشكل مشروط.

---

## 23. الأداء

### تقنيات مستخدمة حاليا

- `select_related`
- `prefetch_related`
- `Prefetch`
- فهارس DB indexes.
- `LocMemCache`
- Cache للمنتجات.

### أهم الفهارس

على مستوى الموديلات:

- `(faculty, is_active)`
- `(cafe, is_active)`
- `(cafe, category)`
- `(cafe, is_available)`
- `(cafe, created_at)`
- `(cafe, status)`
- `(user, created_at)`

### مخطط لاحق

- Redis Cache.
- PostgreSQL.
- Redis Channel Layer للـ WebSocket.

---

## 24. الاختبارات والتحقق

### Backend Tests

موجودة في:

- `core/tests.py`
- `wallet/tests.py`
- `users/tests.py`

تم تشغيل:

```text
python manage.py test core wallet users
```

النتيجة الحالية:

```text
16 tests OK
```

### Flutter Analysis

تم تشغيل:

```text
flutter analyze
```

النتيجة:

```text
No issues found
```

---

## 25. التقنيات المخطط لها أو الجاهزة جزئيا

| التقنية | الحالة | الهدف |
|---|---|---|
| PostgreSQL | مدعوم عبر `DATABASE_URL` | قاعدة إنتاج |
| Redis | موجود كإعداد `REDIS_URL` | Cache و Channel Layer |
| drf-spectacular | مضاف | توثيق API |
| Sentry | مهيأ | مراقبة الأخطاء |
| Firebase | مهيأ جزئيا | إشعارات/Firestore |
| Object Storage | مخطط | تخزين الصور |
| Celery | مخطط | مهام خلفية |
| Docker | مخطط | نشر وتشغيل |
| PostgreSQL RLS | مخطط | عزل أقوى للبيانات |

---

## 26. أهم القرارات المعمارية

### REST API كأساس

REST مناسب للمشروع لأن العمليات واضحة:

- Users
- Cafes
- Products
- Orders
- Wallet
- Admin Actions

### WebSocket فقط للحظي

WebSocket مستخدم في المكان الصحيح:

- تحديثات الطلب.
- لوحة المقهى الحية.
- تتبع الطلب في التطبيق.

### عدم استخدام GraphQL حاليا

GraphQL غير ضروري في المرحلة الحالية لأنه سيزيد التعقيد بدون فائدة واضحة. REST + WebSocket كافيان وأوضح للفريق.

### Multi-Tenant Monolith

النظام Monolith منظم وليس Microservices. هذا أفضل حاليا لأن:

- حجم المشروع مناسب.
- البيانات مترابطة.
- التطوير أسرع.
- الاختبار أسهل.
- النشر أبسط.

---

## 27. توصيات فنية قبل الإنتاج

1. استخدام Python إصدار مستقر بدلا من `3.14.0a7`.
2. الانتقال إلى PostgreSQL.
3. تفعيل Redis للإنتاج.
4. ضبط `DJANGO_DEBUG=False`.
5. ضبط `DJANGO_ALLOWED_HOSTS`.
6. إغلاق CORS العام.
7. استخدام HTTPS.
8. ضبط Sentry DSN.
9. عدم استخدام debug signing في Android release.
10. نقل الصور إلى Object Storage.
11. إضافة CI لتشغيل:
    - Django tests.
    - Flutter analyze.
    - Flutter test.
12. تنظيف النصوص العربية المشوهة encoding داخل بعض الملفات.

---

## 28. الخلاصة

منظومة Bite Hub مبنية بتقنيات مناسبة لمشروع طلبات أكل جامعي:

- Flutter لتطبيق المستخدم.
- Django + DRF للـ Backend.
- REST API للعمليات الأساسية.
- WebSocket للتحديثات الحية.
- Django Templates للوحات الإدارة.
- Multi-Tenancy عبر `cafe_id`.
- Wallet داخلي مع معاملات محمية.

المعمارية الحالية عملية وقابلة للتطوير. أفضل مسار مستقبلي هو تثبيت الإنتاج عبر PostgreSQL و Redis و Sentry و Object Storage، مع الاستمرار على REST API وعدم الانتقال إلى GraphQL في هذه المرحلة.
---

## 29. تحديث فني إضافي بتاريخ 2026-05-09

### إدارة المنتجات من لوحة المقهى

تمت إضافة سيناريو كامل لإدارة المنتج من لوحة المقهى:

- إنشاء منتج جديد من `Cafe Panel`.
- تعديل منتج موجود من نفس اللوحة.
- رفع صورة المنتج عبر `multipart/form-data`.
- تحديد السعر الحالي `price`.
- تحديد السعر قبل التخفيض `original_price`.
- حساب حالة التخفيض تلقائيا عبر `has_discount`.
- حساب نسبة التخفيض تلقائيا عبر `discount_percentage`.
- تحديد توفر المنتج `is_available`.
- تفريغ كاش المنتجات بعد إنشاء/تعديل/تغيير توفر المنتج حتى تظهر البيانات الصحيحة في التطبيق.

### API المنتجات والتوفر والتخفيض

المنتج في App API يرجع الآن الحقول التالية:

```json
{
  "price": "8.00",
  "original_price": "10.00",
  "has_discount": true,
  "discount_percentage": 20,
  "is_available": true,
  "image_url": "/media/products/example.jpg"
}
```

تطبيق Flutter يقرأ هذه الحقول داخل `ProductModel` ويعرض السعر الحالي، السعر القديم مشطوبا عند وجود تخفيض، شارة بنسبة التخفيض، وحالة توفر المنتج.

### مسارات لوحة المقهى الجديدة

| Method | Endpoint | الاستخدام |
|---|---|---|
| POST | `/hub/cafe-panel/products/create/` | إنشاء منتج من لوحة المقهى |
| POST | `/hub/cafe-panel/products/<product_id>/save/` | تعديل منتج من لوحة المقهى |
| POST | `/hub/cafe-panel/products/<product_id>/availability/` | تغيير توفر المنتج |

### سيناريو المحفظة وشحن الرصيد

المحفظة تدعم الآن:

- عرض الرصيد وسجل العمليات من شاشة المستخدم.
- خصم مبلغ من شاشة المستخدم عبر `/api/v2/app/wallet/withdraw/`.
- تحويل رصيد لمحفظة أخرى عبر `/api/v2/app/wallet/transfer/`.
- شحن رصيد المستخدم من شاشة المحفظة عبر `/api/v2/app/wallet/topup/` بشرط تفعيل `WALLET_APP_TOPUP_ENABLED`.

تنبيه أمني مهم: شحن المستخدم لنفسه يجب ألا يكون مفعلا في الإنتاج إلا عند ربط بوابة دفع حقيقية. الإعداد الحالي:

```python
WALLET_APP_TOPUP_ENABLED = DEBUG
```

أي أنه مخصص للتطوير والعروض التجريبية، بينما في الإنتاج يتم إغلاقه افتراضيا عند `DEBUG=False`.

### تحسين عقد API بين التطبيق والمنظومة

- توحيد بناء روابط الصور في Flutter عبر helper واحد.
- تطبيع صور المقاهي والمنتجات وعناصر الطلبات القادمة من API.
- تمرير `request` إلى `OrderSerializer` حتى يرجع `product_image` كرابط كامل عند إنشاء/عرض/إلغاء الطلب.
- إضافة اختبار يثبت أن صورة عنصر الطلب تظهر في رد إنشاء الطلب ورد قائمة الطلبات.
- إضافة زر شحن في شاشة محفظة Flutter مع استدعاء `/api/v2/app/wallet/topup/`.

### اختبارات السيناريوهات الحالية

تمت تغطية السيناريوهات التالية باختبارات:

- إنشاء منتج بصورة وتخفيض من لوحة المقهى.
- ظهور السعر والتخفيض والصورة في App API.
- إنشاء طلب يعتمد على السعر الحالي بعد التخفيض.
- رجوع صورة عنصر الطلب كرابط media كامل.
- تغيير توفر المنتج وتفريغ كاش المنتجات.
- رفض إنشاء طلب على منتج غير متوفر قبل خصم المحفظة.
- شحن الرصيد عند تفعيل `WALLET_APP_TOPUP_ENABLED`.
- رفض الشحن الذاتي عند تعطيل `WALLET_APP_TOPUP_ENABLED`.
- خصم الرصيد.
- تحويل الرصيد.
- منع التحويل بدون رصيد.
- منع إعادة حفظ المستخدم من تغيير رصيد المحفظة.

آخر تحقق يتم اعتماده:

```text
python manage.py check
python manage.py test core wallet users
flutter analyze
```
 ############################################################################################################################################################################################################
