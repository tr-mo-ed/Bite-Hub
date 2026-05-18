import re


def send_real_notification(user, title, body):
    """
    Notification hook kept for order flows.

    External push notifications are disabled; this function intentionally does
    nothing so order creation and status updates keep working without an
    external notification provider.
    """
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

    digits = re.sub(r"\D", "", str(raw_phone))

    if digits.startswith("218"):
        digits = digits[3:]

    if len(digits) == 9:
        digits = "0" + digits

    return digits
