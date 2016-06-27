require 'rubygems'
require 'sinatra'
require 'haml'
require 'boxr'
require 'ruby-growl'
require 'omniauth-salesforce'
require 'pry'
require 'thin'
require_relative '../global_utils/global_utilities'

ENV['BOX_CLIENT_ID']     = CredService.creds.box.client_id
ENV['BOX_CLIENT_SECRET'] = CredService.creds.box.client_secret
SETUP_PROC= lambda do |env|
  request = Rack::Request.new(env)
  env['omniauth.strategy'].options[:consumer_key]    = CredService.creds.salesforce.public_send(request.params['environment'].to_sym).apt_key
  env['omniauth.strategy'].options[:consumer_secret] = CredService.creds.salesforce.public_send(request.params['environment'].to_sym.apt_secret
end
class SalesForceApp < Sinatra::Base
  set env: :development
  set logging: true
  set port: 4567
  set bind: '0.0.0.0'
  set server: 'thin'
  use Rack::Session::Pool
  use OmniAuth::Builder do
    provider :salesforce, setup: SETUP_PROC
  end

  def self.run!
    $environment = ARGV[0] || 'production'
    super do |server|
      server.ssl = true
      server.ssl_options = {
        cert_chain_file:  "/etc/letsencrypt/live/zombiegestation.com/fullchain.pem",
        private_key_file: "/etc/letsencrypt/live/zombiegestation.com/privkey.pem",
        verify_peer:      false
      }
    end
  end

  post '/authenticate/:provider' do
    case params[:provider].downcase 
    when 'salesforce'
      auth_params = {
        :display => 'page',
        :immediate => 'false',
        :scope => 'full refresh_token',
        environment: 'sandbox'
      }
      auth_params = URI.escape(auth_params.collect{|k,v| "#{k}=#{v}"}.join('&'))
      redirect "/auth/salesforce?#{auth_params}"
    when 'box'
      oauth_url = Boxr::oauth_url(URI.encode_www_form_component(CredService.creds.box.token))
      redirect oauth_url
    when 'sandbox'
      auth_params = {
        display:     'page',
        immediate:   'false',
        scope:       'full refresh_token',
        environment: 'sandbox'
      }
      auth_params = URI.escape(auth_params.collect{|k,v| "#{k}=#{v}"}.join('&'))
      redirect "/auth/salesforce?#{auth_params}"
    end
  end

  get '/' do
    haml :index
  end

  get '/unauthenticate' do
    # request.env['rack.session'] = {}
    session.clear
    redirect '/'
  end

  get '/auth/failure' do
    haml :error, :locals => { :message => params[:message] } 
  end

  get '/auth/:provider/callback' do
    if params[:provider] == 'salesforce'
      save_salesforce_credentials
    elsif params[:provider] == 'box'
      creds = Boxr::get_tokens(params['code'])
      client = create_client(creds)
      session[:box_user] = client.current_user.fetch('name')
      redirect '/'
    else
      binding.pry
    end
    redirect '/' unless session[:auth_hash] == nil
  end

  get '/error' do
  end

  get '/*' do
    haml :index 
  end

  error do
    haml :error
  end

  private

  def save_salesforce_credentials
    user = DB::User.Doug
    begin
      if $environment == 'sandbox'
        user.salesforce_sandbox_auth_token     = env['omniauth.auth']['credentials']['token']
        user.salesforce_sandbox_refresh_token  = env['omniauth.auth']['credentials']['refresh_token']
      elsif $environment == 'production'
        user.salesforce_auth_token     = env['omniauth.auth']['credentials']['token']
        user.salesforce_refresh_token  = env['omniauth.auth']['credentials']['refresh_token']
      else
        fail "don't know how to handle this environment"
      end
    rescue => e
      binding.pry
    end
    user.save
    session[:auth_hash] = env['omniauth.auth']
  end

  def create_client(creds, user: DB::User.first)
    user.box_access_token   = creds.fetch('access_token')
    user.box_refresh_token  = creds.fetch('refresh_token')
    puts "User update"
    client = Boxr::Client.new(user.box_access_token,
              refresh_token: creds.fetch('refresh_token'),
              client_id:     CredService.creds.box.client_id,
              client_secret: CredService.creds.box.client_secret
            )
    client
  end


  last_time_say_was_run = File.read('last_run.txt').strip
  unless Date.today.to_s == last_time_say_was_run
    `say sushi is coming online` if RbConfig::CONFIG['host_os'] =~ /darwin/
    File.open('last_run.txt', 'w') do |f|
      f << Date.today.to_s
    end
  end
  run! if app_file == $0
end

