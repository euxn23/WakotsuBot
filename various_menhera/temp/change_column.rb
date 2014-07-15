class <%= @capitalized_name %> < ActiveRecord::Migration
  def change
    <% @change_tasks.each do |task|
      ts = task.split(':')
      %>change_column :<%= @target %>, :<%= ts[0] %>, :<%= ts[1] %>
    <% end %>
  end
end