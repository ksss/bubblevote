#! /usr/bin/env ruby

require 'redis'
require_relative 'app'
require_relative 'app_config'
$r = Redis.new(:host => RedisHost, :port => RedisPort)

p Time.parse((Date.today + 7).to_s).to_i
p Time.parse(Date.today.next.to_s).to_i
