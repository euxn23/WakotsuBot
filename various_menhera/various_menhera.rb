# coding: utf-8
require 'twitter'
require 'yaml'
require 'date'
require 'active_record'
require './twitter_connect.rb'

# modelsを読み込む
Dir[File.expand_path('../models', __FILE__) << '/*.rb'].each do |file|
  require file
end

class VariousMenhera < TwitterConnect
  def initialize identity, opt = nil
    db = YAML.load_file('db/config/database.yml')
    ActiveRecord::Base.establish_connection(db["db"]["development"])
    super(identity, opt)
    @mentioned_tweets = Array.new
  end

  def stream
    @client.user do |status|
      if status.is_a?(Twitter::Tweet)
        puts '---'
        if status.in_reply_to_screen_name == @user_screen_name
          @mentioned_tweets << status.text
          tweet = status.text.match(/^@+(.+)+\s+(.+)$/)[-1]
          UnsavedTweets.create(text: tweet)
          puts tweet
        end
      end
    end
  end

  def observer
    @thread = Thread.new do
      loop do
        new_tweets = UnsavedTweets.where(add: true)
        SavedTweets.create(new_tweets)
        @saved_tweets = SavedTweets.all

        @mentioned_tweets.each do |tweet|
          UnsavedTweets.create(text: tweet)
        end

        # sleep(30*30*6)
        sleep(30)
      end
    end
  end

  def check

  end

  def test
    UnsavedTweets.create(text: 'hoge')
  end
end

# @vm = VariousMenhera.new('various_menhera')
@vm = VariousMenhera.new('wktz')

# @vm.observer
# @vm.stream
@vm.test
