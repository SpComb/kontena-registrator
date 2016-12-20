require 'kontena/registrator'
require 'kontena/registrator/etcd'

describe Kontena::Registrator::Etcd::Writer do
  context "without TTLs", :etcd => true do
    subject { described_class.new() }

    describe '#refresh' do
      it "raises ArgumentError" do
        expect{subject.refresh}.to raise_error(ArgumentError)
      end
    end

  end

  context "for an empty etcd", :etcd => true do
    subject { described_class.new(ttl: 30) }

    describe '#update' do
      it "writes out a node" do
        subject.update(
          '/kontena/test1' => { 'test' => 1 }.to_json,
        )

        expect(etcd_server.logs).to eq [
          [:set, '/kontena/test1'],
        ]
        expect(etcd_server.nodes).to eq(
          '/kontena/test1' => { 'test' => 1 },
        )
      end
    end

    describe '#refresh' do
      it "does nothing" do
        subject.refresh

        expect(etcd_server).to_not be_modified
      end
    end
  end

  context "for etcd one nodes set", :etcd => true do
    subject { described_class.new(ttl: 30) }

    before do
      subject.update(
        '/kontena/test1' => { 'test' => 1 }.to_json,
      )
    end

    describe '#update' do
      it "keeps an existing node" do |ex|
        subject.update(
          '/kontena/test1' => { 'test' => 1 }.to_json,
        )

        expect(etcd_server.logs).to eq [
          [:set, '/kontena/test1'],
        ]
        expect(etcd_server.nodes).to eq(
          '/kontena/test1' => { 'test' => 1 },
        )
      end

      it "updates a node" do |ex|
        subject.update(
          '/kontena/test1' => { 'test' => 2 }.to_json,
        )

        expect(etcd_server.logs).to eq [
          [:set, '/kontena/test1'],
          [:set, '/kontena/test1'],
        ]
        expect(etcd_server.nodes).to eq(
          '/kontena/test1' => { 'test' => 2 },
        )
      end

      it "deletes a node" do |ex|
        subject.update({})

        expect(etcd_server.logs).to eq [
          [:set, '/kontena/test1'],
          [:delete, '/kontena/test1'],
        ]
        expect(etcd_server.nodes).to eq({})
      end

      it "replaces a node" do |ex|
        subject.update(
          '/kontena/test2' => { 'test' => 2 }.to_json,
        )

        expect(etcd_server.logs).to eq [
          [:set, '/kontena/test1'],
          [:set, '/kontena/test2'],
          [:delete, '/kontena/test1'],
        ]
        expect(etcd_server.nodes).to eq(
          '/kontena/test2' => { 'test' => 2 },
        )
      end
    end

    describe '#refresh' do
      it "updates the node" do
        subject.refresh

        # XXX: can't use logs with refresh
        #expect(etcd_server.logs).to eq [
        #  [:set, '/kontena/test1'],
        #]
        expect(etcd_server.nodes).to eq(
          '/kontena/test1' => { 'test' => 1 },
        )
      end
    end
  end
end
