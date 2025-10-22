"""FastAPI application that exposes repository scripts as HTTP endpoints."""
from __future__ import annotations

import json
import os
import subprocess
from functools import lru_cache
from pathlib import Path
from typing import Any, Dict, List, Mapping, MutableMapping, Sequence

from fastapi import Body, FastAPI, HTTPException
from pydantic import BaseModel

ROOT_DIR = Path(__file__).resolve().parent.parent
SCRIPTS_ROOT = ROOT_DIR / "opt" / "serverbond-agent" / "scripts"

# ``REGISTERED_SCRIPTS`` maps endpoint slugs (e.g. ``nginx/add-site``) to script paths
# relative to ``SCRIPTS_ROOT``. ``SCRIPT_TO_SLUG`` stores the inverse mapping to ease
# response construction without recomputing the slug repeatedly.
REGISTERED_SCRIPTS: Dict[str, str] = {}
SCRIPT_TO_SLUG: Dict[str, str] = {}


class ScriptExecutionResponse(BaseModel):
    """Response object that encapsulates the output of the script execution."""

    script: str
    endpoint: str
    return_code: int
    stdout: str
    stderr: str


def _build_command(script_path: Path, args: Sequence[str]) -> List[str]:
    """Return the command that should be executed for the given script."""

    if script_path.suffix == ".py":
        command = ["python3", str(script_path)]
    else:
        # Default to bash for shell scripts.
        command = ["bash", str(script_path)]
    return command + args


def _is_supported_script(path: Path) -> bool:
    """Check whether a path represents a supported script file."""

    return (
        path.is_file()
        and path.suffix in {".sh", ".py"}
        and path.name != "lib.sh"
    )


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


def _slugify_script_path(relative_path: str) -> str:
    """Convert a script path to an HTTP endpoint slug.

    Examples
    --------
    ``nginx/add_site.sh`` -> ``nginx/add-site``
    ``install-php.sh`` -> ``install-php``
    """

    components = relative_path.split("/")
    parts: List[str] = []
    for index, part in enumerate(components):
        if index == len(components) - 1:
            part = part.rsplit(".", 1)[0]
        part = part.replace("_", "-")
        parts.append(part)
    return "/".join(parts)


def _normalize_environment(
    env_data: Mapping[str, Any] | None,
) -> MutableMapping[str, str] | None:
    """Return a sanitized environment mapping for subprocess execution."""

    if env_data is None:
        return None

    sanitized: MutableMapping[str, str] = {}
    for key, value in env_data.items():
        if value is None:
            continue
        sanitized[str(key)] = str(value)
    return sanitized


def _extend_with_value(flag: str, value: Any) -> List[str]:
    """Convert a value into CLI arguments for the given flag."""

    if isinstance(value, bool):
        return [flag] if value else []
    if value is None:
        return []
    if isinstance(value, Mapping):
        return [flag, json.dumps(value)]
    if isinstance(value, list):
        flattened: List[str] = []
        for item in value:
            flattened.extend(_extend_with_value(flag, item))
        return flattened
    return [flag, str(value)]


def _payload_to_args(payload: Mapping[str, Any]) -> List[str]:
    """Translate request payload into script CLI arguments."""

    args: List[str] = []
    for key, value in payload.items():
        flag = f"--{key.replace('_', '-')}"
        args.extend(_extend_with_value(flag, value))
    return args


def _execute_script(
    script_path: str,
    args: Sequence[str],
    *,
    environment: Mapping[str, str] | None,
) -> ScriptExecutionResponse:
    """Run the provided script and return the execution response."""

    scripts = _discover_scripts()
    if script_path not in scripts:
        raise HTTPException(status_code=404, detail="Script not found.")

    file_path = scripts[script_path]
    if not file_path.exists():
        raise HTTPException(status_code=410, detail="Script is no longer available.")

    command = _build_command(file_path, args)

    env = os.environ.copy()
    if environment:
        env.update(environment)

    try:
        process = subprocess.run(
            command,
            check=False,
            capture_output=True,
            text=True,
            cwd=str(file_path.parent),
            env=env,
        )
    except OSError as exc:  # pragma: no cover - defensive branch for OS errors
        raise HTTPException(status_code=500, detail=str(exc)) from exc

    slug = SCRIPT_TO_SLUG.get(script_path, _slugify_script_path(script_path))

    return ScriptExecutionResponse(
        script=script_path,
        endpoint=f"/{slug}",
        return_code=process.returncode,
        stdout=process.stdout,
        stderr=process.stderr,
    )


def _register_script_routes(app: FastAPI) -> None:
    """Create FastAPI endpoints for each discovered script."""

    scripts = _discover_scripts()
    for relative_path in sorted(scripts.keys()):
        slug = _slugify_script_path(relative_path)
        if slug in REGISTERED_SCRIPTS:
            raise RuntimeError(
                f"Duplicate endpoint slug detected for scripts "
                f"'{REGISTERED_SCRIPTS[slug]}' and '{relative_path}'."
            )

        REGISTERED_SCRIPTS[slug] = relative_path
        SCRIPT_TO_SLUG[relative_path] = slug

        endpoint_path = f"/{slug}"
        operation_id = slug.replace("/", "_")
        tags = [slug.split("/", 1)[0]] if "/" in slug else ["scripts"]

        async def endpoint(
            payload: Dict[str, Any] = Body(default_factory=dict),
            *,
            script_rel_path: str = relative_path,
        ) -> ScriptExecutionResponse:
            payload_data: Dict[str, Any] = dict(payload or {})

            env_data = None
            for env_key in ("environment", "env"):
                if env_key in payload_data:
                    raw_env = payload_data.pop(env_key)
                    if raw_env is None:
                        continue
                    if not isinstance(raw_env, Mapping):
                        raise HTTPException(
                            status_code=422,
                            detail=f"{env_key} must be an object of key/value pairs.",
                        )
                    env_data = _normalize_environment(raw_env)
                    break

            extra_args: List[str] = []
            for alias in ("extra_args", "args", "positional_args"):
                if alias not in payload_data:
                    continue
                raw_extra = payload_data.pop(alias)
                if raw_extra is None:
                    continue
                if isinstance(raw_extra, list):
                    extra_args.extend(str(item) for item in raw_extra if item is not None)
                else:
                    extra_args.append(str(raw_extra))

            cli_args = _payload_to_args(payload_data)
            cli_args.extend(extra_args)

            return _execute_script(script_rel_path, cli_args, environment=env_data)

        app.post(
            endpoint_path,
            response_model=ScriptExecutionResponse,
            name=operation_id,
            summary=f"Execute {relative_path}",
            tags=tags,
        )(endpoint)


app = FastAPI(title="ServerBond Script Runner API", version="1.0.0")

_register_script_routes(app)


@app.get("/")
def root() -> Dict[str, Any]:
    """Health endpoint that also points to the scripts listing."""

    return {
        "message": "ServerBond script runner is up and running.",
        "scripts_endpoint": "/scripts",
        "endpoints": sorted(f"/{slug}" for slug in REGISTERED_SCRIPTS.keys()),
    }


@app.get("/scripts")
def list_scripts() -> Dict[str, Any]:
    """Return the list of available scripts as relative paths."""

    scripts = [
        {"endpoint": f"/{slug}", "script": path}
        for slug, path in sorted(REGISTERED_SCRIPTS.items())
    ]
    return {"count": len(scripts), "scripts": scripts}


if __name__ == "__main__":
    import uvicorn

    uvicorn.run("api.main:app", host="0.0.0.0", port=8000)
