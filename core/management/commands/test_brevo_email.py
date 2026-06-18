import secrets

from django.core.management.base import BaseCommand, CommandError

from core.email_delivery import EmailDeliveryError, send_verification_code


class Command(BaseCommand):
    help = "Send a real Bite Hub OTP test email through Brevo."

    def add_arguments(self, parser):
        parser.add_argument("recipient", help="Verified inbox that receives the test.")

    def handle(self, *args, **options):
        recipient = options["recipient"].strip().lower()
        code = f"{secrets.randbelow(1_000_000):06d}"
        try:
            result = send_verification_code(
                recipient_email=recipient,
                recipient_name="Bite Hub Test",
                code=code,
                purpose="login",
            )
        except EmailDeliveryError as exc:
            raise CommandError(str(exc)) from exc

        if result.debug_mode:
            raise CommandError(
                "BREVO_DEBUG_EMAIL_CODES is active and no Brevo API key is configured."
            )

        self.stdout.write(
            self.style.SUCCESS(f"Brevo accepted the test email for {recipient}.")
        )
