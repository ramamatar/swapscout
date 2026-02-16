from pydantic import BaseModel

class FavoriteCreate(BaseModel):
    home_id: int

class FavoriteOut(BaseModel):
    id: int
    home_id: int

    class Config:
        from_attributes = True
