#!/usr/bin/env bash

set -o errexit -o nounset -o pipefail -x

# Argument provided by reusable workflow caller, see
# https://github.com/bazel-contrib/.github/blob/d197a6427c5435ac22e56e33340dff912bc9334e/.github/workflows/release_ruleset.yaml#L72
TAG=$1
# The prefix is chosen to match what GitHub generates for source archives
PREFIX="toolchains_llvm_bootstrapped-$TAG"
ARCHIVE="toolchains_llvm_bootstrapped-$TAG.tar.gz"
ARCHIVE_TMP=$(mktemp)

# Dummy on purpose
git config user.email "you@example.com"
git config user.name "Your Name"
sed -i.bak "s/0.0.0/${TAG}/" MODULE.bazel && git add MODULE.bazel && git commit -m "Update version" >/dev/null

# NB: configuration for 'git archive' is in /.gitattributes
git archive --format=tar --prefix=${PREFIX}/ HEAD >$ARCHIVE_TMP

gzip <$ARCHIVE_TMP >$ARCHIVE
SHA=$(shasum -a 256 $ARCHIVE | awk '{print $1}')

cat << EOF
## What's Changed

TODO

## Using Bzlmod

1. Enable with \`common --enable_bzlmod\` in \`.bazelrc\` if using Bazel>=7.4.0.
2. Add to your \`MODULE.bazel\` file:

\`\`\`starlark
bazel_dep(name = "toolchains_llvm_bootstrapped", version = "$TAG")

register_toolchains(
    "@toolchains_llvm_bootstrapped//toolchain/...",
)
\`\`\`
EOF
