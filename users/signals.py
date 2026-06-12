from django.db.models.signals import post_save
from django.dispatch import receiver
from .models import User
from wallet.models import Wallet

# ???? ???? create_user_wallet ?????? ????? ?????? ?? ????? ????.
@receiver(post_save, sender=User)
def create_user_wallet(sender, instance, created, **kwargs):
    if created:
        # إنشاء محفظة تلقائياً لكل مستخدم جديد
        Wallet.objects.create(user=instance)
