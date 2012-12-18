require 'spec_helper'

describe USDT::Provider do

  describe "create a new provider" do

    it "should create a provider with a name and module as symbols" do
      @provider = USDT::Provider.create(:foo, :bar)
      @provider.should_not be_nil
    end

    it "should create a provider with a name and module as strings" do
      # @provider = USDT::Provider.create("foo", "bar")
      # @provider.should_not be_nil
    end

  end

  describe "create a provider and a probe" do

    it "should create a provider and a probe and list the probe" do
      @provider = USDT::Provider.create(:foo, :bar)
      @probe = @provider.probe(:func, :usdtprobe)
      @provider.enable
      probe_count("foo#{$$}:::").should == 1
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

end
