require 'data_mapper'
DataMapper::Logger.new($stdout, :info)
DataMapper.setup(:default, "sqlite://#{File.expand_path File.dirname(__FILE__)}/../data/dev.db")
require_relative 'user'
require_relative 'meta'
require_relative 'sales_force_progress_record'
require_relative 'zoho_progress_record'
require_relative 'box_progress_record'
require_relative 'box_file'
require_relative 'box_folder'

DataMapper.finalize

DataMapper.auto_upgrade!
