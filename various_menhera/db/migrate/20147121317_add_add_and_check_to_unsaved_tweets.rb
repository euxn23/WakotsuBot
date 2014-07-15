class AddAddAndCheckToUnsavedTweets < ActiveRecord::Migration
  def change
    add_column :unsaved_tweets, :add, :boolean
    add_column :unsaved_tweets, :check, :boolean
    
  end
end