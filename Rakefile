require 'time'

UPDATE_MARKER_FILE = File.expand_path(File.join('tmp', 'LAST_UPDATE'), File.dirname(__FILE__))
BUNDLE_JAR = 'libs/bundle.jar'
BUNDLE_PATH = 'tmp/bundle'

require 'rake/clean'
require 'rexml/document'

generated_libs     = 'generated_libs'
jars = Dir['libs/*.jar']
stdlib             = jars.grep(/stdlib/).first #libs/jruby-stdlib-VERSION.jar
jruby_jar          = jars.grep(/core/).first   #libs/jruby-core-VERSION.jar
stdlib_precompiled = File.join(generated_libs, 'jruby-stdlib-precompiled.jar')
jruby_ruboto_jar   = File.join(generated_libs, 'jruby-ruboto.jar')
dirs = ['tmp/ruby', 'tmp/precompiled', generated_libs]
dirs.each { |d| directory d }

CLEAN.include('tmp', 'bin', generated_libs)

task :default => :debug

desc 'build debug package'
# task :debug => [:generate_libs, BUNDLE_JAR, :mark_update] do
task :debug => [BUNDLE_JAR, :mark_update] do
  sh 'ant debug'
end

desc "build package and install it on the emulator or device"
task :install => [BUNDLE_JAR, :mark_update] do
  sh 'ant install'
end

file stdlib_precompiled => :compile_stdlib
file jruby_ruboto_jar => generated_libs do
  ant.zip(:destfile=>jruby_ruboto_jar) do
    zipfileset(:src=>jruby_jar) do
      exclude(:name=>'jni/**')
      # dx chokes on some of the netdb classes, for some reason
      exclude(:name=>'jnr/netdb/**')
    end
  end
end

desc "precompile ruby stdlib"
task :compile_stdlib => [:clean, *dirs] do
  ant.unzip(:src=>stdlib, :dest=>'tmp/ruby')
  Dir.chdir('tmp/ruby') { sh "jrubyc . -t ../precompiled" }
  ant.zip(:destfile=>stdlib_precompiled, :basedir=>'tmp/precompiled')
end

task :generate_libs => [generated_libs, jruby_ruboto_jar] do
  cp stdlib, generated_libs
end

task :release => :generate_libs

task :tag => :release do
  unless `git branch` =~ /^\* master$/
    puts "You must be on the master branch to release!"
    exit!
  end
  sh "git commit --allow-empty -a -m 'Release #{version}'"
  sh "git tag #{version}"
  sh "git push origin master --tags"
  #sh "gem push pkg/#{name}-#{version}.gem"
end

task :sign => :release do
  sh "jarsigner -keystore #{ENV['RUBOTO_KEYSTORE']} -signedjar bin/#{build_project_name}.apk bin/#{build_project_name}-unsigned.apk #{ENV['RUBOTO_KEY_ALIAS']}"
end

task :align => :sign do
  sh "zipalign 4 bin/#{build_project_name}.apk #{build_project_name}.apk"
end

task :publish => :align do
  puts "#{build_project_name}.apk is ready for the market!"
end

desc 'Start the emulator with larger disk'
task :emulator do
  system 'emulator -partition-size 1024 -avd Android_3.0'
end

task :start_app do
  `adb shell am start -a android.intent.action.MAIN -n #{package}/.#{main_activity}`
end

task :stop_app do
  `adb shell ps | grep #{package} | awk '{print $2}' | xargs adb shell kill`
end

desc 'Restart the application'
task :restart => [:stop_app, :start_app]

task :uninstall do
  puts "Uninstalling package #{package}"
  system "adb uninstall #{package}"
end

namespace :install do
  desc 'Uninstall, build, and install the application'
  task :clean => [:uninstall, :install]

  desc 'Build, install, and restart the application'
  task :restart => [:install, :start_app]

  namespace :restart do
    desc 'Uninstall, build, install, and restart the application'
    task :clean => [:uninstall, :install, :start_app]
  end
end

desc 'Copy scripts to emulator or device'
task :update_scripts => BUNDLE_JAR do
  sdcard_path = "/mnt/sdcard/Android/data/#{package}/files"
  app_files_path = "/data/data/#{package}/files"
  if package_installed? && device_path_exists?(sdcard_path)
    puts 'Pushing files to apk public file area.'
    data_dir = sdcard_path
  elsif package_installed? && device_path_exists?(app_files_path)
    puts 'Pushing files to apk private file area.'
    data_dir = app_files_path
  else
    puts 'Cannot find the scripts directory on the device.'
    puts 'If you have a non-rooted device, you need to add'
    puts %q{    <uses-permission android:name="android.permission.WRITE_EXTERNAL_STORAGE" />}
    puts 'to the AndroidManifest.xml file to enable the update_scripts rake task.'
    puts "Reverting to uninstalling and re-installing the apk."
    Rake::Task['install:clean'].invoke
    next
  end
  last_update = File.exists?(UPDATE_MARKER_FILE) ? Time.parse(File.read(UPDATE_MARKER_FILE)) : Time.parse('1970-01-01T00:00:00')
  Dir.chdir('assets') do
    ['scripts'].each do |asset_dir|
      Dir["#{asset_dir}/*"].each do |asset_file|
        next if File.directory? asset_file
        next if File.ctime(asset_file) < last_update
        print "#{asset_file}: " ; $stdout.flush
        `adb push #{asset_file} #{data_dir}/#{asset_file}`
      end
    end
  end
  mark_update
end

namespace :update_scripts do
  desc 'Copy scripts to emulator and restart the app'
  task :restart => [:stop_app, :update_scripts, :start_app]
end

task :update_test_scripts do
  test_scripts_path = "/data/data/#{package}.tests/files/scripts"
  if false && package_installed?(true) && device_path_exists?(test_scripts_path)
    Dir['test/assets/scripts/*.rb'].each do |script|
      print "#{script}: " ; $stdout.flush
      `adb push #{script} #{test_scripts_path}`
    end
    `adb shell ps | grep #{package}.tests | awk '{print $2}' | xargs adb shell kill`
  else
    Dir.chdir 'test' do
      sh 'ant install'
    end
  end
end

task :test => :uninstall do
  Dir.chdir('test') do
    puts 'Running tests'
    system "adb uninstall #{package}.tests"
    system "ant run-tests"
  end
end

namespace :test do
  task :quick => [:update_scripts, :update_test_scripts] do
    Dir.chdir('test') do
      puts 'Running quick tests'
      sh "ant run-tests-quick"
    end
  end
end

file 'Gemfile'

desc 'Generate bundle jar from Gemfile'
file BUNDLE_JAR => 'Gemfile' do
  next unless File.exists? 'Gemfile'
  puts "Generating #{BUNDLE_JAR}"

  FileUtils.mkdir_p BUNDLE_PATH
  sh "bundle install --path=#{BUNDLE_PATH}"

  # FIXME(uwe):  Should not be necessary.  ARJDBC should not offer the same files as AR.

  Dir.chdir "#{BUNDLE_PATH}/ruby/1.8/gems" do
    scanned_files = []
    Dir["*/lib/**/*"].each do |f|
      raise "Malformed file name" unless f =~ %r{^(.*?)/lib/(.*)$}
      gem_name, lib_file = $1, $2
      if existing_file = scanned_files.find{|sf| sf =~ %r{(.*?)/lib/#{lib_file}}}
        puts "Removing duplicate of file #{lib_file} in gem #{gem_name}"
        puts "Already present in gem #{$1}"
      end
    end
  end

  # FIXME(uwe):  Remove when directory listing in apk subdirectories work.
  # FIXME(uwe):  http://jira.codehaus.org/browse/JRUBY-5775
  Dir["#{BUNDLE_PATH}/ruby/1.8/gems/activesupport-*/lib/active_support/core_ext.rb"].each do |faulty_file|
    faulty_code = <<-'EOF'
Dir["#{File.dirname(__FILE__)}/core_ext/*.rb"].sort.each do |path|
  require "active_support/core_ext/#{File.basename(path, '.rb')}"
end
    EOF
    replace_faulty_code(faulty_file, faulty_code)
  end

  Dir["#{BUNDLE_PATH}/ruby/1.8/gems/activemodel-*/lib/active_model/validations.rb"].each do |faulty_file|
    faulty_code = <<-EOF
Dir[File.dirname(__FILE__) + "/validations/*.rb"].sort.each do |path|
  filename = File.basename(path)
  require "active_model/validations/\#{filename}"
end
    EOF
    replace_faulty_code(faulty_file, faulty_code)
  end

  FileUtils.rm_f BUNDLE_JAR
  Dir["#{BUNDLE_PATH}/ruby/1.8/gems/*"].each_with_index do |gem_dir, i|
    `jar #{i == 0 ? 'c' : 'u'}f #{BUNDLE_JAR} -C #{gem_dir}/lib .`
  end
  FileUtils.rm_rf BUNDLE_PATH

  Rake::Task['install'].invoke
end

task :mark_update do
  mark_update
end

# Methods

def mark_update
  FileUtils.mkdir_p File.dirname(UPDATE_MARKER_FILE)
  File.open(UPDATE_MARKER_FILE, 'w'){|f| f << Time.now.iso8601}
end

def manifest
  @manifest ||= REXML::Document.new(File.read('AndroidManifest.xml'))
end

def strings(name)
  @strings ||= REXML::Document.new(File.read('res/values/strings.xml'))
  value = @strings.elements["//string[@name='#{name.to_s}']"] or raise "string '#{name}' not found in strings.xml"
  value.text
end

def package() manifest.root.attribute('package') end

def version() strings :version_name end

def app_name() strings :app_name end

def main_activity() manifest.root.elements['application'].elements["activity[@android:label='@string/app_name']"].attribute('android:name') end

def build_project_name() @build_project_name ||= REXML::Document.new(File.read('build.xml')).elements['project'].attribute(:name).value end

def device_path_exists?(path)
  path_output =`adb shell ls #{path}`
  result = path_output.chomp !~ /No such file or directory|opendir failed, Permission denied/
  puts "Checking path on device: #{path}: #{result || path_output}"
  result
end

def package_installed? test = false
  package_name = "#{package}#{'.tests' if test}"
  app_paths = ['', '-0', '-1', '-2'].map{|i| "/data/app/#{package_name}#{i}.apk"}
  app_paths.each{|p| puts "adb shell ls #{p}".chomp}
  path_outputs = app_paths.map{|p| `adb shell ls #{p}`.chomp}
  path_outputs.each_with_index do |o, i|
    if o == app_paths[i]
      puts "Found package #{app_paths[i]}"
      return true
    end
  end
#  if path_outputs.any?{|o| o !~ /opendir failed, Permission denied/}
#    puts "Unable to determine installation state of the app.  Assuming it is installed."
#    return true
#  end
  puts "Package not found: #{package_name}"
  return false
end

private

def replace_faulty_code(faulty_file, faulty_code)
  explicit_requires = Dir["#{faulty_file.chomp('.rb')}/*.rb"].sort.map{|f| File.basename(f)}.map do |filename|
    "require 'active_model/validations/#{filename}'"
  end.join("\n")

  old_code = File.read(faulty_file)
  new_code = old_code.gsub faulty_code, explicit_requires
  if new_code != old_code
    puts "Replaced directory listing code in file #{faulty_file} with explicit requires."
    File.open(faulty_file, 'w'){|f| f << new_code}
  else
    puts "Could not find expected faulty code\n\n#{faulty_code}\n\nin file #{faulty_file}\n\n#{old_code}\n\n"
  end
end