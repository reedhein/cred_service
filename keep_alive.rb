class KeepAlive
  def initialize
    @sf_client  = Utils::SalesForce::Client.instance
    @box_client = Utils::Box::Client.instance

    loop do 
      @sf_client.query("SELECT id FROM Opportunity LIMIT 1")
      @box_client.root_folder_items
      sleep 3599
    end

  end
end
