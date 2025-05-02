# frozen_string_literal: true

module NATS
  class Object
    class Watcher
      class Options < NATS::Utils::Config
        # Do not send delete markers to the update channel
        bool :ignore_deletes, default: true

        # Include all history per subject, not just last one
        bool :include_history, default: false

        # Include only updates for keys
        bool :updates_only, default: false

        def consume
          {deliver_policy: deliver_policy}
        end

        private

        def deliver_policy
          return :new if updates_only
          :last_per_subject unless include_history
        end
      end
    end
  end
end
