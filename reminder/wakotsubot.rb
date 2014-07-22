#coding: utf-8
require 'pry'
require 'twitter'
require 'yaml'
require 'active_record'
require 'date'
require './twitter_connect.rb'

class TwitterReminder < TwitterConnect
  def initialize identity, opt = nil
    db = YAML.load_file('db/config/database.yml')
    ActiveRecord::Base.establish_connection(db["db"]["development"])
    super(identity, opt)
    @reminder_stacks = Array.new
  end

  def tweet
    loop do
      # print 'tweet: '
      text = STDIN.gets.chomp
      @rest_client.update(text)
    end
  end
end

@tr = TwitterReminder.new('wakotsu_bot')
@tr.tweet