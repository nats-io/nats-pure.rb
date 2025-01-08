# frozen_string_literal: true

def with_timeout(timeout)
  start_time = Time.now
  yield
  end_time = Time.now
  fail if end_time - start_time > timeout
end

class Stream < Queue
  include MonitorMixin
end

class Future
  def initialize
    @mon = Monitor.new
    @done = @mon.new_cond
    @result = nil
  end

  def wait_for(timeout = 1)
    return @result if @result
    @mon.synchronize do
      @done.wait(timeout)
    end
    @result
  end

  def set_result(result)
    @mon.synchronize do
      @done.signal
    end
    @result = result
  end

  def done
    @mon.synchronize do
      @done.signal
    end
  end
end
