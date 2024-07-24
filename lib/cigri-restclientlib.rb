#!/usr/bin/ruby
#
# This library handles the REST client calls
#

require 'cigri-logger'
require 'cigri-conflib'
$VERBOSE=false
  require 'rest-client'
#$VERBOSE=true
require 'json'
require 'yaml'
require 'uri'

CONF=Cigri.conf unless defined? CONF
RESTCLIENTLIBLOGGER = Cigri::Logger.new('RESTCLIENTLIB', CONF.get('LOG_FILE'))

module Cigri


  # Restclient interface to (partially) HATEOAS REST API
  class RestSession
    attr_reader :content_type, :base_uri

    # Connect to a restfull API
    def initialize(description,content_type)
      options={}
      auth_type = description["api_auth_type"]
      base_uri = description["api_url"]

      options[:proxy] = nil

      if CONF.exists?('REST_QUERIES_TIMEOUT')
        options[:timeout] = CONF.get('REST_QUERIES_TIMEOUT').to_i
      else
        options[:timeout] = 30
      end

      if CONF.exists?('REST_CLIENT_VERIFY_SSL')
        options[:verify_ssl] = CONF.get('REST_CLIENT_VERIFY_SSL').to_i
      else
        options[:verify_ssl] = false
      end
 
      if auth_type == "cert"
        if CONF.exists?('REST_CLIENT_CERTIFICATE_FILE') &&
           CONF.exists?('REST_CLIENT_KEY_FILE')
          options[:ssl_client_cert] = OpenSSL::X509::Certificate.new(
                                        File.read(CONF.get('REST_CLIENT_CERTIFICATE_FILE')))
          options[:ssl_client_key] = OpenSSL::PKey::RSA.new(
                                        File.read(CONF.get('REST_CLIENT_KEY_FILE')))
        else
          raise Cigri::Error, "Authentification type 'cert' for cluster #{description['name']} requires at least a certificate and a key in the configuration file."
        end
        if CONF.exists?('REST_CLIENT_CA_FILE')
          options[:ssl_ca_file] = CONF.get('REST_CLIENT_CA_FILE')
        end
     elsif auth_type == "password"
        # if (user.nil? || user == "")
        #   options[:user]=user
        #   options[:password]=password
        # end
      elsif auth_type == "none"
        nil
      elsif auth_type == "jwt"
        if description["batch"] != "oar3"
          msg = "Authentification type '" + auth_type.to_s + "' only available for oar3 batch system"
          raise Cigri::Error, msg
        end
      else
        msg = "Authentification type '" + auth_type.to_s + "' not supported"
        raise Cigri::Error, msg
      end
      
      @api = RestClient::Resource.new(base_uri, options)
      @content_type=content_type
      @base_uri=URI.parse(base_uri)
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
      end
      resource
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
    #
    # == Parameters
    # - uri: the uri of the resource to get
    # - header: an optional hash to pass as headers options
    # - opts: set :raw => true to get a raw content without parsing
    def get(uri,header={},opts={:raw => false})
      uri = rel_uri(uri)
      header[:accept] = @content_type
      begin
        if opts[:raw]
          @api[uri].get(header)
        else
          parse(@api[uri].get(header))
        end
      rescue RestClient::RequestTimeout
        message = "GET #{base_uri}#{uri}: REST query timeouted!"
        RESTCLIENTLIBLOGGER.error(message)
        raise Cigri::ClusterAPITimeout, message
      rescue RestClient::Exception => e
        if  e.http_code == 401
          raise Cigri::ClusterAPIPermissionDenied, "#{e.http_code} error in GET for #{uri}:\n #{e.response.body}"
        elsif  e.http_code == 400
          raise Cigri::ClusterAPIBadRequest, "#{e.http_code} error in GET for #{uri}:\n #{e.response.body}"
        elsif  e.http_code == 403
          raise Cigri::ClusterAPIForbidden, "#{e.http_code} error in GET for #{uri}:\n #{e.response.body}"
        elsif  e.http_code == 500
          raise Cigri::ClusterAPIServerError, "#{e.http_code} error in GET for #{uri}:\n #{e.response.body}"
        elsif  e.http_code == 404
          raise Cigri::ClusterAPINotFound, "#{e.http_code} error in GET for #{uri}:\n #{e.response.body}"
        elsif not e.http_code
          raise Cigri::Error, "Unknown error in GET for #{uri}:\n #{e.inspect}"
        else
          raise Cigri::Error, "#{e.http_code} error in GET for #{uri}:\n #{e.response.body if e.response}"
        end
      end
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
    def get_collection(uri,header={})
      res=get(uri,header)
      collection=res["items"]
      next_link=get_link_by_rel(res,"next")
      while next_link do
        res=get(next_link,header)
        collection.concat(res["items"])
        next_link=get_link_by_rel(res,"next")
      end
      collection
    end

    def post(uri, resource, header={})
      uri = rel_uri(uri)
      header[:content_type]=@content_type
      begin
        parse(@api[uri].post(convert(resource), header))
      rescue RestClient::RequestTimeout
        message = "POST #{base_uri}#{uri}: REST query timeouted!"
        RESTCLIENTLIBLOGGER.error(message)
        raise Cigri::ClusterAPITimeoutPOST, message
      rescue RestClient::Exception => e
        if  e.http_code == 401
          raise Cigri::ClusterAPIPermissionDenied, "#{e.http_code} error in POST for #{uri}:\n #{e.response.body}"
        elsif  e.http_code == 400
          raise Cigri::ClusterAPIBadRequest, "#{e.http_code} error in POST for #{uri}:\n #{e.response.body}"
        elsif  e.http_code == 403
          raise Cigri::ClusterAPIForbidden, "#{e.http_code} error in POST for #{uri}:\n #{e.response.body}"
        elsif  e.http_code == 413
          raise Cigri::ClusterAPITooLarge, "#{e.http_code} error in POST for #{uri}:\n #{e.response.body}"
        elsif  e.http_code == 500
          raise Cigri::ClusterAPIServerError, "#{e.http_code} error in POST for #{uri}:\n #{e.response.body}"
        elsif e.response.nil?
          raise e, "Error in POST for #{uri}: empty response"
        else
          raise Cigri::Error, "#{e.http_code} error in POST for #{uri}:\n #{e.response.body}"
        end
      end
    end

    # Delete a resource
    def delete(uri,header={})
      uri = rel_uri(uri)
      header[:content_type]=@content_type
      begin # Rest error handling
        parse(@api[uri].delete(header))
      rescue RestClient::RequestTimeout
        message = "DELETE #{base_uri}#{uri}: REST query timeouted!"
        RESTCLIENTLIBLOGGER.error(message)
        raise Cigri::ClusterAPITimeout, message
      rescue RestClient::Exception => e
        body=""
        if e.response.nil?
          body="No response"
        else
          body=e.response.body
        end
        if  e.http_code == 401
          raise Cigri::ClusterAPIPermissionDenied, "#{e.http_code} error in DELETE for #{uri}:\n #{body}"  
        elsif  e.http_code == 400
          raise Cigri::ClusterAPIBadRequest, "#{e.http_code} error in DELETE for #{uri}:\n #{e.response.body}"
        elsif  e.http_code == 403
          raise Cigri::ClusterAPIForbidden, "#{e.http_code} error in DELETE for #{uri}:\n #{body}"
        elsif  e.http_code == 404
          raise Cigri::ClusterAPINotFound, "#{e.http_code} error in DELETE for #{uri}:\n #{body}"
        elsif  e.http_code == 500
          raise Cigri::ClusterAPIServerError, "#{e.http_code} error in DELETE for #{uri}:\n #{body}"
        else
          raise Cigri::Error, "#{e.http_code} error in DELETE for #{uri}:\n #{body}"
        end
      end
    end

  end

end
