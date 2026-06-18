from django.urls import include, path
from rest_framework_simplejwt.views import TokenRefreshView

from . import api_views


# ??? ??????? urlpatterns ??? ????? ??? ???? ???? ???? ????? ????.
urlpatterns = [
    path("auth/login/", api_views.api_login, name="v2_app_login"),
    path(
        "auth/email-code/request/",
        api_views.request_email_login_code,
        name="v2_app_email_code_request",
    ),
    path(
        "auth/email-code/verify/",
        api_views.verify_email_login_code,
        name="v2_app_email_code_verify",
    ),
    path("auth/signup/", api_views.api_signup, name="v2_app_signup"),
    path(
        "auth/signup/verify/",
        api_views.verify_email_signup_code,
        name="v2_app_signup_verify",
    ),
    path("auth/refresh/", TokenRefreshView.as_view(), name="v2_app_token_refresh"),
    path("user/", api_views.get_user_profile, name="v2_app_user_profile"),
    path(
        "user/secondary-phone/",
        api_views.update_secondary_phone,
        # ??? ??????? name ??? ????? ??? ???? ???? ???? ????? ????.
        name="v2_app_user_secondary_phone",
    ),
    path("cafes/", api_views.get_cafes_list, name="v2_app_cafes"),
    path("products/", api_views.get_products, name="v2_app_products"),
    path("orders/", api_views.orders_endpoint, name="v2_app_orders"),
    path("orders/<int:order_id>/cancel/", api_views.cancel_order, name="v2_app_cancel_order"),
    path("notifications/", api_views.notifications_endpoint, name="v2_app_notifications"),
    path("wallet/", include("wallet.api_urls")),
]
