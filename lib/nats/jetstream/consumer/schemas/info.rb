# frozen_string_literal: true

module NATS
  class JetStream
    class Consumer
      class Info < NATS::Utils::Config

        # The Stream the consumer belongs t
        string :stream_name

        # A unique name for the consumer, either machine generated or the durable nam
        string :name

        # The server time the consumer info was created
        string :ts # date-time

        object :config, as: Config
        "config": {
          "required": [
            "deliver_policy",
            "ack_policy",
            "replay_policy"
          ],
          "allOf": [
            {
              "oneOf": [
                {
                  "required": [
                    "deliver_policy"
                  ],
                  "properties": {
                    "deliver_policy": {
                      "type": "string",
                      "enum": [
                        "all"
                      ]
                    }
                  }
                },
                {
                  "required": [
                    "deliver_policy"
                  ],
                  "properties": {
                    "deliver_policy": {
                      "type": "string",
                      "enum": [
                        "last"
                      ]
                    }
                  }
                },
                {
                  "required": [
                    "deliver_policy"
                  ],
                  "properties": {
                    "deliver_policy": {
                      "type": "string",
                      "enum": [
                        "new"
                      ]
                    }
                  }
                },
                {
                  "required": [
                    "deliver_policy",
                    "opt_start_seq"
                  ],
                  "properties": {
                    "deliver_policy": {
                      "type": "string",
                      "enum": [
                        "by_start_sequence"
                      ]
                    },
                    "opt_start_seq": {
                      "minimum": 0,
                      "$comment": "unsigned 64 bit integer",
                      "type": "integer",
                      "maximum": 18446744073709551615
                    }
                  }
                },
                {
                  "required": [
                    "deliver_policy",
                    "opt_start_time"
                  ],
                  "properties": {
                    "deliver_policy": {
                      "type": "string",
                      "enum": [
                        "by_start_time"
                      ]
                    },
                    "opt_start_time": {
                      "$comment": "A point in time in RFC3339 format including timezone, though typically in UTC",
                      "type": "string",
                      "format": "date-time"
                    }
                  }
                },
                {
                  "required": [
                    "deliver_policy"
                  ],
                  "properties": {
                    "deliver_policy": {
                      "type": "string",
                      "enum": [
                        "last_per_subject"
                      ]
                    }
                  }
                }
              ]
            }
          ],
          "properties": {
            "durable_name": {
              "description": "A unique name for a durable consumer",
              "deprecationMessage": "Durable is deprecated. All consumers will have names. picked by clients.",
              "type": "string",
              "pattern": "^[^.*>]+$",
              "minLength": 1
            },
            "name": {
              "description": "A unique name for a consumer",
              "type": "string",
              "pattern": "^[^.*>]+$",
              "minLength": 1
            },
            "description": {
              "description": "A short description of the purpose of this consumer",
              "type": "string",
              "maxLength": 4096
            },
            "deliver_subject": {
              "type": "string",
              "minLength": 1
            },
            "ack_policy": {
              "type": "string",
              "enum": [
                "none",
                "all",
                "explicit"
              ],
              "default": "none"
            },
            "ack_wait": {
              "description": "How long (in nanoseconds) to allow messages to remain un-acknowledged before attempting redelivery",
              "minimum": 1,
              "default": "30000000000",
              "$comment": "nanoseconds depicting a duration in time, signed 64 bit integer",
              "type": "integer",
              "maximum": 9223372036854775807
            },
            "max_deliver": {
              "description": "The number of times a message will be redelivered to consumers if not acknowledged in time",
              "default": -1,
              "$comment": "integer with a dynamic bit size depending on the platform the cluster runs on, can be up to 64bit",
              "type": "integer",
              "maximum": 9223372036854775807,
              "minimum": -9223372036854775807
            },
            "filter_subject": {
              "description": "Filter the stream by a single subjects",
              "type": "string"
            },
            "filter_subjects": {
              "description": "Filter the stream by multiple subjects",
              "type": "array",
              "items": {
                "type": "string",
                "minLength": 1
              }
            },
            "replay_policy": {
              "type": "string",
              "enum": [
                "instant",
                "original"
              ],
              "default": "instant"
            },
            "sample_freq": {
              "type": "string"
            },
            "rate_limit_bps": {
              "description": "The rate at which messages will be delivered to clients, expressed in bit per second",
              "minimum": 0,
              "$comment": "unsigned 64 bit integer",
              "type": "integer",
              "maximum": 18446744073709551615
            },
            "max_ack_pending": {
              "description": "The maximum number of messages without acknowledgement that can be outstanding, once this limit is reached message delivery will be suspended",
              "default": 1000,
              "$comment": "integer with a dynamic bit size depending on the platform the cluster runs on, can be up to 64bit",
              "type": "integer",
              "maximum": 9223372036854775807,
              "minimum": -9223372036854775807
            },
            "idle_heartbeat": {
              "minimum": 0,
              "description": "If the Consumer is idle for more than this many nano seconds a empty message with Status header 100 will be sent indicating the consumer is still alive",
              "$comment": "nanoseconds depicting a duration in time, signed 64 bit integer",
              "type": "integer",
              "maximum": 9223372036854775807
            },
            "flow_control": {
              "type": "boolean",
              "description": "For push consumers this will regularly send an empty mess with Status header 100 and a reply subject, consumers must reply to these messages to control the rate of message delivery"
            },
            "max_waiting": {
              "description": "The number of pulls that can be outstanding on a pull consumer, pulls received after this is reached are ignored",
              "minimum": 0,
              "default": 512,
              "$comment": "integer with a dynamic bit size depending on the platform the cluster runs on, can be up to 64bit",
              "type": "integer",
              "maximum": 9223372036854775807
            },
            "direct": {
              "type": "boolean",
              "description": "Creates a special consumer that does not touch the Raft layers, not for general use by clients, internal use only",
              "default": false
            },
            "headers_only": {
              "type": "boolean",
              "default": false,
              "description": "Delivers only the headers of messages in the stream and not the bodies. Additionally adds Nats-Msg-Size header to indicate the size of the removed payload"
            },
            "max_batch": {
              "type": "integer",
              "description": "The largest batch property that may be specified when doing a pull on a Pull Consumer",
              "default": 0
            },
            "max_expires": {
              "description": "The maximum expires value that may be set when doing a pull on a Pull Consumer",
              "default": 0,
              "$comment": "nanoseconds depicting a duration in time, signed 64 bit integer",
              "type": "integer",
              "maximum": 9223372036854775807,
              "minimum": -9223372036854775807
            },
            "max_bytes": {
              "description": "The maximum bytes value that maybe set when dong a pull on a Pull Consumer",
              "minimum": 0,
              "default": 0,
              "$comment": "integer with a dynamic bit size depending on the platform the cluster runs on, can be up to 64bit",
              "type": "integer",
              "maximum": 9223372036854775807
            },
            "inactive_threshold": {
              "description": "Duration that instructs the server to cleanup ephemeral consumers that are inactive for that long",
              "default": 0,
              "$comment": "nanoseconds depicting a duration in time, signed 64 bit integer",
              "type": "integer",
              "maximum": 9223372036854775807,
              "minimum": -9223372036854775807
            },
            "backoff": {
              "description": "List of durations in Go format that represents a retry time scale for NaK'd messages",
              "type": "array",
              "items": {
                "$comment": "nanoseconds depicting a duration in time, signed 64 bit integer",
                "type": "integer",
                "maximum": 9223372036854775807,
                "minimum": -9223372036854775807
              }
            },
            "num_replicas": {
              "description": "When set do not inherit the replica count from the stream but specifically set it to this amount",
              "type": "integer",
              "minimum": 0,
              "maximum": 5,
              "$comment": "integer with a dynamic bit size depending on the platform the cluster runs on, can be up to 64bit"
            },
            "mem_storage": {
              "description": "Force the consumer state to be kept in memory rather than inherit the setting from the stream",
              "type": "boolean",
              "default": false
            },
            "metadata": {
              "description": "Additional metadata for the Consumer",
              "type": "object",
              "additionalProperties": {
                "type": "string"
              }
            }
          }
        },

        # The time the Consumer was created
        string :created

        # The last message delivered from this Consumer
        object :delivered, of: SequenceInfo

        # The highest contiguous acknowledged message
        object :ack_floor, of: SequenceInfo

        # The number of messages pending acknowledgement
        integer :num_ack_pending

        # The number of redeliveries that have been performed
        integer :num_redelivered

        # The number of pull consumers waiting for messages
        integer :num_waiting

        # The number of messages left unconsumed in this Consumer
        integer :num_pending

        object :cluster do
          # The cluster nam
          string :name

          # The server name of the RAFT leade
          string :leader

          # The members of the RAFT cluster
          array :replicas do
            # The server name of the peer
            string :name

            # Indicates if the server is up to date and synchronised
            bool :current

            # Nanoseconds since this peer was last seen
            integer :active

            # Indicates the node is considered offline by the group
            bool :offline

            # How many uncommitted operations this peer is behind the leader
            integer :lag
          end
        end

        # Indicates if any client is connected and receiving messages from a push consumer
        bool :push_bound
      end
    end
  end
end
