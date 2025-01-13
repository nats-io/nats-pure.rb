# frozen_string_literal: true

module NATS
  class Message
    class Client < Message
    end

    class Connect < Client
    end

    class Pub < Client
    end

    class Hpub < Client
    end

    class Sub < Client
    end

    class Unsub < Client
    end
  end
end
