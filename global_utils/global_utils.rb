require 'json'
require 'pry'
require 'singleton'
module Utils
  @@id_mapping = JSON.parse(File.open(File.join(File.dirname(__FILE__), 'id_json.json')).read)

  class << self
    attr_accessor :environment
  end

  require_relative '../db_share/db'
  require_relative '../cred_service'

  module All
    path = File.dirname(File.absolute_path(__FILE__) )
    Dir.glob(path + '/lib/*').delete_if{|file| File.directory?(file) }.each{ |file| require file }
  end

  def self.id_mapping
    @@id_mapping
  end

  def self.class_from_id(id)
    key = id.slice(0,3)
    id_mapping.fetch(key, 'Generic')
  end
end
