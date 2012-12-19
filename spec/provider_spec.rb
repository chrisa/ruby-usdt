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
        @probe.fire
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

  describe "create a provider with arguments" do

    it "should create a probe with an integer argument" do
      @provider = USDT::Provider.create(:foo, :bar)
      @probe = @provider.probe(:func, :usdtprobe, :integer)
      @provider.enable

      data = dtrace_data_of('foo*:::{ trace(arg0); }') do
        @probe.fire(42)
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
        @probe.fire('foo')
      end

      data.length.should == 1
      d = data.first
      d.data.first.value.should == 'foo'
    end

  end

end
