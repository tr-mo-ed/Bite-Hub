from __future__ import annotations

from io import BytesIO
from pathlib import Path

from django.core.files.uploadedfile import SimpleUploadedFile


def optimize_uploaded_image(image, *, max_dimension: int = 1200, quality: int = 82):
    if image is None:
        return None

    try:
        from PIL import Image, ImageOps
    except Exception:
        return image

    try:
        image.seek(0)
        with Image.open(image) as source:
            source = ImageOps.exif_transpose(source)
            resampling = getattr(
                getattr(Image, "Resampling", Image),
                "LANCZOS",
                1,
            )
            source.thumbnail((max_dimension, max_dimension), resampling)

            if source.mode not in {"RGB", "RGBA"}:
                source = source.convert("RGB")

            if source.mode == "RGBA":
                canvas = Image.new("RGB", source.size, "white")
                canvas.paste(source, mask=source.getchannel("A"))
                source = canvas

            output = BytesIO()
            source.save(output, format="JPEG", optimize=True, quality=quality)
            output.seek(0)

        original_name = getattr(image, "name", "image") or "image"
        optimized_name = f"{Path(original_name).stem or 'image'}.jpg"
        return SimpleUploadedFile(
            optimized_name,
            output.getvalue(),
            content_type="image/jpeg",
        )
    except Exception:
        try:
            image.seek(0)
        except Exception:
            pass
        return image
