import os, strutils, parseopt
from strformat import `&`

type
  Options = object
    specFile, package, packageRoot, maintainer, version, arch, desc, license, vendor: string

proc getCmdOpts(params: seq[string]): Options =
  var optParser = initOptParser(params)
  result.license = "MIT"

  for kind, key, val in optParser.getopt():
    case kind
    of cmdLongOption, cmdShortOption:
      case key
      of "specfile":
        result.specFile = val
      of "package":
        result.package = val
      of "package-root":
        result.packageRoot = val
      of "maintainer":
        result.maintainer = val
      of "vendor":
        result.vendor = val
      of "version":
        result.version = val
      of "arch":
        result.arch = val
      of "description":
        result.desc = val
      of "license":
        result.license = val
    of cmdEnd:
      assert false # cannot happen
    else:
      assert false

proc generateInstallScript(path: string): seq[string] =
  let (head, _) = path.splitPath
  result.add("mkdir -p %{buildroot}" & head)
  result.add("cp -p " & path[1..^1] & " %{buildroot}" & head & "/")

proc replaceTemplate(body, package, maintainer, version, arch, desc, install, files, license, vendor: string): string =
  result =
    body
      .replace("{{PACKAGE}}", package)
      .replace("{{MAINTAINER}}", maintainer)
      .replace("{{VENDOR}}", vendor)
      .replace("{{VERSION}}", version)
      .replace("ARCH", arch)
      .replace("{{DESC}}", desc)
      .replace("{{INSTALL}}", install)
      .replace("{{FILES}}", files)
      .replace("{{LICENSE}}", license)

proc formatDescription(desc: string): string =
  "Description: " & desc

proc fixFile(file, package, maintainer, version, arch, desc, install, files, license, vendor: string) =
  let
    body = readFile(file)
    fixedBody = replaceTemplate(body, package=package, maintainer=maintainer,
                                version=version, arch=arch, desc=desc,
                               install=install, files=files, license=license,
                               vendor=vendor)
  writeFile(file, fixedBody)

proc getInstallFiles(packageRoot: string): (seq[string], seq[string]) =
  var
    installScript: seq[string]
    files: seq[string]
  for relPath in walkDirRec(packageRoot):
    let path = relPath[packageRoot.len..^1]
    installScript.add(path.generateInstallScript)
    files.add(path)
  return (installScript, files)

when isMainModule and not defined modeTest:
  let
    args = commandLineParams()
    params = getCmdOpts(args)

    package = params.package
    packageRoot = params.packageRoot.normalizedPath
    maintainer = params.maintainer
    vendor =
      if params.vendor == "": maintainer
      else: params.vendor
    version = params.version.strip(trailing = false, chars = {'v'})
    arch = params.arch
    desc = params.desc.formatDescription
    license = params.license

  let (installScript, files) = getInstallFiles(packageRoot)
  fixFile(params.specfile,
          package=package,
          maintainer=maintainer,
          version=version,
          arch=arch,
          desc=desc,
          install=installScript.join("\n"),
          files=files.join("\n"),
          license=license,
          vendor=vendor,
         )
