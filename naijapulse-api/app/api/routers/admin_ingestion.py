from fastapi import APIRouter, Depends, HTTPException, status

from app.api.deps import get_ingestion_pipeline_service
from app.schemas.ingestion import (
    IngestionRunRecord,
    IngestionRunRequest,
    IngestionStatusResponse,
)
from app.services.ingestion_pipeline_service import (
    IngestionAlreadyRunningError,
    IngestionPipelineService,
)

router = APIRouter(prefix="/admin/ingestion", tags=["ingestion"])


@router.get("/status", response_model=IngestionStatusResponse)
async def ingestion_status(
    ingestion_service: IngestionPipelineService = Depends(get_ingestion_pipeline_service),
) -> IngestionStatusResponse:
    """Return ingestion runtime state and recent execution summaries."""
    return await ingestion_service.get_status()


@router.post("/run", response_model=IngestionRunRecord)
async def run_ingestion(
    payload: IngestionRunRequest,
    ingestion_service: IngestionPipelineService = Depends(get_ingestion_pipeline_service),
) -> IngestionRunRecord:
    """Trigger an on-demand ingestion run for all or selected sources."""
    try:
        return await ingestion_service.run_manual(
            source_ids=payload.source_ids,
            limit_per_source=payload.limit_per_source,
        )
    except IngestionAlreadyRunningError as exc:
        raise HTTPException(
            status_code=status.HTTP_409_CONFLICT,
            detail=str(exc),
        ) from exc
