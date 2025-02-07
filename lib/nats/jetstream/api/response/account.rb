# frozen_string_literal: true

module NATS
  class JetStream
    class Api
      class AccountInfoResponse < Response
        schema JetStream::Info
      end
    end
  end
end
