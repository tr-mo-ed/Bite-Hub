from urllib.parse import parse_qs

from channels.db import database_sync_to_async
from django.contrib.auth.models import AnonymousUser
from rest_framework_simplejwt.authentication import JWTAuthentication


@database_sync_to_async
def _user_from_token(raw_token):
    if not raw_token:
        return AnonymousUser()
    authentication = JWTAuthentication()
    try:
        validated_token = authentication.get_validated_token(raw_token)
        return authentication.get_user(validated_token)
    except Exception:
        return AnonymousUser()


class QueryStringJwtAuthMiddleware:
    def __init__(self, app):
        self.app = app

    async def __call__(self, scope, receive, send):
        scoped = dict(scope)
        current_user = scoped.get("user")
        if current_user is None or not current_user.is_authenticated:
            query = parse_qs(scoped.get("query_string", b"").decode())
            token = (query.get("token") or [""])[0]
            scoped["user"] = await _user_from_token(token)
        return await self.app(scoped, receive, send)
