class AddAbleToSavedTweets < ActiveRecord::Migration
  def change
    add_column :saved_tweets, :able, :boolean
    
  end
end