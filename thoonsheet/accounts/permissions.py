# accounts/permissions.py
from rest_framework import permissions

class IsSuperUser(permissions.BasePermission):
    """
    Allows access only to superusers.
    """
    def has_permission(self, request, view):
        return request.user and request.user.is_authenticated and request.user.is_superuser

    def has_object_permission(self, request, view, obj):
        # Superuser can manage any object
        return request.user and request.user.is_authenticated and request.user.is_superuser

class IsOwner(permissions.BasePermission):
    """
    Allows access only to authenticated users with user_type 'owner' or superusers.
    Owners can manage their own resources and some aspects of other users.
    """
    def has_permission(self, request, view):
        return (request.user and request.user.is_authenticated and
                (request.user.user_type == 'owner' or request.user.is_superuser))

    def has_object_permission(self, request, view, obj):
        if request.user.is_superuser:
            return True
        # For objects with an 'owner' field (PaymentAccount, CustomGroup)
        if hasattr(obj, 'owner'):
            return obj.owner == request.user
        # For User objects: An owner can view/update other non-superuser users.
        # Specific delete restriction for Owners on User objects is handled in views.py.
        if isinstance(obj, type(request.user)): # If the object is a User instance
            return not obj.is_superuser # Owner can interact with any user EXCEPT superusers
        return False


class IsAuditor(permissions.BasePermission):
    """
    Allows access only to authenticated users with user_type 'auditor'.
    Auditors can submit transactions and manage AuditEntries they created.
    They can only manage their own user profile.
    """
    def has_permission(self, request, view):
        return request.user and request.user.is_authenticated and request.user.user_type == 'auditor'

    def has_object_permission(self, request, view, obj):
        if request.user.is_superuser: # Superuser can do anything
            return True
        # Auditors can modify/delete AuditEntries they created
        if hasattr(obj, 'auditor'):
            return obj.auditor == request.user
        # Auditors can modify/delete their own submitted transactions if allowed by logic
        # if hasattr(obj, 'submitter'):
        #     return obj.submitter == request.user
        # Auditors can only view/update their own user profile
        if isinstance(obj, type(request.user)): # If the object is a User instance
            return obj == request.user
        return False

class IsSuperUserOrSelf(permissions.BasePermission):
    """
    Allows superuser to access any user profile, or a user to access their own profile.
    """
    def has_object_permission(self, request, view, obj):
        # Superuser can access any object
        if request.user and request.user.is_authenticated and request.user.is_superuser:
            return True
        # User can access their own object
        return obj == request.user