import json

from channels.db import database_sync_to_async
from channels.generic.websocket import AsyncWebsocketConsumer

from .models import Cafe


# ???? ???? CafeOrderConsumer ???? ?????? ????????? ???? ???? ?????.
class CafeOrderConsumer(AsyncWebsocketConsumer):
    async def connect(self):
        self.cafe_id = self.scope["url_route"]["kwargs"]["cafe_id"]
        self.user = self.scope.get("user")
        if self.user is None or not self.user.is_authenticated:
            await self.close(code=4401)
            return
        if not await self._can_access_cafe():
            await self.close(code=4403)
            return
        self.group_name = f"cafe_orders_{self.cafe_id}"

        await self.channel_layer.group_add(self.group_name, self.channel_name)
        await self.accept()

    async def disconnect(self, close_code):
        await self.channel_layer.group_discard(self.group_name, self.channel_name)

    async def receive(self, text_data=None, bytes_data=None):
        # The server pushes order events. No client command handling is required yet.
        return None

    async def order_event(self, event):
        payload = event["payload"]
        if not await self._can_receive_order(payload):
            return
        await self.send(
            # ??? ??????? text_data ??? ????? ??? ???? ???? ???? ????? ????.
            text_data=json.dumps(
                {
                    "type": event["type"],
                    "event": event["event"],
                    "payload": payload,
                }
            )
        )

    @database_sync_to_async
    def _can_access_cafe(self):
        if not Cafe.objects.filter(pk=self.cafe_id, is_active=True).exists():
            return False
        if self.user.is_superuser:
            return True
        managed_cafe = getattr(self.user, "my_cafe", None)
        if managed_cafe is not None:
            return str(managed_cafe.id) == str(self.cafe_id)
        return not self.user.is_staff

    @database_sync_to_async
    def _can_receive_order(self, payload):
        if self.user.is_superuser:
            return True
        managed_cafe = getattr(self.user, "my_cafe", None)
        if managed_cafe is not None:
            return str(managed_cafe.id) == str(payload.get("cafe_id"))
        return str(payload.get("user_id")) == str(self.user.id)
