from django.dispatch import receiver
from django.db.models.signals import post_save
from sheets.models import Transaction


@receiver(post_save, sender=Transaction)
def update_audit_entry_on_transaction_save(sender, instance, created, **kwargs):
    # This signal could trigger updates to a related AuditEntry
    # For now, we'll keep it simple and assume audit entries are created/updated explicitly.
    # If an audit entry needs to be automatically created/updated based on transactions,
    # this is where the logic would go.
    pass
