class CreateUsers < ActiveRecord::Migration
  def change
    create_table :users do |t|
      t.string :string
      t.integer :integer
      t.integer :integer
      t.string :string
      
      t.timestamp
    end
  end
end