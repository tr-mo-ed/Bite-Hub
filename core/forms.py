from django import forms
from django.core.exceptions import ValidationError

from .models import Product


class ProductForm(forms.ModelForm):
    class Meta:
        model = Product
        fields = [
            'name',
            'category',
            'price',
            'original_price',
            'stock_quantity',
            'description',
            'image',
            'is_available',
        ]
        widgets = {
            'name': forms.TextInput(attrs={'class': 'form-control', 'placeholder': 'اسم المنتج'}),
            'category': forms.Select(attrs={'class': 'form-select'}),
            'price': forms.NumberInput(attrs={'class': 'form-control', 'placeholder': 'السعر', 'step': '0.01', 'min': '0.01'}),
            'original_price': forms.NumberInput(attrs={'class': 'form-control', 'placeholder': 'السعر قبل التخفيض', 'step': '0.01', 'min': '0.01'}),
            'stock_quantity': forms.NumberInput(attrs={'class': 'form-control', 'placeholder': 'الكمية المتاحة', 'min': '0'}),
            'description': forms.Textarea(attrs={'class': 'form-control', 'rows': 3, 'placeholder': 'وصف المنتج'}),
            'image': forms.ClearableFileInput(attrs={'class': 'form-control', 'accept': 'image/*'}),
            'is_available': forms.CheckboxInput(attrs={'class': 'form-check-input'}),
        }

    def __init__(self, *args, **kwargs):
        super().__init__(*args, **kwargs)
        self.fields['category'].required = False
        self.fields['original_price'].required = False
        self.fields['image'].required = False

    def clean_price(self):
        price = self.cleaned_data['price']
        if price <= 0:
            raise ValidationError("Product price must be greater than zero.")
        return price

    def clean_stock_quantity(self):
        stock_quantity = self.cleaned_data.get('stock_quantity') or 0
        if stock_quantity < 0:
            raise ValidationError("Stock quantity cannot be negative.")
        return stock_quantity

    def clean(self):
        cleaned_data = super().clean()
        price = cleaned_data.get('price')
        original_price = cleaned_data.get('original_price')
        if original_price is not None and price is not None and original_price <= price:
            cleaned_data['original_price'] = None
        if cleaned_data.get('stock_quantity', 0) <= 0:
            cleaned_data['is_available'] = False
        return cleaned_data
