require "minitest/autorun"
require "./lib/dsp"
require "./test/minitest_helper.rb"

class TestDSP < MiniTest::Unit::TestCase
  def setup
    DSP.reset
  end

  def test_log_datas
    DSP.log({ a: true, b: true }, { foo: :bar }, { foo: :baz }, { __time: 0 })
    assert_equal [{ a: true, b: true, foo: :baz, __time: 0 }], DSP.buffer
  end

  def test_log_time
    DSP.log(a: true, __time: Time.now.to_i)
  end

  def test_sample
    DSP.sample(:execs_per_min, 60, { exec: true, at: :start })

    DSP.log(exec: true, at: :start,   __time: 0)
    DSP.log(exec: true, at: :finish,  __time: 1)
    DSP.log(exec: true, at: :start,   __time: 2)
    DSP.log(exec: true, at: :error,   __time: 3)
    DSP.log(exec: true, at: :start,   __time: 60)
    DSP.log(exec: true, at: :finish,  __time: 61)

    assert_equal [
      { execs_per_min: true, num: 2, __time: 0,  __bin: 0 },
      { execs_per_min: true, num: 1, __time: 60, __bin: 1 }
    ], DSP.buffer(:execs_per_min)
  end

  def test_route_file
    skip
    DSP.route(:all,         "log/messages")
    DSP.route(:exceptions,  "log/exceptions")
    DSP.route([:execs_per_min, :avg_exec_time],  "log/stats")
    DSP.route(:all,         ["logger"])
  end

  def test_callback
    DSP.callback(:all, lambda { true }) { |b| STDOUT.puts b.last }
  end
end