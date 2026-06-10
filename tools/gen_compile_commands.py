#!/usr/bin/env python3
"""Generate a clangd compile database from wly BUILD files.

The repository uses alimake, but Neovim/clangd only needs compile flags for
indexing. This script evaluates BUILD files with small rule stubs, expands
source globs, and writes compile_commands.json without invoking alimake.
"""

import argparse
import fnmatch
import glob
import json
import os
import shlex
import sys
from pathlib import Path


CPP_SUFFIXES = {".cc", ".cpp", ".cxx", ".c++", ".C"}
C_SUFFIXES = {".c"}
SOURCE_SUFFIXES = CPP_SUFFIXES | C_SUFFIXES
DEFAULT_BUILD_ROOTS = (
    "ads_index",
    "base",
    "common",
    "dmp",
    "huichuan",
    "model",
    "net",
    "serving_base",
    "vertical",
    "wolong",
    "zilong",
)


class BuildCollector:
  def __init__(self, root):
    self.root = root
    self.rules = []
    self.warnings = []

  def add_rule(self, kind, build_file, kwargs):
    self.rules.append({
        "kind": kind,
        "build_file": build_file,
        "build_dir": build_file.parent,
        "kwargs": kwargs,
    })

  def load(self, build_file):
    def record(kind):
      def fn(**kwargs):
        self.add_rule(kind, build_file, kwargs)
      return fn

    env = {
        "__builtins__": {
            "False": False,
            "None": None,
            "True": True,
            "len": len,
            "list": list,
            "str": str,
        },
        "cc_binary": record("cc_binary"),
        "cc_data": record("cc_data"),
        "cc_fast_test": record("cc_fast_test"),
        "cc_jni_library": record("cc_jni_library"),
        "cc_library": record("cc_library"),
        "cc_pyext": record("cc_pyext"),
        "cc_proto_library": record("cc_proto_library"),
        "cc_shared_library": record("cc_shared_library"),
        "cc_so": record("cc_so"),
        "cc_test": record("cc_test"),
        "exports_files": lambda *args, **kwargs: None,
        "filegroup": record("filegroup"),
        "glob": lambda patterns, exclude=None: self.expand_patterns(
            build_file.parent, patterns, exclude or []),
        "package": lambda *args, **kwargs: None,
        "proto_library": record("proto_library"),
        "set_module_attr": lambda *args, **kwargs: None,
        "shell_script": lambda *args, **kwargs: None,
    }
    try:
      code = build_file.read_text(encoding="utf-8")
    except UnicodeDecodeError:
      code = build_file.read_text(encoding="gb18030")
    try:
      exec(compile(code, str(build_file), "exec"), env, {})
    except Exception as exc:
      self.warnings.append("%s: %s" % (build_file, exc))

  @staticmethod
  def expand_patterns(base_dir, patterns, excludes):
    files = []
    for pattern in as_list(patterns):
      matches = glob.glob(str(base_dir / pattern), recursive=True)
      if matches:
        files.extend(matches)
      else:
        files.append(str(base_dir / pattern))
    excluded = set()
    for pattern in as_list(excludes):
      excluded.update(glob.glob(str(base_dir / pattern), recursive=True))
    return [
        relpath(Path(path))
        for path in files
        if path not in excluded and Path(path).is_file()
    ]


def as_list(value):
  if value is None:
    return []
  if isinstance(value, (list, tuple, set)):
    return list(value)
  return [value]


def relpath(path):
  return os.path.relpath(str(path), os.getcwd())


def read_alimake_flags(path):
  includes = []
  cxxflags = []
  ccflags = []
  if not path.exists():
    return includes, cxxflags, ccflags
  for raw_line in path.read_text(encoding="utf-8").splitlines():
    line = raw_line.strip()
    if not line or line.startswith("#"):
      continue
    if line.startswith("--project-includes="):
      includes.append(line.split("=", 1)[1])
    elif line.startswith("--project-cxxflags="):
      cxxflags.append(line.split("=", 1)[1])
    elif line.startswith("--project-ccflags="):
      ccflags.append(line.split("=", 1)[1])
  return includes, cxxflags, ccflags


def discover_build_files(root, selected):
  build_files = []
  for item in selected:
    path = Path(item)
    if path.is_file() and path.name == "BUILD":
      build_files.append(path)
    elif path.is_dir():
      build_files.extend(path.rglob("BUILD"))
    else:
      candidate = root / item
      if candidate.is_file() and candidate.name == "BUILD":
        build_files.append(candidate)
      elif candidate.is_dir():
        build_files.extend(candidate.rglob("BUILD"))
  rel_build_files = []
  for path in build_files:
    try:
      rel_build_files.append(path.relative_to(root))
    except ValueError:
      rel_build_files.append(Path(relpath(path)))
  return sorted(set(rel_build_files))


def should_exclude(path, build_dir, excludes):
  rel_to_build = relpath(path)
  try:
    local = str(path.relative_to(build_dir))
  except ValueError:
    local = rel_to_build
  return any(fnmatch.fnmatch(local, pattern) or fnmatch.fnmatch(rel_to_build, pattern)
             for pattern in as_list(excludes) if pattern)


def expand_srcs(build_dir, srcs, excludes):
  files = []
  for src in as_list(srcs):
    src = str(src)
    matches = glob.glob(str(build_dir / src), recursive=True)
    if matches:
      files.extend(Path(match) for match in matches)
    else:
      files.append(build_dir / src)
  result = []
  seen = set()
  for path in files:
    if not path.is_file() or path.suffix not in SOURCE_SUFFIXES:
      continue
    if should_exclude(path, build_dir, excludes):
      continue
    key = relpath(path)
    if key not in seen:
      seen.add(key)
      result.append(path)
  return result


def deps_to_includes(deps):
  includes = []
  for dep in as_list(deps):
    dep = str(dep)
    if dep.startswith("//") and "/BUILD:" in dep:
      includes.append(dep[2:].split("/BUILD:", 1)[0])
    elif dep.startswith(":"):
      continue
    elif ":" in dep:
      pkg = dep.split(":", 1)[0]
      includes.append("third_party/%s/include" % pkg)
      includes.append(".dep_create/built/gcc-9.2.1/%s/include" % pkg)
  return includes


def normalize_flag(flag):
  flag = str(flag)
  if flag.startswith("-Werror="):
    return "-Wno-error=" + flag.split("=", 1)[1]
  return flag


def command_for(source, rule, global_includes, global_cxxflags, global_ccflags, compiler):
  kwargs = rule["kwargs"]
  build_dir = rule["build_dir"]
  flags = []
  flags.extend("-I" + inc for inc in global_includes)
  flags.append("-I" + relpath(build_dir))
  flags.append("-I" + relpath(build_dir / "include"))
  flags.extend("-I" + inc for inc in deps_to_includes(kwargs.get("deps")))
  flags.extend(global_ccflags)
  if source.suffix in CPP_SUFFIXES:
    flags.append("-std=gnu++17")
    flags.extend(global_cxxflags)
  flags.extend(as_list(kwargs.get("ccflags")))
  flags.extend(as_list(kwargs.get("cflags")))
  flags.extend(as_list(kwargs.get("cppflags")))
  flags.extend(as_list(kwargs.get("cxxflags")))
  flags.extend(as_list(kwargs.get("ext_cppflags")))
  flags.extend([
      "-DGOOGLE_PROTOBUF_NO_RTTI",
      "-Wno-error",
      "-fsyntax-only",
  ])
  args = [compiler, "-c"] + [normalize_flag(flag) for flag in flags] + [relpath(source)]
  return " ".join(shlex.quote(arg) for arg in args)


def main():
  parser = argparse.ArgumentParser()
  parser.add_argument("paths", nargs="*", help="BUILD files or directories to index")
  parser.add_argument("-o", "--output", default="compile_commands.json")
  parser.add_argument("--compiler", default="g++")
  parser.add_argument("--warnings", action="store_true")
  args = parser.parse_args()

  root = Path.cwd()
  selected = args.paths or [path for path in DEFAULT_BUILD_ROOTS if (root / path).exists()]
  build_files = discover_build_files(root, selected)
  collector = BuildCollector(root)
  for build_file in build_files:
    collector.load(root / build_file)

  global_includes, global_cxxflags, global_ccflags = read_alimake_flags(root / ".alimakerc")
  commands = {}
  for rule in collector.rules:
    if rule["kind"] not in {
        "cc_binary",
        "cc_fast_test",
        "cc_jni_library",
        "cc_library",
        "cc_pyext",
        "cc_shared_library",
        "cc_so",
        "cc_test",
    }:
      continue
    for source in expand_srcs(rule["build_dir"], rule["kwargs"].get("srcs"), rule["kwargs"].get("excludes")):
      full_source = str((root / relpath(source)).absolute())
      commands[full_source] = {
          "directory": str(root),
          "file": full_source,
          "command": command_for(source, rule, global_includes, global_cxxflags,
                                 global_ccflags, args.compiler),
      }

  output = root / args.output
  output.write_text(json.dumps(list(commands.values()), indent=2, sort_keys=True) + "\n",
                    encoding="utf-8")

  print("wrote %s entries to %s" % (len(commands), output))
  if collector.warnings and args.warnings:
    print("BUILD warnings:", file=sys.stderr)
    for warning in collector.warnings:
      print("  " + warning, file=sys.stderr)


if __name__ == "__main__":
  main()
