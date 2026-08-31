#include <stdio.h>

int main(int argc, char **argv) {
  FILE *output;
  int section;

  if (argc != 2) {
    fprintf(stderr, "usage: bigobj_fixture_writer <output.s>\n");
    return 1;
  }
  output = fopen(argv[1], "wb");
  if (output == NULL) {
    fprintf(stderr, "could not open %s\n", argv[1]);
    return 1;
  }
  fprintf(output, ".section .text$big,\"xr\"\n"
                  ".globl bigobj_function\n"
                  "bigobj_function:\n"
                  "  ret\n");
  /* Standard COFF has only 16-bit section indexes. Crossing LLVM's 65,279
     section limit makes clang emit the real BIGOBJ header and symbol format. */
  for (section = 0; section < 65300; ++section) {
    fprintf(output, ".section .sec%05d,\"dr\"\n.byte 0\n", section);
  }
  if (fclose(output) != 0) {
    fprintf(stderr, "could not write %s\n", argv[1]);
    return 1;
  }
  return 0;
}
