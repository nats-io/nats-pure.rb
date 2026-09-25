# frozen_string_literal: true

describe WaitHelpers do
  include described_class

  def elapsed
    start = Process.clock_gettime(Process::CLOCK_MONOTONIC)
    yield
    Process.clock_gettime(Process::CLOCK_MONOTONIC) - start
  end

  describe "#wait_until" do
    it "returns the block's value without sleeping when it is already truthy" do
      calls = 0
      expect(wait_until { (calls += 1) && :done }).to eql(:done)
      expect(calls).to eql(1)
    end

    it "notices a condition that turns true within a few milliseconds" do
      ready_at = Process.clock_gettime(Process::CLOCK_MONOTONIC) + 0.02
      took = elapsed { wait_until { Process.clock_gettime(Process::CLOCK_MONOTONIC) >= ready_at } }

      # Generous for slow runners; a 250ms fixed poll would still pass
      # this, the backoff test below is what pins the schedule.
      expect(took).to be < 0.5
    end

    it "keeps waiting for a slow condition up to the timeout" do
      ready_at = Process.clock_gettime(Process::CLOCK_MONOTONIC) + 0.6
      expect { wait_until(timeout: 5) { Process.clock_gettime(Process::CLOCK_MONOTONIC) >= ready_at } }
        .not_to raise_error
    end

    it "backs off instead of polling at a fixed rate" do
      calls = 0
      expect { wait_until(timeout: 2) { (calls += 1) && false } }
        .to raise_error(RSpec::Expectations::ExpectationNotMetError)
      # A fixed 5ms poll would make ~400 calls in 2s; doubling to a
      # 250ms cap makes about a dozen.
      expect(calls).to be < 30
    end

    it "fails with the description after the timeout" do
      expect { wait_until(timeout: 0.05, description: "the moon to rise") { false } }
        .to raise_error(RSpec::Expectations::ExpectationNotMetError, /the moon to rise/)
    end
  end

  describe "#eventually" do
    it "retries until the expectations pass" do
      ready_at = Process.clock_gettime(Process::CLOCK_MONOTONIC) + 0.03
      expect { eventually { expect(Process.clock_gettime(Process::CLOCK_MONOTONIC)).to be >= ready_at } }
        .not_to raise_error
    end

    it "re-raises the last expectation failure after the timeout" do
      expect { eventually(timeout: 0.05) { expect(1).to eql(2) } }
        .to raise_error(RSpec::Expectations::ExpectationNotMetError, /expected: 2/)
    end
  end
end
