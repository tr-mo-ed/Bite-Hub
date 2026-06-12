import json

from channels.generic.websocket import AsyncWebsocketConsumer


# ???? ???? CafeOrderConsumer ???? ?????? ????????? ???? ???? ?????.
class CafeOrderConsumer(AsyncWebsocketConsumer):
    async def connect(self):
        self.cafe_id = self.scope["url_route"]["kwargs"]["cafe_id"]
        self.group_name = f"cafe_orders_{self.cafe_id}"

        await self.channel_layer.group_add(self.group_name, self.channel_name)
        await self.accept()

    async def disconnect(self, close_code):
        await self.channel_layer.group_discard(self.group_name, self.channel_name)

    async def receive(self, text_data=None, bytes_data=None):
        # The server pushes order events. No client command handling is required yet.
        return None

    async def order_event(self, event):
        await self.send(
            # ??? ??????? text_data ??? ????? ??? ???? ???? ???? ????? ????.
            text_data=json.dumps(
                {
                    "type": event["type"],
                    "event": event["event"],
                    "payload": event["payload"],
                }
            )
        )
