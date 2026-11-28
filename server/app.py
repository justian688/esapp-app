import hashlib
import hmac
import json
import os
import re
import tempfile
from datetime import datetime, timezone
from pathlib import Path

from fastapi import FastAPI, File, Form, Header, HTTPException, UploadFile

app = FastAPI(title="es省電王課程影片接收服務", docs_url=None, redoc_url=None)
upload_root = Path(os.environ.get("UPLOAD_ROOT", "/srv/esapp-course-uploads"))
upload_token = os.environ.get("UPLOAD_TOKEN", "")


def safe_component(value: str, fallback: str) -> str:
    safe = re.sub(r"[^A-Za-z0-9_-]", "_", value.strip())[:100]
    return safe or fallback


@app.get("/healthz")
async def healthz():
    return {"ok": True, "upload_ready": bool(upload_token)}


@app.post("/api/v1/uploads", status_code=201)
async def receive_video(
    file: UploadFile = File(...),
    media_id: str = Form(...),
    course_id: str = Form(""),
    course_name: str = Form("未分類課程"),
    category: str = Form(""),
    teacher: str = Form(""),
    recorded_at: str = Form(""),
    authorization: str | None = Header(default=None),
    idempotency_key: str | None = Header(default=None, alias="Idempotency-Key"),
):
    if not upload_token:
        raise HTTPException(status_code=503, detail="Upload service is not configured")
    supplied = ""
    if authorization and authorization.lower().startswith("bearer "):
        supplied = authorization[7:].strip()
    if not hmac.compare_digest(supplied, upload_token):
        raise HTTPException(status_code=401, detail="Invalid upload token")

    original_name = Path(file.filename or "course.mp4").name
    suffix = Path(original_name).suffix.lower()
    if suffix not in {".mp4", ".mov", ".m4v"}:
        raise HTTPException(status_code=400, detail="Only video files are accepted")
    safe_media_id = safe_component(media_id or idempotency_key or original_name, "video")
    safe_course_id = safe_component(course_id, "uncategorized")
    try:
        recorded = datetime.fromisoformat(recorded_at.replace("Z", "+00:00"))
    except ValueError:
        recorded = datetime.now(timezone.utc)
    month = recorded.strftime("%Y-%m")
    target_dir = upload_root / safe_course_id / month
    target_dir.mkdir(parents=True, exist_ok=True)
    destination = target_dir / f"{safe_media_id}{suffix}"
    metadata_path = target_dir / f"{safe_media_id}.json"

    if destination.exists():
        return {"ok": True, "duplicate": True, "file": str(destination.relative_to(upload_root))}

    digest = hashlib.sha256()
    size = 0
    fd, temp_name = tempfile.mkstemp(prefix=f".{safe_media_id}.", suffix=".part", dir=target_dir)
    try:
        with os.fdopen(fd, "wb") as output:
            while chunk := await file.read(1024 * 1024):
                output.write(chunk)
                digest.update(chunk)
                size += len(chunk)
            output.flush()
            os.fsync(output.fileno())
        os.replace(temp_name, destination)
        metadata = {
            "media_id": safe_media_id,
            "original_filename": original_name,
            "course_id": course_id,
            "course_name": course_name,
            "category": category,
            "teacher": teacher,
            "recorded_at": recorded.isoformat(),
            "uploaded_at": datetime.now(timezone.utc).isoformat(),
            "size_bytes": size,
            "sha256": digest.hexdigest(),
        }
        metadata_tmp = metadata_path.with_suffix(".json.part")
        metadata_tmp.write_text(json.dumps(metadata, ensure_ascii=False, indent=2), encoding="utf-8")
        os.replace(metadata_tmp, metadata_path)
    except Exception:
        try:
            os.unlink(temp_name)
        except FileNotFoundError:
            pass
        raise
    finally:
        await file.close()

    return {"ok": True, "duplicate": False, "file": str(destination.relative_to(upload_root)), "size_bytes": size}
