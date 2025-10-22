"""FastAPI application that exposes repository scripts as HTTP endpoints."""
from __future__ import annotations

import subprocess
from functools import lru_cache
from pathlib import Path
from typing import Dict, List

from fastapi import FastAPI, HTTPException
from pydantic import BaseModel, Field

ROOT_DIR = Path(__file__).resolve().parent.parent
SCRIPTS_ROOT = ROOT_DIR / "opt" / "serverbond-agent" / "scripts"


class ScriptExecutionRequest(BaseModel):
    """Request payload containing arguments passed to the script."""

    args: List[str] = Field(
        default_factory=list,
        description="Optional arguments that will be forwarded to the script.",
    )


class ScriptExecutionResponse(BaseModel):
    """Response object that encapsulates the output of the script execution."""

    script: str
    return_code: int
    stdout: str
    stderr: str


def _build_command(script_path: Path, args: List[str]) -> List[str]:
    """Return the command that should be executed for the given script."""

    if script_path.suffix == ".py":
        command = ["python3", str(script_path)]
    else:
        # Default to bash for shell scripts.
        command = ["bash", str(script_path)]
    return command + args


def _is_supported_script(path: Path) -> bool:
    """Check whether a path represents a supported script file."""

    return path.is_file() and path.suffix in {".sh", ".py"}


@lru_cache(maxsize=1)
def _discover_scripts() -> Dict[str, Path]:
    """Discover available scripts under ``SCRIPTS_ROOT``.

    The function is memoized because the set of scripts in the repository is static during
    the lifetime of the API process.
    """

    scripts: Dict[str, Path] = {}
    if not SCRIPTS_ROOT.exists():
        return scripts

    for file_path in SCRIPTS_ROOT.rglob("*"):
        if not _is_supported_script(file_path):
            continue
        relative_path = file_path.relative_to(SCRIPTS_ROOT).as_posix()
        scripts[relative_path] = file_path
    return scripts


app = FastAPI(title="ServerBond Script Runner API", version="1.0.0")


@app.get("/")
def root() -> Dict[str, str]:
    """Health endpoint that also points to the scripts listing."""

    return {
        "message": "ServerBond script runner is up and running.",
        "scripts_endpoint": "/scripts",
    }


@app.get("/scripts")
def list_scripts() -> Dict[str, List[str]]:
    """Return the list of available scripts as relative paths."""

    scripts = sorted(_discover_scripts().keys())
    return {"scripts": scripts}


@app.post("/scripts/{script_path:path}", response_model=ScriptExecutionResponse)
def run_script(script_path: str, request: ScriptExecutionRequest) -> ScriptExecutionResponse:
    """Execute the script that matches ``script_path`` and return its result."""

    scripts = _discover_scripts()
    if script_path not in scripts:
        raise HTTPException(status_code=404, detail="Script not found.")

    file_path = scripts[script_path]
    if not file_path.exists():
        raise HTTPException(status_code=410, detail="Script is no longer available.")

    command = _build_command(file_path, request.args)

    try:
        process = subprocess.run(
            command,
            check=False,
            capture_output=True,
            text=True,
            cwd=str(file_path.parent),
        )
    except OSError as exc:  # pragma: no cover - defensive branch for OS errors
        raise HTTPException(status_code=500, detail=str(exc)) from exc

    return ScriptExecutionResponse(
        script=script_path,
        return_code=process.returncode,
        stdout=process.stdout,
        stderr=process.stderr,
    )


if __name__ == "__main__":
    import uvicorn

    uvicorn.run("api.main:app", host="0.0.0.0", port=8000)
