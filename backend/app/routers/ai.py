from fastapi import APIRouter, Depends

from app import deps
from app.schemas.ai import DJScriptRequest, DJScriptResponse
from app.services.openai_dj import OpenAIDJService

router = APIRouter()


@router.post("/dj-script", response_model=DJScriptResponse)
async def generate_dj_script(
    body: DJScriptRequest,
    current_user=Depends(deps.get_current_user),
):
    _ = current_user
    script = await OpenAIDJService.generate_script(body)
    return DJScriptResponse(script=script)
