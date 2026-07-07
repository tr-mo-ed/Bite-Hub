import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:bitehub_app/app/core/theme/app_theme.dart';
import 'package:bitehub_app/app/data/models/college_model.dart';
import 'package:bitehub_app/app/data/models/order_model.dart';
import 'package:bitehub_app/app/data/models/product_model.dart';
import 'package:bitehub_app/app/data/models/transaction_model.dart';
import 'package:bitehub_app/app/data/models/user_model.dart';
import 'package:bitehub_app/app/data/models/wallet_model.dart';
import 'package:bitehub_app/app/data/providers/auth_provider.dart';
import 'package:bitehub_app/app/data/providers/cart_provider.dart';
import 'package:bitehub_app/app/data/providers/locale_provider.dart';
import 'package:bitehub_app/app/data/providers/navigation_provider.dart';
import 'package:bitehub_app/app/data/services/api_service.dart';
import 'package:bitehub_app/app/presentation_v2/controllers/home_v2_controller.dart';
import 'package:bitehub_app/app/presentation_v2/controllers/live_order_controller.dart';
import 'package:bitehub_app/app/presentation_v2/controllers/profile_v2_controller.dart';
import 'package:bitehub_app/app/presentation_v2/screens/home/home_screen_v2.dart';
import 'package:bitehub_app/app/presentation_v2/screens/legal/usage_policy_screen.dart';
import 'package:bitehub_app/app/presentation_v2/screens/orders/live_order_tracking_screen_v2.dart';
import 'package:bitehub_app/app/presentation_v2/screens/profile/profile_screen_v2.dart';
import 'package:bitehub_app/app/presentation_v2/widgets/custom_floating_snack_bar.dart';
import 'package:bitehub_app/app/presentation_v2/widgets/order_status_ui.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('redesigned home screen has no overflow', (tester) async {
    await _setPhoneViewport(tester);
    final cafes = [
      CollegeModel(
        id: '1',
        name: 'مقهى تقنية المعلومات',
        image: '',
      ),
      CollegeModel(
        id: '2',
        name: 'مقهى كلية الطب',
        image: '',
      ),
      CollegeModel(
        id: '3',
        name: 'مقهى الاقتصاد',
        image: '',
      ),
    ];
    final controller = HomeV2Controller()
      ..seedPreview(
        cafes: cafes,
        selectedCafe: cafes.first,
        products: [
          _product(
            id: '1',
            name: 'برغر دجاج',
            category: 'وجبات',
            price: 12,
            imageVariant: 1,
          ),
          _product(
            id: '2',
            name: 'بيتزا خضار',
            category: 'بيتزا',
            price: 15,
            originalPrice: 18,
            imageVariant: 2,
          ),
          _product(
            id: '3',
            name: 'قهوة أمريكية',
            category: 'مشروبات ساخنة',
            price: 6,
            imageVariant: 0,
          ),
          _product(
            id: '4',
            name: 'عصير برتقال',
            category: 'مشروبات',
            price: 5,
            imageVariant: 3,
          ),
        ],
      );

    await tester.pumpWidget(
      ChangeNotifierProvider(
        create: (_) => CartProvider(),
        child: Builder(
          builder: (context) => MaterialApp(
            debugShowCheckedModeBanner: false,
            theme: AppTheme.light(context),
            home: Directionality(
              textDirection: TextDirection.rtl,
              child: Scaffold(
                appBar: AppBar(title: const Text('Bite Hub')),
                body: HomeScreenV2(
                  controller: controller,
                  initializeController: false,
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    await tester.drag(find.byType(CustomScrollView), const Offset(0, -520));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });

  testWidgets('redesigned live tracking screen has no overflow',
      (tester) async {
    await _setPhoneViewport(tester);
    final order = OrderModel(
      id: 31,
      orderNumber: '4831',
      totalPrice: 33,
      status: 'PREPARING',
      createdAt: DateTime(2026, 6, 12, 12, 30).toIso8601String(),
      cafeId: '1',
      cafeName: 'مقهى تقنية المعلومات',
      cafeLogo: '',
      items: [
        OrderItem(
          productId: 1,
          productName: 'برغر دجاج',
          quantity: 2,
          price: 12,
          productImage: '',
        ),
        OrderItem(
          productId: 2,
          productName: 'عصير برتقال',
          quantity: 1,
          price: 5,
          productImage: '',
        ),
      ],
    );
    final controller = LiveOrderController()..seedPreview(order);

    await tester.pumpWidget(
      Builder(
        builder: (context) => MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: AppTheme.light(context),
          home: Directionality(
            textDirection: TextDirection.rtl,
            child: LiveOrderTrackingScreenV2(
              initialOrder: order,
              initialOrderId: order.id,
              controller: controller,
              initializeController: false,
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    await tester.drag(find.byType(ListView), const Offset(0, -620));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });

  testWidgets('profile screen uses compact account layout without overflow',
      (tester) async {
    await _setPhoneViewport(tester);
    final authProvider = AuthProvider();
    final controller = ProfileV2Controller(authProvider: authProvider)
      ..seedPreview(
        user: User(
          id: 7,
          fullName: 'محمد صلاح الترهوني',
          email: 'student@bitehub.ly',
          phoneNumber: '0912345678',
        ),
        wallet: WalletModel(
          id: 4,
          balance: 280,
          currency: 'د.ل',
          college: 'كلية اللغة العربية',
          linkCode: '',
          userFullName: 'محمد صلاح الترهوني',
          transactions: const <TransactionModel>[],
        ),
      );

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<AuthProvider>.value(value: authProvider),
          ChangeNotifierProvider(create: (_) => LocaleProvider()),
          ChangeNotifierProvider(create: (_) => NavigationProvider()),
        ],
        child: Builder(
          builder: (context) => MaterialApp(
            debugShowCheckedModeBanner: false,
            theme: AppTheme.light(context),
            home: Directionality(
              textDirection: TextDirection.rtl,
              child: Scaffold(
                appBar: AppBar(title: const Text('حسابي')),
                body: ProfileScreenV2(
                  controller: controller,
                  initializeController: false,
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('سياسة الاستخدام والإلغاء'), findsOneWidget);
    expect(find.text('كود المحفظة'), findsNothing);
    expect(find.text('تحديث البيانات'), findsNothing);
    expect(tester.takeException(), isNull);
    await tester.drag(find.byType(ListView), const Offset(0, -700));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    await tester.pump(const Duration(seconds: 5));
    controller.dispose();
    authProvider.dispose();
  });

  testWidgets('usage policy is readable on a phone viewport', (tester) async {
    await _setPhoneViewport(tester);

    await tester.pumpWidget(
      Builder(
        builder: (context) => MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: AppTheme.light(context),
          home: const Directionality(
            textDirection: TextDirection.rtl,
            child: UsagePolicyScreen(),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.scrollUntilVisible(
      find.text('إلغاء الطلب'),
      300,
      scrollable: find.byType(Scrollable).last,
    );
    expect(find.text('إلغاء الطلب'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.text('استرداد الرصيد'),
      220,
      scrollable: find.byType(Scrollable).last,
    );
    expect(find.text('استرداد الرصيد'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.drag(find.byType(ListView), const Offset(0, -900));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });

  testWidgets('accepted order explains why self cancellation is unavailable',
      (tester) async {
    await _setPhoneViewport(tester);
    final order = OrderModel(
      id: 45,
      orderNumber: 'BH-123456',
      totalPrice: 20,
      status: 'ACCEPTED',
      paymentMethod: 'WALLET',
      createdAt: DateTime(2026, 6, 14, 10).toIso8601String(),
      items: const [],
    );
    final controller = LiveOrderController()..seedPreview(order);

    await tester.pumpWidget(
      Builder(
        builder: (context) => MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: AppTheme.light(context),
          home: Directionality(
            textDirection: TextDirection.rtl,
            child: LiveOrderTrackingScreenV2(
              initialOrder: order,
              controller: controller,
              initializeController: false,
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.scrollUntilVisible(
      find.text('بدأ المقهى تنفيذ الطلب'),
      280,
      scrollable: find.byType(Scrollable).last,
    );
    expect(find.text('بدأ المقهى تنفيذ الطلب'), findsOneWidget);
    expect(find.text('إلغاء الطلب'), findsNothing);
    expect(find.text('عرض السياسة كاملة'), findsOneWidget);
    expect(tester.takeException(), isNull);
    controller.dispose();
  });

  testWidgets('notification banner uses the Bite Hub identity', (tester) async {
    await _setPhoneViewport(tester);

    await tester.pumpWidget(
      Builder(
        builder: (context) => MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: AppTheme.light(context),
          home: Builder(
            builder: (context) => Scaffold(
              body: Center(
                child: FilledButton(
                  onPressed: () {
                    CustomFloatingSnackBar.show(
                      context,
                      title: 'طلبك جاهز',
                      message: 'توجه إلى نقطة الاستلام.',
                      duration: const Duration(seconds: 30),
                    );
                  },
                  child: const Text('عرض الإشعار'),
                ),
              ),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('عرض الإشعار'));
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.text('Bite Hub'), findsOneWidget);
    expect(find.text('طلبك جاهز'), findsOneWidget);
    expect(
      find.image(
        const AssetImage('assets/images/bitehub_app_icon.png'),
      ),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
    await tester.pump(const Duration(seconds: 31));
  });

  test('order tracking statuses keep a stable sequence', () {
    expect(BhOrderStatusSpec.fromStatus('PENDING').trackingIndex, 0);
    expect(BhOrderStatusSpec.fromStatus('ACCEPTED').trackingIndex, 1);
    expect(BhOrderStatusSpec.fromStatus('PREPARING').trackingIndex, 2);
    expect(BhOrderStatusSpec.fromStatus('READY').trackingIndex, 3);
    expect(BhOrderStatusSpec.fromStatus('COMPLETED').trackingIndex, 4);
    expect(BhOrderStatusSpec.fromStatus('CANCELLED').trackingIndex, -1);
    expect(BhOrderStatusSpec.fromStatus('CANCELLED').isCancelled, isTrue);
  });

  test('live tracking never switches to a different order', () async {
    final tracked = OrderModel(
      id: 31,
      orderNumber: '4831',
      totalPrice: 12,
      status: 'PREPARING',
      createdAt: DateTime(2026, 6, 12).toIso8601String(),
      items: const [],
    );
    final unrelated = OrderModel(
      id: 99,
      orderNumber: '9999',
      totalPrice: 20,
      status: 'READY',
      createdAt: DateTime(2026, 6, 12).toIso8601String(),
      items: const [],
    );
    final controller = LiveOrderController(
      apiService: _FakeOrdersApi([unrelated]),
    )..seedPreview(tracked);

    await controller.refresh(orderId: tracked.id, silent: true);

    expect(controller.trackedOrder?.id, tracked.id);
    controller.dispose();
  });
}

Future<void> _setPhoneViewport(WidgetTester tester) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = const Size(390, 844);
  addTearDown(tester.view.reset);
}

ProductModel _product({
  required String id,
  required String name,
  required String category,
  required double price,
  double? originalPrice,
  int? imageVariant,
}) {
  return ProductModel(
    id: id,
    name: name,
    price: price,
    originalPrice: originalPrice,
    hasDiscount: originalPrice != null,
    discountPercentage: originalPrice == null
        ? 0
        : (((originalPrice - price) / originalPrice) * 100).round(),
    imageUrl: '',
    description: 'وصف مختصر للمنتج',
    category: category,
    categoryId: category,
    collegeId: '1',
    collegeName: 'مقهى تقنية المعلومات',
    cafeId: '1',
    cafeName: 'مقهى تقنية المعلومات',
    imageVariant: imageVariant,
    isAvailable: true,
    rating: 4.7,
    ratingCount: 24,
  );
}

class _FakeOrdersApi extends ApiService {
  _FakeOrdersApi(this.orders);

  final List<OrderModel> orders;

  @override
  Future<List<OrderModel>> getOrders() async => orders;
}
