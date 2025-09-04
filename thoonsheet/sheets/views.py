# sheets/views.py

from decimal import Decimal
from django.forms import DecimalField
from django.shortcuts import get_object_or_404
import django_filters
from rest_framework import viewsets, status, permissions, serializers
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
    AuditSummarySerializer, ChangePasswordSerializer, GroupSerializer, OwnerApproveRejectSerializer, PaymentAccountSerializer, SetUserPasswordSerializer, TransactionSerializer,
    AuditEntrySerializer, UserSerializer # <-- UserSerializer ကို import လုပ်ထားကြောင်း သေချာပါစေ။
)
from .permissions import IsAuditorUser, IsOwnerUser, DenyAll
from django_filters.rest_framework import DjangoFilterBackend
from rest_framework.filters import OrderingFilter, SearchFilter
from rest_framework.views import APIView

# Djoser views and related imports
from djoser.views import TokenCreateView
from rest_framework.authtoken.models import Token
from rest_framework.serializers import ModelSerializer # For CustomUserSerializer if needed

from django.db.models.functions import Coalesce
from django.utils import timezone
from django.utils.dateparse import parse_date



class IsOwnerOrAuditor(permissions.BasePermission):
    def has_permission(self, request, view):
        u = request.user
        return bool(u and u.is_authenticated and getattr(u, 'user_type', None) in ('owner', 'auditor'))


class CustomTokenCreateView(TokenCreateView):
    # serializer_class = djoser.serializers.TokenCreateSerializer # Default ကို သုံးပါ
    
    def _action(self, serializer):
        # djoser ရဲ့ default _action method ကို ခေါ်ပြီး token response ကို ရယူပါ။
        token_response = super()._action(serializer) 
        token_key = token_response.data['auth_token'] # type: ignore # djoser က 'auth_token' key နဲ့ ပြန်ပေးပါတယ်။

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

        if user.user_type == 'owner': # type: ignore
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
        user_type = self.request.data.get('user_type', 'auditor') # type: ignore
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

        if user.user_type == 'owner': # type: ignore
            self.permission_classes = [IsOwnerUser]
        elif user.user_type == 'auditor': # type: ignore
            self.permission_classes = [permissions.IsAuthenticatedOrReadOnly]
        else:
            self.permission_classes = [permissions.IsAuthenticated]
        return [permission() for permission in self.permission_classes]
    
    def perform_create(self, serializer):
        serializer.save(owner=self.request.user)

# Transaction ViewSet (Owner: List, Edit, Delete / Auditor: Create, List, Edit (rejected only))

class TransactionFilter(django_filters.FilterSet):
    # /transactions/?transaction_date_after=YYYY-MM-DD&transaction_date_before=YYYY-MM-DD
    transaction_date = django_filters.DateFromToRangeFilter(
        field_name='transaction_date', label='Transaction Date Range'
    )
    transfer_id_last_6_digits = django_filters.CharFilter(max_length=6)

    class Meta:
        model = Transaction
        fields = [
            'transaction_date', 'transfer_id_last_6_digits',
            'status', 'transaction_type', 'group', 'payment_account', 'submitted_by'
        ]




class TransactionViewSet(viewsets.ModelViewSet):
    queryset = Transaction.objects.all().order_by('-submitted_at')
    serializer_class = TransactionSerializer
    parser_classes = [MultiPartParser, FormParser, JSONParser]
    http_method_names = ['get', 'post', 'put', 'patch', 'delete', 'head', 'options']

    # ---- Filters for frontend duplicate & convenience ----
    filter_backends = [DjangoFilterBackend, OrderingFilter, SearchFilter]
    filterset_fields = ['transfer_id_last_6_digits', 'status', 'transaction_type',
                        'submitted_by', 'payment_account', 'group', 'transaction_date']
    ordering_fields = ['submitted_at', 'transaction_date', 'amount']
    search_fields = ['transfer_id_last_6_digits', 'owner_notes']
    filterset_class = TransactionFilter

    def get_permissions(self):
        user = self.request.user
        if not user.is_authenticated:
            self.permission_classes = [permissions.IsAuthenticated]
        else:
            if user.user_type == 'owner': # type: ignore
                self.permission_classes = [IsOwnerUser]
            elif user.user_type == 'auditor': # type: ignore
                # auditor can: create/list/retrieve/update(re-submit rejected), but not destroy
                if self.action in ['create', 'list', 'retrieve', 'update', 'partial_update', 're_submit']:
                    self.permission_classes = [IsAuditorUser]
                elif self.action in ['destroy']:
                    self.permission_classes = [DenyAll]
                else:
                    self.permission_classes = [DenyAll]
            else:
                self.permission_classes = [DenyAll]

            # owner-only custom actions
            if self.action in ['approve', 'reject', 'summary', 'pending', 'rejected']:
                self.permission_classes = [IsOwnerUser]

        return [pc() for pc in self.permission_classes]

    def get_queryset(self):
        qs = super().get_queryset()
        user = self.request.user
        if not user.is_authenticated:
            return Transaction.objects.none()
        if user.is_superuser or user.user_type == 'owner':
            return qs
        if user.user_type == 'auditor':
            return qs.filter(submitted_by=user)
        return Transaction.objects.none()

    def perform_create(self, serializer):
        # submitted_by ကို serializer.create() ထဲမှာလည်း handle လုပ်ထားလို့ပါ—but double set OK
        serializer.save(submitted_by=self.request.user)

    def perform_update(self, serializer):
        user = self.request.user
        instance = serializer.instance

        if user.user_type == 'owner': # type: ignore
            serializer.save()
            return

        if user.user_type == 'auditor': # type: ignore
            if instance.submitted_by != user:
                raise permissions.PermissionDenied("You can only update your own transactions.") # type: ignore
            if instance.status != 'rejected':
                raise permissions.PermissionDenied("You can only re-submit rejected transactions.") # type: ignore
            # Re-submit as pending; owner review info clear
            serializer.save(status='pending', approved_by_owner_at=None, owner_notes=None)
            return

        raise permissions.PermissionDenied("You do not have permission to update this transaction.") # type: ignore

    # -------- Owner-only listing shortcuts --------
    @action(detail=True, methods=['get'])
    def pending(self, request):
        pending_transactions = self.get_queryset().filter(status='pending')
        ser = self.get_serializer(pending_transactions, many=True)
        return Response(ser.data)

    @action(detail=True, methods=['get'])
    def rejected(self, request, pk=None):
        rejected_transactions = self.get_queryset().filter(status='rejected')
        ser = self.get_serializer(rejected_transactions, many=True)
        return Response(ser.data)

    # -------- Approve / Reject (owner) --------
    @action(detail=True, methods=['patch', 'post'], permission_classes=[IsOwnerUser])
    def approve(self, request, pk=None):
        tx = self.get_queryset().filter(pk=pk).first()
        if not tx:
            return Response({'detail': 'မှတ်တမ်းကို ရှာမတွေ့ပါ။'}, status=status.HTTP_404_NOT_FOUND)
        if tx.status != 'pending':
            return Response({'detail': 'ဤမှတ်တမ်းသည် စောင့်ဆိုင်းဆဲ အခြေအနေတွင် မရှိပါ။'}, status=status.HTTP_400_BAD_REQUEST)
        owner_notes = request.data.get('owner_notes')
        tx.status = 'approved'
        tx.approved_by_owner_at = timezone.now()
        if owner_notes is not None:
            tx.owner_notes = owner_notes
        tx.save()
        return Response(self.get_serializer(tx).data)

    @action(detail=True, methods=['patch', 'post'], permission_classes=[IsOwnerUser])
    def reject(self, request, pk=None):
        tx = self.get_queryset().filter(pk=pk).first()
        if not tx:
            return Response({'detail': 'မှတ်တမ်းကို ရှာမတွေ့ပါ။'}, status=status.HTTP_404_NOT_FOUND)
        if tx.status != 'pending':
            return Response({'detail': 'ဤမှတ်တမ်းသည် စောင့်ဆိုင်းဆဲ အခြေအနေတွင် မရှိပါ။'}, status=status.HTTP_400_BAD_REQUEST)
        owner_notes = request.data.get('owner_notes')
        tx.status = 'rejected'
        # reject မှာ approved_by_owner_at မသတ်မှတ်
        if owner_notes is not None:
            tx.owner_notes = owner_notes
        tx.save()
        return Response(self.get_serializer(tx).data)

    # -------- Auditor re-submit endpoint (optional; update() နဲ့လည်း ရ) --------
    @action(detail=True, methods=['post'])
    def re_submit(self, request, pk=None):
        tx = self.get_object()  # get_queryset() + permissions already applied
        if request.user.user_type != 'auditor':
            return Response({"detail": "Only auditor can re-submit."}, status=status.HTTP_403_FORBIDDEN)
        if tx.submitted_by != request.user:
            return Response({"detail": "You can only re-submit your own transactions."}, status=status.HTTP_403_FORBIDDEN)
        if tx.status != 'rejected':
            return Response({"detail": "Transaction is not in 'rejected' status."}, status=status.HTTP_400_BAD_REQUEST)

        tx.status = 'pending'
        tx.approved_by_owner_at = None
        tx.owner_notes = None
        tx.save()
        return Response(self.get_serializer(tx).data, status=status.HTTP_200_OK)

    # -------- Summary (owner) --------
    @action(
        detail=True,
        methods=['get'],
        url_path='summary',
        permission_classes=[IsOwnerOrAuditor],          # Owner/Auditor နှစ်ဦးစလုံးရှုနိုင်
    )
    def summary(self, request):
        # Query params
        period = (request.query_params.get('period') or 'daily').lower()
        start = request.query_params.get('start')
        end = request.query_params.get('end')

        # သင့် model ရဲ့ ရက်စွဲ field အမည်ကို အတိအကျ ထည့်ပါ
        date_field = 'entry_date'  # <-- အကယ်၍ 'created_at' ဆိုရင် ဒီလိုပြောင်း

        qs = self.get_queryset()
        if start:
            d = parse_date(start)
            if d:
                qs = qs.filter(**{f'{date_field}__gte': d})
        if end:
            d = parse_date(end)
            if d:
                qs = qs.filter(**{f'{date_field}__lte': d})

        # Grouping period
        if period == 'weekly':
            trunc = TruncWeek(date_field)
        elif period == 'monthly':
            trunc = TruncMonth(date_field)
        elif period == 'yearly':
            trunc = TruncYear(date_field)
        else:
            trunc = TruncDay(date_field)

        data = (qs
            .annotate(bucket=trunc)
            .values('bucket')
            .annotate(
                total_amount=Coalesce(Sum('amount'), Decimal('0.00')),
                total_count=Coalesce(Sum(Case(When(id__isnull=False, then=1),
                default=0, output_field=DecimalField())), Decimal('0.00')),
                total_receive=Coalesce(Sum(Case(
                    When(entry_type='receive', then=F('amount')),
                    default=Decimal('0.00'), output_field=DecimalField()
                )), Decimal('0.00')),
                total_pay=Coalesce(Sum(Case(
                    When(entry_type='pay', then=F('amount')),
                    default=Decimal('0.00'), output_field=DecimalField()
                )), Decimal('0.00')),
            )
            .order_by('bucket')
        )

        # DRF JSON response
        return Response({
            'period': period,
            'results': [
                {
                    'period_start': row['bucket'],
                    'total_amount': row['total_amount'],
                    'total_count': int(row['total_count']),  # Decimal → int
                    'total_receive': row['total_receive'],
                    'total_pay': row['total_pay'],
                } for row in data
            ]
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

        if user.user_type == 'owner': # type: ignore
            self.permission_classes = [IsOwnerUser]
        elif user.user_type == 'auditor': # type: ignore
            if self.action == 'create':
                self.permission_classes = [IsAuditorUser]
            elif self.action in ['list', 'retrieve', 'update', 'partial_update']:
                self.permission_classes = [IsAuditorUser]
            elif self.action == 'destroy':
                self.permission_classes = [DenyAll]
            else:
                self.permission_classes = [DenyAll]
        else:
            self.permission_classes = [DenyAll]

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


class PasswordChangeView(APIView):
    permission_classes = [IsAuthenticated]

    def post(self, request):
        user = request.user
        target_user_id = request.data.get('user_id')
        new_password = request.data.get('new_password')

        if not new_password:
            return Response({'detail': 'New password is required.'}, status=status.HTTP_400_BAD_REQUEST)

        if target_user_id:
            if user.is_superuser or user.user_type == 'owner':
                try:
                    target_user = User.objects.get(id=target_user_id)
                except User.DoesNotExist:
                    return Response({'detail': 'User not found.'}, status=status.HTTP_404_NOT_FOUND)
            else:
                return Response({'detail': 'You do not have permission to change this password.'}, status=status.HTTP_403_FORBIDDEN)
        else:
            target_user = user

        if user.user_type == 'auditor' and target_user != user:
            return Response({'detail': 'Auditors can only change their own password.'}, status=status.HTTP_403_FORBIDDEN)

        target_user.set_password(new_password)
        target_user.save()
        return Response({'detail': 'Password updated successfully.'})

class AuditSummaryView(APIView):
    permission_classes = [IsOwnerOrAuditor]  # type: ignore # ← Auditor & Owner လိုသလိုခေါ်နိုင်

    def get(self, request, *args, **kwargs):
        try:
            # optional date filters: ?start=YYYY-MM-DD&end=YYYY-MM-DD
            start = request.query_params.get('start')
            end = request.query_params.get('end')
            start_d = parse_date(start) if start else None
            end_d = parse_date(end) if end else None

            qs = Transaction.objects.all()
            if start_d:
                qs = qs.filter(transaction_date__gte=start_d)
            if end_d:
                qs = qs.filter(transaction_date__lte=end_d)

            def agg(q):
                return q.aggregate(total=Coalesce(Sum('amount'), Decimal('0.00')))['total']

            total_income_transactions = agg(qs.filter(transaction_type='income'))
            total_expense_transactions = agg(qs.filter(transaction_type='expense'))
            total_balance = total_income_transactions - total_expense_transactions

            audited_income = agg(qs.filter(transaction_type='income', status='approved'))
            audited_expense = agg(qs.filter(transaction_type='expense', status='approved'))
            audited_balance = audited_income - audited_expense

            unapproved_income = agg(qs.filter(transaction_type='income', status='pending'))
            unapproved_expense = agg(qs.filter(transaction_type='expense', status='pending'))
            unapproved_balance = unapproved_income - unapproved_expense

            payload = {
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
            return Response(AuditSummarySerializer(payload).data, status=status.HTTP_200_OK)

        except Exception as e:
            print(f"Error calculating audit summary: {e}")
            return Response(
                {"detail": "Failed to calculate audit summary."},
                status=status.HTTP_500_INTERNAL_SERVER_ERROR
            )


class ChangePasswordView(APIView):
    """
    POST /api/auth/password/change/
    body: {old_password, new_password, new_password2}
    auth: Token <token>
    """
    permission_classes = [permissions.IsAuthenticated]

    def post(self, request):
        ser = ChangePasswordSerializer(data=request.data, context={'request': request})
        ser.is_valid(raise_exception=True)

        user = request.user
        user.set_password(ser.validated_data['new_password']) # type: ignore
        user.last_login = timezone.now()
        user.save()

        # Token rotation: ဟောင်း token ရုပ်သိမ်း၊ အသစ်ထုတ်
        Token.objects.filter(user=user).delete()
        new_token = Token.objects.create(user=user)

        return Response(
            {'detail': 'စကားဝှက် ပြောင်းလဲပြီးပါပြီ။', 'auth_token': new_token.key},
            status=status.HTTP_200_OK
        )


class SetUserPasswordView(APIView):
    """
    POST /api/auth/users/<id>/password/
    body: {new_password, new_password2}
    auth: owner/admin only
    """
    # owner သာခွင့် – admin သတ်မှတ်ထားရင် IsAdminUser သို့မဟုတ် OR ပြုလုပ်နိုင်
    permission_classes = [IsOwnerUser]

    def post(self, request, pk):
        user = get_object_or_404(User, pk=pk)
        ser = SetUserPasswordSerializer(data=request.data)
        ser.is_valid(raise_exception=True)

        user.set_password(ser.validated_data['new_password']) # type: ignore
        user.save()

        # revoke all existing tokens for that user
        Token.objects.filter(user=user).delete()

        return Response(
            {'detail': 'စကားဝှက် အသစ် သတ်မှတ်ပြီးပါပြီ (အသုံးပြုသူမှ ပြန်လော့ဂ်အင် လုပ်ပါ)'},
            status=status.HTTP_200_OK
        )