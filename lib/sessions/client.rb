class Sessions::Client

  def initialize( client_id )
    @client_id = client_id
    self.log '---client start ws connection---'
    self.fetch
    self.log '---client exiting ws connection---'
  end

  def fetch

    backends = [
      'Sessions::Backend::TicketOverviewIndex',
      'Sessions::Backend::TicketOverviewList',
      'Sessions::Backend::Collections',
      'Sessions::Backend::Rss',
      'Sessions::Backend::ActivityStream',
      'Sessions::Backend::TicketCreate',
    ]

    backend_pool = []
    user_id_last_run = nil
    loop_count = 0
    loop do

      # get connection user
      session_data = Sessions.get( @client_id )
      return if !session_data
      return if !session_data[:user]
      return if !session_data[:user]['id']
      user = User.lookup( id: session_data[:user]['id'] )
      return if !user

      # init new backends
      if user_id_last_run != user.id
        user_id_last_run = user.id

        # release old objects
        backend_pool.collect! {
          nil
        }

        # create new pool
        backend_pool = []
        backends.each {|backend|
          item = backend.constantize.new(user, self, @client_id)
          backend_pool.push item
        }
      end

      loop_count += 1
      self.log "---client - looking for data of user #{user.id}"

      # push messages from backends
      backend_pool.each(&:push)

      self.log '---/client-'

      # start faster in the beginnig
      if loop_count < 20
        sleep 0.6
      else
        sleep 1
      end
    end
  end

  # send update to browser
  def send( data )
    Sessions.send( @client_id, data )
  end

  def log( msg )
    Rails.logger.debug "client(#{ @client_id }) #{ msg }"
  end
end
