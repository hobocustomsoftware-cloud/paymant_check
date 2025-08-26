# sheets/views.py

from decimal import Decimal
from django.forms import DecimalField
from rest_framework import viewsets, status, permissions
from rest_framework.response import Response
from rest_framework.decorators import action
from rest_framework.permissions import IsAuthenticated
from rest_framework.parsers import MultiPartParser, FormParser, JSONParser 
from django.db.models import Sum, Case, When, F, DecimalField
from django.db.models.functions import Coalesce
from django.utils import timezone
from datetime import datetime, timedelta
from rest_framework.decorators import api_view, permission_classes
from rest_framework import generics
# from django.contrib.auth import get_user_model # If you use custom user model, import it directly
from accounts.models import User # <-- သင့် User model လမ်းကြောင်းကို မှန်ကန်စွာ ပြင်ပါ။

from .models import Group, PaymentAccount, Transaction, AuditEntry
from .serializers import (
    AuditSummarySerializer, GroupSerializer, OwnerApproveRejectSerializer, PaymentAccountSerializer, TransactionSerializer,
    AuditEntrySerializer, UserSerializer # <-- UserSerializer ကို import လုပ်ထားကြောင်း သေချာပါစေ။
)
from .permissions import IsAuditorUser, IsOwnerUser
from rest_framework.views import APIView

# Djoser views and related imports
from djoser.views import TokenCreateView
from rest_framework.authtoken.models import Token
from rest_framework.serializers import ModelSerializer # For CustomUserSerializer if needed

# CustomUserSerializer (သင့် User model ရဲ့ fields တွေနဲ့ ကိုက်ညီအောင် ပြင်ဆင်ပါ)
# ဒီ UserSerializer က သင့် sheets/serializers.py ထဲက UserSerializer နဲ့ တူညီသင့်ပါတယ်။
# အကယ်၍ sheets/serializers.py ထဲမှာ UserSerializer မရှိသေးရင် အောက်က code ကို ထည့်ပါ။
# ရှိနှင့်ပြီးသားဆိုရင် ဒီနေရာမှာ ထပ်ထည့်စရာမလိုဘဲ အပေါ်က import ကိုပဲ သုံးပါ။
# class CustomUserSerializer(ModelSerializer):
#     class Meta:
#         model = User
#         fields = ['id', 'username', 'email', 'first_name', 'last_name', 'user_type'] # user_type field ပါဝင်ရပါမည်။


# Djoser ရဲ့ TokenCreateView ကို Override လုပ်ပြီး user data ကိုပါ ထည့်သွင်းရန်
class CustomTokenCreateView(TokenCreateView):
    # serializer_class = djoser.serializers.TokenCreateSerializer # Default ကို သုံးပါ
    
    def _action(self, serializer):
        # djoser ရဲ့ default _action method ကို ခေါ်ပြီး token response ကို ရယူပါ။
        token_response = super()._action(serializer) 
        token_key = token_response.data['auth_token'] # djoser က 'auth_token' key နဲ့ ပြန်ပေးပါတယ်။

        user = serializer.user
        # UserSerializer ကို အသုံးပြုပြီး user object ကို serialize လုပ်ပါ။
        # သင့် sheets/serializers.py ထဲက UserSerializer ကို သုံးပါ။
        user_serializer = UserSerializer(user) 

        return Response({
            'auth_token': token_key, # <-- Flutter ဘက်က 'auth_token' key ကို လိုချင်လို့ ဒီလို ပြန်ပေးပါ။
            'user': user_serializer.data # <-- user data ကို ဒီနေရာမှာ ထည့်သွင်းရပါမယ်။
        }, status=status.HTTP_200_OK)


# User ViewSet (Auditor Account များကို Owner ကသာ CRUD လုပ်ရန်)
class UserViewSet(viewsets.ModelViewSet):
    queryset = User.objects.all().order_by('id')
    serializer_class = UserSerializer
    http_method_names = ['get', 'post', 'put', 'patch', 'delete', 'head', 'options']

    def get_permissions(self):
        user = self.request.user
        if not user.is_authenticated:
            self.permission_classes = [IsAuthenticated]
            return [permission() for permission in self.permission_classes]

        if user.user_type == 'owner':
            self.permission_classes = [IsOwnerUser]
        else:
            self.permission_classes = [permissions.IsAdminUser]
        return [permission() for permission in self.permission_classes]

    def get_queryset(self):
        queryset = super().get_queryset()
        user = self.request.user

        if user.is_superuser:
            return queryset
        elif user.user_type == 'owner':
            return queryset.filter(user_type='auditor')
        else:
            return User.objects.none()

    def perform_create(self, serializer):
        user_type = self.request.data.get('user_type', 'auditor')
        if self.request.user.user_type == 'owner':
            if user_type == 'owner':
                raise serializers.ValidationError({"detail": "Owner cannot create another owner user."})
            if user_type != 'auditor':
                raise serializers.ValidationError({"detail": "Owner can only create auditor users."})
            
            user = User.objects.create_user(
                username=self.request.data['username'],
                email=self.request.data.get('email', ''),
                password=self.request.data['password'],
                user_type=user_type,
                first_name=self.request.data.get('first_name', ''),
                last_name=self.request.data.get('last_name', ''),
                phone_number=self.request.data.get('phone_number', ''),
            )
            serializer.instance = user
        else:
            raise permissions.PermissionDenied("Only owners can create users.")

    def perform_update(self, serializer):
        if self.request.user.user_type == 'owner' or self.request.user.is_superuser:
            password = self.request.data.get('password')
            if password:
                user = serializer.instance
                user.set_password(password)
                user.save()
                validated_data = serializer.validated_data.copy()
                validated_data.pop('password', None)
                serializer.save(**validated_data)
            else:
                serializer.save()
        else:
            raise permissions.PermissionDenied("You do not have permission to update users.")

    def perform_destroy(self, instance):
        if self.request.user.user_type == 'owner' and instance.user_type == 'auditor':
            instance.delete()
        else:
            raise permissions.PermissionDenied("You do not have permission to delete this user.")


# Group ViewSet (Owner CRUD, Auditor List/Retrieve)
class GroupViewSet(viewsets.ModelViewSet):
    queryset = Group.objects.all().order_by('id')
    serializer_class = GroupSerializer
    http_method_names = ['get', 'post', 'put', 'patch', 'delete', 'head', 'options']

    def get_permissions(self):
        user = self.request.user
        if not user.is_authenticated:
            self.permission_classes = [IsAuthenticated]
            return [permission() for permission in self.permission_classes]

        if user.user_type == 'owner':
            self.permission_classes = [IsOwnerUser]
        elif user.user_type == 'auditor':
            self.permission_classes = [permissions.IsAuthenticatedOrReadOnly]
        else:
            self.permission_classes = [permissions.IsAuthenticated]
        return [permission() for permission in self.permission_classes]

    def perform_create(self, serializer):
        serializer.save(owner=self.request.user)

# PaymentAccount ViewSet (Owner CRUD, Auditor List/Retrieve)
class PaymentAccountViewSet(viewsets.ModelViewSet):
    queryset = PaymentAccount.objects.all().order_by('id')
    serializer_class = PaymentAccountSerializer
    http_method_names = ['get', 'post', 'put', 'patch', 'delete', 'head', 'options']

    def get_permissions(self):
        user = self.request.user
        if not user.is_authenticated:
            self.permission_classes = [IsAuthenticated]
            return [permission() for permission in self.permission_classes]

        if user.user_type == 'owner':
            self.permission_classes = [IsOwnerUser]
        elif user.user_type == 'auditor':
            self.permission_classes = [permissions.IsAuthenticatedOrReadOnly]
        else:
            self.permission_classes = [permissions.IsAuthenticated]
        return [permission() for permission in self.permission_classes]
    
    def perform_create(self, serializer):
        serializer.save(owner=self.request.user)

# Transaction ViewSet (Owner: List, Edit, Delete / Auditor: Create, List, Edit (rejected only))
class TransactionViewSet(viewsets.ModelViewSet):
    queryset = Transaction.objects.all().order_by('-submitted_at')
    serializer_class = TransactionSerializer
    parser_classes = [MultiPartParser, FormParser, JSONParser]
    http_method_names = ['get', 'post', 'put', 'patch', 'delete', 'head', 'options']

    def get_permissions(self):
        user = self.request.user
        if not user.is_authenticated:
            self.permission_classes = [IsAuthenticated]
            return [permission() for permission in self.permission_classes]

        if user.user_type == 'owner':
            self.permission_classes = [IsOwnerUser]
        elif user.user_type == 'auditor':
            if self.action == 'create':
                self.permission_classes = [IsAuditorUser]
            elif self.action in ['list', 'retrieve']:
                self.permission_classes = [IsAuditorUser]
            elif self.action in ['update', 'partial_update']:
                self.permission_classes = [IsAuditorUser]
            elif self.action == 'destroy':
                self.permission_classes = [permissions.DenyAll]
            else:
                self.permission_classes = [permissions.DenyAll]
        else:
            self.permission_classes = [permissions.DenyAll]

        if self.action in ['approve', 'reject', 'summary', 'pending', 'rejected']:
            self.permission_classes = [IsOwnerUser]
        
        return [permission() for permission in self.permission_classes]
    
    def get_queryset(self):
        queryset = super().get_queryset()
        user = self.request.user

        if user.is_superuser or user.user_type == 'owner':
            return queryset
        elif user.user_type == 'auditor':
            return queryset.filter(submitted_by=user)
        else:
            return Transaction.objects.none()

    def perform_create(self, serializer):
        serializer.save(submitted_by=self.request.user)

    def perform_update(self, serializer):
        if self.request.user.user_type == 'owner':
            serializer.save()
        elif self.request.user.user_type == 'auditor':
            instance = serializer.instance
            if instance.submitted_by != self.request.user:
                raise permissions.PermissionDenied("You can only update your own transactions.")
            if instance.status != 'rejected':
                raise permissions.PermissionDenied("You can only re-submit rejected transactions.")
            
            instance.status = 'pending'
            instance.approved_by_owner_at = None
            instance.owner_notes = None
            serializer.save(status='pending', approved_by_owner_at=None, owner_notes=None)
        else:
            raise permissions.PermissionDenied("You do not have permission to update this transaction.")


    @action(detail=False, methods=['get'], permission_classes=[IsOwnerUser])
    def pending(self, request):
        pending_transactions = self.get_queryset().filter(status='pending')
        serializer = self.get_serializer(pending_transactions, many=True)
        return Response(serializer.data)

    @action(detail=False, methods=['get'], permission_classes=[IsOwnerUser])
    def rejected(self, request):
        rejected_transactions = self.get_queryset().filter(status='rejected')
        serializer = self.get_serializer(rejected_transactions, many=True)
        return Response(serializer.data)

    @action(detail=True, methods=['patch'], permission_classes=[IsOwnerUser])
    def approve(self, request, pk=None):
        try:
            transaction = self.get_queryset().get(pk=pk)
        except Transaction.DoesNotExist:
            return Response({'detail': 'မှတ်တမ်းကို ရှာမတွေ့ပါ။'}, status=status.HTTP_404_NOT_FOUND)

        if transaction.status != 'pending':
            return Response({'detail': 'ဤမှတ်တမ်းသည် စောင့်ဆိုင်းဆဲ အခြေအနေတွင် မရှိပါ။'}, status=status.HTTP_400_BAD_REQUEST)

        owner_notes = request.data.get('owner_notes')

        transaction.status = 'approved'
        transaction.approved_by_owner_at = timezone.now()
        
        if owner_notes is not None:
            transaction.owner_notes = owner_notes
        transaction.save()
        return Response(self.get_serializer(transaction).data)

    @action(detail=True, methods=['patch'], permission_classes=[IsOwnerUser])
    def reject(self, request, pk=None):
        try:
            transaction = self.get_queryset().get(pk=pk)
        except Transaction.DoesNotExist:
            return Response({'detail': 'မှတ်တမ်းကို ရှာမတွေ့ပါ။'}, status=status.HTTP_404_NOT_FOUND)

        if transaction.status != 'pending':
            return Response({'detail': 'ဤမှတ်တမ်းသည် စောင့်ဆိုင်းဆဲ အခြေအနေတွင် မရှိပါ။'}, status=status.HTTP_400_BAD_REQUEST)

        owner_notes = request.data.get('owner_notes')

        transaction.status = 'rejected'
        transaction.approved_by_owner_at = timezone.now()
        if owner_notes is not None:
            transaction.owner_notes = owner_notes
        transaction.save()
        return Response(self.get_serializer(transaction).data)
    
    @action(detail=True, methods=['post'], permission_classes=[IsAuditorUser])
    def re_submit(self, request, pk=None):
        transaction = self.get_object()
        if transaction.status == 'rejected':
            transaction.status = 'pending'
            transaction.rejection_reason = None # Clear rejection reason
            transaction.audited_by = None # Clear auditor if needed for re-audit
            transaction.save()
            serializer = self.get_serializer(transaction)
            return Response(serializer.data, status=status.HTTP_200_OK)
        return Response(
            {"detail": "Transaction is not in 'rejected' status or cannot be re-submitted."},
            status=status.HTTP_400_BAD_REQUEST
        )

    @action(detail=False, methods=['get'], permission_classes=[IsOwnerUser])
    def summary(self, request):
        total_income = Transaction.objects.filter(
            transaction_type='income', status='approved'
        ).aggregate(sum_amount=Coalesce(Sum('amount'), Decimal('0.00')))['sum_amount']

        total_expense = Transaction.objects.filter(
            transaction_type='expense', status='approved'
        ).aggregate(sum_amount=Coalesce(Sum('amount'), Decimal('0.00')))['sum_amount']

        group_summary_data = Transaction.objects.filter(status='approved') \
            .values('group__name', 'group__target_amount') \
            .annotate(
                total_income=Sum(
                    Case(
                        When(transaction_type='income', then=F('amount')),
                        default=Decimal('0.00'),
                        output_field=DecimalField()
                    )
                ),
                total_expense=Sum(
                    Case(
                        When(transaction_type='expense', then=F('amount')),
                        default=Decimal('0.00'),
                        output_field=DecimalField()
                    )
                ),
                balance=Sum(
                    Case(
                        When(transaction_type='income', then=F('amount')),
                        When(transaction_type='expense', then=-F('amount')),
                        default=Decimal('0.00'),
                        output_field=DecimalField()
                    )
                )
            ) \
            .order_by('group__name')

        final_group_summary_data = []
        for item in group_summary_data:
            collected_amount = item['total_income'] or Decimal('0.00')
            target_amount = item['group__target_amount'] or Decimal('0.00')

            remaining_amount = Decimal('0.00')
            if target_amount > 0:
                remaining = target_amount - collected_amount
                if remaining > 0:
                    remaining_amount = remaining

            final_group_summary_data.append({
                'group_name': item['group__name'],
                'target_amount': item['group__target_amount'],
                'total_income': item['total_income'],
                'total_expense': item['total_expense'],
                'balance': item['balance'],
                'collected_amount': collected_amount,
                'remaining_amount': remaining_amount,
            })

        return Response({
            'overall_summary': {
                'total_income': total_income,
                'total_expense': total_expense,
                'net_balance': total_income - total_expense,
            },
            'group_wise_summary': final_group_summary_data
        })


class AuditEntryViewSet(viewsets.ModelViewSet):
    queryset = AuditEntry.objects.all().order_by('-created_at')
    serializer_class = AuditEntrySerializer
    http_method_names = ['get', 'post', 'put', 'patch', 'delete', 'head', 'options']

    def get_permissions(self):
        user = self.request.user
        if not user.is_authenticated:
            self.permission_classes = [IsAuthenticated]
            return [permission() for permission in self.permission_classes]

        if user.user_type == 'owner':
            self.permission_classes = [IsOwnerUser]
        elif user.user_type == 'auditor':
            if self.action == 'create':
                self.permission_classes = [IsAuditorUser]
            elif self.action in ['list', 'retrieve', 'update', 'partial_update']:
                self.permission_classes = [IsAuditorUser]
            elif self.action == 'destroy':
                self.permission_classes = [permissions.DenyAll]
            else:
                self.permission_classes = [permissions.DenyAll]
        else:
            self.permission_classes = [permissions.DenyAll]

        return [permission() for permission in self.permission_classes]

    def get_queryset(self):
        queryset = super().get_queryset()
        user = self.request.user
        
        if user.is_superuser or user.user_type == 'owner':
            return queryset
        elif user.user_type == 'auditor':
            return queryset.filter(auditor=user)
        else:
            return AuditEntry.objects.none()
            
    def perform_create(self, serializer):
        serializer.save(auditor=self.request.user)

class AuditSummaryView(APIView):
    permission_classes = [IsOwnerUser]

    def get(self, request, *args, **kwargs):
        try:
            total_income_transactions = Transaction.objects.filter(transaction_type='income').aggregate(total=Sum('amount'))['total'] or Decimal('0.00')
            total_expense_transactions = Transaction.objects.filter(transaction_type='expense').aggregate(total=Sum('amount'))['total'] or Decimal('0.00')
            total_balance = total_income_transactions - total_expense_transactions

            audited_income = Transaction.objects.filter(
                transaction_type='income', status='approved'
            ).aggregate(total=Sum('amount'))['total'] or Decimal('0.00')
            audited_expense = Transaction.objects.filter(
                transaction_type='expense', status='approved'
            ).aggregate(total=Sum('amount'))['total'] or Decimal('0.00')
            audited_balance = audited_income - audited_expense

            unapproved_income = Transaction.objects.filter(
                transaction_type='income', status='pending'
            ).aggregate(total=Sum('amount'))['total'] or Decimal('0.00')
            unapproved_expense = Transaction.objects.filter(
                transaction_type='expense', status='pending'
            ).aggregate(total=Sum('amount'))['total'] or Decimal('0.00')
            unapproved_balance = unapproved_income - unapproved_expense

            summary_data = {
                'total_income': total_income_transactions,
                'total_expense': total_expense_transactions,
                'balance': total_balance,
                'audited_income': audited_income,
                'audited_expense': audited_expense,
                'audited_balance': audited_balance,
                'unapproved_income': unapproved_income,
                'unapproved_expense': unapproved_expense,
                'unapproved_balance': unapproved_balance,
                'last_updated': timezone.now(),
            }

            serializer = AuditSummarySerializer(summary_data)
            return Response(serializer.data, status=status.HTTP_200_OK)

        except Exception as e:
            print(f"Error calculating audit summary: {e}")
            return Response(
                {"detail": "Failed to calculate audit summary."},
                status=status.HTTP_500_INTERNAL_SERVER_ERROR
            )
