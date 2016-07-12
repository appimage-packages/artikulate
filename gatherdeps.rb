#!/usr/bin/env ruby
# frozen_string_literal: true
# 
# Copyright (C) 2016 Scarlett Clark <sgclark@kde.org>
# Copyright (C) 2015-2016 Harald Sitter <sitter@kde.org>
#
# This library is free software; you can redistribute it and/or
# modify it under the terms of the GNU Lesser General Public
# License as published by the Free Software Foundation; either
# version 2.1 of the License, or (at your option) version 3, or any
# later version accepted by the membership of KDE e.V. (or its
# successor approved by the membership of KDE e.V.), which shall
# act as a proxy defined in Section 6 of version 3 of the license.
#
# This library is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
# Lesser General Public License for more details.
#
# You should have received a copy of the GNU Lesser General Public
# License along with this library.  If not, see <http://www.gnu.org/licenses/>.

#attempt to get deps. NOTE: This is for ubuntu/debian based distro
require 'fileutils'
require_relative 'generate_recipe.rb'

appimage = Recipe.new
appimage.name = "artikulate"
appimage.proper_name = appimage.name.capitalize
appimage.version = '16.04.1'
#Needed to add ability to pull in external builds that are simply to old
#in Centos.
appimage.external = 'libarchive,https://github.com/libarchive/libarchive,true,""'
appimage.cmake = true
appimage.wayland = false
appimage.boost = false
cmake_deps = ''
oddballs = []
distro_packages = []
kf5_map = YAML.load_file('frameworks.yaml')
kf5_dependencies = []
dependencies = []
if not File.exists?("#{appimage.name}")
    system("git clone http://anongit.kde.org/#{appimage.name}
 #{appimage.name}")
    Dir.chdir("#{appimage.name}") do
      system("git submodule init")
      system("git submodule update") 
    end
end
FileUtils.cp('cmake-dependencies.py', "#{appimage.name}")
Dir.chdir("#{appimage.name}") do
    system("cmake \
    -DCMAKE_INSTALL_PREFIX:PATH=/app/usr/ \
    -DCMAKE_BUILD_TYPE=RelWithDebInfo \
    -DPACKAGERS_BUILD=1 \
    -DBUILD_TESTING=FALSE"
    )
    system("make -j8")
    cmake_deps = `python3 cmake-dependencies.py | grep '\"project\": '`.sub('\\', '').split(',')
end

cmake_deps.each do |dep|
    parts = dep.sub('{', '').sub('}', '').split(',')

    parts.each do |project|        
        a = project.split.each_slice(3).map{ |x| x.join(' ')}.to_s
        if a.to_s.include? "project"
            name = a.gsub((/[^0-9a-z ]/i), '').downcase
            name.slice! "project "
            if ( name == "ecm" )
                name = "extra-cmake-modules"
                kf5_dependencies.push name
            end
            if ( name =~ /kf5/)
              oddballs = ["ksolid","kthreadweaver","ksonnet","kattica"]
              name = name.sub("kf5", "k")
              oddballs.each do |oddball|
                if ( name == oddball)
                  name = name.sub("k", '')                  
                end
              end
              
              kf5_dependencies.push name 
            else
              dependencies.push name
              if ( name =~ /qt5/ )
                dependencies.delete name  
              end
            end
        end
    end
end
kf5_dependencies.delete 'k'
kf5_dependencies.sort!



kf5_dependencies.each do |dep|
  h = kf5_map[dep]
  unless h["distro_packages"].nil? 
    distro_packages |= h["distro_packages"]
  end
  unless h["kf5_deps"].nil?
    kf5_dependencies |= h["kf5_deps"]
  end
end

#dependencies from the cmake parsing does not match anything from a distro, so 
# these still need to be verified by hand and assigned the proper packages. I see no way around this.
puts dependencies
dependencies = "python3"


appimage.dependencies =+ distro_packages.join(' ').to_s + ' ' + dependencies.to_s
appimage.frameworks = kf5_dependencies.join(' ').to_s

puts appimage.dependencies
puts appimage.frameworks

appimage.apps = [Recipe::App.new("#{appimage.name}")]
File.write('Recipe', appimage.render)

#Cleanup
FileUtils.remove_dir(appimage.name)
