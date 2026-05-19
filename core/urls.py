from django.urls import path
from . import backoffice_views

# ??? ??????? app_name ??? ????? ??? ???? ???? ???? ????? ????.
app_name = 'core'

# ??? ??????? urlpatterns ??? ????? ??? ???? ???? ???? ????? ????.
urlpatterns = [
    # Auth + V2 entry
    path('login/', backoffice_views.custom_login, {"portal": "admin"}, name='login'),
    path('admin/login/', backoffice_views.custom_login, {"portal": "admin"}, name='admin_login'),
    path('cafe/login/', backoffice_views.custom_login, {"portal": "cafe"}, name='cafe_login'),
    path('cafe/<slug:cafe_code>/login/', backoffice_views.custom_login, {"portal": "cafe"}, name='cafe_login_for_code'),
    path('logout/', backoffice_views.custom_logout, name='logout'),
    path('switch-cafe/<int:cafe_id>/', backoffice_views.switch_cafe, name='switch_cafe'),
    path('', backoffice_views.route_after_login, name='route_after_login'),

    # Backoffice V2
    path('super-admin/', backoffice_views.super_admin_dashboard, name='super_admin_dashboard'),
    path('super-admin/cafes/create/', backoffice_views.create_cafe_from_dashboard, name='create_cafe_from_dashboard'),
    path('super-admin/cafes/<int:cafe_id>/toggle/', backoffice_views.toggle_cafe_status_from_dashboard, name='toggle_cafe_status_from_dashboard'),
    path('super-admin/cafes/<int:cafe_id>/password/', backoffice_views.reset_cafe_password_from_dashboard, name='reset_cafe_password_from_dashboard'),
    path('cafe-panel/', backoffice_views.cafe_panel, name='cafe_panel'),
    path('cafe-panel/snapshot/', backoffice_views.cafe_panel_snapshot_api, name='cafe_panel_snapshot_api'),
    path('cafe-panel/orders/<int:order_id>/status/', backoffice_views.update_order_status_api, name='update_order_status_api'),
    path('cafe-panel/wallets/operate/', backoffice_views.cafe_wallet_operation_api, name='cafe_wallet_operation_api'),
    path('cafe-panel/wallets/bind-card/', backoffice_views.cafe_bind_wallet_card_api, name='cafe_bind_wallet_card_api'),
    path('cafe-panel/products/create/', backoffice_views.save_product_api, name='create_product_api'),
    path('cafe-panel/products/<int:product_id>/save/', backoffice_views.save_product_api, name='save_product_api'),
    path('cafe-panel/products/<int:product_id>/availability/', backoffice_views.toggle_product_stock_api, name='toggle_product_stock_api'),

    # Manifest
    path('manifest.json', backoffice_views.manifest, name='manifest'),
]
