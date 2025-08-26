# sheets/models.py

from django.db import models
from django.contrib.auth import get_user_model

User = get_user_model()

class Group(models.Model):
    owner = models.ForeignKey(User, on_delete=models.CASCADE, limit_choices_to={'user_type': 'owner'}, verbose_name="ပိုင်ရှင်")
    group_title = models.CharField(max_length=255, verbose_name="အဖွဲ့ခေါင်းစဉ်")
    group_type = models.CharField(max_length=255, verbose_name="အဖွဲ့အမျိုးအစား")
    name = models.CharField(max_length=255, verbose_name="အမည်")
    created_at = models.DateTimeField(auto_now_add=True, verbose_name="ဖန်တီးသည့်အချိန်")
    updated_at = models.DateTimeField(auto_now=True, verbose_name="နောက်ဆုံးပြင်ဆင်သည့်အချိန်")

    class Meta:
        verbose_name = "အဖွဲ့"
        verbose_name_plural = "အဖွဲ့များ"
        ordering = ['name']

    def __str__(self):
        owner_username = self.owner.username if self.owner else "N/A"
        return f"{self.group_title} ({self.group_type}) - Name: {self.name}"

class AuditEntry(models.Model):
    group = models.ForeignKey(Group, on_delete=models.CASCADE, verbose_name="အဖွဲ့")
    auditor = models.ForeignKey(User, on_delete=models.CASCADE, limit_choices_to={'user_type': 'auditor'}, verbose_name="စစ်ဆေးသူ")
    receivable_amount = models.DecimalField(max_digits=10, decimal_places=2, default=0.00, verbose_name="ရရန်ပမာဏ")
    payable_amount = models.DecimalField(max_digits=10, decimal_places=2, default=0.00, verbose_name="ပေးရန်ပမာဏ")
    remarks = models.TextField(blank=True, null=True, verbose_name="မှတ်ချက်")
    created_at = models.DateTimeField(auto_now_add=True, verbose_name="ဖန်တီးသည့်အချိန်")
    last_updated = models.DateTimeField(auto_now=True, verbose_name="နောက်ဆုံးပြင်ဆင်သည့်အချိန်")

    def __str__(self):
        return f"Audit by {self.auditor.username} for {self.group.name} on {self.created_at.date()}"
    
    class Meta:
        ordering = ['-created_at']
        verbose_name = "စာရင်းစစ်မှတ်တမ်း"
        verbose_name_plural = "စာရင်းစစ်မှတ်တမ်းများ"

class PaymentAccount(models.Model):
    owner = models.ForeignKey(User, on_delete=models.CASCADE, limit_choices_to={'user_type': 'owner'}, verbose_name="ပိုင်ရှင်")
    payment_account_name = models.CharField(max_length=100, help_text="kpay, wavepay,bank etc.. ဖွင့်ထားသောအမည်", verbose_name="အကောင့်အမည်")
    payment_account_type = models.CharField(max_length=100, help_text="payment account အမျိုးအစား(ဥပမာ- kpay, wavepay, bank etc..)", verbose_name="အကောင့်အမျိုးအစား")
    bank_name = models.CharField(max_length=100, blank=True, null=True, verbose_name="ဘဏ်အမည်")
    bank_account_number = models.CharField(max_length=100, blank=True, null=True, verbose_name="ဘဏ်အကောင့်နံပါတ်")
    phone_number = models.CharField(max_length=255, blank=True, null=True, verbose_name="ဖုန်းနံပါတ်")
    created_at = models.DateTimeField(auto_now_add=True, verbose_name="ဖန်တီးသည့်အချိန်")
    updated_at = models.DateTimeField(auto_now=True, verbose_name="နောက်ဆုံးပြင်ဆင်သည့်အချိန်")

    class Meta:
        verbose_name = "ငွေပေးချေမှုအကောင့်"
        verbose_name_plural = "ငွေပေးချေမှုအကောင့်များ"
        ordering = ['payment_account_name']

    def __str__(self):
        owner_username = self.owner.username if self.owner else "N/A"
        return f"{self.payment_account_name} ({self.payment_account_type})"


class Transaction(models.Model):
    STATUS_CHOICES = [
        ('pending', 'စောင့်ဆိုင်းဆဲ'),
        ('approved', 'အတည်ပြုပြီး'),
        ('rejected', 'ပယ်ချပြီး'),
    ]

    TRANSACTION_TYPE_CHOICES = [
        ('income', 'ဝင်ငွေ'),
        ('expense', 'ထွက်ငွေ'),
    ]

    submitted_by = models.ForeignKey(User, on_delete=models.CASCADE, related_name='sheets_submitted_transactions', verbose_name="တင်ပြသူ")
    transaction_date = models.DateField(verbose_name="ငွေပေးချေမှုနေ့စွဲ")
    group = models.ForeignKey(Group, on_delete=models.CASCADE, verbose_name="အဖွဲ့")
    payment_account = models.ForeignKey(PaymentAccount, on_delete=models.CASCADE, verbose_name="ငွေပေးချေမှုအကောင့်")
    transfer_id_last_6_digits = models.CharField(max_length=6, verbose_name="Transaction ID (နောက်ဆုံး ၆ လုံး)")
    amount = models.DecimalField(max_digits=15, decimal_places=2, verbose_name="ပမာဏ")
    transaction_type = models.CharField(
        max_length=10, choices=TRANSACTION_TYPE_CHOICES, default='income', verbose_name="မှတ်တမ်းအမျိုးအစား"
    )
    image = models.ImageField(upload_to='transaction_images/', null=True, blank=True, verbose_name="ပုံ") # Make sure this is 'transaction_images/'
    submitted_at = models.DateTimeField(auto_now_add=True, verbose_name="တင်ပြသည့်အချိန်")

    status = models.CharField(
        max_length=10, choices=STATUS_CHOICES, default='pending', verbose_name="အခြေအနေ"
    )
    approved_by_owner_at = models.DateTimeField(null=True, blank=True, verbose_name="ပိုင်ရှင်မှအတည်ပြုသည့်အချိန်")
    owner_notes = models.TextField(null=True, blank=True, verbose_name="ပိုင်ရှင်မှတ်ချက်")

    class Meta:
        unique_together = ('transfer_id_last_6_digits', 'payment_account')
        ordering = ['-submitted_at']
        verbose_name = "Sheets ငွေပေးချေမှုမှတ်တမ်း"
        verbose_name_plural = "Sheets ငွေပေးချေမှုမှတ်တမ်းများ"

    def __str__(self):
        return f"{self.payment_account.payment_account_name} - {self.transfer_id_last_6_digits} - {self.amount} ({self.get_transaction_type_display()})"
    
    @property
    def imageURL(self):
        try:
            url = self.image.url
        except:
            url = ''
        return url


    def image_tag(self):
        return mark_safe('<img src="%s" width="520px" height="1400px" />'%(self.image.url))
    image_tag.short_description = 'Image'
