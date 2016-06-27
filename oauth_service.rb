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
class SalesForceApp < Sinatra::Base
  set env: :development
  set logging: true
  set port: 4567
  set bind: '0.0.0.0'
  set server: 'thin'
  use Rack::Session::Pool
  use OmniAuth::Builder do
    environment_service = CredService.creds.salesforce.send(($environment || :production))
    puts $environment
    binding.pry
    provider :salesforce, environment_service.api_key , environment_service.api_secret
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
        :scope => 'full refresh_token'
      }
      auth_params = URI.escape(auth_params.collect{|k,v| "#{k}=#{v}"}.join('&'))
      redirect "/auth/salesforce?#{auth_params}"
    when 'box'
      oauth_url = Boxr::oauth_url(URI.encode_www_form_component(CredService.creds.box.token))
      redirect oauth_url
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
      user = DB::User.first_or_create#(salesforce_id: env['omniauth.auth']['extra']['user_id'])
      user.salesforce_auth_token     = env['omniauth.auth']['credentials']['token']
      user.salesforce_refresh_token  = env['omniauth.auth']['credentials']['refresh_token']
      session[:auth_hash] = env['omniauth.auth']
    elsif params[:provider] == 'box'
      creds = Boxr::get_tokens(params['code'])
      client = create_client(creds)
      session[:box_user] = client.current_user.fetch('name')
      redirect '/'
    else
      binding.pry
    end
    user.save
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

