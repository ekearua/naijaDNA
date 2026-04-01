from datetime import datetime
from typing import List, Optional

from pydantic import BaseModel, Field


class Category(BaseModel):
    id: str
    name: str
    color_hex: Optional[str] = None
    description: Optional[str] = None
    created_at: datetime


class CategoriesResponse(BaseModel):
    items: List[Category]
    total: int = Field(..., ge=0)


class CreateCategoryRequest(BaseModel):
    id: Optional[str] = Field(default=None, max_length=80)
    name: str = Field(..., min_length=2, max_length=120)
    color_hex: Optional[str] = Field(default=None, min_length=4, max_length=7)
    description: Optional[str] = Field(default=None, max_length=500)
