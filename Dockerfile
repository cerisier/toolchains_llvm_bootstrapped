FROM ubuntu AS build
LABEL description="LLVM Bootstrapped Toolchains Builder"
LABEL version="1.0"
RUN apt update && apt install -y ca-certificates git && apt clean
ADD https://github.com/bazelbuild/bazelisk/releases/download/v1.26.0/bazelisk-linux-amd64 /usr/bin/bazelisk
RUN chmod +x /usr/bin/bazelisk
#RUN bazelisk
ADD . /opt/src

FROM build AS test
WORKDIR /opt/src/examples/rules_cc
RUN bazelisk build :main
RUN ./bazel-bin/main
ENTRYPOINT ["./bazel-bin/main"]

FROM build
WORKDIR /opt/src
ENTRYPOINT ["bazelisk"]
