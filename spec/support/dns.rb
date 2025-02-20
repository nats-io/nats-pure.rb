# frozen_string_literal: true

# Update Ruby DNS resolver to point custom hosts to 127.0.0.1

LOCAL_HOSTS = <<~TXT
  127.0.0.1 server-A.clients.nats-service.localhost
  127.0.0.1 server-A.clients.fake-nats-service.localhost
  127.0.0.1 server-A.routes.nats-service.localhost
  127.0.0.1 server-A.routes.fake-nats-service.localhost
TXT

require "resolv-replace"

hosts_path = File.expand_path(File.join(__dir__, "../../tmp/custom_hosts"))
if !File.file?(hosts_path)
  FileUtils.mkdir_p(File.dirname(hosts_path))
  File.write(hosts_path, LOCAL_HOSTS)
end

hosts_resolver = Resolv::Hosts.new(hosts_path)
dns_resolver = Resolv::DNS.new

Resolv::DefaultResolver.replace_resolvers([hosts_resolver, dns_resolver])

# resolve-replace doesn't support modern Ruby TCPSocket signature:
# https://github.com/ruby/resolv-replace/issues/2
class TCPSocket
  def initialize(host, serv, *rest, **kwargs)
    rest[0] = IPSocket.getaddress(rest[0]) if rest[0]
    original_resolv_initialize(IPSocket.getaddress(host), serv, *rest, **kwargs)
  end
end

# Patch Socket to rely on Resolve when getting address info
# Inspired by the original resolve-replace.rb: https://github.com/ruby/resolv-replace/blob/master/lib/resolv-replace.rb
require "socket"

class << Socket
  # :stopdoc:
  alias_method :original_getaddrinfo, :getaddrinfo
  # :startdoc:
  def getaddrinfo(host, *args)
    original_getaddrinfo(Resolv.getaddress(host).to_s, *args)
  rescue Resolv::ResolvError
    original_getaddrinfo(host, *args)
  end
end
