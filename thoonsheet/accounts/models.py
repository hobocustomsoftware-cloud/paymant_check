# accounts/models.py

from django.contrib.auth.models import AbstractUser, BaseUserManager
from django.db import models

# Custom User Manager (အမြဲတမ်း BaseUserManager ကို继承ပြီး ဖန်တီးပါ)
class UserManager(BaseUserManager):
    def create_user(self, username, email, password=None, **extra_fields):
        if not username:
            raise ValueError('The Username field must be set')
        if not email:
            raise ValueError('The Email field must be set')
        email = self.normalize_email(email)
        user = self.model(username=username, email=email, **extra_fields)
        user.set_password(password)
        user.save(using=self._db)
        return user

    def create_superuser(self, username, email, password=None, **extra_fields):
        extra_fields.setdefault('is_staff', True)
        extra_fields.setdefault('is_superuser', True)
        extra_fields.setdefault('is_active', True)

        if extra_fields.get('is_staff') is not True:
            raise ValueError('Superuser must have is_staff=True.')
        if extra_fields.get('is_superuser') is not True:
            raise ValueError('Superuser must have is_superuser=True.')
        return self.create_user(username, email, password, **extra_fields)


# Custom User Model (AbstractUser ကို 继承ပြီး ဖန်တီးပါ)
# accounts/models.py (သင့်ရဲ့ accounts app ထဲက User model)

from django.db import models
from django.contrib.auth.models import AbstractUser

class User(AbstractUser): # သင့် User model အမည်ကို သေချာစစ်ပါ (ဥပမာ: CustomUser)
    USER_TYPE_CHOICES = [
        ('owner', 'Owner'),
        ('auditor', 'Auditor'),
        # 'accountant' ကို ဖယ်ရှားထားပါသည်။
    ]
    user_type = models.CharField(max_length=20, choices=USER_TYPE_CHOICES, default='auditor', verbose_name="အသုံးပြုသူအမျိုးအစား")
    phone_number = models.CharField(max_length=20, blank=True, null=True, verbose_name="ဖုန်းနံပါတ်")

    # အခြား fields များ...

    class Meta:
        verbose_name = "အသုံးပြုသူ"
        verbose_name_plural = "အသုံးပြုသူများ"

    def __str__(self):
        return self.username

    @property
    def is_owner(self):
        return self.user_type == 'owner'

    @property
    def is_auditor(self):
        return self.user_type == 'auditor'

# အကယ်၍ သင်သည် User model ကို ပြောင်းလဲခဲ့ပါက settings.py တွင် AUTH_USER_MODEL = 'accounts.User' (သင့် model အမည်) ဟု သတ်မှတ်ထားရပါမည်။

