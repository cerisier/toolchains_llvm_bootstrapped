import os
import pathlib
import subprocess
import tempfile


def _resolve_runfile(path: str) -> str:
    candidates = [path]
    if not path.endswith(".exe"):
        candidates.append(path + ".exe")

    for candidate_path in candidates:
        candidate = pathlib.Path(candidate_path)
        if candidate.exists():
            return str(candidate)

    normalized_candidates = [candidate.replace("\\", "/") for candidate in candidates]

    runfiles_dir = os.environ.get("RUNFILES_DIR")
    if runfiles_dir:
        for normalized in normalized_candidates:
            for prefix in ("", "_main/"):
                candidate = pathlib.Path(runfiles_dir, prefix + normalized)
                if candidate.exists():
                    return str(candidate)

    manifest = os.environ.get("RUNFILES_MANIFEST_FILE")
    if manifest:
        with open(manifest, encoding="utf-8") as manifest_file:
            for line in manifest_file:
                key, _, value = line.rstrip("\n").partition(" ")
                if key in normalized_candidates or key in ["_main/" + candidate for candidate in normalized_candidates]:
                    return value

    raise FileNotFoundError(f"could not resolve runfile: {path}")


def _expect_nonzero() -> bool:
    return os.environ.get("EXPECT_NONZERO", "0") == "1"


def main() -> int:
    binary = _resolve_runfile(os.environ["BINARY"])
    expected_substring = os.environ["EXPECTED_SUBSTRING"]
    input_text = os.environ["INPUT_TEXT"]

    with tempfile.TemporaryDirectory() as temp_dir:
        input_path = pathlib.Path(temp_dir) / "seed"
        input_path.write_bytes(input_text.encode("utf-8"))

        result = subprocess.run(
            [binary, str(input_path)],
            check = False,
            stdout = subprocess.PIPE,
            stderr = subprocess.STDOUT,
            text = True,
        )

        if expected_substring not in result.stdout:
            raise RuntimeError(
                "sanitizer output did not contain expected text\n"
                f"expected: {expected_substring}\n"
                f"output:\n{result.stdout}",
            )

        if _expect_nonzero() and result.returncode == 0:
            raise RuntimeError("sanitizer run was expected to fail, but exited successfully")

    return 0


if __name__ == "__main__":
    raise SystemExit(main())
