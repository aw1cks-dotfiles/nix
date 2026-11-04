import re
import sys
from pathlib import Path


# Select executable examples by their declarations/APIs, not prose headings.
def example(path: Path, language: str, symbol: str) -> str:
    blocks = re.findall(
        rf"^```{language}\s*\n(.*?)^```\s*$",
        path.read_text(encoding="utf-8"),
        flags=re.MULTILINE | re.DOTALL,
    )
    matches = [block for block in blocks if re.search(symbol, block)]
    if len(matches) != 1:
        raise ValueError(f"{path}: expected one example for {symbol}")
    return matches[0]


# Keep the published Task and compute definitions; supply the test's own main.
def extract_task(source: Path, destination: Path) -> None:
    code = example(source, "cpp", r"\bstruct\s+Task\s*\{")
    definitions, count = re.subn(
        r"\bint\s+main\s*\([^)]*\)\s*\{.*\Z",
        "",
        code,
        count=1,
        flags=re.DOTALL,
    )
    if count != 1:
        raise ValueError(f"{source}: expected an example main function")
    destination.write_text(definitions, encoding="utf-8")


# Only allocation/registration is replaced; buffer and SQE APIs stay real.
def extract_buffer_ring(source: Path, destination: Path) -> None:
    code = example(source, "c", r"\bio_uring_buf_ring_add\s*\(")
    code = re.sub(r"^#include[^\n]*\n", "", code, flags=re.MULTILINE)
    code, count = re.subn(
        r"\bbuf_ring\s*=\s*io_uring_setup_buf_ring\s*\([^;]*\);",
        "buf_ring = calloc(BUF_COUNT, sizeof(struct io_uring_buf));\n"
        "assert(buf_ring != NULL);\n"
        "io_uring_buf_ring_init(buf_ring);\n"
        "buf_ring->tail = initial_tail;",
        code,
        count=1,
    )
    if count != 1:
        raise ValueError(f"{source}: expected one buffer ring setup call")
    destination.write_text(code, encoding="utf-8")


def main() -> None:
    source = Path(sys.argv[1])
    extract_task(
        source / "cpp-coroutines/SKILL.md", Path("task-example.hpp")
    )
    extract_buffer_ring(
        source / "io-uring/SKILL.md", Path("buffer-ring-example.inc")
    )


if __name__ == "__main__":
    main()
