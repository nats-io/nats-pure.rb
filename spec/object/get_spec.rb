# frozen_string_literal: true

RSpec.describe NATS::Object::Get do
  before(:all) do
    @server = NatsServerControl.new(
      "nats://127.0.0.1:4222",
      "/tmp/test-nats.pid",
      "-js"
    )
    @server.start_server(true)
  end

  after(:all) do
    @server.kill_server
  end

  subject { described_class.new(store) }

  let!(:store) { context.stores.create(bucket: "bucket") }
  let(:context) { NATS.connect.object_store }

  after { store.delete }

  describe "#get" do
    let(:object) { store.put(name: "object", data: "data") }

    let(:get) { subject.get("object", options) }
    let(:options) { {timeout: 1} }

    context "when object does not exists" do
      it "raises ObjectNotFoundError" do
        expect { get }.to raise_error(NATS::Object::ObjectNotFoundError)
      end
    end

    context "when object is deleted" do
      before { object.delete }

      context "with options[:show_deleted] = true" do
        let(:options) { {timeout: 1, show_deleted: true} }

        it "returns NATS::Object" do
          expect(get).to be_a(NATS::Object).and(
            have_attributes(
              info: have_attributes(
                name: "object",
                bucket: "bucket",
                deleted: true
              )
            )
          )
        end
      end

      context "with options[:show_deleted] = false" do
        let(:options) { {timeout: 1, show_deleted: false} }

        it "raises ObjectNotFoundError" do
          expect { get }.to raise_error(NATS::Object::ObjectNotFoundError)
        end
      end
    end

    context "when object is a link" do
      let!(:object) { store.link(name: "object", to: other_object) }
      let(:other_object) { other_store.put(name: "other_object", data: "data") }

      context "and links to a non-existing object" do
        let(:other_store) { store }

        before { other_object.delete }

        it "raises ObjectNotFoundError" do
          expect { get }.to raise_error(NATS::Object::ObjectNotFoundError)
        end
      end

      context "and links to the same bucket" do
        let(:other_store) { store }

        it "returns the linked object" do
          expect(get).to be_a(NATS::Object).and(
            have_attributes(
              info: have_attributes(
                name: "other_object",
                bucket: "bucket"
              )
            )
          )
        end
      end

      context "and links to a different bucket" do
        let(:other_store) { context.stores.create(bucket: "other_bucket") }

        after { other_store.delete }

        it "returns the linked object" do
          expect(get).to be_a(NATS::Object).and(
            have_attributes(
              info: have_attributes(
                name: "other_object",
                bucket: "other_bucket"
              )
            )
          )
        end
      end

      context "and options are provided" do
        let(:other_store) { store }
        let(:options) { {as: :string} }

        it "gets the linked options with the provided options" do
          expect(get).to be_a(NATS::Object).and(
            have_attributes(
              info: have_attributes(
                name: "other_object",
                bucket: "bucket"
              ),
              data: "data"
            )
          )
        end
      end
    end

    context "when object is a data object" do
      before { object }

      it "returns the object" do
        expect(get).to be_a(NATS::Object).and(
          have_attributes(
            info: have_attributes(
              name: "object",
              bucket: "bucket"
            )
          )
        )
      end

      context "with options[:as] = :string" do
        let(:options) { {timeout: 1, as: :string} }

        it "returns the object data as a string" do
          expect(get.data).to eq("data")
        end
      end

      context "with options[:as] = :file" do
        let(:options) { {timeout: 1, as: :file} }

        it "returns the object data as a Tempfile" do
          expect(get.data).to be_a(Tempfile)
        end

        it "writes the object data to the tempfile" do
          expect(File.read(get.data.path)).to eq("data")
        end
      end

      context "with options[:as] = :file and options[:path]" do
        before { FileUtils.mkdir_p("#{FileUtils.pwd}/tmp/objects") }

        let(:options) { {timeout: 1, as: :file, path: path} }
        let(:path) { "#{FileUtils.pwd}/tmp/objects/file.txt" }

        after { FileUtils.rm(path) }

        it "returns the object data as a Tempfile" do
          expect(get.data).to be_a(File).and(
            have_attributes(path: path)
          )
        end

        it "writes the object data to the file" do
          get

          expect(File.read(path)).to eq("data")
        end
      end

      context "with options[:as] = IO" do
        let(:options) { {timeout: 1, as: StringIO.new} }

        it "returns the object data as a IO" do
          expect(get.data).to be_a(StringIO)
        end

        it "writes the object data to the io" do
          expect(get.data.string).to eq("data")
        end
      end

      context "with options[:as] is nil" do
        it "returns the object data as a Object::IO" do
          expect(get.data).to be_a(NATS::Object::IO)
        end
      end
    end
  end
end
