# frozen_string_literal: true

# Copyright 2021 The NATS Authors
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
# http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#

module NATS
  class JetStream
    module Msg
      module Ack
        # rubocop:disable Naming/ConstantName

        # Ack types
        Ack = "+ACK"
        Nak = "-NAK"
        Progress = "+WPI"
        Term = "+TERM"

        Empty = ""
        DotSep = "."
        NoDomainName = "_"

        # Position
        Prefix0 = "$JS"
        Prefix1 = "ACK"
        Domain = 2
        AccHash = 3
        Stream = 4
        Consumer = 5
        NumDelivered = 6
        StreamSeq = 7
        ConsumerSeq = 8
        Timestamp = 9
        NumPending = 10

        # Subject without domain:
        # $JS.ACK.<stream>.<consumer>.<delivered>.<sseq>.<cseq>.<tm>.<pending>
        #
        V1TokenCounts = 9

        # Subject with domain:
        # $JS.ACK.<domain>.<account hash>.<stream>.<consumer>.<delivered>.<sseq>.<cseq>.<tm>.<pending>.<a token with a random value>
        #
        V2TokenCounts = 12

        SequencePair = Struct.new(:stream, :consumer)

        # rubocop:enable Naming/ConstantName
      end
      private_constant :Ack
    end
  end
end
