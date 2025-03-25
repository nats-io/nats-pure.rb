# frozen_string_literal: true

module NATS
  class JetStream
    class API
      class AccountInfoResponse < Response
        schema JetStream::Info
      end
    end
  end
end
