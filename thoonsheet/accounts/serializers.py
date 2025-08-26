# accounts/serializers.py
from rest_framework import serializers
from .models import User
from djoser.serializers import UserCreateSerializer as DjoserUserCreateSerializer, UserSerializer as DjoserUserSerializer
from djoser.serializers import UserSerializer as DjoserUserSerializer
from djoser.serializers import UserCreateSerializer as DjoserUserCreateSerializer




class UserSerializer(serializers.ModelSerializer):
    """
    Serializer for the Custom User model. Handles creation and updates.
    Password is write-only for security.
    """
    class Meta:
        model = User
        fields = ('id', 'username', 'email', 'user_type', 'password', 'is_staff', 'is_superuser')
        extra_kwargs = {'password': {'write_only': True, 'required': False}} # Password not required for update

    def create(self, validated_data):
        """
        Creates a new user with hashed password.
        """
        user = User.objects.create_user(**validated_data)
        return user

    def update(self, instance, validated_data):
        """
        Updates an existing user. Handles password hashing if password is provided.
        """
        instance.username = validated_data.get('username', instance.username)
        instance.email = validated_data.get('email', instance.email)
        # user_type, is_staff, is_superuser are handled by permissions in the ViewSet,
        # so direct update here is fine as permission check is done before this.
        instance.user_type = validated_data.get('user_type', instance.user_type)
        instance.is_staff = validated_data.get('is_staff', instance.is_staff)
        instance.is_superuser = validated_data.get('is_superuser', instance.is_superuser)

        password = validated_data.get('password')
        if password:
            instance.set_password(password) # Hash the new password
        instance.save()
        return instance
    

class UserCreateSerializer(DjoserUserCreateSerializer):
    class Meta(DjoserUserCreateSerializer.Meta):
        model = User
        # Ensure 'user_type' is included for creation if you want to set it during signup
        # Or remove it if user_type is set by default or via admin only.
        fields = ('id', 'username', 'email', 'password', 'user_type') 

class UserSerializer(DjoserUserSerializer):
    class Meta(DjoserUserSerializer.Meta):
        model = User
        fields = ('id', 'username', 'email', 'user_type') # Ensure user_type is included
        read_only_fields = ('user_type',) # user_type is typically read-only for users themselves



class UserSerializer(DjoserUserSerializer):
    """
    Custom User Serializer for Djoser to include additional fields.
    Djoser's default UserSerializer might not include all desired fields.
    """
    class Meta(DjoserUserSerializer.Meta):
        # Add all fields you want to expose via the API for the user model.
        # Ensure 'user_type' is also included if it's a custom field in your User model.
        fields = DjoserUserSerializer.Meta.fields + (
            'first_name',
            'last_name',
            'user_type', # Make sure this matches your custom User model field name
            'is_active',
            'is_staff',
            'is_superuser',
            'date_joined', # This is usually 'createdAt' in Flutter
            'last_login',
        )
        # These fields are typically read-only as they are managed by Django
        read_only_fields = (
            'is_active',
            'is_staff',
            'is_superuser',
            'date_joined',
            'last_login',
        )

class UserCreateSerializer(DjoserUserCreateSerializer):
    """
    Custom User Create Serializer if you need to add fields during user creation.
    For example, if 'user_type' is set during creation.
    """
    class Meta(DjoserUserCreateSerializer.Meta):
        fields = DjoserUserCreateSerializer.Meta.fields + ('user_type',)
