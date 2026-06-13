# مرجع الذكاء الاصطناعي لتعديل مشروع Bite Hub

هذا الملف مكتوب ليكون نقطة البداية لأي ذكاء اصطناعي أو مطور يريد تعديل مشروع **Bite Hub** بسرعة وبدون تخمين. اقرأ هذا الملف قبل تعديل الكود، ثم افتح الملفات المشار إليها حسب نوع المهمة.

## فائدة هذا الملف

- يشرح فكرة المنظومة وأجزائها الرئيسية.
- يحدد أماكن الملفات التي غالبا تحتاج تعديل.
- يوضح مسارات API التي تربط تطبيق Flutter مع Backend.
- يقلل أخطاء التعديل العشوائي، خصوصا في الطلبات، المحفظة، عزل المقاهي، وتسجيل الدخول.
- يعطي قواعد عمل لأي AI حتى يحافظ على بنية المشروع ولا يكسر أجزاء أخرى.

## نظرة عامة على المنظومة

**Bite Hub** منظومة طلبات أكل داخل بيئة جامعية أو متعددة المقاهي. المشروع مقسوم إلى:

- `bitehub_app`: تطبيق Flutter للمستخدم النهائي.
- `bitehub_backend_workspace/bitehub_backend_workspace`: Backend مبني بـ Django و Django REST Framework.
- لوحة ويب داخل Django لإدارة المنظومة والمقاهي.
- WebSocket مهيأ لتحديثات الطلبات الحية.
- نظام محفظة داخلي للدفع، الشحن، السحب، والتحويل.

الاتجاه العام للواجهة عربي و RTL، والخط الأساسي هو `Tajawal`.

## أهم المسارات

| الجزء | المسار |
|---|---|
| تطبيق Flutter | `bitehub_app/` |
| نقطة تشغيل Flutter | `bitehub_app/lib/main.dart` |
| خدمة الاتصال بالـ API | `bitehub_app/lib/app/data/services/api_service.dart` |
| Models في Flutter | `bitehub_app/lib/app/data/models/` |
| Providers في Flutter | `bitehub_app/lib/app/data/providers/` |
| شاشات Flutter الحديثة | `bitehub_app/lib/app/presentation_v2/` |
| Widgets وتصميم V2 | `bitehub_app/lib/app/presentation_v2/widgets/` |
| Backend Django | `bitehub_backend_workspace/bitehub_backend_workspace/` |
| إعدادات Django | `bitehub_backend_workspace/bitehub_backend_workspace/bitehub_backend/settings.py` |
| مسارات Django الرئيسية | `bitehub_backend_workspace/bitehub_backend_workspace/bitehub_backend/urls.py` |
| Models الأساسية | `bitehub_backend_workspace/bitehub_backend_workspace/core/models.py` |
| API التطبيق | `bitehub_backend_workspace/bitehub_backend_workspace/core/api_views.py` |
| مسارات API التطبيق | `bitehub_backend_workspace/bitehub_backend_workspace/core/api_v2_app_urls.py` |
| منطق الأعمال | `bitehub_backend_workspace/bitehub_backend_workspace/core/services.py` |
| استعلامات القراءة | `bitehub_backend_workspace/bitehub_backend_workspace/core/selectors.py` |
| لوحة الإدارة والمقهى | `bitehub_backend_workspace/bitehub_backend_workspace/core/backoffice_views.py` |
| المستخدمون | `bitehub_backend_workspace/bitehub_backend_workspace/users/` |
| المحفظة | `bitehub_backend_workspace/bitehub_backend_workspace/wallet/` |

## تشغيل المشروع أثناء التطوير

### Backend

من داخل:

```powershell
cd bitehub_backend_workspace\bitehub_backend_workspace
```

الأوامر المتوقعة:

```powershell
pip install -r requirements.txt
python manage.py migrate
python manage.py runserver
```

قاعدة البيانات الافتراضية في التطوير هي SQLite:

```text
bitehub_tripoli.sqlite3
```

ويمكن تغييرها عبر `DATABASE_URL`.

### Flutter

من داخل:

```powershell
cd bitehub_app
```

الأوامر المتوقعة:

```powershell
flutter pub get
flutter run --dart-define=BITE_HUB_API_BASE_URL=http://127.0.0.1:8000
```

إن لم يتم تمرير `BITE_HUB_API_BASE_URL` فالتطبيق يستخدم القيمة الافتراضية الموجودة في `ApiService`:

```text
https://fooood.pythonanywhere.com
```

لبناء APK بسرعة يوجد:

```powershell
.\build_apk_fast.ps1
```

أو:

```powershell
.\bitehub_app\scripts\build_apk_fast.ps1
```

## معمارية Flutter

`main.dart` يشغل التطبيق ويعرف `MultiProvider`. أهم الـ Providers:

- `AuthProvider`: تسجيل الدخول والخروج وحالة المستخدم.
- `WalletProvider`: المحفظة والرصيد.
- `CartProvider`: السلة.
- `ProductProvider`: المنتجات.
- `CollegeProvider`: المقاهي أو الكليات.
- `FavoritesProvider`: المفضلة.
- `NotificationProvider`: الإشعارات.
- `ThemeProvider`: الثيم الفاتح والداكن.
- `ProfileImageProvider`: صورة الملف الشخصي.

أهم نقطة ربط مع Backend هي:

```text
bitehub_app/lib/app/data/services/api_service.dart
```

أي تعديل في API غالبا يحتاج تعديلين:

1. Backend endpoint أو serializer.
2. الدالة المقابلة في `ApiService` أو Model في Flutter.

## أهم شاشات Flutter

| الشاشة | المسار |
|---|---|
| الهيكل الرئيسي | `lib/app/presentation_v2/screens/main_shell_v2.dart` |
| الرئيسية | `lib/app/presentation_v2/screens/home/home_screen_v2.dart` |
| السلة | `lib/app/presentation_v2/screens/cart/cart_screen_v2.dart` |
| الطلبات | `lib/app/presentation_v2/screens/orders/orders_screen_v2.dart` |
| تتبع الطلب | `lib/app/presentation_v2/screens/orders/live_order_tracking_screen_v2.dart` |
| المحفظة | `lib/app/presentation_v2/screens/wallet/wallet_screen_v2.dart` |
| الملف الشخصي | `lib/app/presentation_v2/screens/profile/profile_screen_v2.dart` |
| لوحة المقهى داخل التطبيق | `lib/app/presentation_v2/screens/cafe/cafe_dashboard_screen_v2.dart` |
| تسجيل الدخول القديم | `lib/app/presentation/screens/auth/login_screen.dart` |
| إنشاء حساب | `lib/app/presentation/screens/auth/signup_screen.dart` |

## معمارية Backend

تطبيقات Django الأساسية:

- `core`: المقاهي، المنتجات، التصنيفات، الطلبات، الإشعارات، لوحة الإدارة، WebSocket.
- `users`: المستخدم المخصص.
- `wallet`: المحفظة والمعاملات.
- `bitehub_backend`: إعدادات المشروع ومسارات التشغيل.

قواعد مهمة:

- `services.py` لمنطق الأعمال مثل إنشاء الطلب وتحديث حالته.
- `selectors.py` لاستعلامات القراءة وتحسين الأداء.
- `querysets.py` لعزل بيانات المقاهي.
- لا تضع منطق أعمال كبير داخل View إن كان يجب أن يعيش في Service.
- لا تستخدم `.all()` عشوائيا في بيانات مرتبطة بمقهى؛ يجب احترام `cafe_id`.

## الموديلات الأساسية

### Users

`users.User` هو المستخدم المخصص:

- يستخدم `email` كمعرف أساسي.
- يحتوي `phone_number`.
- يحتوي `secondary_phone_number`.
- يحتوي `full_name`.
- يحتوي صورة مرفوعة أو رابط صورة.

### Core

- `Faculty`: مستوى تنظيمي أعلى، مثل كلية.
- `Cafe`: يمثل مقهى، ويرتبط اختياريا بكلية ومالك.
- `CafeScopedModel`: أساس للموديلات المعزولة حسب مقهى.
- `Category`: تصنيف منتجات داخل مقهى.
- `Product`: منتج، سعر، صورة، حالة توفر، كمية مخزون، تقييم.
- `Order`: طلب المستخدم، حالته، طريقة الدفع، الرقم.
- `OrderItem`: عناصر الطلب.
- `Notification`: إشعارات المستخدم.

حالات الطلب:

```text
PENDING
ACCEPTED
PREPARING
READY
COMPLETED
CANCELLED
```

طرق الدفع:

```text
WALLET
CASH
```

### Wallet

- `Wallet`: محفظة لكل طالب مؤهل.
- `Transaction`: إيداع أو خصم.
- يتم استخدام `transaction.atomic` و `select_for_update` لحماية الرصيد من التعارض.
- لا يتم إنشاء محافظ للمشرفين أو أصحاب المقاهي أو المستخدمين الداخليين.

## مسارات API المهمة

المسارات الرئيسية في:

```text
bitehub_backend/urls.py
```

وتتوزع هكذا:

```text
/api/v2/app/
/api/v2/cafe/
/api/v2/admin/
/hub/
```

### API التطبيق

| الغرض | المسار |
|---|---|
| تسجيل الدخول | `POST /api/v2/app/auth/login/` |
| إنشاء حساب | `POST /api/v2/app/auth/signup/` |
| تحديث JWT | `POST /api/v2/app/auth/refresh/` |
| ملف المستخدم | `GET/PATCH/DELETE /api/v2/app/user/` |
| رقم إضافي | `POST /api/v2/app/user/secondary-phone/` |
| المقاهي | `GET /api/v2/app/cafes/` |
| المنتجات | `GET /api/v2/app/products/` |
| الطلبات | `GET/POST /api/v2/app/orders/` |
| إنشاء طلب قديم | `POST /api/v2/app/orders/create/` |
| إلغاء طلب | `PATCH /api/v2/app/orders/<id>/cancel/` |
| الإشعارات | `GET /api/v2/app/notifications/` |
| المحفظة | `/api/v2/app/wallet/` |

### API المحفظة

| الغرض | المسار |
|---|---|
| بيانات المحفظة | `GET /api/v2/app/wallet/` |
| ربط محفظة | `POST /api/v2/app/wallet/link/` |
| شحن | `POST /api/v2/app/wallet/topup/` |
| تحويل | `POST /api/v2/app/wallet/transfer/` |
| سحب | `POST /api/v2/app/wallet/withdraw/` |

### API المقهى والإدارة

| الغرض | المسار |
|---|---|
| تحديث حالة طلب | `POST/PATCH /api/v2/cafe/orders/<id>/status/` |
| تغيير توفر منتج | `POST/PATCH /api/v2/cafe/products/<id>/availability/` |
| إنشاء مقهى | `POST /api/v2/admin/cafes/create/` |
| تفعيل/إيقاف مقهى | `POST/PATCH /api/v2/admin/cafes/<id>/toggle/` |

## قواعد مهمة لأي AI قبل التعديل

1. افحص `git status --short` قبل التعديل حتى لا تلمس تغييرات ليست لك.
2. لا تعدل ملفات Android/iOS/Windows المولدة إلا إذا كانت المهمة تخص المنصة نفسها.
3. حافظ على اللغة العربية و RTL في Flutter.
4. حافظ على خط `Tajawal` والتصميم الموجود في `presentation_v2`.
5. أي تعديل في الطلبات يجب أن يراجع `Order`, `OrderItem`, `services.py`, `selectors.py`, و `ApiService`.
6. أي تعديل في المحفظة يجب أن يحافظ على `transaction.atomic` و `select_for_update`.
7. أي بيانات مرتبطة بمقهى يجب أن تظل معزولة عبر `cafe_id`.
8. عند إضافة Model أو Field في Django، أنشئ Migration ولا تعدل قاعدة البيانات يدويا.
9. عند تغيير Response من Backend، عدل Model أو parsing في Flutter.
10. لا تكسر التوافق مع المسارات القديمة إلا إذا تم تعديل Flutter معها.
11. لا تضع أسرار حقيقية في الكود؛ استخدم Environment Variables.
12. لا تغير اسم التطبيق أو الهوية إلا إذا كان المطلوب صريحا.

## أين تعدل حسب نوع الطلب

| الطلب | ملفات غالبا تحتاجها |
|---|---|
| تعديل واجهة أو شاشة | `bitehub_app/lib/app/presentation_v2/screens/` |
| تعديل Widget مشترك | `bitehub_app/lib/app/presentation_v2/widgets/` |
| تعديل ألوان وثيم | `bitehub_app/lib/app/core/theme/` |
| تعديل طلبات API في التطبيق | `bitehub_app/lib/app/data/services/api_service.dart` |
| تعديل موديل بيانات Flutter | `bitehub_app/lib/app/data/models/` |
| تعديل إدارة حالة Flutter | `bitehub_app/lib/app/data/providers/` |
| إضافة API جديد | `core/api_views.py` وملف urls المناسب |
| تعديل إنشاء الطلب | `core/services.py` و `core/api_views.py` |
| تعديل قائمة الطلبات | `core/selectors.py` و serializers و Flutter orders screen |
| تعديل المنتجات | `core/models.py`, `core/serializers.py`, `core/api_views.py`, `ApiService` |
| تعديل لوحة الإدارة | `templates/admin_v2/`, `static/admin_v2/`, `core/backoffice_views.py` |
| تعديل المحفظة | `wallet/models.py`, `wallet/api_views.py`, `wallet/serializers.py`, `ApiService` |

## اختبارات وفحص بعد التعديل

### Backend

```powershell
cd bitehub_backend_workspace\bitehub_backend_workspace
python manage.py check
python manage.py test
```

### Flutter

```powershell
cd bitehub_app
flutter analyze
flutter test
```

إذا كانت المهمة صغيرة ولا يمكن تشغيل كل الاختبارات، شغل على الأقل الفحص المرتبط بالجزء الذي تم تعديله.

## ملاحظات عن الجودة

- المشروع يحتوي بعض التعليقات العربية الظاهرة بشكل غير صحيح في بعض الملفات بسبب Encoding قديم. لا تكرر هذا النمط في الملفات الجديدة.
- اكتب الملفات الجديدة بترميز UTF-8.
- اجعل أسماء الدوال واضحة.
- لا تضف Abstraction جديد إلا إذا كان يقلل تكرارا حقيقيا.
- حافظ على فصل المسؤوليات بين UI و Provider و Service في Flutter.
- حافظ على فصل المسؤوليات بين View و Serializer و Service و Selector في Django.

## ملخص سريع جدا لأي AI

إذا طلب منك المستخدم تعديل المشروع:

1. اقرأ هذا الملف.
2. حدد هل التعديل Flutter أو Backend أو الاثنين.
3. افتح المسارات المذكورة في جدول "أين تعدل حسب نوع الطلب".
4. نفذ تعديل محدود.
5. شغل الفحص المناسب.
6. اذكر للمستخدم الملفات التي تغيرت وما الذي تم التحقق منه.

