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


def main() -> int:
    binary = _resolve_runfile(os.environ["BINARY"])

    with tempfile.TemporaryDirectory() as temp_dir:
        temp_path = pathlib.Path(temp_dir)
        corpus_dir = temp_path / "corpus"
        corpus_dir.mkdir()
        (corpus_dir / "seed").write_bytes(b"hello")

        output = temp_path / "observed.txt"
        env = os.environ.copy()
        env["LLVM_FUZZER_OUTPUT"] = str(output)

        subprocess.run([binary, "-runs=1", str(corpus_dir)], check=True, env=env)

        if output.read_bytes() != b"hello":
            raise RuntimeError("fuzz target did not observe the seeded input")

    return 0


if __name__ == "__main__":
    raise SystemExit(main())
