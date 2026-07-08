import re


_DIGIT_TRANSLATION = str.maketrans(
    {
        "٠": "0",
        "١": "1",
        "٢": "2",
        "٣": "3",
        "٤": "4",
        "٥": "5",
        "٦": "6",
        "٧": "7",
        "٨": "8",
        "٩": "9",
        "۰": "0",
        "۱": "1",
        "۲": "2",
        "۳": "3",
        "۴": "4",
        "۵": "5",
        "۶": "6",
        "۷": "7",
        "۸": "8",
        "۹": "9",
    }
)


def normalize_ascii_digits(value):
    """
    Convert Arabic/Persian numerals to ASCII numerals before validation.
    """
    return str(value or "").translate(_DIGIT_TRANSLATION)


def send_real_notification(user, title, body, *, event_type="SYSTEM", order=None):
    """
    Store an in-app notification without depending on Firebase or external push.
    """
    if not user:
        return None
    try:
        from .models import Notification

        return Notification.objects.create(
            user=user,
            order=order,
            title=title,
            body=body,
            event_type=event_type,
        )
    except Exception:
        return None


def get_smart_image_for_product(product_name):
    """
    Return a default product image path based on the product name.
    """
    base_path = "products/defaults/"

    if not product_name:
        return None

    name_lower = product_name.lower()
    has = lambda *words: any(word in name_lower for word in words)

    image_name = "general.jpg"

    if has("pizza", "بيتزا"):
        image_name = "pizza.jpg"
    elif has("burger", "cheeseburger", "برجر"):
        image_name = "burger.jpg"
    elif has("cola", "pepsi", "soda", "drink", "juice", "coffee", "مشروب", "قهوة", "عصير"):
        image_name = "juice.jpg"
    elif has("cake", "sweet", "dessert", "kunafa", "حلى", "كيك", "كنافة"):
        image_name = "dessert.jpg"

    return f"{base_path}{image_name}"


def normalize_libyan_phone(raw_phone):
    """
    Normalize Libyan phone numbers to 09XXXXXXXX.
    """
    if not raw_phone:
        return ""

    digits = re.sub(r"\D", "", normalize_ascii_digits(raw_phone))

    if digits.startswith("218"):
        digits = digits[3:]

    if len(digits) == 9:
        digits = "0" + digits

    return digits
