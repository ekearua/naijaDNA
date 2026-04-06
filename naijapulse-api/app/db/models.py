from datetime import datetime

from sqlalchemy import (
    Boolean,
    DateTime,
    Float,
    ForeignKey,
    Integer,
    String,
    Text,
    UniqueConstraint,
)
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.db.base import Base


class NewsArticleRecord(Base):
    __tablename__ = "news_articles"

    id: Mapped[str] = mapped_column(String(96), primary_key=True)
    fingerprint: Mapped[str] = mapped_column(String(40), unique=True, index=True)
    ingestion_provider: Mapped[str | None] = mapped_column(
        String(80),
        nullable=True,
        index=True,
    )
    title: Mapped[str] = mapped_column(String(500))
    source: Mapped[str] = mapped_column(String(255))
    category: Mapped[str] = mapped_column(String(120), index=True)
    summary: Mapped[str | None] = mapped_column(Text(), nullable=True)
    url: Mapped[str | None] = mapped_column(Text(), nullable=True)
    source_domain: Mapped[str | None] = mapped_column(String(255), nullable=True, index=True)
    source_type: Mapped[str] = mapped_column(String(64), default="rss", index=True)
    image_url: Mapped[str | None] = mapped_column(Text(), nullable=True)
    submitted_by: Mapped[str | None] = mapped_column(
        String(128),
        ForeignKey("users.id", ondelete="SET NULL"),
        nullable=True,
        index=True,
    )
    created_by_user_id: Mapped[str | None] = mapped_column(
        String(128),
        ForeignKey("users.id", ondelete="SET NULL"),
        nullable=True,
        index=True,
    )
    reviewed_by_user_id: Mapped[str | None] = mapped_column(
        String(128),
        ForeignKey("users.id", ondelete="SET NULL"),
        nullable=True,
        index=True,
    )
    published_by_user_id: Mapped[str | None] = mapped_column(
        String(128),
        ForeignKey("users.id", ondelete="SET NULL"),
        nullable=True,
        index=True,
    )
    is_user_generated: Mapped[bool] = mapped_column(Boolean(), default=False, index=True)
    status: Mapped[str] = mapped_column(String(32), default="published", index=True)
    verification_status: Mapped[str] = mapped_column(
        String(32),
        default="unverified",
        index=True,
    )
    is_featured: Mapped[bool] = mapped_column(Boolean(), default=False, index=True)
    review_notes: Mapped[str | None] = mapped_column(Text(), nullable=True)
    published_at: Mapped[datetime] = mapped_column(DateTime(timezone=False), index=True)
    fact_checked: Mapped[bool] = mapped_column(Boolean(), default=False)
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=False), default=datetime.utcnow)
    updated_at: Mapped[datetime] = mapped_column(DateTime(timezone=False), default=datetime.utcnow)

    bookmarks: Mapped[list["UserBookmarkRecord"]] = relationship(
        back_populates="article",
        cascade="all, delete-orphan",
        passive_deletes=True,
    )
    feed_events: Mapped[list["FeedEventRecord"]] = relationship(
        back_populates="article",
        cascade="all, delete-orphan",
        passive_deletes=True,
    )
    hidden_by_users: Mapped[list["UserHiddenItemRecord"]] = relationship(
        back_populates="article",
        cascade="all, delete-orphan",
        passive_deletes=True,
    )
    submitter: Mapped["UserRecord | None"] = relationship(
        foreign_keys=[submitted_by],
        back_populates="submitted_articles",
    )
    workflow_events: Mapped[list["ArticleWorkflowEventRecord"]] = relationship(
        back_populates="article",
        cascade="all, delete-orphan",
        passive_deletes=True,
        order_by="ArticleWorkflowEventRecord.created_at.desc()",
    )
    comments: Mapped[list["ArticleCommentRecord"]] = relationship(
        back_populates="article",
        cascade="all, delete-orphan",
        passive_deletes=True,
        order_by="ArticleCommentRecord.created_at.asc()",
    )
    notifications: Mapped[list["NotificationRecord"]] = relationship(
        back_populates="article",
        cascade="all, delete-orphan",
        passive_deletes=True,
    )
    tags: Mapped[list["ArticleTagRecord"]] = relationship(
        back_populates="article",
        cascade="all, delete-orphan",
        passive_deletes=True,
        lazy="selectin",
        order_by="ArticleTagRecord.tag.asc()",
    )


class ArticleTagRecord(Base):
    __tablename__ = "article_tags"
    __table_args__ = (
        UniqueConstraint(
            "article_id",
            "normalized_tag",
            name="uq_article_tags_article_normalized_tag",
        ),
    )

    id: Mapped[int] = mapped_column(Integer(), primary_key=True, autoincrement=True)
    article_id: Mapped[str] = mapped_column(
        String(96),
        ForeignKey("news_articles.id", ondelete="CASCADE"),
        nullable=False,
        index=True,
    )
    tag: Mapped[str] = mapped_column(String(120), nullable=False)
    normalized_tag: Mapped[str] = mapped_column(String(120), nullable=False, index=True)
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=False), default=datetime.utcnow)

    article: Mapped[NewsArticleRecord] = relationship(back_populates="tags")


class NewsSourceRecord(Base):
    __tablename__ = "news_sources"

    id: Mapped[str] = mapped_column(String(80), primary_key=True)
    name: Mapped[str] = mapped_column(String(255))
    type: Mapped[str] = mapped_column(String(80))
    country: Mapped[str | None] = mapped_column(String(8), nullable=True)
    enabled: Mapped[bool] = mapped_column(Boolean(), default=True)
    requires_api_key: Mapped[bool] = mapped_column(Boolean(), default=False)
    configured: Mapped[bool] = mapped_column(Boolean(), default=False)
    feed_url: Mapped[str | None] = mapped_column(Text(), nullable=True)
    api_base_url: Mapped[str | None] = mapped_column(Text(), nullable=True)
    poll_interval_sec: Mapped[int] = mapped_column(Integer(), default=900)
    last_run_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=False), nullable=True)
    notes: Mapped[str | None] = mapped_column(Text(), nullable=True)


class CategoryRecord(Base):
    __tablename__ = "categories"

    id: Mapped[str] = mapped_column(String(80), primary_key=True)
    name: Mapped[str] = mapped_column(String(120), unique=True, index=True)
    color_hex: Mapped[str | None] = mapped_column(String(7), nullable=True)
    description: Mapped[str | None] = mapped_column(Text(), nullable=True)
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=False), default=datetime.utcnow)

    polls: Mapped[list["PollRecord"]] = relationship(back_populates="category")
    user_interests: Mapped[list["UserCategoryInterestRecord"]] = relationship(
        back_populates="category",
        cascade="all, delete-orphan",
        passive_deletes=True,
    )
    personalized_interests: Mapped[list["UserInterestProfileRecord"]] = relationship(
        back_populates="category",
        cascade="all, delete-orphan",
        passive_deletes=True,
    )
    hidden_items: Mapped[list["UserHiddenItemRecord"]] = relationship(
        back_populates="category",
        cascade="all, delete-orphan",
        passive_deletes=True,
    )


class FeedTagRecord(Base):
    __tablename__ = "feed_tags"

    id: Mapped[str] = mapped_column(String(80), primary_key=True)
    name: Mapped[str] = mapped_column(String(120), unique=True, index=True)
    color_hex: Mapped[str | None] = mapped_column(String(7), nullable=True)
    description: Mapped[str | None] = mapped_column(Text(), nullable=True)
    position: Mapped[int] = mapped_column(Integer(), default=0, index=True)
    is_active: Mapped[bool] = mapped_column(Boolean(), default=True, index=True)
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=False), default=datetime.utcnow)


class HomepageCategoryRecord(Base):
    __tablename__ = "homepage_categories"

    id: Mapped[str] = mapped_column(String(80), primary_key=True)
    label: Mapped[str] = mapped_column(String(120))
    color_hex: Mapped[str | None] = mapped_column(String(7), nullable=True)
    position: Mapped[int] = mapped_column(Integer(), default=0, index=True)
    enabled: Mapped[bool] = mapped_column(Boolean(), default=True, index=True)
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=False), default=datetime.utcnow)
    updated_at: Mapped[datetime] = mapped_column(DateTime(timezone=False), default=datetime.utcnow)


class HomepageSecondaryChipRecord(Base):
    __tablename__ = "homepage_secondary_chips"

    id: Mapped[str] = mapped_column(String(80), primary_key=True)
    label: Mapped[str] = mapped_column(String(120))
    chip_type: Mapped[str] = mapped_column(String(32), index=True)
    color_hex: Mapped[str | None] = mapped_column(String(7), nullable=True)
    position: Mapped[int] = mapped_column(Integer(), default=0, index=True)
    enabled: Mapped[bool] = mapped_column(Boolean(), default=True, index=True)
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=False), default=datetime.utcnow)
    updated_at: Mapped[datetime] = mapped_column(DateTime(timezone=False), default=datetime.utcnow)


class HomepageStoryPlacementRecord(Base):
    __tablename__ = "homepage_story_placements"
    __table_args__ = (
        UniqueConstraint(
            "article_id",
            "section",
            "target_key",
            name="uq_homepage_story_section_target",
        ),
    )

    id: Mapped[int] = mapped_column(Integer(), primary_key=True, autoincrement=True)
    article_id: Mapped[str] = mapped_column(
        String(96),
        ForeignKey("news_articles.id", ondelete="CASCADE"),
        index=True,
    )
    section: Mapped[str] = mapped_column(String(32), index=True)
    target_key: Mapped[str | None] = mapped_column(String(80), nullable=True, index=True)
    position: Mapped[int] = mapped_column(Integer(), default=0, index=True)
    enabled: Mapped[bool] = mapped_column(Boolean(), default=True, index=True)
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=False), default=datetime.utcnow)
    updated_at: Mapped[datetime] = mapped_column(DateTime(timezone=False), default=datetime.utcnow)

    article: Mapped[NewsArticleRecord] = relationship()


class UserRecord(Base):
    __tablename__ = "users"

    id: Mapped[str] = mapped_column(String(128), primary_key=True)
    email: Mapped[str | None] = mapped_column(String(255), nullable=True, unique=True, index=True)
    password_hash: Mapped[str | None] = mapped_column(String(512), nullable=True)
    display_name: Mapped[str | None] = mapped_column(String(120), nullable=True)
    avatar_url: Mapped[str | None] = mapped_column(Text(), nullable=True)
    is_active: Mapped[bool] = mapped_column(Boolean(), default=True)
    role: Mapped[str] = mapped_column(String(32), default="user", index=True)
    subscription_tier: Mapped[str] = mapped_column(String(32), default="free")
    stream_access_granted: Mapped[bool] = mapped_column(Boolean(), default=False)
    stream_hosting_granted: Mapped[bool] = mapped_column(Boolean(), default=False)
    contribution_access_granted: Mapped[bool] = mapped_column(Boolean(), default=False)
    billing_provider: Mapped[str | None] = mapped_column(String(32), nullable=True)
    provider_customer_id: Mapped[str | None] = mapped_column(String(255), nullable=True)
    provider_subscription_id: Mapped[str | None] = mapped_column(
        String(255), nullable=True
    )
    subscription_status: Mapped[str] = mapped_column(
        String(32), default="inactive", index=True
    )
    current_period_start: Mapped[datetime | None] = mapped_column(
        DateTime(timezone=False),
        nullable=True,
    )
    current_period_end: Mapped[datetime | None] = mapped_column(
        DateTime(timezone=False),
        nullable=True,
    )
    cancel_at_period_end: Mapped[bool] = mapped_column(Boolean(), default=False)
    last_payment_at: Mapped[datetime | None] = mapped_column(
        DateTime(timezone=False),
        nullable=True,
    )
    subscription_started_at: Mapped[datetime | None] = mapped_column(
        DateTime(timezone=False),
        nullable=True,
    )
    subscription_expires_at: Mapped[datetime | None] = mapped_column(
        DateTime(timezone=False),
        nullable=True,
    )
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=False), default=datetime.utcnow)
    updated_at: Mapped[datetime] = mapped_column(DateTime(timezone=False), default=datetime.utcnow)

    preferences: Mapped["UserPreferenceRecord | None"] = relationship(
        back_populates="user",
        uselist=False,
        cascade="all, delete-orphan",
        passive_deletes=True,
    )
    device_tokens: Mapped[list["DeviceTokenRecord"]] = relationship(
        back_populates="user",
        cascade="all, delete-orphan",
        passive_deletes=True,
    )
    bookmarks: Mapped[list["UserBookmarkRecord"]] = relationship(
        back_populates="user",
        cascade="all, delete-orphan",
        passive_deletes=True,
    )
    category_interests: Mapped[list["UserCategoryInterestRecord"]] = relationship(
        back_populates="user",
        cascade="all, delete-orphan",
        passive_deletes=True,
    )
    submitted_articles: Mapped[list["NewsArticleRecord"]] = relationship(
        foreign_keys="NewsArticleRecord.submitted_by",
        back_populates="submitter",
    )
    article_workflow_events: Mapped[list["ArticleWorkflowEventRecord"]] = relationship(
        back_populates="actor"
    )
    polls_created: Mapped[list["PollRecord"]] = relationship(back_populates="creator")
    poll_votes: Mapped[list["PollVoteRecord"]] = relationship(back_populates="user")
    personalized_interests: Mapped[list["UserInterestProfileRecord"]] = relationship(
        back_populates="user",
        cascade="all, delete-orphan",
        passive_deletes=True,
    )
    followed_topics: Mapped[list["UserTopicFollowRecord"]] = relationship(
        back_populates="user",
        cascade="all, delete-orphan",
        passive_deletes=True,
    )
    feed_events: Mapped[list["FeedEventRecord"]] = relationship(
        back_populates="user",
        cascade="all, delete-orphan",
        passive_deletes=True,
    )
    hidden_items: Mapped[list["UserHiddenItemRecord"]] = relationship(
        back_populates="user",
        cascade="all, delete-orphan",
        passive_deletes=True,
    )
    streams_hosted: Mapped[list["StreamSessionRecord"]] = relationship(
        back_populates="host"
    )
    stream_comments: Mapped[list["StreamCommentRecord"]] = relationship(
        back_populates="user"
    )
    article_comments: Mapped[list["ArticleCommentRecord"]] = relationship(
        foreign_keys="ArticleCommentRecord.user_id",
        back_populates="user",
    )
    moderated_article_comments: Mapped[list["ArticleCommentRecord"]] = relationship(
        foreign_keys="ArticleCommentRecord.moderated_by_user_id",
        back_populates="moderated_by",
    )
    comment_reports: Mapped[list["CommentReportRecord"]] = relationship(
        back_populates="reporter"
    )
    comment_reactions: Mapped[list["CommentReactionRecord"]] = relationship(
        back_populates="user"
    )
    notifications: Mapped[list["NotificationRecord"]] = relationship(
        foreign_keys="NotificationRecord.user_id",
        back_populates="user",
    )
    notification_events: Mapped[list["NotificationRecord"]] = relationship(
        foreign_keys="NotificationRecord.actor_user_id",
        back_populates="actor",
    )
    stream_presence: Mapped[list["StreamViewerPresenceRecord"]] = relationship(
        back_populates="user"
    )


class AdminAccessRequestRecord(Base):
    __tablename__ = "admin_access_requests"

    id: Mapped[str] = mapped_column(String(128), primary_key=True)
    full_name: Mapped[str] = mapped_column(String(120))
    work_email: Mapped[str] = mapped_column(String(255), index=True)
    requested_role: Mapped[str] = mapped_column(String(120))
    bureau: Mapped[str | None] = mapped_column(String(120), nullable=True)
    reason: Mapped[str] = mapped_column(Text())
    status: Mapped[str] = mapped_column(String(32), default="pending", index=True)
    reviewed_by_user_id: Mapped[str | None] = mapped_column(
        String(128),
        ForeignKey("users.id", ondelete="SET NULL"),
        nullable=True,
        index=True,
    )
    granted_user_id: Mapped[str | None] = mapped_column(
        String(128),
        ForeignKey("users.id", ondelete="SET NULL"),
        nullable=True,
        index=True,
    )
    review_note: Mapped[str | None] = mapped_column(Text(), nullable=True)
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=False), default=datetime.utcnow)
    updated_at: Mapped[datetime] = mapped_column(DateTime(timezone=False), default=datetime.utcnow)


class UserAccessRequestRecord(Base):
    __tablename__ = "user_access_requests"

    id: Mapped[str] = mapped_column(String(128), primary_key=True)
    user_id: Mapped[str] = mapped_column(
        String(128),
        ForeignKey("users.id", ondelete="CASCADE"),
        index=True,
    )
    access_type: Mapped[str] = mapped_column(String(64), index=True)
    reason: Mapped[str] = mapped_column(Text())
    status: Mapped[str] = mapped_column(String(32), default="pending", index=True)
    reviewed_by_user_id: Mapped[str | None] = mapped_column(
        String(128),
        ForeignKey("users.id", ondelete="SET NULL"),
        nullable=True,
        index=True,
    )
    review_note: Mapped[str | None] = mapped_column(Text(), nullable=True)
    created_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=False), default=datetime.utcnow
    )
    updated_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=False), default=datetime.utcnow
    )


class PollRecord(Base):
    __tablename__ = "polls"

    id: Mapped[str] = mapped_column(String(80), primary_key=True)
    question: Mapped[str] = mapped_column(Text())
    category_id: Mapped[str | None] = mapped_column(
        String(80),
        ForeignKey("categories.id", ondelete="SET NULL"),
        nullable=True,
        index=True,
    )
    created_by: Mapped[str | None] = mapped_column(
        String(128),
        ForeignKey("users.id", ondelete="SET NULL"),
        nullable=True,
        index=True,
    )
    ends_at: Mapped[datetime] = mapped_column(DateTime(timezone=False), index=True)
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=False), default=datetime.utcnow)

    category: Mapped[CategoryRecord | None] = relationship(back_populates="polls")
    creator: Mapped[UserRecord | None] = relationship(back_populates="polls_created")
    options: Mapped[list["PollOptionRecord"]] = relationship(
        back_populates="poll",
        cascade="all, delete-orphan",
        passive_deletes=True,
        order_by="PollOptionRecord.position",
    )


class PollOptionRecord(Base):
    __tablename__ = "poll_options"
    __table_args__ = (
        UniqueConstraint("poll_id", "option_id", name="uq_poll_option"),
    )

    id: Mapped[int] = mapped_column(Integer(), primary_key=True, autoincrement=True)
    poll_id: Mapped[str] = mapped_column(
        String(80),
        ForeignKey("polls.id", ondelete="CASCADE"),
        index=True,
    )
    option_id: Mapped[str] = mapped_column(String(80))
    label: Mapped[str] = mapped_column(String(255))
    votes: Mapped[int] = mapped_column(Integer(), default=0)
    position: Mapped[int] = mapped_column(Integer(), default=0)

    poll: Mapped[PollRecord] = relationship(back_populates="options")


class PollVoteRecord(Base):
    __tablename__ = "poll_votes"
    __table_args__ = (
        UniqueConstraint("idempotency_key", name="uq_poll_vote_idempotency_key"),
        UniqueConstraint("poll_id", "voter_id", name="uq_poll_vote_per_voter"),
        UniqueConstraint("poll_id", "user_id", name="uq_poll_vote_per_user"),
    )

    id: Mapped[int] = mapped_column(Integer(), primary_key=True, autoincrement=True)
    poll_id: Mapped[str] = mapped_column(
        String(80),
        ForeignKey("polls.id", ondelete="CASCADE"),
        index=True,
    )
    option_id: Mapped[str] = mapped_column(String(80))
    voter_id: Mapped[str | None] = mapped_column(String(128), nullable=True, index=True)
    user_id: Mapped[str | None] = mapped_column(
        String(128),
        ForeignKey("users.id", ondelete="SET NULL"),
        nullable=True,
        index=True,
    )
    idempotency_key: Mapped[str] = mapped_column(String(160))
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=False), default=datetime.utcnow)

    user: Mapped[UserRecord | None] = relationship(back_populates="poll_votes")


class UserPreferenceRecord(Base):
    __tablename__ = "user_preferences"
    __table_args__ = (
        UniqueConstraint("user_id", name="uq_user_preferences_user_id"),
    )

    id: Mapped[int] = mapped_column(Integer(), primary_key=True, autoincrement=True)
    user_id: Mapped[str] = mapped_column(
        String(128),
        ForeignKey("users.id", ondelete="CASCADE"),
        index=True,
    )
    breaking_news_alerts: Mapped[bool] = mapped_column(Boolean(), default=True)
    live_stream_alerts: Mapped[bool] = mapped_column(Boolean(), default=True)
    comment_replies: Mapped[bool] = mapped_column(Boolean(), default=True)
    theme: Mapped[str] = mapped_column(String(32), default="system")
    text_size: Mapped[str] = mapped_column(String(32), default="small")
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=False), default=datetime.utcnow)
    updated_at: Mapped[datetime] = mapped_column(DateTime(timezone=False), default=datetime.utcnow)

    user: Mapped[UserRecord] = relationship(back_populates="preferences")


class DeviceTokenRecord(Base):
    __tablename__ = "device_tokens"
    __table_args__ = (
        UniqueConstraint("token", name="uq_device_tokens_token"),
    )

    id: Mapped[int] = mapped_column(Integer(), primary_key=True, autoincrement=True)
    user_id: Mapped[str] = mapped_column(
        String(128),
        ForeignKey("users.id", ondelete="CASCADE"),
        index=True,
    )
    token: Mapped[str] = mapped_column(String(512))
    platform: Mapped[str] = mapped_column(String(24), default="unknown")
    is_active: Mapped[bool] = mapped_column(Boolean(), default=True)
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=False), default=datetime.utcnow)
    last_seen_at: Mapped[datetime] = mapped_column(DateTime(timezone=False), default=datetime.utcnow)

    user: Mapped[UserRecord] = relationship(back_populates="device_tokens")


class UserBookmarkRecord(Base):
    __tablename__ = "user_bookmarks"
    __table_args__ = (
        UniqueConstraint("user_id", "article_id", name="uq_user_bookmark"),
    )

    id: Mapped[int] = mapped_column(Integer(), primary_key=True, autoincrement=True)
    user_id: Mapped[str] = mapped_column(
        String(128),
        ForeignKey("users.id", ondelete="CASCADE"),
        index=True,
    )
    article_id: Mapped[str] = mapped_column(
        String(96),
        ForeignKey("news_articles.id", ondelete="CASCADE"),
        index=True,
    )
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=False), default=datetime.utcnow)

    user: Mapped[UserRecord] = relationship(back_populates="bookmarks")
    article: Mapped[NewsArticleRecord] = relationship(back_populates="bookmarks")


class UserCategoryInterestRecord(Base):
    __tablename__ = "user_category_interests"
    __table_args__ = (
        UniqueConstraint("user_id", "category_id", name="uq_user_category_interest"),
    )

    id: Mapped[int] = mapped_column(Integer(), primary_key=True, autoincrement=True)
    user_id: Mapped[str] = mapped_column(
        String(128),
        ForeignKey("users.id", ondelete="CASCADE"),
        index=True,
    )
    category_id: Mapped[str] = mapped_column(
        String(80),
        ForeignKey("categories.id", ondelete="CASCADE"),
        index=True,
    )
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=False), default=datetime.utcnow)

    user: Mapped[UserRecord] = relationship(back_populates="category_interests")
    category: Mapped[CategoryRecord] = relationship(back_populates="user_interests")


class UserInterestProfileRecord(Base):
    __tablename__ = "user_interest_profiles"
    __table_args__ = (
        UniqueConstraint("user_id", "category_id", name="uq_user_interest_profile"),
    )

    id: Mapped[int] = mapped_column(Integer(), primary_key=True, autoincrement=True)
    user_id: Mapped[str] = mapped_column(
        String(128),
        ForeignKey("users.id", ondelete="CASCADE"),
        index=True,
    )
    category_id: Mapped[str] = mapped_column(
        String(80),
        ForeignKey("categories.id", ondelete="CASCADE"),
        index=True,
    )
    explicit_weight: Mapped[float] = mapped_column(Float(), default=0.5)
    implicit_weight: Mapped[float] = mapped_column(Float(), default=0.0)
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=False), default=datetime.utcnow)
    updated_at: Mapped[datetime] = mapped_column(DateTime(timezone=False), default=datetime.utcnow)

    user: Mapped[UserRecord] = relationship(back_populates="personalized_interests")
    category: Mapped[CategoryRecord] = relationship(back_populates="personalized_interests")


class UserTopicFollowRecord(Base):
    __tablename__ = "user_topic_follows"
    __table_args__ = (
        UniqueConstraint("user_id", "topic", name="uq_user_topic_follow"),
    )

    id: Mapped[int] = mapped_column(Integer(), primary_key=True, autoincrement=True)
    user_id: Mapped[str] = mapped_column(
        String(128),
        ForeignKey("users.id", ondelete="CASCADE"),
        index=True,
    )
    topic: Mapped[str] = mapped_column(String(120), index=True)
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=False), default=datetime.utcnow)

    user: Mapped[UserRecord] = relationship(back_populates="followed_topics")


class FeedEventRecord(Base):
    __tablename__ = "feed_events"
    __table_args__ = (
        UniqueConstraint("idempotency_key", name="uq_feed_event_idempotency_key"),
    )

    id: Mapped[int] = mapped_column(Integer(), primary_key=True, autoincrement=True)
    user_id: Mapped[str] = mapped_column(
        String(128),
        ForeignKey("users.id", ondelete="CASCADE"),
        index=True,
    )
    article_id: Mapped[str | None] = mapped_column(
        String(96),
        ForeignKey("news_articles.id", ondelete="CASCADE"),
        nullable=True,
        index=True,
    )
    category_id: Mapped[str | None] = mapped_column(
        String(80),
        ForeignKey("categories.id", ondelete="SET NULL"),
        nullable=True,
        index=True,
    )
    source: Mapped[str | None] = mapped_column(String(255), nullable=True, index=True)
    event_type: Mapped[str] = mapped_column(String(32), index=True)
    dwell_ms: Mapped[int | None] = mapped_column(Integer(), nullable=True)
    idempotency_key: Mapped[str | None] = mapped_column(String(160), nullable=True)
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=False), default=datetime.utcnow, index=True)

    user: Mapped[UserRecord] = relationship(back_populates="feed_events")
    article: Mapped[NewsArticleRecord | None] = relationship(back_populates="feed_events")
    category: Mapped[CategoryRecord | None] = relationship()


class ArticleWorkflowEventRecord(Base):
    __tablename__ = "article_workflow_events"

    id: Mapped[int] = mapped_column(Integer(), primary_key=True, autoincrement=True)
    article_id: Mapped[str] = mapped_column(
        String(96),
        ForeignKey("news_articles.id", ondelete="CASCADE"),
        index=True,
    )
    actor_user_id: Mapped[str | None] = mapped_column(
        String(128),
        ForeignKey("users.id", ondelete="SET NULL"),
        nullable=True,
        index=True,
    )
    event_type: Mapped[str] = mapped_column(String(64), index=True)
    from_status: Mapped[str | None] = mapped_column(String(32), nullable=True)
    to_status: Mapped[str | None] = mapped_column(String(32), nullable=True)
    notes: Mapped[str | None] = mapped_column(Text(), nullable=True)
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=False), default=datetime.utcnow)

    article: Mapped[NewsArticleRecord] = relationship(back_populates="workflow_events")
    actor: Mapped[UserRecord | None] = relationship(back_populates="article_workflow_events")


class ArticleCommentRecord(Base):
    __tablename__ = "article_comments"

    id: Mapped[int] = mapped_column(Integer(), primary_key=True, autoincrement=True)
    article_id: Mapped[str] = mapped_column(
        String(96),
        ForeignKey("news_articles.id", ondelete="CASCADE"),
        index=True,
    )
    user_id: Mapped[str | None] = mapped_column(
        String(128),
        ForeignKey("users.id", ondelete="SET NULL"),
        nullable=True,
        index=True,
    )
    parent_comment_id: Mapped[int | None] = mapped_column(
        Integer(),
        ForeignKey("article_comments.id", ondelete="CASCADE"),
        nullable=True,
        index=True,
    )
    author_name: Mapped[str] = mapped_column(String(120))
    body: Mapped[str] = mapped_column(Text())
    status: Mapped[str] = mapped_column(String(32), default="visible", index=True)
    reply_count: Mapped[int] = mapped_column(Integer(), default=0)
    like_count: Mapped[int] = mapped_column(Integer(), default=0)
    moderated_by_user_id: Mapped[str | None] = mapped_column(
        String(128),
        ForeignKey("users.id", ondelete="SET NULL"),
        nullable=True,
        index=True,
    )
    moderated_at: Mapped[datetime | None] = mapped_column(
        DateTime(timezone=False),
        nullable=True,
    )
    moderation_reason: Mapped[str | None] = mapped_column(Text(), nullable=True)
    created_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=False),
        default=datetime.utcnow,
        index=True,
    )
    updated_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=False),
        default=datetime.utcnow,
    )

    article: Mapped[NewsArticleRecord] = relationship(back_populates="comments")
    user: Mapped[UserRecord | None] = relationship(
        foreign_keys=[user_id],
        back_populates="article_comments",
    )
    moderated_by: Mapped[UserRecord | None] = relationship(
        foreign_keys=[moderated_by_user_id],
        back_populates="moderated_article_comments",
    )
    parent_comment: Mapped["ArticleCommentRecord | None"] = relationship(
        remote_side="ArticleCommentRecord.id",
        back_populates="replies",
    )
    replies: Mapped[list["ArticleCommentRecord"]] = relationship(
        back_populates="parent_comment",
        cascade="all, delete-orphan",
        passive_deletes=True,
        order_by="ArticleCommentRecord.created_at.asc()",
    )
    reports: Mapped[list["CommentReportRecord"]] = relationship(
        back_populates="comment",
        cascade="all, delete-orphan",
        passive_deletes=True,
    )
    reactions: Mapped[list["CommentReactionRecord"]] = relationship(
        back_populates="comment",
        cascade="all, delete-orphan",
        passive_deletes=True,
    )
    notifications: Mapped[list["NotificationRecord"]] = relationship(
        back_populates="comment",
        cascade="all, delete-orphan",
        passive_deletes=True,
    )


class CommentReportRecord(Base):
    __tablename__ = "comment_reports"
    __table_args__ = (
        UniqueConstraint("comment_id", "reporter_user_id", name="uq_comment_report_per_user"),
    )

    id: Mapped[int] = mapped_column(Integer(), primary_key=True, autoincrement=True)
    comment_id: Mapped[int] = mapped_column(
        Integer(),
        ForeignKey("article_comments.id", ondelete="CASCADE"),
        index=True,
    )
    reporter_user_id: Mapped[str | None] = mapped_column(
        String(128),
        ForeignKey("users.id", ondelete="SET NULL"),
        nullable=True,
        index=True,
    )
    reason: Mapped[str | None] = mapped_column(Text(), nullable=True)
    created_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=False),
        default=datetime.utcnow,
    )

    comment: Mapped[ArticleCommentRecord] = relationship(back_populates="reports")
    reporter: Mapped[UserRecord | None] = relationship(back_populates="comment_reports")


class CommentReactionRecord(Base):
    __tablename__ = "comment_reactions"
    __table_args__ = (
        UniqueConstraint(
            "comment_id",
            "user_id",
            "reaction_type",
            name="uq_comment_reaction_per_user",
        ),
    )

    id: Mapped[int] = mapped_column(Integer(), primary_key=True, autoincrement=True)
    comment_id: Mapped[int] = mapped_column(
        Integer(),
        ForeignKey("article_comments.id", ondelete="CASCADE"),
        index=True,
    )
    user_id: Mapped[str] = mapped_column(
        String(128),
        ForeignKey("users.id", ondelete="CASCADE"),
        index=True,
    )
    reaction_type: Mapped[str] = mapped_column(String(32), default="like", index=True)
    created_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=False),
        default=datetime.utcnow,
    )

    comment: Mapped[ArticleCommentRecord] = relationship(back_populates="reactions")
    user: Mapped[UserRecord] = relationship(back_populates="comment_reactions")


class NotificationRecord(Base):
    __tablename__ = "notifications"

    id: Mapped[int] = mapped_column(Integer(), primary_key=True, autoincrement=True)
    user_id: Mapped[str] = mapped_column(
        String(128),
        ForeignKey("users.id", ondelete="CASCADE"),
        index=True,
    )
    type: Mapped[str] = mapped_column(String(48), index=True)
    title: Mapped[str] = mapped_column(String(255))
    body: Mapped[str] = mapped_column(Text())
    actor_user_id: Mapped[str | None] = mapped_column(
        String(128),
        ForeignKey("users.id", ondelete="SET NULL"),
        nullable=True,
        index=True,
    )
    actor_name: Mapped[str | None] = mapped_column(String(120), nullable=True)
    article_id: Mapped[str | None] = mapped_column(
        String(96),
        ForeignKey("news_articles.id", ondelete="CASCADE"),
        nullable=True,
        index=True,
    )
    comment_id: Mapped[int | None] = mapped_column(
        Integer(),
        ForeignKey("article_comments.id", ondelete="CASCADE"),
        nullable=True,
        index=True,
    )
    is_read: Mapped[bool] = mapped_column(Boolean(), default=False, index=True)
    created_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=False),
        default=datetime.utcnow,
        index=True,
    )

    user: Mapped[UserRecord] = relationship(
        foreign_keys=[user_id],
        back_populates="notifications",
    )
    actor: Mapped[UserRecord | None] = relationship(
        foreign_keys=[actor_user_id],
        back_populates="notification_events",
    )
    article: Mapped[NewsArticleRecord | None] = relationship(back_populates="notifications")
    comment: Mapped[ArticleCommentRecord | None] = relationship(back_populates="notifications")


class StreamSessionRecord(Base):
    __tablename__ = "stream_sessions"

    id: Mapped[str] = mapped_column(String(80), primary_key=True)
    host_user_id: Mapped[str | None] = mapped_column(
        String(128),
        ForeignKey("users.id", ondelete="SET NULL"),
        nullable=True,
        index=True,
    )
    title: Mapped[str] = mapped_column(String(255))
    description: Mapped[str | None] = mapped_column(Text(), nullable=True)
    category: Mapped[str] = mapped_column(String(120), index=True)
    cover_image_url: Mapped[str | None] = mapped_column(Text(), nullable=True)
    stream_url: Mapped[str | None] = mapped_column(Text(), nullable=True)
    status: Mapped[str] = mapped_column(String(24), index=True)
    scheduled_for: Mapped[datetime | None] = mapped_column(
        DateTime(timezone=False),
        nullable=True,
        index=True,
    )
    started_at: Mapped[datetime | None] = mapped_column(
        DateTime(timezone=False),
        nullable=True,
        index=True,
    )
    ended_at: Mapped[datetime | None] = mapped_column(
        DateTime(timezone=False),
        nullable=True,
        index=True,
    )
    created_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=False),
        default=datetime.utcnow,
    )
    updated_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=False),
        default=datetime.utcnow,
    )

    host: Mapped[UserRecord | None] = relationship(back_populates="streams_hosted")
    viewers: Mapped[list["StreamViewerPresenceRecord"]] = relationship(
        back_populates="stream",
        cascade="all, delete-orphan",
        passive_deletes=True,
    )
    comments: Mapped[list["StreamCommentRecord"]] = relationship(
        back_populates="stream",
        cascade="all, delete-orphan",
        passive_deletes=True,
        order_by="StreamCommentRecord.created_at.desc()",
    )


class StreamCommentRecord(Base):
    __tablename__ = "stream_comments"

    id: Mapped[int] = mapped_column(Integer(), primary_key=True, autoincrement=True)
    stream_id: Mapped[str] = mapped_column(
        String(80),
        ForeignKey("stream_sessions.id", ondelete="CASCADE"),
        index=True,
    )
    user_id: Mapped[str | None] = mapped_column(
        String(128),
        ForeignKey("users.id", ondelete="SET NULL"),
        nullable=True,
        index=True,
    )
    author_name: Mapped[str] = mapped_column(String(120))
    body: Mapped[str] = mapped_column(Text())
    created_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=False),
        default=datetime.utcnow,
        index=True,
    )

    stream: Mapped[StreamSessionRecord] = relationship(back_populates="comments")
    user: Mapped[UserRecord | None] = relationship(back_populates="stream_comments")


class StreamViewerPresenceRecord(Base):
    __tablename__ = "stream_viewer_presence"
    __table_args__ = (
        UniqueConstraint(
            "stream_id",
            "viewer_key",
            name="uq_stream_viewer_presence",
        ),
    )

    id: Mapped[int] = mapped_column(Integer(), primary_key=True, autoincrement=True)
    stream_id: Mapped[str] = mapped_column(
        String(80),
        ForeignKey("stream_sessions.id", ondelete="CASCADE"),
        index=True,
    )
    viewer_key: Mapped[str] = mapped_column(String(128), index=True)
    user_id: Mapped[str | None] = mapped_column(
        String(128),
        ForeignKey("users.id", ondelete="SET NULL"),
        nullable=True,
        index=True,
    )
    joined_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=False),
        default=datetime.utcnow,
    )
    last_seen_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=False),
        default=datetime.utcnow,
        index=True,
    )
    left_at: Mapped[datetime | None] = mapped_column(
        DateTime(timezone=False),
        nullable=True,
        index=True,
    )

    stream: Mapped[StreamSessionRecord] = relationship(back_populates="viewers")
    user: Mapped[UserRecord | None] = relationship(back_populates="stream_presence")


class UserHiddenItemRecord(Base):
    __tablename__ = "user_hidden_items"
    __table_args__ = (
        UniqueConstraint("user_id", "article_id", name="uq_user_hidden_article"),
        UniqueConstraint("user_id", "source", name="uq_user_hidden_source"),
        UniqueConstraint("user_id", "category_id", name="uq_user_hidden_category"),
    )

    id: Mapped[int] = mapped_column(Integer(), primary_key=True, autoincrement=True)
    user_id: Mapped[str] = mapped_column(
        String(128),
        ForeignKey("users.id", ondelete="CASCADE"),
        index=True,
    )
    article_id: Mapped[str | None] = mapped_column(
        String(96),
        ForeignKey("news_articles.id", ondelete="CASCADE"),
        nullable=True,
        index=True,
    )
    source: Mapped[str | None] = mapped_column(String(255), nullable=True, index=True)
    category_id: Mapped[str | None] = mapped_column(
        String(80),
        ForeignKey("categories.id", ondelete="CASCADE"),
        nullable=True,
        index=True,
    )
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=False), default=datetime.utcnow)

    user: Mapped[UserRecord] = relationship(back_populates="hidden_items")
    article: Mapped[NewsArticleRecord | None] = relationship(back_populates="hidden_by_users")
    category: Mapped[CategoryRecord | None] = relationship(back_populates="hidden_items")
