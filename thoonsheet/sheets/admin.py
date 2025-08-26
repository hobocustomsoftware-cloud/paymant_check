# sheets/admin.py

from django.contrib import admin
from django.utils.html import format_html, mark_safe
from django import forms
from django.contrib.auth import get_user_model

from sheets.models import AuditEntry, Group, PaymentAccount, Transaction

User = get_user_model()

# Custom User Admin (Optional - if you want to register your custom User model in admin)
# class CustomUserAdmin(BaseUserAdmin):
#     list_display = ('username', 'email', 'first_name', 'last_name', 'user_type', 'is_staff', 'is_superuser', 'is_active')
#     list_filter = ('user_type', 'is_staff', 'is_superuser', 'is_active')
#     fieldsets = (
#         (None, {'fields': ('username', 'password')}),
#         ('Personal info', {'fields': ('first_name', 'last_name', 'email', 'phone_number', 'user_type')}),
#         ('Permissions', {'fields': ('is_active', 'is_staff', 'is_superuser', 'groups', 'user_permissions')}),
#         ('Important dates', {'fields': ('last_login', 'date_joined')}),
#     )
# try:
#     admin.site.unregister(User)
# except admin.sites.NotRegistered:
#     pass
# admin.site.register(User, CustomUserAdmin)


@admin.register(PaymentAccount)
class PaymentAccountAdmin(admin.ModelAdmin):
    list_display = ('id', 'payment_account_name', 'payment_account_type', 'bank_name', 'bank_account_number', 'phone_number', 'owner', 'created_at')
    list_filter = ('payment_account_type', 'bank_name', 'owner__user_type')
    search_fields = ('payment_account_name', 'bank_account_number', 'phone_number', 'owner__username')
    raw_id_fields = ('owner',)

    def get_form(self, request, obj=None, **kwargs):
        form = super().get_form(request, obj, **kwargs)
        if not obj and not request.user.is_superuser:
            if 'owner' in form.base_fields:
                form.base_fields['owner'].initial = request.user.id
                form.base_fields['owner'].widget = forms.HiddenInput()
        return form

    def save_model(self, request, obj, form, change):
        if not obj.pk and not request.user.is_superuser:
            obj.owner = request.user
        super().save_model(request, obj, form, change)


@admin.register(Group)
class GroupAdmin(admin.ModelAdmin):
    list_display = ('id', 'group_title', 'group_type', 'name', 'owner', 'created_at')
    list_filter = ('group_type', 'owner__user_type')
    search_fields = ('group_title', 'name', 'owner__username')
    raw_id_fields = ('owner',)

    def get_form(self, request, obj=None, **kwargs):
        form = super().get_form(request, obj, **kwargs)
        if not obj and not request.user.is_superuser:
            if 'owner' in form.base_fields:
                form.base_fields['owner'].initial = request.user.id
                form.base_fields['owner'].widget = forms.HiddenInput()
        return form

    def save_model(self, request, obj, form, change):
        if not obj.pk and not request.user.is_superuser:
            obj.owner = request.user
        super().save_model(request, obj, form, change)


@admin.register(AuditEntry)
class AuditEntryAdmin(admin.ModelAdmin):
    list_display = ('id', 'group', 'auditor', 'receivable_amount', 'payable_amount', 'created_at', 'last_updated')
    list_filter = ('group__name', 'auditor__username', 'created_at')
    search_fields = ('group__name', 'auditor__username', 'remarks')
    readonly_fields = ('created_at', 'last_updated', 'auditor')

    def get_form(self, request, obj=None, **kwargs):
        form = super().get_form(request, obj, **kwargs)
        if not obj:
            if 'auditor' in form.base_fields:
                form.base_fields['auditor'].initial = request.user.id
                if not request.user.is_superuser:
                    form.base_fields['auditor'].widget = forms.HiddenInput()
            else:
                print("DEBUG: 'auditor' not found in form.base_fields!")
        return form

    def save_model(self, request, obj, form, change):
        if not obj.pk:
            obj.auditor = request.user
        super().save_model(request, obj, form, change)


@admin.register(Transaction)
class TransactionAdmin(admin.ModelAdmin):
    list_display = (
        'id', 'amount', 'transaction_type', 'status', 'submitted_by',
        'group', 'payment_account', 'transaction_date', 'image_tag',
        'transfer_id_last_6_digits',
        'submitted_at',
    )
    list_filter = (
        'status',
        'transaction_type',
        'group__name',
        'payment_account__payment_account_name',
        'submitted_by__username',
    )
    search_fields = (
        'transfer_id_last_6_digits',
        'submitted_by__username',
        'group__name',
        'payment_account__payment_account_name',
        'owner_notes',
    )
    date_hierarchy = 'transaction_date'
    readonly_fields = (
        'submitted_at',
        'approved_by_owner_at',
        'image_tag',
    )

    def image_tag(self, obj):
        if obj.image and hasattr(obj.image, 'url'):
            return mark_safe(f'<img src="{obj.image.url}" width="50" height="auto" />')
        return "No Image"
    image_tag.short_description = 'ပုံ'
