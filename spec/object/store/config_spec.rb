# frozen_string_literal: true

RSpec.describe NATS::Object::Store::Config do
  subject { described_class.new(config) }

  let(:config) do
    {
      bucket: "store",
      description: "description",
      ttl: 70,
      max_bytes: 100,
      storage: "file",
      num_replicas: 3,
      placement: {
        cluster: "cluster",
        tags: ["tag"]
      },
      compression: "s2",
      metadata: {key: :value}
    }
  end

  describe "#initialize" do
    it "sets attributes" do
      expect(subject).to have_attributes(
        bucket: "store",
        description: "description",
        ttl: 70,
        max_bytes: 100,
        storage: "file",
        num_replicas: 3,
        placement: have_attributes(
          cluster: "cluster",
          tags: ["tag"]
        ),
        compression: "s2",
        metadata: {key: :value}
      )
    end
  end

  describe "#name" do
    it "returns store stream name" do
      expect(subject.name).to eq("OBJ_store")
    end
  end

  describe "#subjects" do
    it "returns store stream subjects" do
      expect(subject.subjects).to eq(["$O.store.C.>", "$O.store.M.>"])
    end
  end

  describe "#stream" do
    it "returns store stream attributes" do
      expect(subject.stream).to match(
        **config,
        name: "OBJ_store",
        subjects: ["$O.store.C.>", "$O.store.M.>"],
        max_age: 70,
        discard: "new",
        allow_rollup_hdrs: true,
        allow_direct: true
      )
    end
  end
end
