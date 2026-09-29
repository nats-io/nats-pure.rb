# frozen_string_literal: true

# Copyright 2026 The NATS Authors
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
    # Header names headers that publishers set for JetStream, and that
    # JetStream sets on the messages that it stores, republishes or returns
    # from direct gets.
    #
    # @example Publish unless the subject got another message since sequence 10
    #   js.publish("orders.1", data, header: {
    #     NATS::JetStream::Header::EXPECTED_LAST_SUBJECT_SEQUENCE => "10"
    #   })
    module Header
      # Id of the message; the stream stores a message only once for each
      # id within its duplicate_window.
      MSG_ID = "Nats-Msg-Id"
      # Name of the stream that has to store the message.
      EXPECTED_STREAM = "Nats-Expected-Stream"
      # Sequence of the last message that the stream has to have.
      EXPECTED_LAST_SEQUENCE = "Nats-Expected-Last-Sequence"
      # Sequence of the last message that the subject has to have.
      EXPECTED_LAST_SUBJECT_SEQUENCE = "Nats-Expected-Last-Subject-Sequence"
      # Subject for EXPECTED_LAST_SUBJECT_SEQUENCE to check instead of the
      # subject of the message (requires nats-server v2.11.0).
      EXPECTED_LAST_SUBJECT_SEQUENCE_SUBJECT = "Nats-Expected-Last-Subject-Sequence-Subject"
      # Id of the last message that the stream has to have.
      EXPECTED_LAST_MSG_ID = "Nats-Expected-Last-Msg-Id"
      # "sub" to remove the earlier messages of the subject, or "all" those
      # of the stream, as the message is stored.
      ROLLUP = "Nats-Rollup"

      # TTL of the message: seconds, a Go duration such as "1h", or "never"
      # (requires nats-server v2.11.0).
      MSG_TTL = "Nats-TTL"
      # Set by the server on the marker it leaves when the last message of a
      # subject expires, to "MaxAge" (requires nats-server v2.11.0).
      MARKER_REASON = "Nats-Marker-Reason"

      # Set by the server on the messages that it republishes or returns
      # from direct gets, to the stream of the message.
      STREAM = "Nats-Stream"
      # Set with STREAM, to the subject of the message.
      SUBJECT = "Nats-Subject"
      # Set with STREAM, to the sequence of the message in the stream.
      SEQUENCE = "Nats-Sequence"
      # Set with STREAM, to when the stream stored the message.
      TIME_STAMP = "Nats-Time-Stamp"
      # Set by the server on the messages that it republishes, to the
      # sequence of the message before on the same subject, or "0".
      LAST_SEQUENCE = "Nats-Last-Sequence"
      # Set by the server on the messages that a stream sources, starting
      # with the name of the stream they come from and their sequence there.
      STREAM_SOURCE = "Nats-Stream-Source"

      # Id of an atomic batch, of up to 64 characters
      # (requires nats-server v2.12.0).
      BATCH_ID = "Nats-Batch-Id"
      # Sequence of the message in its atomic batch, from 1.
      BATCH_SEQUENCE = "Nats-Batch-Sequence"
      # "1" to commit an atomic batch with the message, or, since nats-server
      # v2.14.0, "eob" to commit it without storing the message.
      BATCH_COMMIT = "Nats-Batch-Commit"

      # Makes the message a schedule: "@at" and an RFC 3339 time (requires
      # nats-server v2.12.0), or "@every" and a Go duration, a cron
      # expression with seconds, or "@hourly", "@daily" (or "@midnight"),
      # "@weekly", "@monthly" or "@yearly" (or "@annually")
      # (requires nats-server v2.14.0).
      SCHEDULE = "Nats-Schedule"
      # Subject that the schedule publishes its messages to.
      SCHEDULE_TARGET = "Nats-Schedule-Target"
      # Subject whose last message the schedule publishes, instead of its
      # own (requires nats-server v2.14.0).
      SCHEDULE_SOURCE = "Nats-Schedule-Source"
      # MSG_TTL of the messages that the schedule publishes.
      SCHEDULE_TTL = "Nats-Schedule-TTL"
      # Time zone of a cron schedule, such as "Europe/Warsaw"
      # (requires nats-server v2.14.0).
      SCHEDULE_TIME_ZONE = "Nats-Schedule-Time-Zone"
      # "sub" to roll up the target with each message that the schedule
      # publishes (requires nats-server v2.14.0).
      SCHEDULE_ROLLUP = "Nats-Schedule-Rollup"
      # Set by the server on the messages that a schedule publishes, to the
      # subject of the schedule. With SCHEDULE_NEXT "purge", names the
      # schedule to cancel.
      SCHEDULER = "Nats-Scheduler"
      # Set by the server on the messages that a schedule publishes, to when
      # the schedule fires next, or to "purge" when it does not. Published
      # as "purge", cancels the SCHEDULER schedule.
      SCHEDULE_NEXT = "Nats-Schedule-Next"

      # The API level that the server has to have for a JetStream API
      # request, a pull, a direct get, or a message of an atomic batch
      # (since nats-server v2.12.1) or a fast batch, which it otherwise
      # refuses with status 412, and err_code 10185 for API requests and
      # batches (requires nats-server v2.12.0). The server stores batch
      # messages without it, and plain publishes with it, as sent.
      REQUIRED_API_LEVEL = "Nats-Required-Api-Level"
    end
  end
end
