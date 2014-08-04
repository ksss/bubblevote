# TODO
# web views
# save title for url
#   web版どうする
# recent機能
#   最後にうpされたところから7日で消えるカウンター
# test
# rake

require 'sinatra'
require 'redis'
require 'json'
require 'oauth'
require 'oauth2'
require 'net/http'
require 'uri'
require_relative 'consumer'
require_relative 'app_config'
require_relative 'html'

set :erb, :format => :html5
set :sessions, true
enable :sessions

before do
  $r = Redis.new(:host => RedisHost, :port => RedisPort) unless $r
  $user = auth_user(request.cookies['auth'])
  $today = Date.today.to_s
  $ts = Time.parse($today).to_i
end

get '/' do
  HTML.page(AppName) {
    HTML.div(:class => 'ranking') {
      h2(:class => 'title'){"#{$today}"} +
      day_ranking_to_html
    } +
    HTML.div(:class => 'ranking') {
      h2(:class => 'title'){"Total Ranking"} +
      total_ranking_to_html
    }
  }
end

get '/logout' do
  auth = request.cookies["auth"]
  if auth
    $r.del("auth:#{auth}")
    response.delete_cookie("auth")
  end
  redirect '/'
end

post '/votes/:url' do
  redirect '/' unless $user
  url = params[:url]
end

get '/oauth/:provider' do
  provider = params[:provider]
  
  consumer = Consumer.new(provider)

  case provider
  when 'twitter'
    request_token = consumer.get_request_token :oauth_callback => consumer.call_back

    session[:request_token] = request_token.token
    session[:request_token_secret] = request_token.secret
    url = request_token.authorize_url

  when 'facebook'
    url = consumer.auth_code.authorize_url :redirect_uri => consumer.call_back
  end

  redirect url
end

get '/oauth_callback/:provider' do
  provider = params[:provider]

  consumer = Consumer.new(provider)

  case provider
  when 'twitter'
    request_token = OAuth::RequestToken.new(
      consumer,
      session[:request_token],
      session[:request_token_secreta])
  
    access_token = request_token.get_access_token(
      {},
      :oauth_verifier => params[:oauth_verifier])
  
    session[:request_token] = nil
    session[:request_token_secret] = nil
  
    twitter_user = consumer.get_user({
      :access_token => access_token.token,
      :access_token_secret => access_token.secret
    })

    id = twitter_user['id']
    name = twitter_user['screen_name']
    token = access_token.token
    secret = access_token.secret

  when 'facebook'
    access_token = consumer.get_access_token params[:code]
    response = access_token.request :get, '/me'
    facebook_user = response.parsed

    id = facebook_user["id"]
    name = facebook_user["name"]
    token = access_token.token
    secret = ''
  end

  save_user({
    :name => name,
    :provider => provider,
    :provider_id => id,
    :token => token,
    :secret => secret
  }, 86400 * 7)

  redirect '/'
end

# APIs

get '/api/auth' do
  content_type 'application/json'
  if $user
    {:status => 'ok', :user => $user}.to_json
  else
    {:status => 'error', :error => "Not authenticated."}.to_json
  end
end

get '/api/votes' do
  content_type 'application/json'
  url = params[:url]
  return {:status => "error", :error => "not set params 'url'."}.to_json if url.nil?

  {:status => "ok", :vote => vote_by_url(url), :user => $user}.to_json
end

post '/api/votes' do
  content_type 'application/json'
  return {:status => "error", :error => "Not authenticated."}.to_json unless $user
  return {:status => "error", :error => "Wrong from secret."}.to_json unless check_api_secret

  {:status => "ok", :vote => vote(params)}.to_json
end

get '/api/detail' do
  content_type 'application/json'
  url = params[:url]
  return {:status => "error", :error => "not set params 'url'."}.to_json if url.nil?

  {:status => "ok", :vote => vote_by_url(url), :user => $user}.to_json
end

class HTML
  class << self
    def application_header
      HTML.header {
        h1 {
          link_to(AppName, "/")
        } +
        nav(:class => 'account') {
          if $user
            link_to("logout", "/logout")
          else
            link_to("twitterでログイン", "/oauth/twitter") +
            " / " +
            link_to("facebookでログイン", "/oauth/facebook")
          end
        }
      }
    end

    def application_footer
      if $user
        apisecret = HTML.script {
          "var apisecret = '#{$user['apisecret']}';"
        }
      else
        apisecret = ""
      end
      apisecret + HTML.footer {
        "&copy; " + link_to("ksss", "https://www.facebook.com/yuuki.kurihara.75")
      }
    end
  end
end

def after_day_to_ts (day)
  $_after_ts ||= Time.parse((Date.today + day).to_s).to_i
end

def rand_hash
  ret = ""
  File.open("/dev/urandom").read(20).each_byte { |x| ret << sprintf("%02x", x) }
  ret
end

def check_api_secret
  return false unless $user
  params["apisecret"] and (params["apisecret"] == $user["apisecret"])
end

# user
def auth_user(auth)
  return unless auth
  id = $r.get("auth:#{auth}")
  return unless id
  user = $r.hgetall("user:#{id}")
  0 < user.length ? user : nil
end

def save_user (opts, expires)
  provider_id = opts[:provider_id]
  name = opts[:name]
  provider = opts[:provider]

  seed = "#{provider}:#{provider_id}"
  user_uniq_key = Digest::SHA1.hexdigest(seed)

  auth = rand_hash
  response.set_cookie("auth", {
    :value => auth,
    :path => '/'
  })

  id = uniq_to_id(user_uniq_key)
  if !id
    id = create_user(user_uniq_key, name)
  end

  $r.setex("auth:#{auth}", expires, id)
  return auth, nil
end

def create_user (uniq_key, name)
  id = $r.incr("users.count")
  $r.hset("uniq.to.id", uniq_key, id)
  $r.hmset("user:#{id}",
    "id", id,
    "uniq", uniq_key,
    "name", name,
    "apisecret", rand_hash,
    "ctime", Time.now.to_i)
  return id
end

def uniq_to_id (uniq_key)
  $r.hget("uniq.to.id", uniq_key)
end

def fetch_user (id)
  user = $r.hgetall("user:#{id}");
  user.empty? ? nil : user
end

def vote_to_url (url, method, title, favicon_url)
  vote = vote_by_url(url)
  vote[method.to_s] += 1
  vote['title'] = title
  vote['favicon'] = favicon_url

  if !$r.exists("urls.#{$today}")
    $r.hset "urls.#{$today}", url, vote.to_json
    $r.expireat("urls.#{$today}", after_day_to_ts(7))
  else
    $r.hset "urls.#{$today}", url, vote.to_json
  end

  $r.hset "urls.total", url, vote.to_json
end

def vote_by_url (url)
  votes_json = $r.hget("urls.total", url)
  if votes_json.nil?
    {'up' => 0, 'down' => 0, 'title' => 'no title', 'favicon' => ''}
  else
    JSON.parse(votes_json)
  end
end

def voted? (url)
  return false unless $user

  ret = $r.hget("voted:#{$user['id']}", url)
  !ret.nil?
end

def voted (url, method)
  return false unless $user
  $r.hset("voted:#{$user['id']}", url, method)
end

# "up" and "down" even 'one' vote
def vote_to_score (url, method)
  return false unless $user

  if !$r.exists("votes.#{$today}")
    $r.zincrby "votes.#{$today}", 1, url
    $r.expireat("votes.#{$today}", after_day_to_ts(7))
  else
    $r.zincrby "votes.#{$today}", 1, url
  end
  
  $r.zincrby "votes.total", 1, url
end

def vote (opts)
  url = opts[:url]
  method = opts[:method]
  title = opts[:title]
  favicon = opts[:favIconUrl]
  return unless %w{up down}.include?(method)

  if !voted?(url)
    vote_to_url(url, method, title, favicon)
    vote_to_score(url, method)
  end
  voted(url, method)
  vote_by_url(url)
end

def total_votes_to_hash (limit=20)
  votes_to_hash_by_key "votes.total", "urls.total", limit
end

def day_votes_to_hash (limit=20, day=$today)
  votes_to_hash_by_key "votes.#{day}", "urls.#{day}", limit
end

def votes_to_hash_by_key (votes_key, url_key, limit)
  urls = []
  $r.zrange(votes_key.to_s, 0, limit).each do |url, score|
    urls << url
  end
  return [] if (urls.length == 0)

  rows = []
  $r.hmget(url_key.to_s, *urls).each_with_index { |vote_json, index|
    vote = JSON.parse(vote_json)
    rows << {
      :url => urls[index],
      :favicon => vote['favicon'],
      :title => vote['title'],
      :total => vote['up'].to_i + vote['down'].to_i,
      :up => vote['up'],
      :down => vote['down']
    }
  }
  rows
end

def day_ranking_to_html
  ranking_to_html day_votes_to_hash  
end

def total_ranking_to_html
  ranking_to_html total_votes_to_hash
end

def ranking_to_html (hash)
  str = ''
  hash.each_with_index do |row, index|
    str << div {
      div(:class => "title"){
        img(:src => row[:favicon], :width => "16px") +
        link_to(row[:title], row[:url]) +
        link_to("▲", "#up") +
        link_to("▼", "#down")
      } +
      div(:class => "description") {
        "#{span{row[:up]}} up and #{span{row[:down]}} down"
      }
    }
  end
  str  
end