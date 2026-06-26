from sqlalchemy import Column, Integer, String, Text, Date, ARRAY, ForeignKey, TIMESTAMP, Float, Boolean, UniqueConstraint, DateTime, Enum, LargeBinary
import enum
from sqlalchemy.sql import func
from database import Base
from sqlalchemy.orm import relationship


class User(Base):
    __tablename__ = "users"

    id = Column(Integer, primary_key=True, index=True)
    email = Column(String, unique=True, index=True, nullable=False)
    password = Column(String, nullable=False)
    trip_preferences = relationship(
        "TripPreference",
        back_populates="user",
        cascade="all, delete-orphan"
    )
    homes = relationship(
        "Home",
        back_populates="owner",
        cascade="all, delete-orphan"
    )
    favorites = relationship(
    "Favorite",
    back_populates="user",
    cascade="all, delete-orphan"
)
    notifications = relationship("Notification", back_populates="user", cascade="all, delete-orphan")
    sent_messages = relationship(
    "Message",
    foreign_keys="Message.sender_id",
    cascade="all, delete-orphan",
    back_populates="sender"
)

    received_messages = relationship(
    "Message",
    foreign_keys="Message.receiver_id",
    cascade="all, delete-orphan",
    back_populates="receiver"
)

    name = Column(String, nullable=True)
    country = Column(String, nullable=True)
    city = Column(String, nullable=True)
    lifestyle_tags = Column(String, nullable=True)  # simple comma-separated for now
    bio = Column(Text, nullable=True)

class Home(Base):
    __tablename__ = "homes"

    id = Column(Integer, primary_key=True, index=True)

    title = Column(String, nullable=False)
    description = Column(Text, nullable=False)

    country = Column(String, nullable=False)
    city = Column(String, nullable=False)

    capacity = Column(Integer, nullable=False)

    amenities = Column(Text, nullable=True)  # comma-separated
    environment = Column(String, nullable=True)  # Beach, City, Mountain, Countryside, etc.
    property_type = Column(String, nullable=True)  # Apartment, House, Villa, Cottage, Cabin, etc.
    is_hidden = Column(Boolean, default=False, nullable=False)  # Hide house if not available
    
    total_reviews = Column(Integer, default=0, nullable=False)
    average_rating = Column(Float, default=0.0, nullable=False)

    latitude = Column(Float, nullable=True)
    longitude = Column(Float, nullable=True)

    available_from = Column(Date, nullable=False)  # ISO date string
    available_to = Column(Date, nullable=False)

    images = Column(ARRAY(String), default=[])

    owner_id = Column(Integer, ForeignKey("users.id"), nullable=False)
    owner = relationship("User", back_populates="homes")
    favorites = relationship("Favorite", cascade="all, delete-orphan", back_populates="home")
    bookings = relationship("HomeBooking", back_populates="home", cascade="all, delete-orphan")


class HomeImage(Base):
    __tablename__ = "home_images"

    id = Column(Integer, primary_key=True, index=True)
    home_id = Column(Integer, ForeignKey("homes.id", ondelete="CASCADE"), nullable=False)
    image_data = Column(LargeBinary, nullable=False)
    content_type = Column(String, nullable=False)

    home = relationship("Home")


class HomeBooking(Base):
    __tablename__ = "home_bookings"

    id = Column(Integer, primary_key=True, index=True)
    home_id = Column(Integer, ForeignKey("homes.id", ondelete="CASCADE"), nullable=False)
    
    start_date = Column(Date, nullable=False)
    end_date = Column(Date, nullable=False)
    
    home = relationship("Home", back_populates="bookings")
class TripPreference(Base):
    __tablename__ = "trip_preferences"

    id = Column(Integer, primary_key=True, index=True)
    user_id = Column(Integer, ForeignKey("users.id"), nullable=False)

    preferred_country = Column(String, nullable=False)
    preferred_city = Column(String, nullable=False)

    start_date = Column(Date, nullable=False)
    end_date = Column(Date, nullable=False)

    guests = Column(Integer, nullable=False)

    lifestyle_tags = Column(ARRAY(String), nullable=True)

    user = relationship("User", back_populates="trip_preferences")


class Match(Base):
    __tablename__ = "matches"

    match_id = Column(Integer, primary_key=True, index=True)

    user_a_id = Column(Integer, ForeignKey("users.id"), nullable=False)
    user_b_id = Column(Integer, ForeignKey("users.id"), nullable=False)

    status = Column(
        String(20),
        default="pending"  # pending | accepted | rejected
    )

    created_at = Column(DateTime(timezone=True), server_default=func.now())
    updated_at = Column(
        DateTime(timezone=True),
        server_default=func.now(),
        onupdate=func.now()
    )

    __table_args__ = (
        UniqueConstraint("user_a_id", "user_b_id", name="unique_match_pair"),
    )

    user_a = relationship("User", foreign_keys=[user_a_id])
    user_b = relationship("User", foreign_keys=[user_b_id])

class Message(Base):
    __tablename__ = "messages"
    id = Column(Integer, primary_key=True, index=True)
    sender_id = Column(Integer, ForeignKey("users.id", ondelete="CASCADE"))
    receiver_id = Column(Integer, ForeignKey("users.id", ondelete="CASCADE"))
    content = Column(Text, nullable=False)
    created_at = Column(DateTime(timezone=True), server_default=func.now())

    sender = relationship("User", foreign_keys=[sender_id], back_populates="sent_messages")
    receiver = relationship("User", foreign_keys=[receiver_id], back_populates="received_messages")

class Favorite(Base):
    __tablename__ = "favorites"

    id = Column(Integer, primary_key=True, index=True)
    user_id = Column(Integer, ForeignKey("users.id", ondelete="CASCADE"))
    home_id = Column(Integer, ForeignKey("homes.id", ondelete="CASCADE"))

    user = relationship("User", back_populates="favorites")
    home = relationship("Home", back_populates="favorites")

    __table_args__ = (
        UniqueConstraint("user_id", "home_id", name="unique_user_home_favorite"),)


class Activity(Base):
    __tablename__ = "activities"

    activity_id = Column(Integer, primary_key=True, index=True)
    user_id = Column(Integer, ForeignKey("users.id", ondelete="CASCADE"))
    activity_type = Column(String(50), nullable=False)  # match_found, message, swap_confirmed, etc.
    title = Column(String(200), nullable=False)
    description = Column(Text)
    related_user_id = Column(Integer, ForeignKey("users.id", ondelete="CASCADE"), nullable=True)
    related_home_id = Column(Integer, ForeignKey("homes.id", ondelete="CASCADE"), nullable=True)
    created_at = Column(TIMESTAMP(timezone=True), server_default=func.now())


class Notification(Base):
    __tablename__ = "notifications"

    id = Column(Integer, primary_key=True, index=True)
    user_id = Column(Integer, ForeignKey("users.id", ondelete="CASCADE"))
    message = Column(Text, nullable=False)
    type = Column(String(50), nullable=False)
    is_read = Column(Boolean, default=False)
    created_at = Column(TIMESTAMP(timezone=True), server_default=func.now())

    user = relationship("User", back_populates="notifications")

class SwapRequestStatus(str, enum.Enum):
    PENDING = "pending"
    ACCEPTED = "accepted"
    DECLINED = "declined"
    CANCELED = "canceled"
    COMPLETED = "completed"

class SwapRequest(Base):
    __tablename__ = "swap_requests"

    id = Column(Integer, primary_key=True, index=True)
    
    requester_id = Column(Integer, ForeignKey("users.id", ondelete="CASCADE"), nullable=False)
    host_id = Column(Integer, ForeignKey("users.id", ondelete="CASCADE"), nullable=False)
    
    requester_home_id = Column(Integer, ForeignKey("homes.id", ondelete="CASCADE"), nullable=False)
    host_home_id = Column(Integer, ForeignKey("homes.id", ondelete="CASCADE"), nullable=False)

    start_date = Column(Date, nullable=False)
    end_date = Column(Date, nullable=False)
    intro_message = Column(Text, nullable=True)
    
    status = Column(Enum(SwapRequestStatus), default=SwapRequestStatus.PENDING, nullable=False)
    
    created_at = Column(DateTime(timezone=True), server_default=func.now())

    # Relationships
    requester = relationship("User", foreign_keys=[requester_id])
    host = relationship("User", foreign_keys=[host_id])
    
    requester_home = relationship("Home", foreign_keys=[requester_home_id])
    host_home = relationship("Home", foreign_keys=[host_home_id])

class Review(Base):
    __tablename__ = "reviews"

    id = Column(Integer, primary_key=True, index=True)
    swap_request_id = Column(Integer, ForeignKey("swap_requests.id", ondelete="CASCADE"), nullable=False)
    reviewer_id = Column(Integer, ForeignKey("users.id", ondelete="CASCADE"), nullable=False)
    reviewee_id = Column(Integer, ForeignKey("users.id", ondelete="CASCADE"), nullable=False)
    home_id = Column(Integer, ForeignKey("homes.id", ondelete="CASCADE"), nullable=False)
    
    rating = Column(Integer, nullable=False)
    comment = Column(Text, nullable=True)
    
    created_at = Column(DateTime(timezone=True), server_default=func.now())

    __table_args__ = (
        UniqueConstraint("swap_request_id", "reviewer_id", name="unique_review_per_swap"),
    )
