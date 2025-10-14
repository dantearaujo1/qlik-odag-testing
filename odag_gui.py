import json
import os
import shlex
import sys
import threading
from dataclasses import dataclass, asdict
from pathlib import Path
from typing import Optional, Tuple

from PyQt6.QtCore import Qt, pyqtSignal, QObject
from PyQt6.QtGui import QAction
from PyQt6.QtWidgets import (
    QApplication, QWidget, QGridLayout, QLineEdit, QLabel, QPushButton,
    QFileDialog, QTextEdit, QCheckBox, QMessageBox, QHBoxLayout, QVBoxLayout,
    QGroupBox, QFormLayout, QSpinBox, QComboBox
)

# ----------------------------
# Utilities
# ----------------------------

def which(cmd: str) -> Optional[str]:
    """Cross-platform 'which'."""
    paths = os.environ.get("PATH", "").split(os.pathsep)
    exts = [""] if os.name != "nt" else os.environ.get("PATHEXT", ".EXE;.BAT;.CMD").split(";")
    for p in paths:
        full = Path(p) / cmd
        for ext in exts:
            cand = str(full) + ext
            if os.path.isfile(cand) and os.access(cand, os.X_OK):
                return cand
    return None


def run_cmd(args: list[str], cwd: Optional[str] = None) -> Tuple[int, str, str]:
    """
    Run a command cross-platform; returns (returncode, stdout, stderr).
    Uses shell=False and passes a list of args to avoid quoting issues.
    """
    import subprocess
    try:
        proc = subprocess.run(args, cwd=cwd, capture_output=True, text=True)
        return proc.returncode, proc.stdout.strip(), proc.stderr.strip()
    except FileNotFoundError as e:
        return 127, "", f"Command not found: {args[0]}"
    except Exception as e:
        return 1, "", f"Error running {args}: {e}"


def ensure_directory(path: str) -> None:
    Path(path).mkdir(parents=True, exist_ok=True)


# ----------------------------
# Config dataclass
# ----------------------------

@dataclass
class OdagConfig:
    dev_context: str = "dante"
    prod_context: str = "prod"
    selection_name: str = "selector odag"
    template_name: str = "template"
    link_name: str = "dante"
    sheet_title: str = "My new sheet (1)"
    button_qid: str = "qpHx"
    odag_template_file: str = "odag_create_template.json"
    work_dir: str = "./files"  # where selection.qvf/template.qvf/temp JSONs go
    debug: bool = False

    def validate(self) -> Optional[str]:
        if not self.dev_context:
            return "Dev context is required."
        if not self.prod_context:
            return "Prod context is required."
        if not self.selection_name:
            return "Selection app name is required."
        if not self.template_name:
            return "Template app name is required."
        if not self.link_name:
            return "Link name is required."
        if not self.sheet_title:
            return "Sheet title is required."
        if not self.button_qid:
            return "Button QID is required."
        if not self.odag_template_file or not Path(self.odag_template_file).is_file():
            return "Valid ODAG template JSON file is required."
        return None


# ----------------------------
# Worker that performs the process (runs on a thread)
# ----------------------------

class ProcessSignals(QObject):
    log = pyqtSignal(str)
    done = pyqtSignal(bool, str)


class OdagProcessWorker(threading.Thread):
    def __init__(self, cfg: OdagConfig, signals: ProcessSignals):
        super().__init__(daemon=True)
        self.cfg = cfg
        self.signals = signals

    def log(self, msg: str):
        self.signals.log.emit(msg)

    def debug(self, msg: str):
        if self.cfg.debug:
            self.signals.log.emit(f"[DEBUG] {msg}")

    def fail(self, msg: str):
        self.signals.done.emit(False, msg)

    def run(self):
        # Ensure qlik CLI is available
        if which("qlik") is None:
            self.fail("Qlik CLI not found on PATH. Please install it and try again.")
            return

        err = self.cfg.validate()
        if err:
            self.fail(f"Invalid configuration: {err}")
            return

        try:
            ensure_directory(self.cfg.work_dir)
            work_dir = str(Path(self.cfg.work_dir).resolve())
            selection_qvf = str(Path(work_dir) / "selection.qvf")
            template_qvf = str(Path(work_dir) / "template.qvf")
            tmp_sheet_json = str(Path(work_dir) / "tmp_sheet_data.json")
            tmp_button_json = str(Path(work_dir) / "tmp_button_data.json")

            # 1) Switch to DEV context
            self.log(f"Switching to DEV context: {self.cfg.dev_context}")
            rc, out, err = run_cmd(["qlik", "context", "use", self.cfg.dev_context])
            if rc != 0:
                self.fail(f"Failed to switch DEV context: {err or out}")
                return

            # 2) Export selection app
            self.log(f"Exporting ODAG selection app: {self.cfg.selection_name}")
            # Get ID with --quiet
            rc, out, err = run_cmd(["qlik", "app", "ls", "--quiet", "--name", self.cfg.selection_name])
            if rc != 0 or not out:
                self.fail(f"Unable to find selection app '{self.cfg.selection_name}': {err or out}")
                return
            sel_app_id = out.split()[0]
            self.debug(f"Selection app id: {sel_app_id}")

            rc, out, err = run_cmd(["qlik", "app", "export", sel_app_id, "--output-file", selection_qvf])
            if rc != 0:
                self.fail(f"Export selection failed: {err or out}")
                return

            # 3) Export template app
            self.log(f"Exporting ODAG template app: {self.cfg.template_name}")
            rc, out, err = run_cmd(["qlik", "app", "ls", "--quiet", "--name", self.cfg.template_name])
            if rc != 0 or not out:
                self.fail(f"Unable to find template app '{self.cfg.template_name}': {err or out}")
                return
            tmpl_app_id = out.split()[0]
            self.debug(f"Template app id: {tmpl_app_id}")

            rc, out, err = run_cmd(["qlik", "app", "export", tmpl_app_id, "--output-file", template_qvf])
            if rc != 0:
                self.fail(f"Export template failed: {err or out}")
                return

            # 4) Switch to PROD context
            self.log(f"Switching to PROD context: {self.cfg.prod_context}")
            rc, out, err = run_cmd(["qlik", "context", "use", self.cfg.prod_context])
            if rc != 0:
                self.fail(f"Failed to switch PROD context: {err or out}")
                return

            # 5) Import selection/template QVFs
            self.log("Importing selection.qvf...")
            rc, out, err = run_cmd(["qlik", "app", "import", "--file", selection_qvf, "--quiet"])
            if rc != 0 or not out:
                self.fail(f"Import selection failed: {err or out}")
                return
            new_sel_app = out.strip()
            self.debug(f"Imported selection app id: {new_sel_app}")

            self.log("Importing template.qvf...")
            rc, out, err = run_cmd(["qlik", "app", "import", "--file", template_qvf, "--quiet"])
            if rc != 0 or not out:
                self.fail(f"Import template failed: {err or out}")
                return
            new_tmpl_app = out.strip()
            self.debug(f"Imported template app id: {new_tmpl_app}")

            # 6) Find the sheet qId by title
            self.log(f"Locating sheet by title: {self.cfg.sheet_title}")
            rc, out, err = run_cmd(["qlik", "app", "object", "ls", "--app", new_sel_app, "--verbose", "--json"])
            if rc != 0 or not out:
                self.fail(f"Failed to list objects in selection app: {err or out}")
                return
            try:
                objs = json.loads(out)
            except json.JSONDecodeError:
                self.fail("Could not parse JSON from 'qlik app object ls' output.")
                return
            sheet_qid = None
            for obj in objs:
                if obj.get("qType") == "sheet" and obj.get("title") == self.cfg.sheet_title:
                    sheet_qid = obj.get("qId")
                    break
            if not sheet_qid:
                self.fail(f"Sheet with title '{self.cfg.sheet_title}' not found.")
                return
            self.debug(f"Sheet qId: {sheet_qid}")

            # 7) Unpublish the sheet
            self.log(f"Unpublishing sheet: {sheet_qid}")
            rc, out, err = run_cmd(["qlik", "app", "object", "unpublish", sheet_qid, "--app", new_sel_app])
            if rc != 0:
                self.fail(f"Unpublish failed: {err or out}")
                return

            # 8) Update ODAG template JSON (name/selectionApp/templateApp)
            self.log("Updating ODAG template JSON…")
            try:
                with open(self.cfg.odag_template_file, "r", encoding="utf-8") as f:
                    odag_data = json.load(f)
            except Exception as e:
                self.fail(f"Failed to read {self.cfg.odag_template_file}: {e}")
                return

            odag_data["name"] = self.cfg.link_name
            odag_data["selectionApp"] = new_sel_app
            odag_data["templateApp"] = new_tmpl_app

            # Write to a tmp file next to original to avoid partial writes
            tmp_odag = str(Path(self.cfg.odag_template_file).with_suffix(".tmp.json"))
            try:
                with open(tmp_odag, "w", encoding="utf-8") as f:
                    json.dump(odag_data, f, ensure_ascii=False, indent=2)
                # Atomic-ish replace
                os.replace(tmp_odag, self.cfg.odag_template_file)
            except Exception as e:
                self.fail(f"Failed to write updated ODAG template: {e}")
                return

            # 9) Create ODAG link
            self.log("Creating ODAG link…")
            rc, out, err = run_cmd(["qlik", "raw", "post", "/v1/odaglinks", "--body-file", self.cfg.odag_template_file, "-q"])
            if rc != 0 or not out:
                self.fail(f"Create ODAG link failed: {err or out}")
                return
            odag_link_ref = out.strip()
            self.debug(f"ODAG link ref: {odag_link_ref}")

            # 10) Fetch properties (sheet + button)
            self.log("Fetching sheet & button properties…")
            rc, out, err = run_cmd(["qlik", "app", "object", "properties", sheet_qid, "--app", new_sel_app])
            if rc != 0 or not out:
                self.fail(f"Failed to get sheet properties: {err or out}")
                return
            try:
                with open(tmp_sheet_json, "w", encoding="utf-8") as f:
                    f.write(out)
            except Exception as e:
                self.fail(f"Failed writing {tmp_sheet_json}: {e}")
                return

            rc, out, err = run_cmd(["qlik", "app", "object", "properties", self.cfg.button_qid, "--app", new_sel_app])
            if rc != 0 or not out:
                self.fail(f"Failed to get button properties (QID={self.cfg.button_qid}): {err or out}")
                return
            try:
                with open(tmp_button_json, "w", encoding="utf-8") as f:
                    f.write(out)
            except Exception as e:
                self.fail(f"Failed writing {tmp_button_json}: {e}")
                return

            # 11) Edit JSONs (button and sheet)
            self.log("Updating button/sheet JSON with ODAG reference…")
            try:
                with open(tmp_button_json, "r", encoding="utf-8") as f:
                    btn = json.load(f)
                btn.setdefault("qMetaDef", {})["odagLinkRef"] = odag_link_ref
                with open(tmp_button_json, "w", encoding="utf-8") as f:
                    json.dump(btn, f, ensure_ascii=False, indent=2)
            except Exception as e:
                self.fail(f"Failed updating button JSON: {e}")
                return

            try:
                with open(tmp_sheet_json, "r", encoding="utf-8") as f:
                    sheet = json.load(f)
                # Ensure navPoints exists & index 0
                nav = sheet.setdefault("navPoints", [])
                if not nav:
                    nav.append({})
                nav[0]["odagLinkRefID"] = odag_link_ref
                nav[0]["title"] = self.cfg.link_name
                with open(tmp_sheet_json, "w", encoding="utf-8") as f:
                    json.dump(sheet, f, ensure_ascii=False, indent=2)
            except Exception as e:
                self.fail(f"Failed updating sheet JSON: {e}")
                return

            # 12) Apply updated objects
            self.log("Applying updated objects…")
            rc, out, err = run_cmd(["qlik", "app", "object", "set", tmp_button_json, "--app", new_sel_app])
            if rc != 0:
                self.fail(f"Setting button failed: {err or out}")
                return
            rc, out, err = run_cmd(["qlik", "app", "object", "set", tmp_sheet_json, "--app", new_sel_app])
            if rc != 0:
                self.fail(f"Setting sheet failed: {err or out}")
                return

            # 13) Publish sheet again
            self.log(f"Publishing sheet: {sheet_qid}")
            rc, out, err = run_cmd(["qlik", "app", "object", "publish", sheet_qid, "--app", new_sel_app])
            if rc != 0:
                self.fail(f"Publish failed: {err or out}")
                return

            self.signals.done.emit(True, "Process completed successfully.")

        except Exception as e:
            self.fail(f"Unexpected error: {e}")


# ----------------------------
# UI
# ----------------------------

class OdagGUI(QWidget):
    def __init__(self):
        super().__init__()
        self.setWindowTitle("ODAG Link Builder")
        self.setMinimumWidth(760)

        self.cfg = OdagConfig()
        self.signals = ProcessSignals()
        self.signals.log.connect(self.append_log)
        self.signals.done.connect(self.finish_process)

        # Form
        form = QFormLayout()

        self.dev_context = QLineEdit(self.cfg.dev_context)
        self.prod_context = QLineEdit(self.cfg.prod_context)
        self.selection_name = QLineEdit(self.cfg.selection_name)
        self.template_name = QLineEdit(self.cfg.template_name)
        self.link_name = QLineEdit(self.cfg.link_name)
        self.sheet_title = QLineEdit(self.cfg.sheet_title)
        self.button_qid = QLineEdit(self.cfg.button_qid)
        self.work_dir = QLineEdit(self.cfg.work_dir)
        self.debug = QCheckBox("Enable debug logging")
        self.debug.setChecked(self.cfg.debug)

        self.template_file = QLineEdit(self.cfg.odag_template_file)
        browse_btn = QPushButton("Browse…")
        browse_btn.clicked.connect(self.browse_template)

        tf_layout = QHBoxLayout()
        tf_layout.addWidget(self.template_file, 1)
        tf_layout.addWidget(browse_btn)

        form.addRow("Dev context:", self.dev_context)
        form.addRow("Prod context:", self.prod_context)
        form.addRow("Selection app name:", self.selection_name)
        form.addRow("Template app name:", self.template_name)
        form.addRow("Link name:", self.link_name)
        form.addRow("Sheet title:", self.sheet_title)
        form.addRow("Button QID:", self.button_qid)
        form.addRow("Work dir:", self.work_dir)
        form.addRow("ODAG template JSON:", tf_layout)
        form.addRow("", self.debug)

        # Buttons
        btns = QHBoxLayout()
        save_btn = QPushButton("Save Config")
        run_btn = QPushButton("Run Process")
        clear_btn = QPushButton("Clear Log")
        btns.addWidget(save_btn)
        btns.addWidget(run_btn)
        btns.addStretch()
        btns.addWidget(clear_btn)

        save_btn.clicked.connect(self.save_config)
        run_btn.clicked.connect(self.run_process)
        clear_btn.clicked.connect(self.clear_log)

        # Log
        self.log_view = QTextEdit()
        self.log_view.setReadOnly(True)
        self.log_view.setLineWrapMode(QTextEdit.LineWrapMode.NoWrap)

        # Main layout
        group = QGroupBox("ODAG Settings")
        group.setLayout(form)

        layout = QVBoxLayout()
        layout.addWidget(group)
        layout.addLayout(btns)
        layout.addWidget(QLabel("Logs:"))
        layout.addWidget(self.log_view, 1)
        self.setLayout(layout)

        # Menu (optional)
        about = QAction("About", self)
        about.triggered.connect(self.show_about)
        self.addActions([about])

    # ----- UI helpers -----

    def append_log(self, msg: str):
        self.log_view.append(msg)

    def clear_log(self):
        self.log_view.clear()

    def show_about(self):
        QMessageBox.information(self, "About", "ODAG Link Builder\nCross-platform PyQt6 GUI\nRuns Qlik CLI under the hood.")

    def browse_template(self):
        path, _ = QFileDialog.getOpenFileName(self, "Select ODAG template JSON", "", "JSON Files (*.json);;All Files (*)")
        if path:
            self.template_file.setText(path)

    def read_cfg_from_ui(self) -> OdagConfig:
        cfg = OdagConfig(
            dev_context=self.dev_context.text().strip(),
            prod_context=self.prod_context.text().strip(),
            selection_name=self.selection_name.text().strip(),
            template_name=self.template_name.text().strip(),
            link_name=self.link_name.text().strip(),
            sheet_title=self.sheet_title.text().strip(),
            button_qid=self.button_qid.text().strip(),
            odag_template_file=self.template_file.text().strip(),
            work_dir=self.work_dir.text().strip() or "./files",
            debug=self.debug.isChecked(),
        )
        return cfg

    def save_config(self):
        cfg = self.read_cfg_from_ui()
        err = cfg.validate()
        if err:
            QMessageBox.warning(self, "Invalid config", err)
            return
        dest, _ = QFileDialog.getSaveFileName(self, "Save Config JSON", "odag_config.json", "JSON Files (*.json)")
        if not dest:
            return
        try:
            with open(dest, "w", encoding="utf-8") as f:
                json.dump(asdict(cfg), f, ensure_ascii=False, indent=2)
            QMessageBox.information(self, "Saved", f"Config saved to:\n{dest}")
        except Exception as e:
            QMessageBox.critical(self, "Error", f"Failed to save config:\n{e}")

    def run_process(self):
        cfg = self.read_cfg_from_ui()
        err = cfg.validate()
        if err:
            QMessageBox.warning(self, "Invalid config", err)
            return
        self.clear_log()
        self.append_log("Starting process…")
        worker = OdagProcessWorker(cfg, self.signals)
        # keep a ref so thread isn't GC-ed
        self._worker = worker
        worker.start()

    def finish_process(self, ok: bool, msg: str):
        if ok:
            self.append_log("✅ " + msg)
            QMessageBox.information(self, "Done", msg)
        else:
            self.append_log("❌ " + msg)
            QMessageBox.critical(self, "Failed", msg)


# ----------------------------
# Entry
# ----------------------------

def main():
    app = QApplication(sys.argv)
    win = OdagGUI()
    win.show()
    sys.exit(app.exec())

if __name__ == "__main__":
    main()
