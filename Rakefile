require 'redis'
require_relative 'app_config'
$r = Redis.new(:host => RedisHost, :port => RedisPort)

task :default => [:bundle]

desc "exec `bundle install`"
task :bundle do
  sh %{bundle install}
end

desc "delete all redis keys"
task "redis-flushall" do
  $r.flushall
end

desc "delete for all vote data"
task "redis-delete-vote" do
  $r.keys.each { |key|
    if key =~ /voted|votes|urls/
      $r.del key
    end
  }
end