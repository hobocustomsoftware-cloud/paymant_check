from rest_framework import permissions

class IsOwnerUser(permissions.BasePermission):
    """
    Allows access only to 'owner' type users.
    """
    def has_permission(self, request, view):
        return request.user and request.user.is_authenticated and request.user.user_type == 'owner'

    def has_object_permission(self, request, view, obj):
        return request.user and request.user.is_authenticated and request.user.user_type == 'owner'

class IsAuditorUser(permissions.BasePermission):
    """
    Allows access only to 'auditor' type users.
    For object-level permissions, it checks if the auditor submitted the object.
    """
    def has_permission(self, request, view):
        return request.user and request.user.is_authenticated and request.user.user_type == 'auditor'

    def has_object_permission(self, request, view, obj):
        # Auditors can only view/edit/delete objects they submitted
        # For Transaction and AuditEntry, check if submitted_by or auditor matches
        if hasattr(obj, 'submitted_by'): # For Transaction objects
            return obj.submitted_by == request.user
        if hasattr(obj, 'auditor'): # For AuditEntry objects
            return obj.auditor == request.user
        return False # Deny access for other object types
