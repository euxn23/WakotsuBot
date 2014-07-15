class CreateSavedTweets < ActiveRecord::Migration
  def change
    create_table :saved_tweets do |t|
      t.string :text
      
      t.timestamp
    end
  end
end