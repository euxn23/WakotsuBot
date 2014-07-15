require 'date'
require 'erb'

now = DateTime.now
file_name = "#{now.year}#{now.month}#{now.day}#{now.hour}#{now.minute}_#{ARGV[0]}"

@capitalized_name = ARGV[0].split('_').map{|s| s.capitalize!}.join
@change_tasks = ARGV[1..-1]

regexp_add = /^add_(.+)_to_(.+)$/
regexp_create = /^create_(.+)$/
regexp_change = /^change_(.+)$/

case ARGV[0]
  when regexp_add
    @target = $+
    erb = ERB.new(File.read('./temp/add_column.rb'))
    migration = erb.result(binding)

  when regexp_create
    @target = $+
    erb = ERB.new(File.read('./temp/create_table.rb'))
    migration = erb.result(binding)

    @capitalized_target = @target.split('_').map{|s| s.capitalize!}.join
    erb = ERB.new(File.read('./temp/create_model.rb'))
    model = erb.result(binding)
    f = open("./models/#{@target}.rb", "w")
    f.write(model)
    f.close

  when regexp_change
    @target = $+
    erb = ERB.new(File.read('./temp/change_column.rb'))
    migration = erb.result(binding)

end

f = open("./db/migrate/#{file_name}.rb", "w")
f.write(migration)
f.close