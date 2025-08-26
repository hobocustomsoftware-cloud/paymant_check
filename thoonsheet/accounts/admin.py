
from django.contrib import admin
from django.contrib.auth.admin import UserAdmin as BaseUserAdmin
from .models import User

@admin.register(User)
class UserAdmin(BaseUserAdmin):
    list_display = ('username', 'email', 'user_type', 'is_staff', 'is_superuser', 'date_joined', 'last_login')
    list_filter = ('user_type', 'is_staff', 'is_superuser', 'is_active')
    search_fields = ('username', 'email', 'first_name', 'last_name')
    ordering = ('username',)

    # Add 'user_type' to the fieldsets for editing user properties
    fieldsets = BaseUserAdmin.fieldsets + (
        (None, {'fields': ('user_type',)}),
    )
    # If you customize add_fieldsets, add 'user_type' there too
    add_fieldsets = BaseUserAdmin.add_fieldsets + (
        (None, {'fields': ('user_type',)}),
    )




