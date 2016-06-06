require 'watir'
require 'nokogiri'
require 'mechanize'
require 'pry'
require 'pry-byebug'
require 'open-uri'
require 'selenium-webdriver'
require '../global_utilities/global_utilities'


class SetupKeys
  attr_reader :agent 
  def initialize
    @work          = parse_args
    @agent         = Watir::Browser.new :firefox
    @ngrok_page    = 'http://localhost:4040/status'
    @download_page = 'https://na34.salesforce.com/02u?retURL=%2Fui%2Fsetup%2FSetup%3Fsetupid%3DDevTools&setupid=TabSet'
    @box_page      = 'https://reedhein.app.box.com/developers/services'
    @ngrok_tunnel = find_tunnel
    begin
      do_work
    rescue => e
      puts e
      binding.pry
    ensure
      @agent.close
    end
  end

  def find_tunnel
    agent.goto(@ngrok_page)
    document = agent.html
    doc = Nokogiri::HTML(document)
    doc.at('table:first tr:first td:last').text.strip
  end

  def salesforce
    @agent.goto(@download_page)
    @agent.text_field(id: 'username').set CredService.creds.user.salesforce.username
    @agent.text_field(id: 'password').set CredService.creds.user.salesforce.password
    @agent.button(name: 'Login').click
    sleep 10
    @agent.links(text: 'UtilityApp').first.click
    a = Nokogiri::HTML(@agent.html)
    current_value = URI.parse(a.search('td.dataCol.last:last').text)
    new_value     = URI.parse(@ngrok_tunnel)
    unless new_value.host == current_value.host
      @agent.button(text: 'Edit').click
      callback_text_field = @agent.textarea(id: /callback/)
      callback_text_field.value = @ngrok_tunnel.to_s + '/auth/salesforce/callback'
      agent.button(text: "Save").click
      agent.button(text: "Continue").click
    end
  end

  def box
    @agent.goto(@box_page)
    @agent.text_field(name: 'login').set    CredService.creds.user.box.username
    @agent.text_field(name: 'password').set CredService.creds.user.box.password
    @agent.button(type: 'submit').click
    @agent.text_field(id: 'field_oauth2_redirect_uri')
    @agent.button(id: /button_edit_application_/).click
    box_field = @agent.text_field(id: 'field_oauth2_redirect_uri')
    current_value = box_field.value
    unless URI.parse(@ngrok_tunnel).host == URI.parse(current_value).host
      box_field.set(@ngrok_tunnel.to_s + '/auth/box/callback')
      @agent.button(id: 'save_service_button').click
    end
    authenticate_box
  end

  def do_work
    case @work
    when 'all'
      salesforce
      authenticate_salesforce
      box
      authenticate_box
    when 'sf'
      salesforce
      authenticate_salesforce
    when 'box'
      box
      authenticate_box
    else
      salesforce
      authenticate_salesforce
      box
      authenticate_box
    end
  end

  private

  def authenticate_salesforce
    @agent.goto(@ngrok_tunnel)
    sleep 2
    @agent.button(id: 'salesforce_auth').click
    sleep 2
    while agent.text.include? 'You are NOT authenticated in salesforce' do
      puts 'waiting for salesforce to update'
      sleep 60
      @agent.goto(@ngrok_tunnel)
      @agent.button(id: 'salesforce_auth').click
    end
    `say sales force authorization token updated` if RbConfig::CONFIG['host_os'] =~ /darwin/
  end

  def authenticate_box
    @agent.goto(@ngrok_tunnel)
    sleep 2
    while agent.text.include? 'You are NOT authenticated in box' do
      @agent.button(id: 'box_auth').click
      puts 'waiting for box to update'
      sleep 60
      @agent.goto(@ngrok_tunnel)
      @agent.id(id: 'box_auth').click
    end
    @agent.button(id: 'consent_accept_button').click

    `say box authorization token updated` if RbConfig::CONFIG['host_os'] =~ /darwin/
  end

  def parse_args
    puts ARGV[0]
    case ARGV[0]
    when "all"
      'all'
    when "box"
      'box'
    when /salesforce|sf/
      'sf'
    else
      'all'
    end
  end
end

a = SetupKeys.new
puts 'finished'
