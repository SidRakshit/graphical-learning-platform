# backend/models.py
from pydantic import BaseModel, Field
from typing import Optional, List  # If you need lists or optional fields
import uuid  # To generate unique IDs


class TopicBase(BaseModel):
    name: str = Field(
        ..., min_length=3, max_length=150, description="The name of the topic"
    )
    description: Optional[str] = Field(
        None, max_length=500, description="A brief description of the topic"
    )


class TopicCreate(TopicBase):
    pass


class Topic(TopicBase):
    id: str = Field(
        default_factory=lambda: str(uuid.uuid4()),
        description="Unique identifier for the topic",
    )

    # This is the Pydantic V2 specific part:
    model_config = {"from_attributes": True}


class TopicUpdate(BaseModel):
    name: Optional[str] = Field(None, min_length=3, max_length=150)
    description: Optional[str] = Field(None, max_length=500)
