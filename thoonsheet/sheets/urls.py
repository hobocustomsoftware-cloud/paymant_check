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
)

router = DefaultRouter()
router.register(r'payment-accounts', PaymentAccountViewSet)
router.register(r'groups', GroupViewSet)
router.register(r'audit-entries', AuditEntryViewSet) # For Auditor's manual AuditEntry management
router.register(r'transactions', TransactionViewSet)

urlpatterns = [
    path('', include(router.urls)),
    path('audit-summary/', views.AuditSummaryView.as_view(), name='audit_summary'),
    
]