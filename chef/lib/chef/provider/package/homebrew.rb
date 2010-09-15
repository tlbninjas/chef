#
# Author:: Sahil Cooner (<scooner@yammer-inc.com>)
# Copyright:: Copyright (c) 2010 Yammer, Inc.
# License:: Apache License, Version 2.0
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
# 
#     http://www.apache.org/licenses/LICENSE-2.0
# 
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#

class Chef
  class Provider
    class Package
      class HomeBrew < Chef::Provider::Package

        def load_current_resource
          @current_resource =  Chef::Resource::Package.new(@new_resource.name)
          @current_resource.package_name(@new_resource.package_name)

          @current_resource.version(current_installed_version)
          Chef::Log.debug("Current version is #{@current_resource}") if @current_resource.version

          @candidate_version = homebrew_candidate_version

          if !@new_resource.version and !@candidate_version
            raise Chef::Exceptions::Package, 
              "Could not get a candidate version for this package -- #{@new_resource.name} does not seem to be a valid package!"
          end

          Chef::Log.debug("Homebrew candidate version is #{@candidate_version}") if @candidate_version
          @current_resources
        end

        def current_installed_version 
          #command = "brew list --versions | grep #{@new_resource.package_name}"
          command = "brew list --versions"
          output  = get_response_from_command(command)

          response = nil
          output.each_line do |line|
            # this skips HEAD packages, but you want those to install anyway since they aren't versioned.
            match = line.match(/(?:\d+(?:(?=\.\d+)\.\d+)*)/)
            response = match[0] if match
          end
          response
        end

        def homebrew_candidate_version
          command = "brew info #{@new_resource.package_name}"
          output  = get_response_from_command(command)
          match   = output.match(/^#{@new_resource.package_name} (.+)$/)
          match ? match[1] : nil
        end

        def install_package(name, version)
          unless @current_resource.version == version
            command = "brew install #{name}"
            #command << " @#{version}" if version and !version.empty?
            run_command_with_systems_locale(
              :command => command
            )
          end
        end

        def remove_package(name, version)
          command = "brew uninstall #{name}"
          run_command_with_systems_locale(
            :command => command                           
          )
        end

        def upgrade_package(name, version)
          current_version = @current_resource.version

          if current_version.nil? or current_version.empty?
            # brew requires you to install, no such thing as upgrade
            install_package(name, version)
          elsif current_version != version
            run_command_with_systems_locale(
              :command => "brew -v install #{name}"
            )
          end
        end

        private
        def get_response_from_command(command)
          output = nil
          status = popen4(command) do |pid, stdin, stdout, stderr|
            begin 
              output = stdout.read
            rescue Exception
              raise Chef::Exceptions::Package, "Could not read from STDOUT on command: #{command}"
            end
          end
          unless status.exitstatus == 0 || status.exitstatus == 1
            raise Chef::Exceptions::Package, "#{command} failed - #{status.insect}!"
          end
          output
        end
      end
    end
  end
end
