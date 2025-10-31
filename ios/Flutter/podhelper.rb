# Copyright 2014 The Flutter Authors. All rights reserved.
# Use of this source code is governed by a BSD-style license that can be
# found in the LICENSE file.

require 'json'

# Install pods needed by Flutter plugins.
#
# @param [String] ios_application_path
#         The path to the root of the iOS application. Optional, defaults to
#         the directory of the Podfile.
def flutter_install_all_ios_pods(ios_application_path = nil)
  ios_application_path ||= File.dirname(File.expand_path_impersonating_pwd('Podfile'))
  flutter_plugins_podspec_path = File.join(ios_application_path, 'Flutter', 'FlutterPluginRegistrant', 'podspec.json')

  return unless File.exist?(flutter_plugins_podspec_path)

  podspec = JSON.parse(File.read(flutter_plugins_podspec_path))

  dependencies = podspec['dependencies']
  return unless dependencies

  dependencies.each do |name, requirements|
    # Can be an empty array, which means no version requirement.
    if requirements.empty?
      pod name
    else
      # Can be a single version string or an array of versions.
      # The flutter tool generates a single version string.
      pod name, requirements.first
    end
  end
end

def flutter_ios_podfile_setup
  # This is a hook for the flutter tool to do additional setup.
  # For now, it does nothing.
end

def flutter_additional_ios_build_settings(target)
  # This is a hook for the flutter tool to do additional setup.
  # For now, it does nothing.
end

# `expand_path` is relative to the current working directory, which is not
# necessarily the directory of the Podfile.
# Instead, this gives the full path of the file relative to the directory
# of the impersonated file.
#
# @example
#
#   File.expand_path_impersonating_pwd('Podfile')
#
# @param [String] filename
#         The name of the file to expand.
#
# @return [String] The full path of the file.
def File.expand_path_impersonating_pwd(filename)
  # The directory of the Podfile.
  podfile_directory = File.dirname(caller_locations.first.absolute_path)
  File.expand_path(filename, podfile_directory)
end
