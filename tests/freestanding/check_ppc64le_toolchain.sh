#!/usr/bin/env bash

set -euo pipefail

readonly object_target=//tests/freestanding:ppc64le_object
readonly executable_targets=(
  //tests/freestanding:ppc64le_stage1_executable
  //tests/freestanding:ppc64le_stage1_hosted_executable
)
readonly platform=//tests/freestanding:linux_ppc64le
readonly bootstrap_stage=stage1_from_source
readonly hosted_target_dependency_pattern='(^|//)(runtimes/(compiler-rt|cxxstdlib|glibc|musl)|runtimes:(crt_objects_directory|dynamic_runtime_lib|resource_directory|static_runtime_lib)|sanitizers:|toolchain:(default_libs|default_startfiles|resource_dir|rtlib))|@(glibc|kernel_headers|llvm-project|musl)//'

command_args=(--noannounce_rc)
if [[ -n "${BAZEL_REMOTE_HEADER:-}" ]]; then
  command_args+=("--remote_header=${BAZEL_REMOTE_HEADER}")
fi

bazel "$@" build "${command_args[@]}" \
  --platforms="${platform}" \
  --@llvm//toolchain:bootstrap_stage="${bootstrap_stage}" \
  --remote_download_outputs=toplevel \
  "${object_target}" \
  "${executable_targets[@]}"

target_line=$(
  bazel "$@" cquery "${object_target}" \
    "${command_args[@]}" \
    --platforms="${platform}" \
    --@llvm//toolchain:bootstrap_stage="${bootstrap_stage}" \
    --output=label
)
target_config=${target_line##* (}
target_config=${target_config%)}

bad_target_runtime_deps=$(
  bazel "$@" cquery "deps(${object_target})" \
    "${command_args[@]}" \
    --platforms="${platform}" \
    --@llvm//toolchain:bootstrap_stage="${bootstrap_stage}" \
    --output=label |
    awk -v config="(${target_config})" '$NF == config' |
    grep -E "${hosted_target_dependency_pattern}" || true
)

if [[ -n "${bad_target_runtime_deps}" ]]; then
  echo "linux+ppc64le selected hosted target runtimes:" >&2
  echo "${bad_target_runtime_deps}" >&2
  exit 1
fi

compile_actions=$(bazel "$@" aquery "mnemonic(CppCompile, ${object_target})" \
  "${command_args[@]}" \
  --platforms="${platform}" \
  --@llvm//toolchain:bootstrap_stage="${bootstrap_stage}")
if ! grep -q -- 'powerpc64le-linux-gnu' <<<"${compile_actions}"; then
  echo "linux+ppc64le did not select the powerpc64le-linux-gnu compiler triple" >&2
  exit 1
fi

archive=$(bazel "$@" cquery "${object_target}" \
  "${command_args[@]}" \
  --platforms="${platform}" \
  --@llvm//toolchain:bootstrap_stage="${bootstrap_stage}" \
  --output=files | grep -E '\.a$' | head -n 1)
elf_header=$(readelf -h "${archive}")

grep -q 'Class:.*ELF64' <<<"${elf_header}"
grep -q "Data:.*little endian" <<<"${elf_header}"
grep -q 'Type:.*REL' <<<"${elf_header}"
grep -q 'Machine:.*PowerPC64' <<<"${elf_header}"

for target in "${executable_targets[@]}"; do
  target_name=${target##*:}
  action_commands=$(
    bazel "$@" aquery \
      "outputs('.*${target_name}_/${target_name}(/.*)?', mnemonic('CppCompile|CppLink', deps(${target})))" \
      "${command_args[@]}" \
      --color=no \
      --include_commandline \
      --noinclude_artifacts \
      --platforms="${platform}" \
      --@llvm//toolchain:bootstrap_stage="${bootstrap_stage}" \
      --output=text
  )
  if [[ -z "${action_commands}" ]]; then
    echo "Could not locate compile and link actions for ${target}" >&2
    exit 1
  fi

  for required in \
    powerpc64le-linux-gnu \
    -fuse-ld=lld \
    -nostdlib \
    -static \
    --entry=_start \
    --no-pie; do
    if ! grep -Fq -- "${required}" <<<"${action_commands}"; then
      echo "${target} is missing required freestanding link argument ${required}" >&2
      exit 1
    fi
  done

  dependency_lines=$(
    bazel "$@" cquery "deps(${target})" \
      "${command_args[@]}" \
      --platforms="${platform}" \
      --@llvm//toolchain:bootstrap_stage="${bootstrap_stage}" \
      --output=label
  )
  internal_target_line=$(
    grep -F "//tests/freestanding:${target_name}_/${target_name} " <<<"${dependency_lines}" |
      head -n 1 || true
  )
  if [[ -z "${internal_target_line}" ]]; then
    echo "Could not locate transitioned target configuration for ${target}" >&2
    exit 1
  fi
  internal_target_config=${internal_target_line##* (}
  internal_target_config=${internal_target_config%)}
  bad_target_runtime_deps=$(
    awk -v config="(${internal_target_config})" '$NF == config' <<<"${dependency_lines}" |
      grep -E "${hosted_target_dependency_pattern}" || true
  )
  if [[ -n "${bad_target_runtime_deps}" ]]; then
    echo "${target} selected hosted target dependencies:" >&2
    echo "${bad_target_runtime_deps}" >&2
    exit 1
  fi

  for forbidden in \
    ' -B' \
    -resource-dir \
    -rtlib=compiler-rt \
    libclang_rt \
    crtbegin \
    crtend \
    kernel_headers \
    sanitizers_headers \
    runtimes/cxxstdlib \
    runtimes/glibc \
    runtimes/musl \
    -lpthread \
    -ldl \
    -lstdc++ \
    -lc++ \
    -lc; do
    if grep -Fq -- "${forbidden}" <<<"${action_commands}"; then
      echo "${target} unexpectedly uses hosted argument or input ${forbidden}" >&2
      exit 1
    fi
  done

  binary=$(
    bazel "$@" cquery "${target}" \
      "${command_args[@]}" \
      --platforms="${platform}" \
      --@llvm//toolchain:bootstrap_stage="${bootstrap_stage}" \
      --output=files |
      awk -v target_name="${target_name}" '$0 ~ ("/" target_name "$") { print; exit }'
  )
  if [[ -z "${binary}" ]]; then
    echo "Could not locate linked output for ${target}" >&2
    exit 1
  fi

  elf_header=$(readelf -h "${binary}")
  grep -q 'Class:.*ELF64' <<<"${elf_header}"
  grep -q "Data:.*little endian" <<<"${elf_header}"
  grep -q 'Type:.*EXEC' <<<"${elf_header}"
  grep -q 'Machine:.*PowerPC64' <<<"${elf_header}"
  if readelf -l "${binary}" | grep -q 'INTERP'; then
    echo "${target} unexpectedly requests a hosted program interpreter" >&2
    exit 1
  fi
  if readelf -d "${binary}" 2>/dev/null | grep -q 'NEEDED'; then
    echo "${target} unexpectedly depends on a shared library" >&2
    exit 1
  fi
  readelf -p .comment "${binary}" | grep -q 'Linker: LLD'
  readelf -Ws "${binary}" | grep -q '[[:space:]]_start$'
done
