require File.expand_path(File.dirname(__FILE__)) + '/usdt'

provider = USDT::Provider.create :ruby, :test
puts provider
p = provider.probe(:myfn, :probe,
                   :string, :string, :integer)

provider.enable

puts "run:\nsudo dtrace -n 'ruby*:test:myfn:probe { printf(\"%s %s %d\",
  copyinstr(arg0),
  copyinstr(arg1),
  args[2])
}'"

while true
  if p.enabled? 
    p.fire("one", "two", 3)
    puts("Fired!")
  end
  sleep 0.5
end

