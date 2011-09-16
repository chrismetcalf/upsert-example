#!/usr/bin/env ruby
# Given a "delta" file, "upserts" the values into a dataset using the new beta API

require 'rubygems'

# Load helper libraries
['config', 'socrata'].each do |lib|
  require File.join(File.dirname(__FILE__), "../lib/#{lib}")
end

config = ConfigCache.instance

# Read our data file
records = []
headers = nil
ARGF.each do |line|
  data = line.split(/\t/).collect {|d| d.strip }

  if headers.nil?
    # Read the first line as the header
    headers = data
  else
    # Reading data
    record = {}
    data.each_index do |i|
      record[headers[i]] = data[i]
    end

    records << record
  end
end

# Use the publishing workflow (http://dev.socrata.com/publisher/workflow)
draft_copy = Socrata.instance.post("/views/#{config[:uid]}/publication.json?method=copy")
if draft_copy["id"].nil?
  Logger.critical "It doesn't look like we got back a valid draft copy: #{draft_copy.inspect}"
  exit 1
else 
  Logger.debug "Created draft copy with UID #{draft_copy["uid"]}"
end

# Upsert on the draft copy
results = Socrata.instance.post("/id/#{draft_copy["id"]}.json", {:body => records.to_json})
if results["Errors"] != 0
  Logger.critical "Errors were encountered during the update: #{results.inspect}}"
  Logger.debug "Submission: #{records.inspect}}"
  exit 1
else
  Logger.debug "Update was succesful: #{results.collect{ |k,v| "#{k}: #{v}"}.join ", "}"
end

# Publish the resulting updates
results = Socrata.instance.post("/views/#{draft_copy["id"]}/publication.json")
if results["id"] != config[:uid]
  Logger.critical "Something went wrong in publication, UIDs don't match: #{results}"
else
  Logger.debug "Publication was successful!"
end

