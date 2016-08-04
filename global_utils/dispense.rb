require 'fileutils'
require 'pry'
require 'pathname'


gemfile      = [Pathname.new(File.absolute_path(__FILE__)).dirname ,  'Gemfile'].join('/')
gemfile_lock = [Pathname.new(File.absolute_path(__FILE__)).dirname , 'Gemfile.lock'].join('/')
ruby_version = [Pathname.new(File.absolute_path(__FILE__)).dirname , '.ruby-version'].join('/')
ruby_gemset  = [Pathname.new(File.absolute_path(__FILE__)).dirname , '.ruby-gemset'].join('/')
work_folder  = File.absolute_path(Pathname.new('..'))
gem_files    = [gemfile, gemfile_lock, ruby_version, ruby_gemset]
skip_folders = [ 'global_utilities', 'global_utils', 'rubyzoho', 'Dougs', 'tooling-force.com' ]
def link_gem_files(gem_files, entity)
  gem_files.each do |file|
    proposed_file = [entity , Pathname.new(file).basename].join('/')
    FileUtils.rm(proposed_file) if Pathname.new(proposed_file).exist? || Pathname.new(proposed_file).symlink?
    puts proposed_file
    FileUtils.ln_s(file, entity)
  end
end

Dir.glob(work_folder + '/*').each do |entity|
  if Pathname(entity).directory? && !skip_folders.include?(entity.split('/').last)
    link_gem_files(gem_files, entity)
  end
end


