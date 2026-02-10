# C definition vs assembler tentative definition (`.comm`)

This mini repo demonstrates how the linker handles:

1. A **strong definition** of a symbol in C (`defined.c`), and
2. A **tentative/common definition** of the same symbol in assembly (`tentative_comm.s`) using `.comm`.

It also includes a contrasting case with a second **strong definition** (`duplicate_strong.s`) that should fail at link time.

## Files

- `defined.c`: `int shared_symbol = 1234;` (strong definition) + `main`.
- `tentative_comm.s`: `.comm shared_symbol,4,4` (common/tentative definition).
- `duplicate_strong.s`: another strong definition of `shared_symbol`.

## Build and run

### Case 1: Strong C definition + `.comm` tentative definition (expected: **works**)

```bash
gcc -c defined.c -o defined.o
gcc -c tentative_comm.s -o tentative_comm.o
gcc defined.o tentative_comm.o -o demo_comm
./demo_comm
```

Expected output:

```text
shared_symbol = 1234
```

### Case 2: Strong C definition + strong assembly definition (expected: **fails**)

```bash
gcc -c duplicate_strong.s -o duplicate_strong.o
gcc defined.o duplicate_strong.o -o demo_duplicate
```

Expected linker error (or equivalent):

```text
multiple definition of `shared_symbol`
```

## Why this happens

- `.comm name,size,align` emits a **common symbol**. If a strong definition of `name` exists elsewhere, the strong definition wins and the link succeeds.
- Two strong definitions of the same global symbol violate the one-definition rule at link time, producing a multiple-definition error.
