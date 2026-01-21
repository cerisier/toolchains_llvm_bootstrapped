FROM --platform=linux/arm64 ubuntu
RUN apt-get update && apt-get install -y ca-certificates curl git python3 #binutils zstd file
RUN curl -L https://github.com/bazelbuild/bazelisk/releases/download/v1.18.0/bazelisk-linux-arm64 -o /usr/bin/bazel && chmod +x /usr/bin/bazel
RUN adduser fakeuser
USER fakeuser

WORKDIR /repo/examples/rules_cc
RUN echo "9.0.0" > .bazelversion
#COPY .bazelversion .
RUN touch WORKSPACE && bazel help
RUN echo "bazel test //:all" > ~/.bash_history

