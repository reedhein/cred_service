require 'restforce'
require 'active_support/all'
module Utils
  module SalesForce
    class Client
      include Inspector
      include Singleton
      attr_reader :client

      def initialize(user = DB::User.first)
        @client = self.class.client(user)
        dynanmic_methods_for_client
      end

      def custom_query(query: nil, &block)
        fail ArgumentError if query.nil?
        begin
          result = @client.query(query)
        rescue => e
          ap e.backtrace
          binding.pry
        end
        return [] if result.count < 1
        object_type = result.first.dig('attributes', 'type')
        klass = create_klass(object_type)
        result.entries.map do |entity|
          if block_given?
            yield klass.new(entity)
          else
            klass.new(entity)
          end
        end
      end

      def self.client(user = DB::User.first)
        Restforce.log = true
        Restforce.configure do |c|
          c.log_level = :info
        end
        update_user_tokens = lambda do |reply|
            user.salesforce_auth_token = reply.fetch('access_token')
            user.save
            puts "Salesforce Token updated: #{Time.now.to_s}"
          end

        cred_environment = CredService.creds.salesforce.public_send((Utils.environment.try(:to_sym) || :production))
        if Utils.environment == 'sandbox'
          refresh_token = user.salesforce_sandbox_refresh_token
          auth_token = user.salesforce_sandbox_auth_token
        else
          refresh_token = user.salesforce_refresh_token
          auth_token = user.salesforce_auth_token
        end
        Restforce.new oauth_token: auth_token,
          refresh_token: refresh_token,
          host: cred_environment.host,
          instance_url: cred_environment.instance_url,
          client_id:  cred_environment.api_key,
          client_secret:  cred_environment.api_secret,
          api_version:  cred_environment.api_version,
          authentication_callback: update_user_tokens
      end

      def for_date(date)
        requested_time   = Time.parse(date)
        beginning_of_day = requested_time.beginning_of_day
        end_of_day       = requested_time.end_of_day
        offices       = @client.query("select id from account where recordtype.name = 'Office Location'")
        opportunities = @client.query("select id from opportunity where createddate > #{format_time_to_soql(beginning_of_day) } and createddate < #{format_time_to_soql(end_of_day)}")
        leads         = @client.query("select id from lead where createddate > #{format_time_to_soql(beginning_of_day) } and createddate < #{format_time_to_soql(end_of_day)}")
        [offices, opportunities, leads]
      end


      private

      def create_klass(object_type)
        ['Utils', 'SalesForce', object_type.camelize].join('::').classify.constantize
      end
      def dynanmic_methods_for_client
        methods = @client.public_methods - self.public_methods
        methods.each do |meth|
          define_singleton_method meth do |*args|
            @client.send(meth, *args)
          end
        end
      end

    end
  end
end
