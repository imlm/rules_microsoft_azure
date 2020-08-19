load("@bazel_skylib//lib:dicts.bzl", "dicts")
load("@bazel_skylib//lib:paths.bzl", "paths")
load("//az:providers/providers.bzl", "AzConfigInfo")
load("//az/private/common:common.bzl", "AZ_TOOLCHAIN", "common")

def _impl(ctx):
    extension = ctx.attr.generator_function
    files = []
    files += ctx.files.srcs

    if hasattr(ctx.attr, "_action"):
        az_action = ctx.attr._action
        az_account_name = ctx.attr.account_name.strip()
        az_container_name = ctx.attr.container_name.strip()

        basecmd = "$CLI_PATH {ext} {az_action} {global_args}".format(
            ext = extension,
            az_action = az_action,
            global_args = ctx.attr.config[AzConfigInfo].global_args,
        )

        template_cmd = []

        for fp in files:
            bazel_path = fp.short_path
            bazel_dirname = paths.dirname(bazel_path)
            args_cmd = []

            if az_action == "remove":
                args_cmd = [
                    "--account-name \"%s\"" % az_account_name,
                    "--container-name \"%s\"" % az_container_name,
                    "--name \"%s\"" % bazel_path,
                ]
            else:
                args_cmd = [
                    "--destination-account-name \"%s\"" % az_account_name,
                    "--destination-container \"%s\"" % (paths.join(az_container_name, bazel_dirname)),
                    "--source \"%s\"" % bazel_path,
                ]
            template_cmd.append(" ".join([basecmd] + args_cmd))

        template_substitutions = {
            "%{CLI_PATH}": ctx.var["AZ_PATH"],
            "%{CMD}": ";\n".join(template_cmd),
        }

    else:
        template_substitutions = {
            "%{CLI_PATH}": "ls -ahls",
            "%{CMD}": ";\n".join(["$CLI_PATH \"%s\"" % fp.short_path for fp in files]),
        }

    ctx.actions.expand_template(
        is_executable = True,
        output = ctx.outputs.executable,
        template = ctx.file._resolved,
        substitutions = template_substitutions,
    )

    return [
        DefaultInfo(
            runfiles = ctx.runfiles(
                transitive_files = depset(files),
            ),
            files = depset([ctx.outputs.executable]),
        ),
    ]

_common_attr = {
    "_resolved": attr.label(
        default = common.resolve_tpl,
        allow_single_file = True,
    ),
    "config": attr.label(
        mandatory = True,
        providers = [AzConfigInfo],
    ),
    "account_name": attr.string(
        mandatory = True,
    ),
    "container_name": attr.string(
        mandatory = True,
    ),
    "srcs": attr.label_list(
        mandatory = True,
        allow_files = True,
    ),
}

_storage = rule(
    attrs = _common_attr,
    executable = True,
    toolchains = [AZ_TOOLCHAIN],
    implementation = _impl,
)

_storage_copy = rule(
    attrs = dicts.add(
        _common_attr,
        {
            "_action": attr.string(default = "copy"),
        },
    ),
    executable = True,
    toolchains = [AZ_TOOLCHAIN],
    implementation = _impl,
)

_storage_remove = rule(
    attrs = dicts.add(
        _common_attr,
        {
            "_action": attr.string(default = "remove"),
        },
    ),
    executable = True,
    toolchains = [AZ_TOOLCHAIN],
    implementation = _impl,
)

def storage(name, **kwargs):
    _storage(name = name, **kwargs)
    _storage_copy(name = name + ".copy", **kwargs)
    _storage_remove(name = name + ".remove", **kwargs)