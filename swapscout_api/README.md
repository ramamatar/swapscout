# SwapScout API Documentation

## Overview
FastAPI-based REST API for the SwapScout home swapping application.

## Setup

1. Install dependencies:
```bash
pip install -r requirements.txt
```

2. Configure database connection in `database.py`:
```python
DATABASE_URL = "postgresql://username:password@localhost/swapscout_db"
```

3. Run the server:
```bash
uvicorn main:app --reload
```

The API will be available at `http://localhost:8000`

API documentation (Swagger UI): `http://localhost:8000/docs`

## Endpoints

### Authentication

#### POST `/auth/login`
Login with email and password.

**Request Body:**
```json
{
  "email": "user@example.com",
  "password": "password123"
}
```

**Response:**
```json
{
  "access_token": "jwt_token_here",
  "token_type": "bearer",
  "user_id": 1
}
```

#### POST `/auth/signup`
Create a new user account.

**Request Body:**
```json
{
  "full_name": "John Doe",
  "email": "user@example.com",
  "password": "password123",
  "phone_number": "+1234567890",
  "country": "USA",
  "city": "New York"
}
```

**Response:**
```json
{
  "access_token": "jwt_token_here",
  "token_type": "bearer",
  "user_id": 1
}
```

### User Profile

#### GET `/users/{user_id}`
Get user profile information.

**Response:**
```json
{
  "user_id": 1,
  "full_name": "John Doe",
  "email": "user@example.com",
  "phone_number": "+1234567890",
  "country": "USA",
  "city": "New York",
  "lifestyle_tags": ["Pet-friendly", "Remote Worker"],
  "preferred_travel_style": "Adventurous"
}
```

#### PUT `/users/{user_id}`
Update user profile.

**Request Body:**
```json
{
  "full_name": "John Doe Updated",
  "phone_number": "+1234567890",
  "city": "Los Angeles"
}
```

#### GET `/users/{user_id}/home`
Get user's home listing.

#### PUT `/users/{user_id}/home`
Update user's home listing.

**Request Body:**
```json
{
  "location": "Barcelona, Spain",
  "home_type": "Apartment",
  "description": "Beautiful modern apartment...",
  "amenities": ["Wi-Fi", "Pool", "Kitchen"],
  "guest_capacity": 4,
  "available_from": "2024-07-15",
  "available_to": "2024-08-10"
}
```

### Trip Preferences

#### POST `/users/{user_id}/trip-preferences`
Create or update trip preferences.

**Request Body:**
```json
{
  "mood_description": "A tranquil escape surrounded by nature",
  "selected_moods": ["Relaxing", "Adventurous"],
  "preferred_environments": ["Beach", "Mountain"],
  "lifestyle_fit": ["Pet-friendly", "Remote Worker"],
  "travel_dates_from": "2024-07-15",
  "travel_dates_to": "2024-08-10",
  "home_location": "London, UK"
}
```

#### GET `/users/{user_id}/trip-preferences`
Get user's trip preferences.

### Search

#### POST `/search`
Search for homes with filters.

**Request Body:**
```json
{
  "location": "Barcelona",
  "check_in_date": "2024-07-15",
  "check_out_date": "2024-08-10",
  "guest_count": 4,
  "environments": ["Beach", "City"],
  "property_types": ["Apartment", "House"],
  "amenities": ["Wi-Fi", "Pool"],
  "min_match_score": 50.0
}
```

**Response:**
```json
{
  "results": [
    {
      "home_id": 1,
      "location": "Barcelona, Spain",
      "home_type": "Apartment",
      "description": "...",
      "amenities": ["Wi-Fi", "Pool"],
      "guest_capacity": 4,
      "rating": 4.8,
      "host_name": "Elena Martinez",
      "host_id": 2
    }
  ],
  "count": 1
}
```

### Matches

#### POST `/users/{user_id}/matches/generate`
Generate AI-based matches for user based on trip preferences.

**Response:**
```json
{
  "matches": [
    {
      "match_id": 1,
      "match_score": 95.0,
      "location": "Barcelona, Spain",
      "host_name": "Elena Martinez",
      "host_id": 2,
      "home_id": 3,
      "description": "...",
      "guest_capacity": 4,
      "amenities": ["Wi-Fi", "Pool"],
      "rating": 4.9,
      "availability": "2024-07-15 to 2024-08-10",
      "image_url": "https://..."
    }
  ],
  "count": 5
}
```

#### GET `/users/{user_id}/matches`
Get user's saved matches.

### Insights

#### GET `/users/{user_id}/insights`
Get user insights and analytics.

**Response:**
```json
{
  "overview": {
    "total_swaps": 12,
    "matches": 8,
    "upcoming": 4
  },
  "performance": {
    "response_rate": 92.0,
    "match_success_rate": 67.0,
    "avg_response_time": "2.5 hours"
  },
  "popular_destinations": [
    {"destination": "Barcelona, Spain", "count": 8},
    {"destination": "Paris, France", "count": 6}
  ],
  "recent_activity": [...]
}
```

#### GET `/users/{user_id}/activities`
Get user's activity timeline.

**Query Parameters:**
- `limit` (optional): Number of activities to return (default: 20, max: 100)

### Messages

#### POST `/messages`
Send a message to another user.

**Query Parameters:**
- `sender_id`: ID of the user sending the message

**Request Body:**
```json
{
  "receiver_id": 2,
  "home_id": 3,
  "subject": "Interested in home swap",
  "content": "Hello, I'm interested in swapping homes..."
}
```

#### GET `/users/{user_id}/messages`
Get user's messages (sent and received).

### Favorites

#### POST `/users/{user_id}/favorites`
Add a home to favorites.

**Query Parameters:**
- `home_id`: ID of the home to favorite

#### GET `/users/{user_id}/favorites`
Get user's favorite homes.

#### DELETE `/users/{user_id}/favorites/{home_id}`
Remove a home from favorites.

## Database Models

### User
- user_id (Primary Key)
- full_name
- email (Unique)
- password_hash
- phone_number
- country
- city
- lifestyle_tags (Array)
- preferred_travel_style
- created_at

### Home
- home_id (Primary Key)
- user_id (Foreign Key)
- location
- home_type
- description
- amenities (Array)
- guest_capacity
- available_from
- available_to
- images (Array)
- rating
- created_at

### TripPreferences
- preference_id (Primary Key)
- user_id (Foreign Key)
- mood_description
- selected_moods (Array)
- preferred_environments (Array)
- lifestyle_fit (Array)
- travel_dates_from
- travel_dates_to
- home_location
- created_at
- updated_at

### Match
- match_id (Primary Key)
- user_id (Foreign Key)
- matched_user_id (Foreign Key)
- matched_home_id (Foreign Key)
- match_score
- status (pending/accepted/rejected)
- created_at

### Message
- message_id (Primary Key)
- sender_id (Foreign Key)
- receiver_id (Foreign Key)
- home_id (Foreign Key, optional)
- subject
- content
- read (Boolean)
- created_at

### Favorite
- favorite_id (Primary Key)
- user_id (Foreign Key)
- home_id (Foreign Key)
- created_at

### Activity
- activity_id (Primary Key)
- user_id (Foreign Key)
- activity_type
- title
- description
- related_user_id (Foreign Key, optional)
- related_home_id (Foreign Key, optional)
- created_at

## Notes

- All endpoints require proper authentication in production (currently simplified for development)
- Password hashing uses bcrypt
- JWT tokens are used for authentication (30-minute expiration)
- CORS is enabled for all origins (restrict in production)
- Database migrations should be run to create/update tables after model changes

## Future Enhancements

- Add proper JWT authentication middleware
- Add rate limiting
- Add request validation
- Add comprehensive error handling
- Add API versioning
- Add caching layer
- Add email notifications
- Add file upload for images
- Add geolocation-based search
- Add recommendation engine improvements

