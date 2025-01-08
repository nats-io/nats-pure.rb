# frozen_string_literal: true

describe "NUID" do
  it "should have a fixed length and be unique" do
    nuid = NATS::NUID.new
    entries = []
    total = 500_000
    total.times do
      entry = nuid.next
      expect(entry.size).to eql(NATS::NUID::TOTAL_LENGTH)
      entries << entry
    end
    entries.uniq!
    expect(entries.count).to eql(total)
  end

  it "should be unique after 1M entries" do
    total = 1_000_000
    entries = []
    nuid = NATS::NUID.new
    total.times do
      entries << nuid.next
    end
    entries.uniq!
    expect(entries.count).to eql(total)
  end

  it "should randomize the prefix after sequence is done" do
    nuid = NATS::NUID.new
    seq_a = nuid.instance_variable_get("@seq")
    inc_a = nuid.instance_variable_get("@inc")
    a = nuid.next

    seq_b = nuid.instance_variable_get("@seq")
    nuid.instance_variable_get("@inc")
    expect(seq_a < seq_b).to eql(true)
    expect(seq_b).to eql(seq_a + inc_a)
    b = nuid.next

    nuid.instance_variable_set("@seq", NATS::NUID::MAX_SEQ + 1)
    c = nuid.next
    l = NATS::NUID::PREFIX_LENGTH
    expect(a[0..l]).to eql(b[0..l])
    expect(a[0..l]).to_not eql(c[0..l])
  end

  context "when using the NUID.next" do
    it "should be thread safe" do
      ts = Hash.new { |h, k| h[k] = {} }
      total = 100_000
      10.times do |n|
        ts[n][:thread] = Thread.new do
          sleep 0.01
          total.times do
            ts[n][:entries] ||= []
            ts[n][:entries] << NATS::NUID.next
          end
        end
      end

      total_entries = []
      ts.each do |k, t|
        t[:thread].join
        expect(t[:entries].count).to eql(total)
        total_entries << t[:entries]
      end
      total_entries.flatten!
      total_entries.uniq!
      expect(total_entries.count).to eql(total * 10)
    end
  end
end
