/* Distributed under the OSI-approved BSD 3-Clause License.  See accompanying
   file Copyright.txt or https://cmake.org/licensing for details.  */

#ifndef HERMETIC_LLVM_TOOLS_COFF_DEF_PARSER_DEF_PARSER_H_
#define HERMETIC_LLVM_TOOLS_COFF_DEF_PARSER_DEF_PARSER_H_

#include <stdio.h>

#ifdef __cplusplus
extern "C" {
#endif

struct coff_def_parser;

struct coff_def_parser *coff_def_parser_create(void);
void coff_def_parser_destroy(struct coff_def_parser *parser);
void coff_def_parser_set_dll_name(struct coff_def_parser *parser,
                                  const char *name);
int coff_def_parser_add_object_file(struct coff_def_parser *parser,
                                    const char *filename);
int coff_def_parser_add_definition_file(struct coff_def_parser *parser,
                                        const char *filename);
int coff_def_parser_add_file(struct coff_def_parser *parser,
                             const char *filename);
void coff_def_parser_write_file(const struct coff_def_parser *parser,
                                FILE *file);
FILE *coff_def_parser_open_file(const char *filename, const char *mode);

#ifdef __cplusplus
}
#endif

#endif // HERMETIC_LLVM_TOOLS_COFF_DEF_PARSER_DEF_PARSER_H_
