require 'json'
require 'net/http'

class ZabbixApi
  class Client

    attr :options

    def id
      rand(100000)
    end

    def api_version
      @version ||= api_request(:method => "apiinfo.version", :params => {})
    end

    def auth
      api_request(
        :method => 'user.authenticate', 
        :params => {
          :user      => @options[:user],
          :password  => @options[:password],
        }
      )
    end

    def initialize(options = {})
      @options = options
      unless ENV['http_proxy'].nil?
        @proxy_uri = URI.parse(ENV['http_proxy'])
        @proxy_host = @proxy_uri.host
        @proxy_port = @proxy_uri.port
        @proxy_user, @proxy_pass = @proxy_uri.userinfo.split(/:/) if @proxy_uri.userinfo
      end
      @auth_hash = auth
    end

    def message_json(body)
      message = {
        :method  => body[:method],
        :params  => body[:params],
        :auth    => @auth_hash,
        :id      => id,
        :jsonrpc => '2.0'
      }
      JSON.generate(message)
    end

    def http_request(body)
      uri = URI.parse(@options[:url])

      unless @proxy_uri.nil?
        http = Net::HTTP.Proxy(@proxy_host, @proxy_port, @proxy_user, @proxy_pass).new(uri.host, uri.port)
        if uri.port == 443
          http.use_ssl = true
          http.verify_mode = OpenSSL::SSL::VERIFY_NONE
        end
      else
        http = Net::HTTP.new(uri.host, uri.port)
        if uri.port == 443
          http.use_ssl = true
          http.verify_mode = OpenSSL::SSL::VERIFY_NONE
        end
      end
      request = Net::HTTP::Post.new(uri.request_uri)
      request.basic_auth @options[:http_user], @options[:http_password] if @options[:http_user]
      request.add_field('Content-Type', 'application/json-rpc')
      request.body = body
      response = http.request(request)
      raise "HTTP Error: #{response.code} on #{@options[:url]}" unless response.code == "200"
      puts "[DEBUG] Get answer: #{response.body}" if @options[:debug]
      response.body
    end

    def _request(body)
      puts "[DEBUG] Send request: #{body}" if @options[:debug]
      result = JSON.parse(http_request(body))
      raise "Server answer API error:\n #{JSON.pretty_unparse(result['error'])}\n on request:\n #{JSON.pretty_unparse(JSON.parse(body))}" if result['error']
      result['result']
    end

    def api_request(body)
      _request message_json(body)
    end

  end
end
