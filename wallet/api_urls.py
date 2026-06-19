from django.urls import path
from . import api_views

# ??? ??????? urlpatterns ??? ????? ??? ???? ???? ???? ????? ????.
urlpatterns = [
    # الرابط سيكون: /api/wallet/
    path('', api_views.get_wallet, name='get_wallet'),
    
    # الرابط سيكون: /api/wallet/link/
    path('link/', api_views.link_wallet, name='link_wallet'),
    path('nfc/link/', api_views.link_nfc_card, name='link_nfc_card'),
    path('nfc/lookup/', api_views.lookup_nfc_card, name='lookup_nfc_card'),
    path('nfc/transfer/', api_views.transfer_to_nfc_card, name='transfer_to_nfc_card'),
    
    # الرابط سيكون: /api/wallet/topup/
    path('topup/', api_views.topup_wallet, name='topup_wallet'),

    # الرابط سيكون: /api/wallet/transfer/
    path('transfer/', api_views.transfer_wallet, name='transfer_wallet'),
    path('withdraw/', api_views.withdraw_wallet, name='withdraw_wallet'),
    path(
        'debit-requests/<uuid:request_id>/respond/',
        api_views.respond_wallet_debit_request,
        name='respond_wallet_debit_request',
    ),
]
