require "minitest/autorun"
require "./lib/dsp"
require "./test/minitest_helper.rb"

class TestDSP < MiniTest::Unit::TestCase
  def setup
    DSP.reset
  end

  def teardown
    DSP.close
  end

  def test_log_datas
    DSP.log({ a: true, b: true }, { foo: :bar }, { foo: :baz }, { __time: 0 })
    assert_equal [{ a: true, b: true, foo: :baz, __time: 0 }], DSP.buffer
  end

  def test_log_time
    DSP.log(a: true)
    assert DSP.buffer.last[:__time] > 0
  end

  def test_filter
    DSP.filter(:execs_per_min, 60, { exec: true, at: :start })

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

  def test_callback
    buffer = []
    DSP.callback(:all, lambda { true }) { |b| buffer << b.last }
    DSP.log(__time: 0)
    assert_equal [{:__time=>0}], buffer
  end

  def test_io
    DSP.add_io :stdout,   STDOUT
    DSP.add_io :logger,   ["logger"]
    DSP.add_io :messages, "log/messages"
  end

  def test_routing
    path = "log/messages"
    DSP.add_io :messages, path, mode: "w"
    DSP.callback(:all) { |b| io = DSP.ios[:messages]; io.puts DSP.unparse(b.last); io.flush }

    DSP.log(__time: 0)
    assert_equal "__time=0\n", File.read(path)
  end
end