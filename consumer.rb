module Consumer
  def self.new (provider)
    case provider
    when 'twitter'
      Twitter.new(TwitterOAuthConsumerKey, TwitterOAuthConsumerSecret)
    when 'facebook'
      Facebook.new(FacebookOAuthConsumerKey, FacebookOAuthConsumerSecret)
    else
    end
  end
  
  def call_back
    "http://#{AppDomain}/oauth_callback/#{self.class.to_s.downcase}"
  end
end

class Twitter < OAuth::Consumer
  include Consumer

  def initialize (oauth_consumer_key, oauth_consumer_secret)
    super(
      oauth_consumer_key,
      oauth_consumer_secret,
      :site               => '',
      :request_token_path => 'https://api.twitter.com/oauth/request_token',
      :authorize_path     => 'https://api.twitter.com/oauth/authorize',
      :access_token_path  => 'https://api.twitter.com/oauth/access_token')
  end

  def get_user (options = {})
    get_api_to '/account/verify_credentials.json', options
  end
  
  private
  def get_api_to (path, options)
    access_token = OAuth::AccessToken.new(
      self,
      options[:access_token],
      options[:access_token_secret])

    response = access_token.request :get, "http://api.twitter.com/1.1#{path}"
    if response
      JSON.parse(response.body)
    else
      ''
    end
  end
end

class Facebook < OAuth2::Client
  include Consumer

  def initialize (key, secret)
    OAuth2::Response.register_parser(:text, 'text/plain') do |body|
      ret = {}
      body.split('&').each do |str|
        key, value = str.split '=', 2
        ret[key] = value
      end
      ret
    end

    super(
      key,
      secret,
      :site => 'https://graph.facebook.com',
      :token_url  => '/oauth/access_token',
      :token_method => :get)
  end

  def get_access_token(code)
    auth_code.get_token(code, {
      :redirect_uri => call_back
    }, {
      :mode => :query
    })
  end
end