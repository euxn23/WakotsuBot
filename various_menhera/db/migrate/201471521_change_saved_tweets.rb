class ChangeSavedTweets < ActiveRecord::Migration
  def change
    change_column :saved_tweets, :able, :boolean, default: true

  end
end