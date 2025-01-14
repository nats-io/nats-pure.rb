# frozen_string_literal: true

RSpec.describe NATS::Parser do
  subject { described_class.new }

  let(:result) { subject.parse(data) }
  let(:message) { result.message }
  let(:leftover) { result.leftover }

  describe "#parse" do
    context "when data contains only a message definition" do
      let(:data) { "PING\r\n" }

      it "returns NATS::Parser::Result" do
        expect(result).to be_a(NATS::Parser::Result)
      end

      it "parses the message" do
        expect(message).to be_a(NATS::Message::Ping)
      end

      it "sets leftover to an empty string" do
        expect(leftover).to eq("")
      end
    end

    context "when data contains a message definition with a leftover" do
      let(:data) { "PING\r\nleftover" }

      it "returns NATS::Parser::Result" do
        expect(result).to be_a(NATS::Parser::Result)
      end

      it "parses the message" do
        expect(message).to be_a(NATS::Message::Ping)
      end

      it "sets leftover" do
        expect(leftover).to eq("leftover")
      end
    end

    context "when data does not contain a message definition" do
      let(:data) { "unknown" }

      it "returns NATS::Parser::Result" do
        expect(result).to be_a(NATS::Parser::Result)
      end

      it "parses the message as Unknow" do
        expect(message).to be_a(NATS::Message::Unknown)
      end

      it "parses the message as Unknow" do
        expect(message).to have_attributes(data: "unknown")
      end

      it "sets leftover to an empty string" do
        expect(leftover).to eq("")
      end
    end
  end

  describe "INFO" do
    context "when message is valid" do
      let(:data) { "INFO {\"server_id\":100}\r\n" }

      it "returns NATS::Message::Info" do
        expect(message).to be_a(NATS::Message::Info)
      end

      it "parses INFO options" do
        expect(message).to have_attributes(options: { "server_id" => 100 })
      end
    end

    context "when message is in lower case" do
      let(:data) { "info {\"server_id\":100}\r\n" }

      it "returns NATS::Message::Info" do
        expect(message).to be_a(NATS::Message::Info)
      end

      it "parses INFO options" do
        expect(message).to have_attributes(options: { "server_id" => 100 })
      end
    end

    context "when message contains additional spaces" do
      let(:data) { "INFO   { \"server_id\": 100 }   \r\n" }

      it "returns NATS::Message::Info" do
        expect(message).to be_a(NATS::Message::Info)
      end

      it "parses INFO options" do
        expect(message).to have_attributes(options: { "server_id" => 100 })
      end
    end

    context "when message does not contain CRLF" do
      let(:data) { "INFO {\"server_id\":100}" }

      it "returns NATS::Message::Unknown" do
        expect(message).to be_a(NATS::Message::Unknown)
      end
    end

    context "when there is no space between INFO and options" do
      let(:data) { "INFO{\"server_id\":100}\r\n" }

      it "returns NATS::Message::Unknown" do
        expect(message).to be_a(NATS::Message::Unknown)
      end
    end

    context "when message does not have options" do
      let(:data) { "INFO\r\n" }

      it "returns NATS::Message::Unknown" do
        expect(message).to be_a(NATS::Message::Unknown)
      end
    end

    context "when message options is not a valid json" do
      let(:data) { "INFO {invalid-json}\r\n" }

      it "raises ServerError" do
        expect { message }.to raise_error(NATS::IO::ServerError)
      end
    end

    context "when message has a preceeding" do
      let(:data) { "message\r\nINFO {\"server_id\":100}\r\n" }

      it "returns NATS::Message::Unknown" do
        expect(message).to be_a(NATS::Message::Unknown)
      end
    end
  end

  describe "MSG" do
    context "when message is valid" do
      let(:data) { "MSG foo 10 bar 100\r\n" }

      it "returns NATS::Message::Msg" do
        expect(message).to be_a(NATS::Message::Msg)
      end

      it "parses MSG params" do
        expect(message).to have_attributes(subject: "foo", sid: 10, reply_to: "bar", bytes: 100)
      end
    end

    context "when message does not contain reply_to" do
      let(:data) { "MSG foo 10 100\r\n" }

      it "returns NATS::Message::Msg" do
        expect(message).to be_a(NATS::Message::Msg)
      end

      it "parses MSG params" do
        expect(message).to have_attributes(subject: "foo", sid: 10, reply_to: nil, bytes: 100)
      end
    end

    context "when message is in lower case" do
      let(:data) { "msg foo 10 bar 100\r\n" }

      it "returns NATS::Message::Msg" do
        expect(message).to be_a(NATS::Message::Msg)
      end

      it "parses MSG params" do
        expect(message).to have_attributes(subject: "foo", sid: 10, reply_to: "bar", bytes: 100)
      end
    end

    context "when message contains additional spaces" do
      let(:data) { "MSG   foo   10   bar   100\r\n" }

      it "returns NATS::Message::Msg" do
        expect(message).to be_a(NATS::Message::Msg)
      end

      it "parses MSG params" do
        expect(message).to have_attributes(subject: "foo", sid: 10, reply_to: "bar", bytes: 100)
      end
    end

    context "when message contains payload" do
      let(:data) { "MSG foo 10 bar 100\r\npayload\r\n" }

      it "returns NATS::Message::Msg" do
        expect(message).to be_a(NATS::Message::Msg)
      end

      it "parses MSG params without payload" do
        expect(message).to have_attributes(subject: "foo", sid: 10, reply_to: "bar", bytes: 100)
      end
    end

    context "when message does not contain CRLF" do
      let(:data) { "MSG foo 10 bar 100" }

      it "returns NATS::Message::Unknown" do
        expect(message).to be_a(NATS::Message::Unknown)
      end
    end

    context "when there is no space between MSG and options" do
      let(:data) { "MSGfoo 10 bar 100\r\n" }

      it "returns NATS::Message::Unknown" do
        expect(message).to be_a(NATS::Message::Unknown)
      end
    end

    context "when message does not contain all params" do
      let(:data) { "MSG foo bar\r\n" }

      it "returns NATS::Message::Unknown" do
        expect(message).to be_a(NATS::Message::Unknown)
      end
    end

    context "when message contain invalid params" do
      let(:data) { "MSG foo bar invalid\r\n" }

      it "returns NATS::Message::Unknown" do
        expect(message).to be_a(NATS::Message::Unknown)
      end
    end

    context "when message has a preceeding" do
      let(:data) { "message\r\nMSG foo 10 bar 100\r\n" }

      it "returns NATS::Message::Unknown" do
        expect(message).to be_a(NATS::Message::Unknown)
      end
    end
  end

  describe "HMSG" do
    context "when message is valid" do
      let(:data) { "HMSG foo 10 bar 30 100\r\n" }

      it "returns NATS::Message::Msg" do
        expect(message).to be_a(NATS::Message::Hmsg)
      end

      it "parses MSG params" do
        expect(message).to have_attributes(
          subject: "foo",
          sid: 10,
          reply_to: "bar",
          header_bytes: 30, 
          total_bytes: 100
        )
      end
    end

    context "when message does not contain reply_to" do
      let(:data) { "HMSG foo 10 30 100\r\n" }

      it "returns NATS::Message::Msg" do
        expect(message).to be_a(NATS::Message::Hmsg)
      end

      it "parses MSG params" do
        expect(message).to have_attributes(
          subject: "foo",
          sid: 10,
          reply_to: nil,
          header_bytes: 30,
          total_bytes: 100
        )
      end
    end

    context "when message is in lower case" do
      let(:data) { "hmsg foo 10 bar 30 100\r\n" }

      it "returns NATS::Message::Msg" do
        expect(message).to be_a(NATS::Message::Hmsg)
      end

      it "parses MSG params" do
        expect(message).to have_attributes(
          subject: "foo",
          sid: 10,
          reply_to: "bar",
          header_bytes: 30, 
          total_bytes: 100
        )
      end
    end

    context "when message contains additional spaces" do
      let(:data) { "HMSG   foo   10   bar   30   100\r\n" }

      it "returns NATS::Message::Msg" do
        expect(message).to be_a(NATS::Message::Hmsg)
      end

      it "parses MSG params" do
        expect(message).to have_attributes(
          subject: "foo",
          sid: 10,
          reply_to: "bar",
          header_bytes: 30, 
          total_bytes: 100
        )
      end
    end

    context "when message contains payload" do
      let(:data) { "HMSG foo 10 bar 30 100\r\npayload\r\n" }

      it "returns NATS::Message::Msg" do
        expect(message).to be_a(NATS::Message::Hmsg)
      end

      it "parses MSG params" do
        expect(message).to have_attributes(
          subject: "foo",
          sid: 10,
          reply_to: "bar",
          header_bytes: 30, 
          total_bytes: 100,
          payload: ""
        )
      end
    end

    context "when message does not contain CRLF" do
      let(:data) { "HMSG foo 10 bar 30 100" }

      it "returns NATS::Message::Unknown" do
        expect(message).to be_a(NATS::Message::Unknown)
      end
    end

    context "when there is no space between MSG and options" do
      let(:data) { "HMSGfoo 10 bar 30 100\r\n" }

      it "returns NATS::Message::Unknown" do
        expect(message).to be_a(NATS::Message::Unknown)
      end
    end

    context "when message does not contain all params" do
      let(:data) { "HMSG foo bar\r\n" }

      it "returns NATS::Message::Unknown" do
        expect(message).to be_a(NATS::Message::Unknown)
      end
    end

    context "when message contain invalid params" do
      let(:data) { "HMSG foo 10 bar invalid invalid\r\n" }

      it "returns NATS::Message::Unknown" do
        expect(message).to be_a(NATS::Message::Unknown)
      end
    end

    context "when message has a preceeding" do
      let(:data) { "message\r\nHMSG foo 10 bar 30 100\r\n" }

      it "returns NATS::Message::Unknown" do
        expect(message).to be_a(NATS::Message::Unknown)
      end
    end
  end

  describe "PING" do
    context "when message is valid" do
      let(:data) { "PING\r\n" }

      it "returns NATS::Message::Ping" do
        expect(message).to be_a(NATS::Message::Ping)
      end
    end

    context "when message is in lower case" do
      let(:data) { "ping\r\n" }

      it "returns NATS::Message::Ping" do
        expect(message).to be_a(NATS::Message::Ping)
      end
    end

    context "when message contains additional spaces" do
      let(:data) { "PING   \r\n" }

      it "returns NATS::Message::Ping" do
        expect(message).to be_a(NATS::Message::Ping)
      end
    end

    context "when message does not contain CRLF" do
      let(:data) { "PING" }

      it "returns NATS::Message::Unknown" do
        expect(message).to be_a(NATS::Message::Unknown)
      end
    end

    context "when message has a preceeding" do
      let(:data) { "message\r\nPING\r\n" }

      it "returns NATS::Message::Unknown" do
        expect(message).to be_a(NATS::Message::Unknown)
      end
    end
  end

  describe "PONG" do
    context "when message is valid" do
      let(:data) { "PONG\r\n" }

      it "returns NATS::Message::Pong" do
        expect(message).to be_a(NATS::Message::Pong)
      end
    end

    context "when message is in lower case" do
      let(:data) { "pong\r\n" }

      it "returns NATS::Message::Pong" do
        expect(message).to be_a(NATS::Message::Pong)
      end
    end

    context "when message contains additional spaces" do
      let(:data) { "PONG   \r\n" }

      it "returns NATS::Message::Pong" do
        expect(message).to be_a(NATS::Message::Pong)
      end
    end

    context "when message does not contain CRLF" do
      let(:data) { "PONG" }

      it "returns NATS::Message::Unknown" do
        expect(message).to be_a(NATS::Message::Unknown)
      end
    end

    context "when message has a preceeding" do
      let(:data) { "message\r\nPONG\r\n" }

      it "returns NATS::Message::Unknown" do
        expect(message).to be_a(NATS::Message::Unknown)
      end
    end
  end

  describe "OK" do
    context "when message is valid" do
      let(:data) { "+OK\r\n" }

      it "returns NATS::Message::Ok" do
        expect(message).to be_a(NATS::Message::Ok)
      end
    end

    context "when message is in lower case" do
      let(:data) { "+ok\r\n" }

      it "returns NATS::Message::Ok" do
        expect(message).to be_a(NATS::Message::Ok)
      end
    end

    context "when message contains additional spaces" do
      let(:data) { "+OK   \r\n" }

      it "returns NATS::Message::Ok" do
        expect(message).to be_a(NATS::Message::Ok)
      end
    end

    context "when message does not contain CRLF" do
      let(:data) { "OK" }

      it "returns NATS::Message::Unknown" do
        expect(message).to be_a(NATS::Message::Unknown)
      end
    end

    context "when message does not have + before OK" do
      let(:data) { "OK\r\n" }

      it "returns NATS::Message::Unknown" do
        expect(message).to be_a(NATS::Message::Unknown)
      end
    end

    context "when message has a preceeding" do
      let(:data) { "message\r\n+OK\r\n" }

      it "returns NATS::Message::Unknown" do
        expect(message).to be_a(NATS::Message::Unknown)
      end
    end
  end

  describe "ERR" do
    context "when message is valid" do
      let(:data) { "-ERR 'Error'\r\n" }

      it "returns NATS::Message::Err" do
        expect(message).to be_a(NATS::Message::Err)
      end

      it "parses ERR options" do
        expect(message).to have_attributes(message: "Error")
      end
    end

    context "when message contains additional spaces" do
      let(:data) { "-ERR   'Error'\r\n" }

      it "returns NATS::Message::Err" do
        expect(message).to be_a(NATS::Message::Err)
      end

      it "parses ERR options" do
        expect(message).to have_attributes(message: "Error")
      end
    end

    context "when message does not have an error message" do
      let(:data) { "-ERR \r\n" }

      it "returns NATS::Message::Err" do
        expect(message).to be_a(NATS::Message::Err)
      end

      it "leaves params empty" do
        expect(message).to have_attributes(message: nil)
      end
    end

    context "when message does not contain CRLF" do
      let(:data) { "-ERR 'Error'" }

      it "returns NATS::Message::Unknown" do
        expect(message).to be_a(NATS::Message::Unknown)
      end
    end

    context "when there is no space between -ERR and options" do
      let(:data) { "-ERR'Error'\r\n" }

      it "returns NATS::Message::Unknown" do
        expect(message).to be_a(NATS::Message::Unknown)
      end
    end

    context "when message options does not have - before ERR" do
      let(:data) { "ERR 'Error'\r\n" }

      it "returns NATS::Message::Unknown" do
        expect(message).to be_a(NATS::Message::Unknown)
      end
    end

    context "when message is in lower case" do
      let(:data) { "-err 'Error'\r\n" }

      it "returns NATS::Message::Unknown" do
        expect(message).to be_a(NATS::Message::Unknown)
      end
    end

    context "when message has a preceeding" do
      let(:data) { "message\r\n-ERR 'Error'\r\n" }

      it "returns NATS::Message::Unknown" do
        expect(message).to be_a(NATS::Message::Unknown)
      end
    end
  end
end
