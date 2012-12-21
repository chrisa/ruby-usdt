require 'spec_helper'

describe USDT::Provider do

  after(:each) do
    @provider.disable if @provider
  end

  describe "create a new provider" do

    it "should raise an error for no provider name" do
      lambda { USDT::Provider.create }.should raise_error
    end

    it "should raise an error for nil provider name" do
      lambda { USDT::Provider.create(nil) }.should raise_error
    end

    it "should raise an error for nil provider name and module" do
      lambda { USDT::Provider.create(nil, nil) }.should raise_error
    end

    it "should raise an error for too many arguments" do
      lambda { USDT::Provider.create("foo", "bar", "baz") }.should raise_error
    end

    it "should create a provider with a name and module as symbols" do
      @provider = USDT::Provider.create(:foo, :bar)
      @provider.should_not be_nil
    end

    it "should create a provider with a name and module as strings" do
      @provider = USDT::Provider.create("foo", "bar")
      @provider.should_not be_nil
    end

    it "should create a provider with a name but no module" do
      @provider = USDT::Provider.create("foo")
      @provider.should_not be_nil
    end

    it "should create a provider with a name but nil module" do
      @provider = USDT::Provider.create("foo", nil)
      @provider.should_not be_nil
    end

  end

  describe "create a provider and a probe" do

    it "should raise an error for no probe func or name" do
      @provider = USDT::Provider.create(:foo, :bar)
      lambda { @probe = @provider.probe }.should raise_error
    end

    it "should raise an error for nil probe func and no name" do
      @provider = USDT::Provider.create(:foo, :bar)
      lambda { @probe = @provider.probe(nil) }.should raise_error
    end

    it "should raise an error for nil probe func and name" do
      @provider = USDT::Provider.create(:foo, :bar)
      lambda { @probe = @provider.probe(nil, nil) }.should raise_error
    end

    it "should create a provider and a probe with func and name as symbols" do
      @provider = USDT::Provider.create(:foo, :bar)
      @probe = @provider.probe(:func, :usdtprobe)
      @provider.enable
      probe_count("foo#{$$}:::").should == 1
    end

    it "should create a provider and a probe with func and name as strings" do
      @provider = USDT::Provider.create(:foo, :bar)
      @probe = @provider.probe('func', 'usdtprobe')
      @provider.enable
      probe_count("foo#{$$}:::").should == 1
    end

    it "should create a provider and a probe with unspecified module" do
      @provider = USDT::Provider.create(:foo)
      @probe = @provider.probe('func', 'usdtprobe')
      @provider.enable
      probe_count("foo#{$$}:::").should == 1
    end

    it "should create a provider and a probe with unspecified module and function" do
      @provider = USDT::Provider.create(:foo)
      @probe = @provider.probe(nil, 'usdtprobe')
      @provider.enable
      probe_count("foo#{$$}::func:").should == 1
    end

  end

  describe "create a provider and fire a probe" do

    it "should fire a probe" do
      @provider = USDT::Provider.create(:foo, :bar)
      @probe = @provider.probe(:func, :usdtprobe)
      @provider.enable

      data = dtrace_data_of('foo*:::{ trace("foo"); }') do
        @probe.fire.should == true
      end

      data.length.should == 1
      d = data.first

      d.data.first.value.should == 'foo'
      d.probe.provider.should == "foo#{$$}"
      d.probe.mod.should == 'bar'
      d.probe.func.should == 'func'
      d.probe.name.should == 'usdtprobe'
      d.probe.to_s.should == "foo#{$$}:bar:func:usdtprobe"
    end

  end

  describe "create a probe with arguments" do

    it "should handle strings for argument types" do
      @provider = USDT::Provider.create(:foo, :bar)
      lambda { @provider.probe(:func, :usdtprobe, 'integer') }.should raise_error
    end

    it "should create a probe with an integer argument" do
      @provider = USDT::Provider.create(:foo, :bar)
      @probe = @provider.probe(:func, :usdtprobe, :integer)
      @provider.enable

      data = dtrace_data_of('foo*:::{ trace(arg0); }') do
        @probe.fire(42).should == true
      end

      data.length.should == 1
      d = data.first
      d.data.first.value.should == 42
    end

    it "should create a probe with a string argument" do
      @provider = USDT::Provider.create(:foo, :bar)
      @probe = @provider.probe(:func, :usdtprobe, :string)
      @provider.enable

      data = dtrace_data_of('foo*:::{ trace(copyinstr(arg0)); }') do
        @probe.fire('foo').should == true
      end

      data.length.should == 1
      d = data.first
      d.data.first.value.should == 'foo'
    end

    it "should create a probe with a json argument" do
      @provider = USDT::Provider.create(:foo, :bar)
      @probe = @provider.probe(:func, :usdtprobe, :json)
      @provider.enable

      data = dtrace_data_of('foo*:::{ trace(copyinstr(arg0)); }') do
        @probe.fire({ :foo => 1 }).should == true
      end

      data.length.should == 1
      d = data.first
      d.data.first.value.should == '{"foo":1}'
    end

  end

  describe "create probes with various numbers of arguments" do

    it "should create a probe with the maximum number of integer probes" do
      args = (1..32).map {|i| :integer }
      @provider = USDT::Provider.create(:foo)
      @probe = @provider.probe('func', 'usdtprobe', *args)
      @provider.enable
      probe_count("foo#{$$}:::").should == 1
    end

    it "should create a probe with the maximum number of string probes" do
      args = (1..32).map {|i| :string }
      @provider = USDT::Provider.create(:foo)
      @probe = @provider.probe('func', 'usdtprobe', *args)
      @provider.enable
      probe_count("foo#{$$}:::").should == 1
    end

  end

  describe "is-enabled check" do

    it "should not fire a probe that is not enabled" do
      @provider = USDT::Provider.create(:foo, :bar)
      @probe = @provider.probe(:func, :usdtprobe)
      @provider.enable
      @probe.enabled?.should == false
    end

    it "should fire a probe that is enabled" do
      @provider = USDT::Provider.create(:foo, :bar)
      @probe = @provider.probe(:func, :usdtprobe)
      @provider.enable

      data = dtrace_data_of('foo*:::{ trace("foo"); }') do
        @probe.enabled?.should == true
      end
    end

  end

  describe "remove a probe" do

    it "should raise an error for a bad argument to remove_probe" do
      @provider = USDT::Provider.create(:foo, :bar)
      lambda { @provider.remove_probe(1) }.should raise_error
    end

    it "should create and remove a probe with no arguments" do
      @provider = USDT::Provider.create(:foo, :bar)
      @probe1 = @provider.probe(:func, :usdtprobe1)
      @probe2 = @provider.probe(:func, :usdtprobe2)
      @provider.enable
      probe_count("foo#{$$}:::").should == 2
      @provider.disable
      @provider.remove_probe(@probe1)
      @provider.enable
      probe_count("foo#{$$}:::").should == 1
    end

  end

  describe "values for json arguments" do

    it "should handle a ruby Hash" do
      @provider = USDT::Provider.create(:foo, :bar)
      @probe = @provider.probe(:func, :usdtprobe, :json)
      @provider.enable

      arg = { :foo => 'bar' }

      data = dtrace_data_of('foo*:::{ trace(copyinstr(arg0)); }') do
        @probe.fire(arg).should == true
      end

      data.length.should == 1
      d = data.first
      d.data.first.value.should == '{"foo":"bar"}'
    end

    it "should handle a ruby Array" do
      @provider = USDT::Provider.create(:foo, :bar)
      @probe = @provider.probe(:func, :usdtprobe, :json)
      @provider.enable

      arg = [1, 2, 3]

      data = dtrace_data_of('foo*:::{ trace(copyinstr(arg0)); }') do
        @probe.fire(arg).should == true
      end

      data.length.should == 1
      d = data.first
      d.data.first.value.should == '[1,2,3]'
    end

    it "should handle a ruby string" do
      @provider = USDT::Provider.create(:foo, :bar)
      @probe = @provider.probe(:func, :usdtprobe, :json)
      @provider.enable

      arg = "foo"

      data = dtrace_data_of('foo*:::{ trace(copyinstr(arg0)); }') do
        @probe.fire(arg).should == true
      end

      data.length.should == 1
      d = data.first
      d.data.first.value.should == '"foo"'
    end

    it "should handle a ruby integer" do
      @provider = USDT::Provider.create(:foo, :bar)
      @probe = @provider.probe(:func, :usdtprobe, :json)
      @provider.enable

      arg = 1

      data = dtrace_data_of('foo*:::{ trace(copyinstr(arg0)); }') do
        @probe.fire(arg).should == true
      end

      data.length.should == 1
      d = data.first
      d.data.first.value.should == '1'
    end

  end

  describe "bad values for probe arguments" do

    it "should not raise an error when string passed but probe not enabled" do
      @provider = USDT::Provider.create(:foo, :bar)
      @probe = @provider.probe(:func, :usdtprobe, :integer)
      @provider.enable
      @probe.fire("foo").should == false
    end

    it "should not raise an error when integer passed but probe not enabled" do
      @provider = USDT::Provider.create(:foo, :bar)
      @probe = @provider.probe(:func, :usdtprobe, :string)
      @provider.enable
      @probe.fire(1).should == false
    end

    it "should raise an error for a string passed to an integer argument" do
      @provider = USDT::Provider.create(:foo, :bar)
      @probe = @provider.probe(:func, :usdtprobe, :integer)
      @provider.enable
      dtrace_data_of('foo*:::{ trace(copyinstr(arg0)); }') do
        lambda { @probe.fire("foo") }.should raise_error
      end
    end

    it "should raise an error for an integer passed to a string argument" do
      @provider = USDT::Provider.create(:foo, :bar)
      @probe = @provider.probe(:func, :usdtprobe, :string)
      @provider.enable
      dtrace_data_of('foo*:::{ trace(copyinstr(arg0)); }') do
        lambda { @probe.fire(1) }.should raise_error
      end
    end

  end

  describe "integer limits" do

    if RbConfig::CONFIG['target_cpu'] == 'i386'

      # Workaround for: 6978322 libdtrace compiler fails to sign extend certain variables
      # http://mail.opensolaris.org/pipermail/dtrace-discuss/2010-August/008902.html

      trace_min_max = <<EOD
foo*:::
{
  this->max = (long) (int) arg0;
  this->min = (long) (int) arg1;
  trace(this->max);
  trace(this->min);
}
EOD
    else

      trace_min_max = <<EOD
foo*:::
{
  trace(arg0);
  trace(arg1);
}
EOD
    end

    it "should handle 32 bit Fixnum max and min" do
      @provider = USDT::Provider.create(:foo, :bar)
      @probe = @provider.probe(:func, :usdtprobe, :integer, :integer)
      @provider.enable

      max = (2 ** 30) - 1
      min = -(2 ** 30)

      # should be Fixnum everywhere
      max.class.should == Fixnum
      min.class.should == Fixnum

      data = dtrace_data_of(trace_min_max) do
        @probe.fire(max, min).should == true
      end

      data.length.should == 1
      d = data.first
      d.data[0].value.should == max
      d.data[1].value.should == min
    end

    it "should handle 32 bit INT_MAX and INT_MIN" do
      @provider = USDT::Provider.create(:foo, :bar)
      @probe = @provider.probe(:func, :usdtprobe, :integer, :integer)
      @provider.enable

      max = (2 ** 31) - 1
      min = -(2 ** 31)

      # should be Fixnum on x86_64
      if RbConfig::CONFIG['target_cpu'] == 'i386'
        max.class.should == Bignum
        min.class.should == Bignum
      else
        max.class.should == Fixnum
        min.class.should == Fixnum
      end
      data = dtrace_data_of(trace_min_max) do
        @probe.fire(max, min).should == true
      end

      data.length.should == 1
      d = data.first
      d.data[0].value.should == max
      d.data[1].value.should == min
    end

    it "should handle 64 bit ruby Fixnum min and max" do
      @provider = USDT::Provider.create(:foo, :bar)
      @probe = @provider.probe(:func, :usdtprobe, :integer, :integer)
      @provider.enable

      max = (2 ** 61) - 1
      min = -(2 ** 61)

      # should be Fixnum on x86_64
      if RbConfig::CONFIG['target_cpu'] == 'i386'
        max.class.should == Bignum
        min.class.should == Bignum
      else
        max.class.should == Fixnum
        min.class.should == Fixnum
      end

      data = dtrace_data_of(trace_min_max) do
        if RbConfig::CONFIG['target_cpu'] == 'i386'
          lambda { @probe.fire(max, min) }.should raise_error
        else
          @probe.fire(max, min).should == true
        end
      end

      unless RbConfig::CONFIG['target_cpu'] == 'i386'
        data.length.should == 1
        d = data.first
        d.data[0].value.should == max
        d.data[1].value.should == min
      end
    end

    it "should handle 64 bit INT_MAX and INT_MIN" do
      @provider = USDT::Provider.create(:foo, :bar)
      @probe = @provider.probe(:func, :usdtprobe, :integer, :integer)
      @provider.enable

      max = (2 ** 63) - 1
      min = -(2 ** 63)

      # should be Bignum everywhere
      max.class.should == Bignum
      min.class.should == Bignum

      data = dtrace_data_of(trace_min_max) do
        if RbConfig::CONFIG['target_cpu'] == 'i386'
          lambda { @probe.fire(max, min) }.should raise_error
        else
          @probe.fire(max, min).should == true
        end
      end

      unless RbConfig::CONFIG['target_cpu'] == 'i386'
        data.length.should == 1
        d = data.first
        d.data[0].value.should == max
        d.data[1].value.should == min
      end
    end

    it "should raise an error for Bignums beyond 64 bits" do
      @provider = USDT::Provider.create(:foo, :bar)
      @probe = @provider.probe(:func, :usdtprobe, :integer, :integer)
      @provider.enable

      max = (2 ** 128) - 1
      min = -(2 ** 128)

      # should be Bignum everywhere
      max.class.should == Bignum
      min.class.should == Bignum

      dtrace_data_of(trace_min_max) do
        lambda { @probe.fire(max, min) }.should raise_error
      end
    end

  end

end
