module DB
  class User
    include DataMapper::Resource
    property :id, Serial
    property :email, String, length: 255, index: true, unique: true
    property :salesforce_id, String
    property :salesforce_auth_token, String, length: 255
    property :salesforce_refresh_token, String, length: 255
    property :salesforce_sandbox_auth_token, String, length: 255
    property :salesforce_sandbox_refresh_token, String, length: 255
    property :box_access_token, String, length: 255
    property :box_refresh_token, String, length: 255
    property :box_identifier, String, length: 255
    property :box_refresh_token, String, length: 255
    property :box_id, String

    def sfsb_auth
      salesforce_sandbox_auth_token
    end

    def sfsb_refersh
      salesforce_sandbox_refresh_token
    end

    def box_auth_token
      box_access_token
    end

    def box_auth_token=(string)
      self.box_access_token=(string)
    end

    def self.Doug
      first_or_create
    end

  end
end
