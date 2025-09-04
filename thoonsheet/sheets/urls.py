# core/urls.py
from django.urls import path, include
from rest_framework.routers import DefaultRouter
from . import views

from .views import (
    AuditSummaryView,
    PaymentAccountViewSet,
    GroupViewSet,
    AuditEntryViewSet,
    TransactionViewSet,
    # ChangePasswordView,
    # SetUserPasswordView
)



router = DefaultRouter()
router.register(r'payment-accounts', PaymentAccountViewSet)
router.register(r'groups', GroupViewSet)
router.register(r'audit-entries', AuditEntryViewSet) # For Auditor's manual AuditEntry management
router.register(r'transactions', TransactionViewSet)

urlpatterns = [
    path('', include(router.urls)),
    # path('audit-entries/summary/', views.AuditSummaryView.as_view(), name='audit_summary',),
    path('api/change-password/', views.ChangePasswordView.as_view(), name='change_password'),
    path('api/users/<int:pk>/password/', views.SetUserPasswordView.as_view(), name='change_password'),
]