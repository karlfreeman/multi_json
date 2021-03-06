require 'helper'
require 'adapter_shared_example'
require 'json_common_shared_example'
require 'has_options'
require 'stringio'

describe 'MultiJson' do
  context 'adapters' do
    before{ MultiJson.use nil }

    context 'when no other json implementations are available' do
      before do
        @old_map = MultiJson::REQUIREMENT_MAP
        @old_json = Object.const_get :JSON if Object.const_defined?(:JSON)
        @old_oj = Object.const_get :Oj if Object.const_defined?(:Oj)
        @old_yajl = Object.const_get :Yajl if Object.const_defined?(:Yajl)
        @old_gson = Object.const_get :Gson if Object.const_defined?(:Gson)
        MultiJson::REQUIREMENT_MAP.each_with_index do |(library, adapter), index|
          MultiJson::REQUIREMENT_MAP[index] = ["foo/#{library}", adapter]
        end
        Object.send :remove_const, :JSON if @old_json
        Object.send :remove_const, :Oj if @old_oj
        Object.send :remove_const, :Yajl if @old_yajl
        Object.send :remove_const, :Gson if @old_gson
      end

      after do
        @old_map.each_with_index do |(library, adapter), index|
          MultiJson::REQUIREMENT_MAP[index] = [library, adapter]
        end
        Object.const_set :JSON, @old_json if @old_json
        Object.const_set :Oj, @old_oj if @old_oj
        Object.const_set :Yajl, @old_yajl if @old_yajl
        Object.const_set :Gson, @old_gson if @old_gson
      end

      it 'defaults to ok_json if no other json implementions are available' do
        silence_warnings do
          expect(MultiJson.default_adapter).to eq :ok_json
        end
      end

      it 'prints a warning' do
        Kernel.should_receive(:warn).with(/warning/i)
        MultiJson.default_adapter
      end
    end

    it 'defaults to the best available gem' do
      # Clear cache variable already set by previous tests
      MultiJson.send(:remove_instance_variable, :@adapter)
      unless jruby?
        require 'oj'
        expect(MultiJson.adapter.name).to eq 'MultiJson::Adapters::Oj'
      else
        require 'json'
        expect(MultiJson.adapter.name).to eq 'MultiJson::Adapters::JsonGem'
      end
    end

    it 'looks for adapter even if @adapter variable is nil' do
      MultiJson.send(:instance_variable_set, :@adapter, nil)
      MultiJson.should_receive(:default_adapter).and_return(:ok_json)
      expect(MultiJson.adapter.name).to eq 'MultiJson::Adapters::OkJson'
    end

    it 'is settable via a symbol' do
      MultiJson.use :json_gem
      expect(MultiJson.adapter.name).to eq 'MultiJson::Adapters::JsonGem'
    end

    it 'is settable via a class' do
      MultiJson.use MockDecoder
      expect(MultiJson.adapter.name).to eq 'MockDecoder'
    end

    it 'is settable via a module' do
      MultiJson.use MockModuleDecoder
      expect(MultiJson.adapter.name).to eq 'MockModuleDecoder'
    end

    context 'using one-shot parser' do
      before do
        MultiJson::Adapters::JsonPure.should_receive(:dump).exactly(1).times.and_return('dump_something')
        MultiJson::Adapters::JsonPure.should_receive(:load).exactly(1).times.and_return('load_something')
      end

      it 'should use the defined parser just for the call' do
        MultiJson.use :json_gem
        expect(MultiJson.dump('', :adapter => :json_pure)).to eq 'dump_something'
        expect(MultiJson.load('', :adapter => :json_pure)).to eq 'load_something'
        expect(MultiJson.adapter.name).to eq 'MultiJson::Adapters::JsonGem'
      end
    end
  end

  it 'can set adapter for a block' do
    MultiJson.use :ok_json
    MultiJson.with_adapter(:json_pure) do
      MultiJson.with_engine(:json_gem) do
        expect(MultiJson.adapter.name).to eq 'MultiJson::Adapters::JsonGem'
      end
      expect(MultiJson.adapter.name).to eq 'MultiJson::Adapters::JsonPure'
    end
    expect(MultiJson.adapter.name).to eq 'MultiJson::Adapters::OkJson'
  end

  it 'JSON gem does not create symbols on parse' do
    MultiJson.with_engine(:json_gem) do
      MultiJson.load('{"json_class":"ZOMG"}') rescue nil

      expect{
        MultiJson.load('{"json_class":"OMG"}') rescue nil
      }.to_not change{Symbol.all_symbols.count}
    end
  end

  unless jruby?
    it 'Oj does not create symbols on parse' do
      MultiJson.with_engine(:oj) do
        MultiJson.load('{"json_class":"ZOMG"}') rescue nil

        expect{
          MultiJson.load('{"json_class":"OMG"}') rescue nil
        }.to_not change{Symbol.all_symbols.count}
      end
    end
  end

  describe 'default options' do
    it 'is deprecated' do
      Kernel.should_receive(:warn).with(/deprecated/i)
      silence_warnings{ MultiJson.default_options = {:foo => 'bar'} }
    end

    it 'sets both load and dump options' do
      MultiJson.should_receive(:dump_options=).with(:foo => 'bar')
      MultiJson.should_receive(:load_options=).with(:foo => 'bar')
      silence_warnings{ MultiJson.default_options = {:foo => 'bar'} }
    end
  end

  it_behaves_like 'has options', MultiJson

  %w(gson json_gem json_pure nsjsonserialization oj ok_json yajl).each do |adapter|
    next if adapter == 'gson' && !jruby?
    next if adapter == 'nsjsonserialization' && !macruby?
    next if jruby? && (adapter == 'oj' || adapter == 'yajl')
    context adapter do
      it_behaves_like 'an adapter', adapter
    end
  end

  %w(json_gem json_pure).each do |adapter|
    context adapter do
      it_behaves_like 'JSON-like adapter', adapter
    end
  end
end
