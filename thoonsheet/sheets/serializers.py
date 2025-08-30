# sheets/serializers.py

import re
from django.db import IntegrityError
from rest_framework import serializers
from .models import Group, PaymentAccount, Transaction, AuditEntry
from django.contrib.auth import get_user_model
from rest_framework.validators import UniqueValidator
from django.contrib.auth.password_validation import validate_password

User = get_user_model()

class UserSerializer(serializers.ModelSerializer):
    class Meta:
        model = User
        fields = ['id', 'username', 'email', 'first_name', 'last_name', 'phone_number', 'user_type', 'is_staff', 'is_active', 'date_joined']
        read_only_fields = ['is_staff', 'is_active', 'date_joined']
        extra_kwargs = {
            'password': {'write_only': True, 'required': False}, # Password can be updated but not read
            'username': {'required': False}, # Username can be optional for update
        }

    def create(self, validated_data):
        # Owner က Auditor ကို ဖန်တီးသောအခါ user_type ကို 'auditor' အဖြစ် သတ်မှတ်ပေးပါမည်။
        # သို့မဟုတ် default value အဖြစ် 'auditor' ကို model တွင် သတ်မှတ်ထားပါက ဤနေရာတွင် ထပ်မံသတ်မှတ်ရန် မလိုအပ်ပါ။
        # user_type = validated_data.get('user_type', 'auditor') # Default to auditor if not provided
        # validated_data['user_type'] = user_type

        user = User.objects.create_user(
            username=validated_data['username'],
            email=validated_data.get('email', ''),
            password=validated_data['password'],
            user_type=validated_data.get('user_type', 'auditor'), # Default to auditor if not explicitly set
            first_name=validated_data.get('first_name', ''),
            last_name=validated_data.get('last_name', ''),
            phone_number=validated_data.get('phone_number', ''),
        )
        return user

    def update(self, instance, validated_data):
        # Update user fields
        instance.first_name = validated_data.get('first_name', instance.first_name)
        instance.last_name = validated_data.get('last_name', instance.last_name)
        instance.email = validated_data.get('email', instance.email)
        instance.phone_number = validated_data.get('phone_number', instance.phone_number)
        instance.user_type = validated_data.get('user_type', instance.user_type)

        # Update password if provided
        password = validated_data.get('password')
        if password:
            instance.set_password(password)
        
        instance.save()
        return instance


class GroupSerializer(serializers.ModelSerializer):
    owner_username = serializers.CharField(source='owner.username', read_only=True)
    class Meta:
        model = Group
        fields = '__all__'
        read_only_fields = ('created_at', 'updated_at') # 'owner' ကို ဖယ်ရှားလိုက်ပါပြီ

class PaymentAccountSerializer(serializers.ModelSerializer):
    owner_username = serializers.CharField(source='owner.username', read_only=True)
    class Meta:
        model = PaymentAccount
        fields = '__all__'
        read_only_fields = ('created_at', 'updated_at') # 'owner' ကို ဖယ်ရှားလိုက်ပါပြီ

# class TransactionSerializer(serializers.ModelSerializer):
#     group_name = serializers.CharField(source='group.name', read_only=True)
#     payment_account_name = serializers.CharField(source='payment_account.payment_account_name', read_only=True)
#     submitted_by_username = serializers.CharField(source='submitted_by.username', read_only=True)
#     transaction_type_display = serializers.CharField(source='get_transaction_type_display', read_only=True)
#     status_display = serializers.CharField(source='get_status_display', read_only=True)

#     class Meta:
#         model = Transaction
#         fields = [
#             'id', 'submitted_by', 'submitted_by_username', 'transaction_date', 'group', 'group_name',
#             'payment_account', 'payment_account_name', 'transfer_id_last_6_digits',
#             'amount', 'transaction_type', 'transaction_type_display', 'image',
#             'submitted_at', 'status', 'status_display', 'approved_by_owner_at', 'owner_notes'
#         ]
#         read_only_fields = [
#             'id', 'submitted_by', 'submitted_by_username', 'group_name', 'payment_account_name',
#             'transaction_type_display', 'status_display', 'submitted_at',
#             'approved_by_owner_at', # approved_by_owner_at ကို owner ကပဲ သတ်မှတ်နိုင်
#         ]
#         # unique_together constraint ကို model မှာ သတ်မှတ်ထားပြီးသားဖြစ်သောကြောင့် ဤနေရာတွင် ထပ်မံသတ်မှတ်ရန် မလိုအပ်ပါ။

#     def create(self, validated_data):
#         # Auditor က Transaction ဖန်တီးသောအခါ submitted_by ကို အလိုအလျောက် သတ်မှတ်ပေးပါမည်။
#         validated_data['submitted_by'] = self.context['request'].user
#         try:
#             return super().create(validated_data)
#         except IntegrityError:
#             raise serializers.ValidationError({"detail": "ဤငွေပေးချေမှုအကောင့်အတွက် တူညီသော နောက်ဆုံး ၆ လုံးပါသော မှတ်တမ်း ရှိနေပြီးသား ဖြစ်ပါသည်။"})

#     def update(self, instance, validated_data):
#         # Auditor က rejected transaction ကို ပြန်တင်တဲ့အခါ image ကို ပြောင်းလဲနိုင်ရန်
#         if 'image' in validated_data:
#             if validated_data['image'] == '': # If client sends empty string to clear image
#                 instance.image = None
#             else:
#                 instance.image = validated_data.get('image', instance.image)
#             validated_data.pop('image') # Remove image from validated_data to prevent error with super().update
#         return super().update(instance, validated_data)


class TransactionSerializer(serializers.ModelSerializer):
    group_name = serializers.CharField(source='group.name', read_only=True)
    payment_account_name = serializers.CharField(source='payment_account.payment_account_name', read_only=True)
    submitted_by_username = serializers.CharField(source='submitted_by.username', read_only=True)
    transaction_type_display = serializers.CharField(source='get_transaction_type_display', read_only=True)
    status_display = serializers.CharField(source='get_status_display', read_only=True)

    # ⭐ Global unique on the 6 digits
    transfer_id_last_6_digits = serializers.CharField(
        max_length=6,
        validators=[UniqueValidator(queryset=Transaction.objects.all(),
                   message="ဤ လွှဲပြောင်း ID (၆ လုံး) သည် ရှိပြီးသား ဖြစ်နေပါသည်။")]
    )

    class Meta:
        model = Transaction
        fields = [
            'id', 'submitted_by', 'submitted_by_username', 'transaction_date', 'group', 'group_name',
            'payment_account', 'payment_account_name', 'transfer_id_last_6_digits',
            'amount', 'transaction_type', 'transaction_type_display', 'image',
            'submitted_at', 'status', 'status_display', 'approved_by_owner_at', 'owner_notes'
        ]
        read_only_fields = [
            'id', 'submitted_by', 'submitted_by_username', 'group_name', 'payment_account_name',
            'transaction_type_display', 'status_display', 'submitted_at', 'approved_by_owner_at',
        ]

    # ⭐ ၆ လုံး digit-only backend validation
    def validate_transfer_id_last_6_digits(self, v):
        if not re.fullmatch(r'\d{6}', v or ''):
            raise serializers.ValidationError("၆ လုံး ဂဏန်း အတိအကျ ဖြစ်ရမည်။")
        return v

    def create(self, validated_data):
        # submitted_by ကို request user ဖြင့်အလိုအလျောက် သတ်မှတ်
        validated_data['submitted_by'] = self.context['request'].user
        try:
            return super().create(validated_data)
        except IntegrityError:
            # DB-level unique (optional) ကလည်း ထပ်တူသွားရင် fallback error
            raise serializers.ValidationError({"transfer_id_last_6_digits": ["ဤ ၆ လုံး ID သည် ရှိပြီးသား ဖြစ်ပါသည်။"]})

    def update(self, instance, validated_data):
        """
        - clear_image flag => image ဖျက်
        - image file ပို့လာရင်အသစ်ယူ
        """
        request = self.context.get('request')
        clear_flag = False
        if request is not None:
            raw = str(request.data.get('clear_image', '0')).lower()
            clear_flag = raw in ('1', 'true', 'yes')

        # clear flag မူတည်၍ ပုံဖျက်
        if clear_flag and instance.image:
            instance.image.delete(save=False)
            instance.image = None

        # image file တင်လာလျှင် ဘာသာရပ်ပေါ်က validated_data ထဲကနေ ယူ
        new_image = validated_data.pop('image', None)
        if new_image is not None:
            instance.image = new_image

        # အခြား field များကို default update ချ
        for attr, val in validated_data.items():
            setattr(instance, attr, val)
        instance.save()
        return instance


class OwnerApproveRejectSerializer(serializers.Serializer):
    owner_notes = serializers.CharField(required=False, allow_blank=True)


class AuditEntrySerializer(serializers.ModelSerializer):
    group_name = serializers.CharField(source='group.name', read_only=True)
    auditor_username = serializers.CharField(source='auditor.username', read_only=True)

    class Meta:
        model = AuditEntry
        fields = '__all__'
        read_only_fields = ('created_at', 'last_updated') # 'auditor' ကို ဖယ်ရှားလိုက်ပါပြီ

    def create(self, validated_data):
        # Auditor က AuditEntry ဖန်တီးသောအခါ auditor ကို အလိုအလျောက် သတ်မှတ်ပေးပါမည်။
        validated_data['auditor'] = self.context['request'].user
        return super().create(validated_data)

class AuditSummarySerializer(serializers.Serializer):
    total_income = serializers.DecimalField(max_digits=10, decimal_places=2)
    total_expense = serializers.DecimalField(max_digits=10, decimal_places=2)
    balance = serializers.DecimalField(max_digits=10, decimal_places=2)
    audited_income = serializers.DecimalField(max_digits=10, decimal_places=2)
    audited_expense = serializers.DecimalField(max_digits=10, decimal_places=2)
    audited_balance = serializers.DecimalField(max_digits=10, decimal_places=2)
    unapproved_income = serializers.DecimalField(max_digits=10, decimal_places=2)
    unapproved_expense = serializers.DecimalField(max_digits=10, decimal_places=2)
    unapproved_balance = serializers.DecimalField(max_digits=10, decimal_places=2)
    last_updated = serializers.DateTimeField()

    def to_representation(self, instance):
        data = super().to_representation(instance)
        return data





class ChangePasswordSerializer(serializers.Serializer):
    old_password = serializers.CharField(write_only=True, trim_whitespace=False)
    new_password = serializers.CharField(write_only=True, trim_whitespace=False)
    new_password2 = serializers.CharField(write_only=True, trim_whitespace=False)

    def validate(self, attrs):
        user = self.context['request'].user
        old_pw = attrs.get('old_password') or ''
        new_pw = attrs.get('new_password') or ''
        new_pw2 = attrs.get('new_password2') or ''

        if not user.check_password(old_pw):
            raise serializers.ValidationError({'old_password': ['လက်ရှိ စကားဝှက် မှားနေပါသည်။']})
        if new_pw != new_pw2:
            raise serializers.ValidationError({'new_password2': ['စကားဝှက် တူညီရပါမည်။']})
        if old_pw == new_pw:
            raise serializers.ValidationError({'new_password': ['ဟောင်းနှင့်အသစ် တူနေပါသည်။']})

        validate_password(new_pw, user=user)
        return attrs


class SetUserPasswordSerializer(serializers.Serializer):
    new_password = serializers.CharField(write_only=True, trim_whitespace=False)
    new_password2 = serializers.CharField(write_only=True, trim_whitespace=False)

    def validate(self, attrs):
        pw1 = attrs.get('new_password') or ''
        pw2 = attrs.get('new_password2') or ''
        if pw1 != pw2:
            raise serializers.ValidationError({'new_password2': ['စကားဝှက် တူညီရပါမည်။']})
        validate_password(pw1)
        return attrs
