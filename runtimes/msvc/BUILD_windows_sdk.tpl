package(default_visibility = ["//visibility:public"])

filegroup(
    name = "libs",
    srcs = glob([
        "c/ucrt/*/*.lib",
        "c/um/*/*.lib",
    ]),
)
