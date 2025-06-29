"""
main.py – Minimal, robust Watsonx Chat Agent
"""

from __future__ import annotations

import logging
import os
from functools import lru_cache
from typing import Final, Optional

from dotenv import load_dotenv
from fastapi import Depends, FastAPI, HTTPException, status
from pydantic import BaseModel

# --------------------------------------------------------------------------- #
# IBM Watsonx SDK imports
# --------------------------------------------------------------------------- #
try:
    from ibm_watsonx_ai.credentials import Credentials
    from ibm_watsonx_ai.foundation_models import ModelInference
    from ibm_watsonx_ai.metanames import GenTextParamsMetaNames as GenParams
except ImportError as exc:  # pragma: no cover
    raise SystemExit(
        "The package `ibm-watsonx-ai` is required. "
        "Install it with `pip install ibm-watsonx-ai`."
    ) from exc

# --------------------------------------------------------------------------- #
# Logging
# --------------------------------------------------------------------------- #
logging.basicConfig(
    format="%(asctime)s | %(levelname)s | %(name)s | %(message)s",
    datefmt="%Y-%m-%d %H:%M:%S",
    level=logging.INFO,
)
logger: Final = logging.getLogger("watsonx-agent")

# --------------------------------------------------------------------------- #
# Configuration
# --------------------------------------------------------------------------- #
load_dotenv()  # .env support

WATSONX_APIKEY: Final[str | None] = os.getenv("WATSONX_APIKEY")
WATSONX_URL:    Final[str | None] = os.getenv("WATSONX_URL")
PROJECT_ID:     Final[str | None] = os.getenv("PROJECT_ID")

if not all([WATSONX_APIKEY, WATSONX_URL, PROJECT_ID]):
    missing = [k for k, v in {
        "WATSONX_APIKEY": WATSONX_APIKEY,
        "WATSONX_URL":    WATSONX_URL,
        "PROJECT_ID":     PROJECT_ID,
    }.items() if not v]
    raise SystemExit(
        f"Missing required environment variables: {', '.join(missing)}. "
        "Create a .env file or export them before running."
    )

# --------------------------------------------------------------------------- #
# Pydantic models
# --------------------------------------------------------------------------- #
class ToolArgs(BaseModel):
    prompt: str


class ToolRequest(BaseModel):
    tool: str
    args: ToolArgs


class ToolResponse(BaseModel):
    result: str


# --------------------------------------------------------------------------- #
# Model initialisation (lazy singleton)
# --------------------------------------------------------------------------- #
@lru_cache
def get_model() -> Optional[ModelInference]:
    """
    Cache a single ModelInference client. Return None if initialisation fails
    so later requests can respond quickly with 503.
    """
    logger.info("Initialising Watsonx.ai model …")

    # --- Watsonx.ai Model Initialisation ---
    credentials = Credentials(url=WATSONX_URL, api_key=WATSONX_APIKEY)
    decoding="sample"
    if decoding == "sample":

        parameters = {
            GenParams.DECODING_METHOD: "sample",
            GenParams.MAX_NEW_TOKENS: 512,
            GenParams.MIN_NEW_TOKENS: 50,
            GenParams.TEMPERATURE: 0.7,
            GenParams.TOP_P: 0.9,
            GenParams.REPETITION_PENALTY: 1.2,
            GenParams.STOP_SEQUENCES: ["\n\n", "===", "---"],
        }
    else:
            parameters = {                      
        GenParams.DECODING_METHOD:    "greedy",
        GenParams.MAX_NEW_TOKENS:     512,
        GenParams.MIN_NEW_TOKENS:     1,
        GenParams.REPETITION_PENALTY: 1.1,
        GenParams.STOP_SEQUENCES:     ["\n\n", "===", "---"],
    }


    try:
        model = ModelInference(
            model_id="ibm/granite-13b-instruct-v2",
            params=parameters,
            credentials=credentials,
            project_id=PROJECT_ID,
        )
        logger.info("Watsonx.ai model ready.")
        return model
    except Exception as exc:
        logger.exception("Watsonx.ai initialisation failed", exc_info=True)
        return None  # type: ignore[return-value]


# --------------------------------------------------------------------------- #
# FastAPI application
# --------------------------------------------------------------------------- #
app = FastAPI(
    title="Watsonx Chat Agent",
    description="MCP-compatible microservice backed by IBM Watsonx.ai",
    version="1.0.0",
)


@app.get("/", summary="Health-check")
async def health() -> dict[str, str]:
    return {"status": "ok", "agent": "watsonx-agent"}


@app.post("/http", response_model=ToolResponse, summary="Invoke tool")
async def call_tool(
    payload: ToolRequest,
    model: Optional[ModelInference] = Depends(get_model),
) -> ToolResponse:
    """Only the 'chat' tool is supported."""
    if payload.tool.lower() != "chat":
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail=f"Tool '{payload.tool}' not found.",
        )

    if model is None:
        raise HTTPException(
            status_code=status.HTTP_503_SERVICE_UNAVAILABLE,
            detail="Watsonx model unavailable",
        )

    prompt_preview = payload.args.prompt.replace("\n", " ")[:80]
    logger.info("Prompt: %s%s", prompt_preview, "…" if len(prompt_preview) == 80 else "")

    try:
        result = model.generate_text(prompt=payload.args.prompt)
        return ToolResponse(result=result)
    except Exception as exc:  # pragma: no cover
        logger.exception("Watsonx.ai error")
        raise HTTPException(
            status_code=status.HTTP_502_BAD_GATEWAY,
            detail="Error communicating with Watsonx.ai",
        ) from exc


# --------------------------------------------------------------------------- #
# Entry-point
# --------------------------------------------------------------------------- #
if __name__ == "__main__":  # pragma: no cover
    import uvicorn

    logger.info("Starting Watsonx Chat Agent at http://0.0.0.0:8082")
    uvicorn.run("main:app", host="0.0.0.0", port=8082, log_level="info")
