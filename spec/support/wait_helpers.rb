# frozen_string_literal: true

# Condition waits for specs, instead of fixed sleeps.
#
# Polling backs off exponentially from a few milliseconds, so a condition
# that is met quickly is noticed quickly, while the generous timeout still
# tolerates a slow CI runner. The per-example CI timeout (spec_helper)
# bounds everything regardless.
module WaitHelpers
  FIRST_DELAY = 0.005
  MAX_DELAY = 0.25
  DEFAULT_TIMEOUT = 10

  # Yields until the block returns a truthy value, and returns it.
  def wait_until(timeout: DEFAULT_TIMEOUT, description: nil)
    deadline = wait_helpers_now + timeout
    delay = FIRST_DELAY
    loop do
      result = yield
      return result if result

      remaining = deadline - wait_helpers_now
      if remaining <= 0
        raise RSpec::Expectations::ExpectationNotMetError,
          "timed out after #{timeout}s waiting for #{description || "condition"}"
      end
      sleep [delay, remaining].min
      delay = [delay * 2, MAX_DELAY].min
    end
  end

  # Retries a block of expectations until they pass; after the timeout
  # the last failure is raised, so the message says what was wrong.
  def eventually(timeout: DEFAULT_TIMEOUT, &block)
    last_failure = nil
    wait_until(timeout: timeout) do
      block.call
      true
    rescue RSpec::Expectations::ExpectationNotMetError => e
      last_failure = e
      false
    end
  rescue RSpec::Expectations::ExpectationNotMetError
    raise last_failure || $!
  end

  private

  def wait_helpers_now
    Process.clock_gettime(Process::CLOCK_MONOTONIC)
  end
end

RSpec.configure do |config|
  config.include WaitHelpers
end
