#encoding: utf-8
#!/usr/bin/ruby

# This script looks up an executable's list of shared libraries, copies
# non-standard ones (ie. anything not under /usr or /System/) into the target's
# bundle and updates the executable install_name to point to the "packaged"
# version.

# Usage:
# Add the script as a Run Script build phase in the target using Xcode.

# FIXMEs:
# - only handles dylibs
# - only tested against a framework target
# - doesn't care about codesigning


require 'fileutils'
require 'ostruct'

Encoding.default_external = 'UTF-8'

def err(msg)
  puts "\terror: " + msg
  exit 1
end

def warn(msg)
  puts "\twarning: " + msg
end

def note(msg)
  puts "\t" + msg
end

def section(msg)
  puts "================================= #{msg} ================================="
end

envvars = %w(
  TARGET_BUILD_DIR
  EXECUTABLE_PATH
  LIBRARY_SEARCH_PATHS
  FRAMEWORK_SEARCH_PATHS
  FRAMEWORKS_FOLDER_PATH
  SRCROOT
  FULL_PRODUCT_NAME
)

envvars.each do |var|
  Kernel.const_set(var, ENV[var])
end

require 'shellwords'
TARGET_EXECUTABLE_PATH = File.join(TARGET_BUILD_DIR, EXECUTABLE_PATH)
TARGET_FRAMEWORKS_PATH = FRAMEWORKS_FOLDER_PATH ? File.join(TARGET_BUILD_DIR, FRAMEWORKS_FOLDER_PATH) : TARGET_BUILD_DIR
FRAMEWORK_SEARCH_PATH_ARRAY = Shellwords::shellwords(FRAMEWORK_SEARCH_PATHS)
LIBRARY_SEARCH_PATH_ARRAY = Shellwords::shellwords(LIBRARY_SEARCH_PATHS)
NAME = File.basename(TARGET_EXECUTABLE_PATH, '.*')

section "Copy Libraries"
def search_library(name)
  name = name.sub("@rpath/", '')
  is_framework = name =~ /\.framework\//
  paths = is_framework ? FRAMEWORK_SEARCH_PATH_ARRAY : LIBRARY_SEARCH_PATH_ARRAY
  paths.each do |path|
    path = File.join(SRCROOT, path) if File.absolute_path(path) != path
    path = File.join(path, name)
    return path if File.exists?(path)
  end
  return nil
end

ALL_DEPS = []
def extract_link_dependencies(executable)
  unless File.exist?(executable)
    warn "executable not exists: #{executable}"
    return []
  end
  deps = `otool -L #{executable}`

  lines = deps.split("\n").map(&:strip)
  lines.shift
  # lines.shift
  lines.map do |dep|
    path, compat, current = /^(.*) \(compatibility version (.*), current version (.*)\)$/.match(dep)[1..3]
    err "Failed to parse #{dep}" if path.nil?

    name = File.basename(path)
    next if ALL_DEPS.include?(name)
    ALL_DEPS << name

    dep = OpenStruct.new
    dep.is_self = (File.basename(path) == File.basename(executable))
    dep.executable = executable
    dep.install_name = path
    dep.current_version = current
    dep.compat_version = compat
    dep.type = path =~ /\.framework\// ? ".framework" : File.extname(path)
    dep.name = name
    dep.is_packaged = false
    dep.path = if path =~ /^@rpath/
      search_library(path)
    else
      dep.install_name
    end
    if dep.path.nil?
      nil
    else
      dep.library_path = dep.path.sub(/\.framework\/.*/, ".framework")
      dep
    end
  end.compact
end

def repackage_dependency(dep)
  return if dep.is_self or dep.path =~ /^(\/usr\/lib|\/System\/Library)/

  note "Packaging #{dep.name}…"

  FileUtils.mkdir(TARGET_FRAMEWORKS_PATH) unless Dir.exist?(TARGET_FRAMEWORKS_PATH)
  packaged_path = File.join(TARGET_FRAMEWORKS_PATH, File.basename(dep[:library_path]))
  note "path: #{packaged_path}"
  case dep.type
  when ".dylib", ".framework"
    if File.exist? packaged_path
      note "#{packaged_path} already in Frameworks directory, removing"
      FileUtils.rm_rf packaged_path
    end

    note "Copying #{dep[:library_path]} to #{TARGET_FRAMEWORKS_PATH}"
    FileUtils.cp_r dep[:library_path], TARGET_FRAMEWORKS_PATH
#    FileUtils.chmod "u=rw", packaged_path

    unless dep.is_packaged
#      note "install_name_tool -change #{dep.install_name} #{dep.install_name.sub('Versions/A/', "")} #{dep.executable}"
#      out = `install_name_tool -change #{dep.install_name} "#{dep.install_name.sub('Versions/A/', "")}" #{dep.executable}`
#      if $? != 0
#        err "install_name_tool failed with error #{$?}:\n#{out}"
#      end

      dep.path = packaged_path
      dep.install_name = "@rpath/#{dep.name}"
      dep.is_packaged = true      
    end
  else
    warn "Unhandled type #{dep.type} for #{dep.path}, ignoring"
  end
end

def fix_install_id(dep)
  note "Fixing #{dep.name} install_name id…"
  out = `install_name_tool -id @rpath/#{dep.name.sub('Versions/A/', "")} #{dep.executable}`
  if $? != 0
    err "install_name_tool failed with error #{$?}:\n#{out}"
  end
end

#link_deps = []
#deps = extract_link_dependencies(TARGET_EXECUTABLE_PATH)
#while (dep = deps.shift) do
#  if dep.name.start_with?("MBox")
#    dep_name = File.basename(dep.library_path, '.*')
#    link_deps << dep_name if dep_name != File.basename(TARGET_EXECUTABLE_PATH, '.*')
#  else
#    repackage_dependency dep
#  end
##  fix_install_id dep
##  deps += extract_link_dependencies(dep[:path]) if dep.is_packaged and not dep.is_self and dep.path
#end

GIT_ROOT = `git -C "#{SRCROOT}" rev-parse --show-toplevel`.strip

section "Copy manifest.yml"
manifest_path = File.join(GIT_ROOT, "manifest.yml")
target_manifest_path = File.join(TARGET_BUILD_DIR, "manifest.yml")
if File.exists?(manifest_path) && !File.exists?(target_manifest_path)
  note "copy '#{manifest_path}' -> '#{target_manifest_path}'"
  FileUtils.cp_r manifest_path, target_manifest_path
end

section "Copy setting.schema.json"
schema_path = File.join(GIT_ROOT, "setting.schema.json")
target_schema_path = File.join(TARGET_BUILD_DIR, "setting.schema.json")
if File.exists?(schema_path) && !File.exists?(target_schema_path)
  note "copy '#{schema_path}' -> '#{target_schema_path}'"
  FileUtils.cp_r schema_path, target_schema_path
end

section "Generate Podspec"
def framework_paths(name)
  return [] unless name.end_with?(".framework")
  path = File.join(name, "Versions/A/Frameworks")
  return [] unless File.exists?(path)
  files = Dir[path + "/*"]
  return [] if files.empty?
  return [path] + files.flat_map { |file| framework_paths(file) }
end

podspec_path = File.join(SRCROOT, NAME + ".podspec")
note podspec_path
if File.exist?(podspec_path)
  require 'cocoapods-core'
  spec = Pod::Specification.from_file(podspec_path)
  subspec = begin
    spec.subspec_by_name("#{NAME}/Core")
  rescue
    spec
  end
  Dir.chdir(TARGET_BUILD_DIR) do
    frameworks = framework_paths(FULL_PRODUCT_NAME)
    modulemaps = frameworks.flat_map { |path|
      Dir["#{path}/*/"].select { |name|
        !name.end_with?(".framework/")
      }
    }.map { |file|
      "\"${PODS_ROOT}/#{spec.name}/#{file[0...-1]}\""
    }
    search_paths = frameworks.map { |file|
      "\"${PODS_ROOT}/#{spec.name}/#{file}\""
    }

    xcconfig = subspec.attributes_hash["user_target_xcconfig"] || {}
    xcconfig["FRAMEWORK_SEARCH_PATHS"] = search_paths.join(" ") unless search_paths.empty?
    xcconfig["SWIFT_INCLUDE_PATHS"] = modulemaps.join(" ") unless modulemaps.empty?
    subspec.user_target_xcconfig = xcconfig unless xcconfig.empty?

    subspec.source_files = []
    subspec.vendored_frameworks = FULL_PRODUCT_NAME

    out_podspec_path = File.join(TARGET_BUILD_DIR, "#{NAME}.podspec.json")
    File.write(out_podspec_path, spec.to_pretty_json)
  end
end

puts "Packaging done"
exit 0
