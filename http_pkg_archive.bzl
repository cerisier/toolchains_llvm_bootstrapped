load(
    "@bazel_tools//tools/build_defs/repo:utils.bzl",
    "get_auth",
    "patch",
    "workspace_and_buildfile",
)
load("@bazel_lib//lib:repo_utils.bzl", "repo_utils")

def _http_pkg_archive_impl(rctx):
    if rctx.attr.build_file and rctx.attr.build_file_content:
        fail("Only one of build_file and build_file_content can be provided.")
    rctx.download(
        url = rctx.attr.urls,
        output = ".downloaded.pkg",
        sha256 = rctx.attr.sha256,
        canonical_id = " ".join(rctx.attr.urls),
        auth = get_auth(rctx, rctx.attr.urls),
    )

    args = []
    if rctx.attr.strip_files:
        for file in rctx.attr.strip_files:
            args.extend(["--exclude", file])
    if rctx.attr.strip_prefix:
        args.extend(["--strip-components", str(len(rctx.attr.strip_prefix.split("/")))])
    args.extend(["--expand-full", ".downloaded.pkg", "."])

    # host_pkgutil = Label("@toolchain-extra-prebuilts-%s//:bin/pkgutil" % (repo_utils.platform(rctx).replace("_", "-")))
    host_pkgutil = Label("@xpkgutilprebuilt//:pkgutil_darwin_arm64")
    res = rctx.execute([str(rctx.path(host_pkgutil))] + args)
    if res.return_code != 0:
        fail("Failed to extract package: {}".format(res.stderr))

    rctx.delete(".downloaded.pkg")
    workspace_and_buildfile(rctx)
    patch(rctx)

http_pkg_archive = repository_rule(
    _http_pkg_archive_impl,
    attrs = {
        "urls": attr.string_list(mandatory = True),
        "sha256": attr.string(mandatory = True),
        "strip_prefix": attr.string(),
        "strip_files": attr.string_list(),
        "build_file": attr.label(allow_single_file = True),
        "build_file_content": attr.string(),
        "workspace_file": attr.label(allow_single_file = True),
        "workspace_file_content": attr.string(),
    },
)
