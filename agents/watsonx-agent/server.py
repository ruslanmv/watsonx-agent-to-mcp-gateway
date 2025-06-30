# server.py
import os, logging
from dotenv import load_dotenv
from mcp.server.fastmcp import FastMCP
from ibm_watsonx_ai import APIClient, Credentials
from ibm_watsonx_ai.foundation_models import ModelInference
from ibm_watsonx_ai.metanames import GenTextParamsMetaNames as GenParams

# ——— Load settings ———
load_dotenv()  
API_KEY    = os.getenv("WATSONX_API_KEY")
URL        = os.getenv("WATSONX_URL")
PROJECT_ID = os.getenv("PROJECT_ID")
MODEL_ID   = os.getenv("MODEL_ID", "ibm/granite-3-3-8b-instruct")

for name,val in [("WATSONX_API_KEY",API_KEY),("WATSONX_URL",URL),("PROJECT_ID",PROJECT_ID)]:
    if not val:
        raise RuntimeError(f"{name} is not set")

logging.basicConfig(level=logging.INFO, format="%(asctime)s [%(levelname)s] %(message)s")

creds  = Credentials(url=URL, api_key=API_KEY)
client = APIClient(credentials=creds, project_id=PROJECT_ID)
model  = ModelInference(model_id=MODEL_ID, credentials=creds, project_id=PROJECT_ID)

# ——— Define MCP server ———
mcp = FastMCP("Watsonx Chat Agent")

@mcp.tool()
def chat(query: str) -> str:
    logging.info("chat() got %r", query)
    params = {
      GenParams.DECODING_METHOD: "greedy",
      GenParams.MAX_NEW_TOKENS:   200,
    }
    resp = model.generate_text(prompt=query, params=params, raw_response=True)
    text = resp["results"][0]["generated_text"].strip()
    logging.info("→ %r", text)
    return text

if __name__ == "__main__":
    # run via stdio (default)
    logging.info("Starting Watsonx MCP server on STDIO…")
    mcp.run()
