from pathlib import Path
import sys

SCRIPT_DIR = Path(__file__).resolve().parent
if str(SCRIPT_DIR) not in sys.path:
    sys.path.insert(0, str(SCRIPT_DIR))

from manage_user import main


if __name__ == "__main__":
    raise SystemExit(main(default_role="editor"))
