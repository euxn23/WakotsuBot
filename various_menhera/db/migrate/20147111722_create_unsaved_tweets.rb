class CreateUnsavedTweets < ActiveRecord::Migration
  def change
    create_table :unsaved_tweets do |t|
      t.string :text
      
      t.timestamp
    end
  end
end