# accounts/views.py
from rest_framework import viewsets, status
from rest_framework.response import Response
from rest_framework_simplejwt.views import TokenObtainPairView
from rest_framework.permissions import IsAuthenticated

from .models import User
from .serializers import UserSerializer
from .permissions import IsSuperUser, IsSuperUserOrSelf, IsOwner, IsAuditor
from djoser.views import TokenCreateView
from rest_framework.response import Response
from rest_framework import status
from rest_framework.authtoken.models import Token
from rest_framework.serializers import ModelSerializer

class MyTokenObtainPairView(TokenObtainPairView):
    """
    Custom view for obtaining JWT tokens.
    """
    pass

class UserViewSet(viewsets.ModelViewSet):
    """
    API endpoint for managing User accounts.
    Permissions are strictly controlled based on user roles (Superuser, Owner, Auditor).
    """
    queryset = User.objects.all()
    serializer_class = UserSerializer

    def get_queryset(self):
        # Determine which users can be listed/retrieved based on the requesting user's role.
        if self.request.user.is_superuser:
            return User.objects.all() # Superuser can see all users
        elif self.request.user.user_type == 'owner':
            return User.objects.all() # Owner can see all users (for management context)
        elif self.request.user.user_type == 'auditor':
            return User.objects.filter(id=self.request.user.id) # Auditor can only see their own profile
        return User.objects.none() # For unauthenticated or other unexpected roles

    def get_permissions(self):
        # Set permissions for different actions in the UserViewSet.
        # This is crucial for role-based access control.
        if self.action == 'create':
            # Only SuperUser or Owner can create new user accounts.
            self.permission_classes = [IsSuperUser | IsOwner]
        elif self.action == 'retrieve':
            # SuperUser, Owner can retrieve any user. Auditor can retrieve only self.
            self.permission_classes = [IsSuperUserOrSelf | IsOwner]
        elif self.action in ['update', 'partial_update']:
            # SuperUser can update any user.
            # Owner can update any user except Superusers.
            # Auditor can only update their own profile.
            self.permission_classes = [IsSuperUserOrSelf | IsOwner]
        elif self.action == 'destroy':
            # Only SuperUser can delete users. Owners and Auditors cannot delete.
            self.permission_classes = [IsSuperUser]
        else:
            # Default for list action (already handled by get_queryset and IsAuthenticated)
            self.permission_classes = [IsAuthenticated]
        return [permission() for permission in self.permission_classes]

    def create(self, request, *args, **kwargs):
        """
        Handles the creation of new user accounts.
        Owners can only create 'auditor' accounts. Superusers can create any type.
        """
        serializer = self.get_serializer(data=request.data)
        serializer.is_valid(raise_exception=True)

        user_type = request.data.get('user_type', 'owner') # Default to 'owner' if not specified
        is_staff = request.data.get('is_staff', False)
        is_superuser = request.data.get('is_superuser', False)

        current_user = request.user

        if current_user.is_superuser:
            # Superuser can create any user type (owner, auditor, staff, superuser)
            user = serializer.save()
        elif current_user.user_type == 'owner':
            # Owner can only create 'auditor' type accounts.
            # They cannot create other owners, staff, or superusers.
            if user_type == 'auditor' and not is_staff and not is_superuser:
                user = serializer.save(user_type='auditor')
            else:
                return Response(
                    {"detail": "Owners can only create auditor accounts."},
                    status=status.HTTP_403_FORBIDDEN
                )
        else: # Should be caught by permission_classes, but as a fallback
            return Response(
                {"detail": "You do not have permission to create users."},
                status=status.HTTP_403_FORBIDDEN
            )

        headers = self.get_success_headers(serializer.data)
        return Response(serializer.data, status=status.HTTP_201_CREATED, headers=headers)

    def update(self, request, *args, **kwargs):
        """
        Handles updating existing user profiles based on role-based rules.
        """
        partial = kwargs.pop('partial', False)
        instance = self.get_object() # The user object being updated

        current_user = request.user

        # Apply specific update logic based on roles
        if current_user.is_superuser:
            # Superuser can update any user's profile, including their role/staff status.
            pass
        elif current_user.user_type == 'owner':
            # Owner can update any user's profile EXCEPT a Superuser's profile.
            # Owners can change username/email of other owners/auditors.
            # They can also change user_type of other users if allowed (e.g., owner can make another owner an auditor, or vice versa).
            # For simplicity, let's say owner can update general user data (username, email) for non-superusers.
            # If changing role (user_type, is_staff, is_superuser) is intended, specific checks are needed.
            if instance.is_superuser:
                return Response(
                    {"detail": "Owners cannot update Superusers."},
                    status=status.HTTP_403_FORBIDDEN
                )
            # Prevent owners from changing staff/superuser status of other users
            if 'is_staff' in request.data or 'is_superuser' in request.data:
                return Response(
                    {"detail": "Owners cannot change staff or superuser status of other users."},
                    status=status.HTTP_403_FORBIDDEN
                )
            # Owner can change user_type of other Owner/Auditor users
            if 'user_type' in request.data and not instance.is_superuser:
                # An owner should generally only manage their auditors or self.
                # If they try to change another owner to auditor, or auditor to owner,
                # specific business rules apply. For this scope, let's allow it for simplicity.
                pass # The serializer will save the user_type if it's in validated_data

        elif current_user.user_type == 'auditor':
            # Auditor can only update their own profile.
            if instance != current_user:
                return Response(
                    {"detail": "Auditors can only update their own profile."},
                    status=status.HTTP_403_FORBIDDEN
                )
            # Auditors cannot change their user_type or staff/superuser status.
            if 'user_type' in request.data or 'is_staff' in request.data or 'is_superuser' in request.data:
                 return Response(
                    {"detail": "Auditors cannot change their user type or staff/superuser status."},
                    status=status.HTTP_403_FORBIDDEN
                )
        else: # Should be caught by permission_classes, but as a fallback
            return Response(
                {"detail": "You do not have permission to update users."},
                status=status.HTTP_403_FORBIDDEN
            )

        serializer = self.get_serializer(instance, data=request.data, partial=partial)
        serializer.is_valid(raise_exception=True)
        self.perform_update(serializer) # Calls the serializer's update method

        if getattr(instance, '_prefetched_objects_cache', None):
            instance = self.get_object() # Refresh instance if prefetch_related was used
        return Response(serializer.data)


    def destroy(self, request, *args, **kwargs):
        """
        Handles deleting user accounts. Only Superusers are allowed to delete users.
        """
        instance = self.get_object() # Get the user object to be deleted

        # The permission check (IsSuperUser) is already handled by get_permissions()
        # If a non-superuser tries to call this, it will be blocked by DRF.
        # We can add an extra check here for clarity, though it's redundant if permissions are correct.
        if not request.user.is_superuser:
            return Response(
                {"detail": "You do not have permission to delete users."},
                status=status.HTTP_403_FORBIDDEN
            )

        self.perform_destroy(instance) # Perform the actual deletion
        return Response(status=status.HTTP_204_NO_CONTENT)


