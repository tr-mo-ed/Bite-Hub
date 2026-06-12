from django.db.models.signals import post_save
from django.dispatch import receiver
from .models import Order

# ???? ???? order_status_notification ?????? ????? ?????? ?? ????? ????.
@receiver(post_save, sender=Order)
def order_status_notification(sender, instance, created, **kwargs):
    """
    إشعارات الطلب تدار من طبقة الخدمات حتى لا تصل للمستخدم رسائل مكررة.
    """
    return
