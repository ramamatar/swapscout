from pydantic import BaseModel, ConfigDict

class FavoriteCreate(BaseModel):
    home_id: int

class FavoriteOut(BaseModel):
    id: int
    home_id: int

    model_config = ConfigDict(from_attributes=True)
