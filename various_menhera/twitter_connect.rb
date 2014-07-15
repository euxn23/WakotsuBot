# coding: utf-8
require 'twitter'
require 'yaml'

class TwitterConnect
  def initialize identify, opt = nil
    @identify = identify

    # 通常のクラス宣言時には引数アカウントのyamlトークンでコネクションを確立し@clientを生成する
    # オプションを指定しクラス宣言された場合にはコネクションは確立しない
    # if opt.nil?
    #   connect_twitter
    # end
    connect_twitter
  end

  def connect_twitter
    keys = YAML.load_file('config.yml')
    @client = Twitter::Streaming::Client.new do |config|
      config.consumer_key = keys[@identify]['twitter']['consumer_key']
      config.consumer_secret = keys[@identify]['twitter']['consumer_secret']
      config.access_token = keys[@identify]['twitter']['access_token']
      config.access_token_secret = keys[@identify]['twitter']['access_token_secret']
    end

    @rest_client = Twitter::REST::Client.new do |config|
      config.consumer_key = keys[@identify]['twitter']['consumer_key']
      config.consumer_secret = keys[@identify]['twitter']['consumer_secret']
      config.access_token = keys[@identify]['twitter']['access_token']
      config.access_token_secret = keys[@identify]['twitter']['access_token_secret']
    end

    @user_screen_name = @rest_client.user.screen_name
  end
end