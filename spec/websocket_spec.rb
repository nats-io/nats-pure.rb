# frozen_string_literal: true

require "nats/io/websocket"

describe NATS::IO::WebSocket do
  subject(:ws) { described_class.new(uri: URI.parse("ws://127.0.0.1:8080")) }

  let(:sockets) { UNIXSocket.pair }
  let(:client_io) { sockets[0] }
  let(:server_io) { sockets[1] }

  before do
    ws.socket = client_io
    ws.instance_variable_set(:@frame, ::WebSocket::Frame::Incoming::Client.new)
  end

  after { sockets.each { |s| s.close unless s.closed? } }

  def server_frame(data)
    ::WebSocket::Frame::Outgoing::Server.new(data: data, type: :binary, version: 13).to_s
  end

  describe "#read after #read_line" do
    it "returns bytes decoded by read_line beyond the last consumed line" do
      server_io.write(server_frame("PONG\r\nPING\r\n"))

      expect(ws.read_line(1)).to eq("PONG\r\n")

      server_io.write(server_frame("MSG foo 1 0\r\n\r\n"))

      # A short read returning only the buffered bytes is fine; nothing
      # may be dropped and order must be preserved.
      expect(ws.read(NATS::IO::MAX_SOCKET_READ_BYTES, 1)).to eq("PING\r\n")
      expect(ws.read(NATS::IO::MAX_SOCKET_READ_BYTES, 1)).to eq("MSG foo 1 0\r\n\r\n")
    end

    it "reads from the wire when read_line consumed the whole buffer" do
      server_io.write(server_frame("PONG\r\n"))

      expect(ws.read_line(1)).to eq("PONG\r\n")

      server_io.write(server_frame("PING\r\n"))
      expect(ws.read(NATS::IO::MAX_SOCKET_READ_BYTES, 1)).to eq("PING\r\n")
    end
  end
end
