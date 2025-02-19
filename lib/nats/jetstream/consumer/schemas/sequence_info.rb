
          # The sequence number of the Consumer
          integer :consumer_seq

          # The sequence number of the Stream
          integer :stream_seq

          # The last time a message was delivered or acknowledged (for ack_floor)
          string :last_active
