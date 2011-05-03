#!/usr/bin/ruby -w
#
# Cigri cluster library. This library gives methods to access
# to the local resource manager of the clusters. It is based on
# REST calls.
#
# == Example:
#  cluster=Cigri::Cluster.new(1)
#  cluster.get_resources.each do |resource|
#    puts resource['id']
#  end

require 'cigri-logger'
require 'cigri-conflib'
require 'restfully'
#require 'pp'
#require 'cigri-iolib'

module Cigri
  ##
  # Meta class for REST Clusters
  # This class defines the interface for cluster objects.
  ##
  class RestCluster
    def initialize(cluster_id)
      # To get into the iolib:
      options={}
      options[:base_uri]="http://localhost/oarapi-priv/"
      options[:username]="kameleon"
      options[:password]="kameleon"
      #
      @api=Restfully::Session.new(options).root
    end

    # Get the resources
    def get_resources
      raise "Method must be overridden"
    end

    # Get the running jobs
    def get_jobs
      raise "Method must be overridden"
    end
    
    # Submit the given job
    def submit_job(job)
      raise "Method must be overridden"
    end
  end


  ##
  # Cluster object factory
  # This class allows us to create cluster objects of the 
  # type given by the "batch" field.
  # 
  # == Example: 
  #  cluster=Cigri::Cluster.new(6)
  #  Assuming the cluster which id is 6 is of the type oar2_5, 
  #  this will return a OarCluster object.
  ##
  class Cluster 



   ##
   # Oar REST API methods definitions.
   # Check the RestCluster class for definitions
   ##
   class OarCluster < RestCluster

     def get_resources
       @api.resources
     end 
 
     def get_jobs
       @api.jobs
     end 

     def submit_job(job)
       raise "not yet implemented"      
     end
   end



 
   ##
   # g5k REST API methods definitions
   # Check the RestCluster class for definitions
   ##
   class G5kCluster < RestCluster

     def get_resources
       raise "not yet implemented"      
     end 

     def submit_job(job)
       raise "not yet implemented"      
     end
   end

   
   ##
   # Switch to create objects of the correct type
   ##
   def Cluster::new(cluster_id)
     # To get from iolib
     type="oar2_5"
     classe = 
       case type
         when /oar2_5/
           OarCluster
         when /g5k/
           G5kCluster
       end
     classe::new(type)
   end

  end

end
