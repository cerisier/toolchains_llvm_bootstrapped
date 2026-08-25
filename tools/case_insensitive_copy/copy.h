#ifndef HERMETIC_LLVM_TOOLS_CASE_INSENSITIVE_COPY_COPY_H_
#define HERMETIC_LLVM_TOOLS_CASE_INSENSITIVE_COPY_COPY_H_

#ifdef __cplusplus
extern "C" {
#endif

int case_insensitive_copy_directory(const char *source, const char *destination,
                                    char **error);

#ifdef __cplusplus
}
#endif

#endif // HERMETIC_LLVM_TOOLS_CASE_INSENSITIVE_COPY_COPY_H_
