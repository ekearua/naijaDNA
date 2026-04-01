from datetime import datetime
from typing import List, Literal, Optional

from pydantic import BaseModel, Field


class IngestionRunRequest(BaseModel):
    source_ids: Optional[List[str]] = None
    limit_per_source: int = Field(default=25, ge=1, le=100)


class SourceIngestionResult(BaseModel):
    source_id: str
    source_name: str
    status: Literal["success", "skipped", "failed"]
    fetched: int = Field(default=0, ge=0)
    inserted: int = Field(default=0, ge=0)
    deduped: int = Field(default=0, ge=0)
    errors: List[str] = Field(default_factory=list)


class IngestionRunRecord(BaseModel):
    run_id: str
    triggered_by: Literal["manual", "scheduler"]
    started_at: datetime
    finished_at: Optional[datetime] = None
    status: Literal["running", "success", "partial", "failed"] = "running"
    fetched_count: int = Field(default=0, ge=0)
    inserted_count: int = Field(default=0, ge=0)
    deduped_count: int = Field(default=0, ge=0)
    error_count: int = Field(default=0, ge=0)
    sources: List[SourceIngestionResult] = Field(default_factory=list)


class IngestionStatusResponse(BaseModel):
    running: bool
    last_run: Optional[IngestionRunRecord] = None
    recent_runs: List[IngestionRunRecord] = Field(default_factory=list)
    total_sources: int = Field(default=0, ge=0)
    active_sources: int = Field(default=0, ge=0)
