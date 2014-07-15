class ChangeUnsavedTweets < ActiveRecord::Migration
  def change
    change_column :unsaved_tweets, :add, :boolean, default: false
    change_column :unsaved_tweets, :check, :boolean, default: false

  end
end