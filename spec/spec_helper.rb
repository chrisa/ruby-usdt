RSpec.configure do |c|
  c.mock_with 'flexmock'
end

require 'dtrace'

$LOAD_PATH << File.expand_path('../ext', File.dirname(__FILE__))
$LOAD_PATH << File.expand_path('../lib', File.dirname(__FILE__))
require 'usdt'

def probe_count(filter=nil)
  dtp = DTrace.new
  probes = 0
  dtp.each_probe(filter) do |probe|
    probes = probes + 1
  end
  dtp.close
  probes
end

def dtrace_data_of(code)
  @dtp = DTrace.new
  @dtp.setopt("bufsize", "4m")
  @dtp.compile(code).execute
  @dtp.go

  yield

  data = []
  c = DTrace::Consumer.new(@dtp)
  c.consume_once { |d| data << d }

  @dtp.stop
  @dtp.close

  data
end
