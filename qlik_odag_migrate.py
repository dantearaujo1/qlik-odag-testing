#!/usr/bin/env python3
import argparse
import json
import os
import shutil
import subprocess
import sys
import tempfile
import time
from pathlib import Path
from typing import Dict, Any, Optional

def run(cmd: list[str], cwd: Optional[str] = None, capture: bool = True) -> subprocess.CompletedProcess:
    """Run a command with robust error reporting (no shell), cross-platform safe."""
    try:
        cp = subprocess.run(
            cmd,
            cwd=cwd,
            check=True,
            text=True,
            stdout=subprocess.PIPE if capture else None,
            stderr=subprocess.PIPE if capture else None,
        )
        return cp
    except subprocess.CalledProcessError as e:
        msg = f"\nCommand failed: {' '.join(cmd)}\nExit code: {e.returncode}\n"
        if e.stdout:
            msg += f"STDOUT:\n{e.stdout}\n"
        if e.stderr:
            msg += f"STDERR:\n{e.stderr}\n"
        raise RuntimeError(msg) from e

def ensure_cli_available(qlik_bin: str) -> None:
    if shutil.which(qlik_bin) is None:
        raise RuntimeError(
            f"`{qlik_bin}` not found in PATH. Install qlik-cli and ensure it’s on PATH."
        )

def context_use(qlik_bin: str, ctx: str) -> None:
    print(f"→ Switching context to: {ctx}")
    run([qlik_bin, "context", "use", ctx], capture=True)

def export_app(qlik_bin: str, app_id: str, out_qvf: str) -> None:
    print(f"→ Exporting app {app_id} to {out_qvf}")
    out_path = Path(out_qvf)
    out_path.parent.mkdir(parents=True, exist_ok=True)
    run([qlik_bin, "app", "export", app_id, "--output-file", out_qvf], capture=True)

def import_app(qlik_bin: str, qvf_file: str, dst_app_name: Optional[str], dst_app_id: Optional[str]) -> None:
    print(f"→ Importing {qvf_file} into destination environment")
    cmd = [qlik_bin, "app", "import", "--file", qvf_file]
    if dst_app_name:
        cmd += ["--name", dst_app_name]
    if dst_app_id:
        cmd += ["--appId", dst_app_id]  # update existing app id if provided
    run(cmd, capture=True)

def read_json(path: str) -> Dict[str, Any]:
    with open(path, "r", encoding="utf-8") as f:
        return json.load(f)

def write_json(path: str, payload: Dict[str, Any]) -> None:
    with open(path, "w", encoding="utf-8") as f:
        json.dump(payload, f, ensure_ascii=False, indent=2)

def now_epoch_ms() -> int:
    return int(time.time() * 1000)

def get_object_properties(qlik_bin: str, obj_id: str, app_ref: str) -> Dict[str, Any]:
    """app_ref can be app name or app id (qlik-cli accepts either)."""
    print(f"  • Fetching properties for object {obj_id}")
    cp = run([qlik_bin, "app", "object", "properties", obj_id, "--app", app_ref], capture=True)
    try:
        return json.loads(cp.stdout)
    except json.JSONDecodeError as e:
        raise RuntimeError(
            f"Failed to parse properties JSON for object {obj_id}.\nRaw output:\n{cp.stdout}"
        ) from e

def set_object_properties(qlik_bin: str, payload: Dict[str, Any], app_ref: str) -> None:
    """Write payload to a temp file and push back via `qlik app object set`."""
    with tempfile.NamedTemporaryFile("w", prefix="qlik_obj_", suffix=".json", delete=False, encoding="utf-8") as tf:
        temp_path = tf.name
        json.dump(payload, tf, ensure_ascii=False, indent=2)
    try:
        run([qlik_bin, "app", "object", "set", temp_path, "--app", app_ref], capture=True)
    finally:
        try:
            os.remove(temp_path)
        except OSError:
            pass

def fix_odag_button(
    qlik_bin: str,
    app_ref: str,
    obj_id: str,
    new_link_ref: str,
    enforce_qtype: bool,
    update_timestamp: bool,
    dry_run: bool,
) -> bool:
    """
    Returns True if an update was applied (or would be in dry-run), False if skipped.
    """
    props = get_object_properties(qlik_bin, obj_id, app_ref)

    # Basic validations and navigation
    qinfo = props.get("qInfo", {})
    qmeta = props.get("qMetaDef", {})

    if enforce_qtype:
        qtype = qinfo.get("qType")
        if qtype != "odagapplink":
            print(f"    ↳ Skip: object {obj_id} qType={qtype} (expected odagapplink).")
            return False

    current_link = qmeta.get("odagLinkRef")
    if current_link == new_link_ref:
        print(f"    ↳ No change: object {obj_id} already has odagLinkRef={current_link}.")
        return False

    print(f"    ↳ Will set odagLinkRef: {current_link}  →  {new_link_ref}")
    if dry_run:
        return True

    # Apply mutation
    qmeta["odagLinkRef"] = new_link_ref
    if update_timestamp:
        qmeta["timestamp"] = now_epoch_ms()

    props["qMetaDef"] = qmeta  # reattach in case it was missing

    # Push back
    set_object_properties(qlik_bin, props, app_ref)
    print(f"    ✓ Updated {obj_id}")
    return True

def main() -> None:
    parser = argparse.ArgumentParser(
        description="Migrate a Qlik app between contexts and fix ODAG buttons' odagLinkRef."
    )
    parser.add_argument("--qlik-bin", default="qlik", help="Name/path of qlik-cli binary (default: qlik)")
    parser.add_argument("--src-context", required=True, help="Source context name (e.g., dev)")
    parser.add_argument("--dst-context", required=True, help="Destination context name (e.g., prod)")
    parser.add_argument("--src-app-id", required=True, help="Source app id (to export from src-context)")
    parser.add_argument("--dst-app-name", required=True, help="Destination app name (for import/updates)")
    parser.add_argument("--dst-app-id", default=None, help="Destination app id (optional; if set, import updates this app id)")
    parser.add_argument("--view-qvf", required=True, help="Path to save exported view QVF (from src-context)")
    parser.add_argument("--export-template", action="store_true", help="Also export a template app (optional)")
    parser.add_argument("--src-template-app-id", default=None, help="Template app id (if --export-template is set)")
    parser.add_argument("--template-qvf", default=None, help="Path to save exported template QVF (if --export-template)")
    parser.add_argument("--mapping-file", required=True, help="JSON file with { '<button_qid>': '<odagLinkRef>' }")
    parser.add_argument("--enforce-qtype", action="store_true", help="Require qInfo.qType == 'odagapplink' to update")
    parser.add_argument("--update-timestamp", action="store_true", help="Update qMetaDef.timestamp to now")
    parser.add_argument("--dry-run", action="store_true", help="Show what would change but do not modify anything")
    args = parser.parse_args()

    ensure_cli_available(args.qlik_bin)

    # Load mapping
    mapping = read_json(args.mapping_file)
    if not isinstance(mapping, dict) or not mapping:
        raise RuntimeError("Mapping file must be a non-empty JSON object like { 'BUTTON_QID': 'LINK_REF', ... }")

    # 1) Export from source context
    context_use(args.qlik_bin, args.src_context)
    export_app(args.qlik_bin, args.src_app_id, args.view_qvf)

    if args.export_template:
        if not args.src_template_app_id or not args.template_qvf:
            raise RuntimeError("--export-template requires --src-template-app-id and --template-qvf")
        export_app(args.qlik_bin, args.src_template_app_id, args.template_qvf)

    # 2) Import into destination context
    context_use(args.qlik_bin, args.dst_context)
    import_app(args.qlik_bin, args.view_qvf, args.dst_app_name, args.dst_app_id)

    # 3) For each mapping entry: pull, patch, push
    print(f"\n→ Fixing ODAG buttons in app: {args.dst_app_name}")
    updated = 0
    skipped = 0
    for obj_id, new_link in mapping.items():
        try:
            changed = fix_odag_button(
                qlik_bin=args.qlik_bin,
                app_ref=args.dst_app_name if args.dst_app_name else (args.dst_app_id or ""),
                obj_id=obj_id,
                new_link_ref=new_link,
                enforce_qtype=args.enforce_qtype,
                update_timestamp=args.update_timestamp,
                dry_run=args.dry_run,
            )
            if changed:
                updated += 1
            else:
                skipped += 1
        except Exception as e:
            print(f"    ✗ Error updating {obj_id}: {e}")
            skipped += 1

    print("\n=== Summary ===")
    print(f"Updated: {updated}")
    print(f"Skipped/No change/Errors: {skipped}")
    if args.dry_run:
        print("Mode: DRY RUN (no changes were pushed)")

if __name__ == "__main__":
    try:
        main()
    except Exception as e:
        print(f"\nFATAL: {e}", file=sys.stderr)
        sys.exit(1)
