#!/usr/bin/ruby -w
#
# This library handles the REST client calls
#

require 'cigri-logger'
require 'cigri-conflib'
$VERBOSE=false
  require 'rest_client'
$VERBOSE=true
require 'json'
require 'yaml'
require 'uri'
require 'timeout'

CONF=Cigri.conf unless defined? CONF
RESTCLIENTLIBLOGGER = Cigri::Logger.new('RESTCLIENTLIB', CONF.get('LOG_FILE'))

module Cigri


  # Restclient interface to (partially) HATEOAS REST API
  class RestSession
    attr_reader :content_type, :base_uri

    # Connect to a restfull API
    def initialize(base_uri,user,password,content_type)
      if (user.nil? || user == "")
        @api = RestClient::Resource.new(base_uri)
      else 
        @api = RestClient::Resource.new(base_uri, :user => user, :password => password)
      end
      @content_type=content_type
      @base_uri=URI.parse(base_uri)
      if CONF.exists?('REST_QUERIES_TIMEOUT')
        @timeout=CONF.get('REST_QUERIES_TIMEOUT').to_i
      else
        @timeout=30
      end
    end
  
    # Converts the given uri, to something relative
    # to the base of the API
    def rel_uri(uri)
      raise Cigri::Error, "uri shouldn't be nil" if uri.nil?
      abs_uri=@base_uri.merge(uri).to_s
      target_uri=URI.parse(abs_uri).to_s
      @base_uri.route_to(target_uri).to_s
    end

    # Parse a rest resource depending on its content_type
    def parse(resource)
      if (resource.headers[:content_type] =~ /application.*json.*/)
        return JSON.parse(resource)
      elsif (resource.headers[:content_type] =~ /text.*yaml.*/)
        return YAML.parse(resource)
      else
        raise Cigri::Error, "Unsupported content_type: #{resource.headers[:content_type]}"
      end
    end

    # Convert a rest resource to the current content_type
    def convert(resource)
      if (@content_type =~ /application.*json.*/)
        return resource.to_json
      elsif (@content_type =~ /text.*yaml.*/)
        return resource.to_yaml
      else
        raise Cigri::Error, "Unsupported content_type: #{@content_type}"
      end
    end

    # Get a rest resource
    def get(uri)
      uri=rel_uri(uri)
      begin # Timeout error handling
        Timeout::timeout(@timeout) {
          begin # Rest error handling
            parse(@api[uri].get(:accept => @content_type))
          rescue => e # Rest error
            if e.respond_to?('http_code')
              raise Cigri::Error, "#{e.http_code} error in get for #{uri} :\n #{e.response.body}"
            else
              raise Cigri::Error, "Parse error: #{e.inspect}"
            end
          end # rescue (Rest error)
        } 
      rescue Timeout::Error # Timeouted
        message="GET #{base_uri}#{uri} : REST query timeouted!"
        RESTCLIENTLIBLOGGER.warn(message)
        raise Timeout::Error, message
      end # rescue (timeout)
    end

    # Get a link by relation or nil if not found
    def get_link_by_rel(resource,rel)
      if defined? resource["links"]
        resource["links"].each do |link|
          return link["href"] if link["rel"] == rel
        end
        return nil
      end
    end

    # Get a collection
    # A collection is an "items" array, and may be paginated
    def get_collection(uri)
      res=get(uri)
      collection=res["items"]
      next_link=get_link_by_rel(res,"next")
      while next_link do
        res=get(next_link)
        collection.concat(res["items"])
        next_link=get_link_by_rel(res,"next")
      end
      collection
    end

    # Post a new resource
    def post(uri,resource)
      uri=rel_uri(uri)
      begin # Timeout error handling
        Timeout::timeout(@timeout) {
          begin # Rest error handling
            parse(@api[uri].post(convert(resource), :content_type => @content_type))
          rescue => e
            if e.respond_to?('http_code')
              raise Cigri::Error, "#{e.http_code} error in post #{uri} :\n #{e.response.body}"
            else
              raise Cigri::Error, "Parse error: #{e.inspect}"
            end
          end # rescue (rest error)
        }
      rescue Timeout::Error # Timeouted
        message="POST #{base_uri}#{uri} : REST query timeouted!"
        RESTCLIENTLIBLOGGER.warn(message)
        raise Timeout::Error, message
      end # rescue (timeout)
    end

    # Delete a resource
    def delete(uri)
      uri=rel_uri(uri)
      begin # Timeout error handling
        Timeout::timeout(@timeout) {
          begin # Rest error handling
            parse(@api[uri].delete(:content_type => @content_type))
          rescue => e
             if e.respond_to?('http_code')
              raise Cigri::Error, "#{e.http_code} error in post #{uri} :\n #{e.response.body}"
            else
              raise Cigri::Error, "Parse error: #{e.inspect}"
            end
          end # rescue (rest error)
        }
      rescue Timeout::Error # Timeouted
        message="DELETE #{base_uri}#{uri} : REST query timeouted!"
        RESTCLIENTLIBLOGGER.warn(message)
        raise Timeout::Error, message
      end # rescue (timeout)
    end

  end

end
