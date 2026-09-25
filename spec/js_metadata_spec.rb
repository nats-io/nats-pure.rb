# frozen_string_literal: true

describe "JetStream::Msg metadata" do
  def metadata_for(reply)
    NATS::Msg.new(subject: "foo", reply: reply).metadata
  end

  let(:ts) { 1_700_000_000_123_456_789 }

  it "parses v1 ack subjects" do
    meta = metadata_for("$JS.ACK.stream.consumer.2.10.3.#{ts}.7")

    expect(meta.stream).to eql("stream")
    expect(meta.consumer).to eql("consumer")
    expect(meta.domain).to eql("")
    expect(meta.num_delivered).to eql(2)
    expect(meta.sequence.stream).to eql(10)
    expect(meta.sequence.consumer).to eql(3)
    expect(meta.num_pending).to eql(7)
    expect(meta.timestamp.to_i).to eql(1_700_000_000)
    expect(meta.timestamp.nsec).to eql(123_456_789)
  end

  # nats-server 2.16 sends v2 ack subjects by default (js_ack_fc_v2),
  # with no trailing random token.
  it "parses v2 ack subjects without the trailing token" do
    meta = metadata_for("$JS.ACK.hub.ACCHASH.stream.consumer.2.10.3.#{ts}.7")

    expect(meta.domain).to eql("hub")
    expect(meta.stream).to eql("stream")
    expect(meta.consumer).to eql("consumer")
    expect(meta.num_delivered).to eql(2)
    expect(meta.sequence.stream).to eql(10)
    expect(meta.sequence.consumer).to eql(3)
    expect(meta.num_pending).to eql(7)
  end

  it "parses v2 ack subjects with extra tokens" do
    meta = metadata_for("$JS.ACK.hub.ACCHASH.stream.consumer.2.10.3.#{ts}.7.rand.more")

    expect(meta.domain).to eql("hub")
    expect(meta.stream).to eql("stream")
    expect(meta.num_pending).to eql(7)
  end

  it "maps the v2 no-domain placeholder to an empty domain" do
    meta = metadata_for("$JS.ACK._.ACCHASH.stream.consumer.2.10.3.#{ts}.7")

    expect(meta.domain).to eql("")
  end

  [
    "$JS.ACK.stream.consumer.2.10.3.1",
    "$JS.ACK.hub.stream.consumer.2.10.3.1.7",
    "$JS.NAK.stream.consumer.2.10.3.1.7",
    "$XX.ACK.stream.consumer.2.10.3.1.7",
    # ADR-15: numeric fields that do not parse make it an invalid ack subject.
    "$JS.ACK.stream.consumer.x.10.3.1.7",
    "$JS.ACK.stream.consumer.2.10.3.1.-7",
    "$JS.ACK.hub.ACCHASH.stream.consumer.2.1e3.3.1.7",
    "$JS.ACK.hub.ACCHASH.stream.consumer.2.10.3.1..rand"
  ].each do |reply|
    it "raises NotJSMessage for #{reply}" do
      expect { metadata_for(reply) }.to raise_error(NATS::JetStream::Error::NotJSMessage)
    end
  end
end
