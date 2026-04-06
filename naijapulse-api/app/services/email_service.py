import asyncio
import logging
import smtplib
import ssl
from email.message import EmailMessage
from email.utils import formataddr
from html import escape


logger = logging.getLogger(__name__)


class EmailService:
    def __init__(
        self,
        *,
        enabled: bool,
        smtp_host: str,
        smtp_port: int,
        smtp_username: str,
        smtp_password: str,
        smtp_security: str,
        from_address: str,
        from_name: str,
        reply_to: str,
        support_address: str,
    ) -> None:
        self._enabled = enabled and bool(smtp_host.strip() and from_address.strip())
        self._smtp_host = smtp_host.strip()
        self._smtp_port = smtp_port
        self._smtp_username = smtp_username.strip()
        self._smtp_password = smtp_password
        self._smtp_security = (smtp_security or "starttls").strip().lower()
        self._from_address = from_address.strip()
        self._from_name = from_name.strip()
        self._reply_to = reply_to.strip()
        self._support_address = support_address.strip()

    @property
    def enabled(self) -> bool:
        return self._enabled

    async def send_password_reset_email(
        self,
        *,
        to_email: str,
        recipient_name: str | None,
        reset_url: str,
        expires_minutes: int,
    ) -> bool:
        title_name = self._display_name(recipient_name, to_email)
        subject = "Reset your naijaDNA password"
        text = (
            f"Hello {title_name},\n\n"
            f"We received a request to reset your naijaDNA password.\n\n"
            f"Reset your password: {reset_url}\n\n"
            f"This link expires in {expires_minutes} minutes.\n"
            "If you did not request this, you can ignore this email.\n\n"
            f"Need help? Reply to this email or contact {self._support_address or self._from_address}.\n\n"
            "naijaDNA"
        )
        html = f"""
        <p>Hello {escape(title_name)},</p>
        <p>We received a request to reset your <strong>naijaDNA</strong> password.</p>
        <p><a href="{escape(reset_url)}">Reset your password</a></p>
        <p>This link expires in {expires_minutes} minutes.</p>
        <p>If you did not request this, you can ignore this email.</p>
        <p>Need help? Reply to this email or contact {escape(self._support_address or self._from_address)}.</p>
        <p>naijaDNA</p>
        """
        return await self._send_email(
            to_email=to_email,
            subject=subject,
            text_body=text,
            html_body=html,
        )

    async def send_password_changed_confirmation(
        self,
        *,
        to_email: str,
        recipient_name: str | None,
    ) -> bool:
        title_name = self._display_name(recipient_name, to_email)
        subject = "Your naijaDNA password was changed"
        text = (
            f"Hello {title_name},\n\n"
            "Your naijaDNA password was changed successfully.\n\n"
            "If you made this change, no further action is needed.\n"
            "If you did not make this change, reset your password immediately and contact support.\n\n"
            f"Support: {self._support_address or self._from_address}\n\n"
            "naijaDNA"
        )
        html = f"""
        <p>Hello {escape(title_name)},</p>
        <p>Your <strong>naijaDNA</strong> password was changed successfully.</p>
        <p>If you made this change, no further action is needed.</p>
        <p>If you did not make this change, reset your password immediately and contact support.</p>
        <p>Support: {escape(self._support_address or self._from_address)}</p>
        <p>naijaDNA</p>
        """
        return await self._send_email(
            to_email=to_email,
            subject=subject,
            text_body=text,
            html_body=html,
        )

    async def send_access_request_received_email(
        self,
        *,
        to_email: str,
        recipient_name: str | None,
        request_label: str,
        request_id: str,
    ) -> bool:
        title_name = self._display_name(recipient_name, to_email)
        subject = f"We received your {request_label} request"
        text = (
            f"Hello {title_name},\n\n"
            f"We received your request for {request_label}.\n"
            f"Request ID: {request_id}\n\n"
            "Our team will review it and email you once a decision is made.\n\n"
            f"If you need to add context, reply to this email or contact {self._support_address or self._from_address}.\n\n"
            "naijaDNA"
        )
        html = f"""
        <p>Hello {escape(title_name)},</p>
        <p>We received your request for <strong>{escape(request_label)}</strong>.</p>
        <p>Request ID: <strong>{escape(request_id)}</strong></p>
        <p>Our team will review it and email you once a decision is made.</p>
        <p>If you need to add context, reply to this email or contact {escape(self._support_address or self._from_address)}.</p>
        <p>naijaDNA</p>
        """
        return await self._send_email(
            to_email=to_email,
            subject=subject,
            text_body=text,
            html_body=html,
        )

    async def send_access_request_reviewed_email(
        self,
        *,
        to_email: str,
        recipient_name: str | None,
        request_label: str,
        approved: bool,
        review_note: str | None,
    ) -> bool:
        title_name = self._display_name(recipient_name, to_email)
        outcome = "approved" if approved else "rejected"
        subject = f"Your {request_label} request was {outcome}"
        note_line = ""
        if review_note and review_note.strip():
            note_line = f"\nReview note: {review_note.strip()}\n"
        text = (
            f"Hello {title_name},\n\n"
            f"Your request for {request_label} was {outcome}.\n"
            f"{note_line}\n"
            f"If you have questions, reply to this email or contact {self._support_address or self._from_address}.\n\n"
            "naijaDNA"
        )
        review_note_html = ""
        if review_note and review_note.strip():
            review_note_html = (
                f"<p><strong>Review note:</strong> {escape(review_note.strip())}</p>"
            )
        html = f"""
        <p>Hello {escape(title_name)},</p>
        <p>Your request for <strong>{escape(request_label)}</strong> was <strong>{escape(outcome)}</strong>.</p>
        {review_note_html}
        <p>If you have questions, reply to this email or contact {escape(self._support_address or self._from_address)}.</p>
        <p>naijaDNA</p>
        """
        return await self._send_email(
            to_email=to_email,
            subject=subject,
            text_body=text,
            html_body=html,
        )

    async def send_newsroom_access_approved_email(
        self,
        *,
        to_email: str,
        recipient_name: str | None,
        requested_role: str,
        setup_url: str,
        review_note: str | None,
    ) -> bool:
        title_name = self._display_name(recipient_name, to_email)
        note_block = ""
        if review_note and review_note.strip():
            note_block = f"\nReview note: {review_note.strip()}\n"
        subject = f"Your newsroom access request for {requested_role} was approved"
        text = (
            f"Hello {title_name},\n\n"
            f"Your newsroom access request for {requested_role} was approved.\n"
            "Use the link below to set your password and complete your account setup.\n\n"
            f"Complete setup: {setup_url}\n"
            f"{note_block}\n"
            f"If you have questions, reply to this email or contact {self._support_address or self._from_address}.\n\n"
            "naijaDNA"
        )
        note_html = ""
        if review_note and review_note.strip():
            note_html = (
                f"<p><strong>Review note:</strong> {escape(review_note.strip())}</p>"
            )
        html = f"""
        <p>Hello {escape(title_name)},</p>
        <p>Your newsroom access request for <strong>{escape(requested_role)}</strong> was approved.</p>
        <p>Use the link below to set your password and complete your account setup.</p>
        <p><a href="{escape(setup_url)}">Complete account setup</a></p>
        {note_html}
        <p>If you have questions, reply to this email or contact {escape(self._support_address or self._from_address)}.</p>
        <p>naijaDNA</p>
        """
        return await self._send_email(
            to_email=to_email,
            subject=subject,
            text_body=text,
            html_body=html,
        )

    async def _send_email(
        self,
        *,
        to_email: str,
        subject: str,
        text_body: str,
        html_body: str,
    ) -> bool:
        normalized_to = (to_email or "").strip()
        if not self._enabled or not normalized_to:
            return False

        message = EmailMessage()
        message["Subject"] = subject
        message["From"] = formataddr((self._from_name, self._from_address))
        message["To"] = normalized_to
        if self._reply_to:
            message["Reply-To"] = self._reply_to
        message.set_content(text_body)
        message.add_alternative(html_body, subtype="html")

        try:
            await asyncio.to_thread(self._deliver_message, message)
            return True
        except Exception:  # noqa: BLE001
            logger.exception("Failed to send transactional email to %s", normalized_to)
            return False

    def _deliver_message(self, message: EmailMessage) -> None:
        security = self._smtp_security
        if security == "ssl":
            context = ssl.create_default_context()
            with smtplib.SMTP_SSL(
                self._smtp_host,
                self._smtp_port,
                context=context,
                timeout=20,
            ) as smtp:
                self._login_if_needed(smtp)
                smtp.send_message(message)
            return

        with smtplib.SMTP(
            self._smtp_host,
            self._smtp_port,
            timeout=20,
        ) as smtp:
            if security == "starttls":
                context = ssl.create_default_context()
                smtp.starttls(context=context)
            self._login_if_needed(smtp)
            smtp.send_message(message)

    def _login_if_needed(self, smtp: smtplib.SMTP) -> None:
        if self._smtp_username and self._smtp_password:
            smtp.login(self._smtp_username, self._smtp_password)

    def _display_name(self, value: str | None, email: str) -> str:
        normalized = (value or "").strip()
        if normalized:
            return normalized
        local_part = email.split("@", 1)[0].replace(".", " ").replace("_", " ").strip()
        return local_part.title() if local_part else "there"
