from django.conf import settings
from django.conf.urls.static import static
from django.contrib.staticfiles.urls import staticfiles_urlpatterns
from django.shortcuts import redirect
from django.urls import include, path


# ???? ???? root_redirect ?????? ????? ?????? ?? ????? ????.
def root_redirect(request):
    return redirect("/hub/")


# ??? ??????? urlpatterns ??? ????? ??? ???? ???? ???? ????? ????.
urlpatterns = [
    path("", root_redirect),
    path("api/v2/app/", include("core.api_v2_app_urls")),
    path("api/v2/cafe/", include("core.api_v2_cafe_urls")),
    path("api/v2/admin/", include("core.api_v2_admin_urls")),
    path("hub/", include("core.urls")),
]

if getattr(settings, "HAS_DRF_SPECTACULAR", False):
    from drf_spectacular.views import (
        SpectacularAPIView,
        SpectacularRedocView,
        SpectacularSwaggerView,
    )

    urlpatterns += [
        path("api/schema/", SpectacularAPIView.as_view(), name="schema"),
        path(
            "api/docs/",
            SpectacularSwaggerView.as_view(url_name="schema"),
            name="swagger-ui",
        ),
        path(
            "api/redoc/",
            SpectacularRedocView.as_view(url_name="schema"),
            name="redoc",
        ),
    ]


if settings.DEBUG:
    urlpatterns += staticfiles_urlpatterns()
    urlpatterns += static(settings.MEDIA_URL, document_root=settings.MEDIA_ROOT)
