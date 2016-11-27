require 'rubygems'
require 'sinatra'
require 'haml'
require 'boxr'
require 'ruby-growl'
require 'omniauth-salesforce'
require 'pry'
require 'thin'
require 'addressable/uri'
require_relative './global_utils/global_utils'

class SalesForceApp < Sinatra::Base
  set env: :development
  set logging: true
  set port: 4567
  set bind: '0.0.0.0'
  set server: 'thin'
  use Rack::Session::Pool
  use OmniAuth::Builder do
    # provider :salesforce, CredService.creds.salesforce.production.api_key, CredService.creds.salesforce.production.api_secret, provider_ignores_state: true
    # provider OmniAuth::Strategies::SalesforceSandbox, CredService.creds.salesforce.sandbox.kitten_clicker.api_key, CredService.creds.salesforce.sandbox.kitten_clicker.api_secret, provider_ignores_state: true
    provider :salesforce,
      CredService.creds.salesforce.production.utility_app.api_key,
      CredService.creds.salesforce.production.utility_app.api_secret,
      provider_ignores_state: true
    provider OmniAuth::Strategies::SalesforceSandbox,
      CredService.creds.salesforce.production.utility_app.api_key,
      CredService.creds.salesforce.production.utility_app.api_secret,
      provider_ignores_state: true
  end

  # def self.run!
    $environment = ARGV[0] || 'production'
    # super do |server|
    #   server.ssl = true
    #   server.ssl_options = {
    #     cert_chain_file:  "/etc/letsencrypt/live/zombiegestation.com/fullchain.pem",
    #     private_key_file: "/etc/letsencrypt/live/zombiegestation.com/privkey.pem",
    #     verify_peer:      false
    #   }
    # end
  # end

  post '/authenticate/:provider' do
    case params[:provider].downcase 
    when 'salesforce'
      auth_params = {
        :display => 'page',
        :immediate => 'false',
        :scope => 'full',
      }
      auth_params = URI.escape(auth_params.collect{|k,v| "#{k}=#{v}"}.join('&'))
      redirect "/auth/salesforce?#{auth_params}"
    when 'box'
      oauth_url = Boxr::oauth_url(
        URI.encode_www_form_component(CredService.creds.box.utility_app.token),
        client_id: CredService.creds.box.utility_app.client_id
      )
      redirect oauth_url
    when 'sandbox'
      auth_params = {
        display:     'page',
        immediate:   'false',
        scope:       'full',
      }
      auth_params = URI.escape(auth_params.collect{|k,v| "#{k}=#{v}"}.join('&'))
      redirect "/auth/salesforcesandbox?#{auth_params}"
    end
  end

  get '/' do
    session[:return_address] ||= params[:return_address]
    session[:return_port]    ||= params[:return_port]
    # binding.pry unless session[:return_address] && session[:return_port]
    if session[:box] && !session[:box][:email].nil? && session[:salesforce] && !session[:salesforce][:email].nil?
      user = DB::User.first(email: session[:box][:email])
      params =  {
                  salesforce_auth_token:    user.salesforce_auth_token,
                  salesforce_refresh_token: user.salesforce_refresh_token,
                  box_access_token:         user.box_access_token,
                  box_refresh_token:        user.box_refresh_token,
                  email:                    user.email
                }
      uri = Addressable::URI.new
      uri.query_values= params
      @my_params  = uri.query
      @user_email = user.email
      @user = user
      # redirect 'http://10.10.0.162:4545/authorize?' + uri.query
      # redirect 'https://52506ad4.ngrok.io/authorize?' + uri.query
      # binding.pry
      if session[:return_address] && session[:return_port] && session[:return_port] != '80'
        redirect "http://#{session[:return_address]}:#{session[:return_port]}/authorize?"   + uri.query
      elsif session[:return_address] && (session[:return_port].nil? || (session[:return_port] && session[:return_port] == '80'))
        redirect "http://#{session[:return_address]}/authorize?"   + uri.query
      else
        redirect '/'
      end
    else
      haml :index
    end
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
    session[:return_address] ||= params[:return_address]
    session[:return_port]    ||= params[:return_port]
    case params[:provider] 
    when 'salesforce'
      save_salesforce_credentials('salesforce')
    when 'salesforcesandbox'
      save_salesforce_credentials('salesforcesandbox')
    when 'box'
      # creds = Boxr::get_tokens(params['code'])
      creds = Boxr::get_tokens(params[:code], client_id: CredService.creds.box.utility_app.client_id, client_secret: CredService.creds.box.utility_app.client_secret)
      client = create_box_client_from_creds(creds)
      user = populate_box_creds_to_db(client)
      session[:box] = {}
      session[:box][:email] = user.email
    else
      binding.pry
    end
    if session[:box] && !session[:box][:email].nil? && session[:salesforce] && !session[:salesforce][:email].nil?
      user = DB::User.first(email: session[:box][:email])
      params =  {
                  salesforce_auth_token:    user.salesforce_auth_token,
                  salesforce_refresh_token: user.salesforce_refresh_token,
                  box_access_token:         user.box_access_token,
                  box_refresh_token:        user.box_refresh_token
                }
      uri = Addressable::URI.new
      uri.query_values= params
      @my_params = uri.query
      puts uri.query
      if session[:return_address] && session[:return_port] && session[:return_port] != '80'
        redirect "http://#{session[:return_address]}:#{session[:return_port]}/authorize?"   + uri.query
      elsif session[:return_address] && (session[:return_port].nil? || (session[:return_port] && session[:return_port] == '80'))
        redirect "http://#{session[:return_address]}/authorize?"   + uri.query
      else
        redirect '/'
      end
    else
      redirect '/'
    end
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

  def save_salesforce_credentials(callback)
    user = DB::User.first_or_create(email: env.dig('omniauth.auth', 'extra', 'email'))
    if callback == 'salesforce'
      user.salesforce_auth_token     = env.dig('omniauth.auth','credentials','token')
      user.salesforce_refresh_token  = env.dig('omniauth.auth','credentials','refresh_token')
      session[:salesforce] = {}
      session[:salesforce][:email] = user.email
    elsif callback == 'salesforcesandbox'
      user.salesforce_sandbox_auth_token     = env['omniauth.auth']['credentials']['token']
      user.salesforce_sandbox_refresh_token  = env['omniauth.auth']['credentials']['refresh_token']
      session[:salesforcesandbox] = {}
      session[:salesforcesandbox][:email] = user.email
    else
      fail "don't know how to handle this environment"
    end
    user.save
  rescue => e
    puts e.backtrace
    binding.pry
  end

  def create_box_client_from_creds(creds)
    client = Boxr::Client.new(creds.fetch('access_token'),
              refresh_token: creds.fetch('refresh_token'),
              client_id:     CredService.creds.box.kitten_clicker.client_id,
              client_secret: CredService.creds.box.kitten_clicker.client_secret
            )
    client
  end

  def create_client(creds, user: DB::User.first)
    user.box_access_token    = creds.fetch('access_token')
    user.box_refresh_token = creds.fetch('refresh_token')
    puts "User update"
    client = Boxr::Client.new(user.box_access_token,
              refresh_token: creds.fetch('refresh_token'),
              client_id:     CredService.creds.box.client_id,
              client_secret: CredService.creds.box.client_secret
            )
    client
  end

  def populate_box_creds_to_db(client)
    email = client.current_user.login
    user  = DB::User.first_or_create(email: email)
    user.box_access_token    = client.access_token
    user.box_refresh_token = client.refresh_token
    session[:box] = {}
    session[:box][:email] = email
    user.save
    user
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

