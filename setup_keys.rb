require 'watir'
require 'nokogiri'
require 'mechanize'
require 'pry'
require 'pry-byebug'
require 'open-uri'
require 'selenium-webdriver'
require '../global_utilities/global_utilities'

ngrok_page = 'http://localhost:4040/status'
download_page = 'https://na34.salesforce.com/02u?retURL=%2Fui%2Fsetup%2FSetup%3Fsetupid%3DDevTools&setupid=TabSet'

begin
  agent = Watir::Browser.new :firefox
  agent.goto(ngrok_page)
  document = agent.html
  doc = Nokogiri::HTML(document)
  new_url = doc.at('table:first tr:first td:last').text.strip
  agent.goto(download_page)
  agent.text_field(id: 'username' ).set CredService.creds.user.salesforce.username
  agent.text_field(id: 'password').set CredService.creds.user.salesforce.password
  agent.button(name: 'Login').click
  sleep 10

  agent.links(text: 'UtilityApp').first.click
  agent.button(text: 'Edit').click
  callback_text_field = agent.textarea(id: /callback/)
  current_value = URI.parse(callback_text_field.value)
  new_value     = URI.parse(new_url)
  unless new_value.host == current_value.host
    callback_text_field.value = new_value.to_s + '/auth/salesforce/callback'
    agent.button(text: "Save").click
    agent.button(text: "Continue").click
  end
  agent.goto(new_url)
  agent.link(text: 'Authenticate using your salesforce credentials').click
  while !agent.text.include? 'omniauth salesforce example' do
    puts 'waiting for salesforce to update'
    sleep 60
    agent.goto(new_url)
    agent.link(text: 'Authenticate using your salesforce credentials').click
  end
  `say authorization token updated` if RbConfig::CONFIG['host_os'] =~ /darwin/
ensure
  agent.close
end
