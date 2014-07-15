class <%= @capitalized_name %> < ActiveRecord::Migration
  def change
    create_table :<%= @target %> do |t|
      <% @change_tasks.each do |task| %><%
        ts = task.split(':')
      %>t.<%= ts[1] %> :<%= ts[0] %>
      <% end %>
      t.timestamp
    end
  end
end