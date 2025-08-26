# accounts/urls.py
from django.urls import path, include
from rest_framework.routers import DefaultRouter
from rest_framework_simplejwt.views import TokenRefreshView

from .views import MyTokenObtainPairView, UserViewSet

router = DefaultRouter()
router.register(r'users', UserViewSet) # /api/auth/users/

urlpatterns = [
    path('', include(router.urls)), # Includes /api/auth/users/, /api/auth/users/{id}/
    # path('users/me/', UserViewSet.as_view({'get': 'me', 'put': 'me', 'patch': 'me', 'delete': 'me'}), name='user-me'),
    path('', include('djoser.urls')),
    # path('', include('djoser.urls.jwt')),
    
    path('token/', MyTokenObtainPairView.as_view(), name='token_obtain_pair'), # /api/auth/token/
    path('token/refresh/', TokenRefreshView.as_view(), name='token_refresh'), # /api/auth/token/refresh/
]