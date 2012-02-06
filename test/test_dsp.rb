require "minitest/autorun"
require "./lib/dsp"
require "./test/minitest_helper.rb"

class TestDSP < MiniTest::Unit::TestCase
  def setup
    DSP.reset
  end

  def test_sanity
    assert true
  end

  def test_log_datas
    DSP.log({ a: true, b: true }, { foo: :bar }, { foo: :baz })
    assert_equal [{ a: true, b: true, foo: :baz }], DSP.buffer
  end

  def test_log_data
    DSP.log(scheduler: true, task: true, exec: true, at: :start, id: 12, command: "bin/cache")
    DSP.log(scheduler: true, task: true, exec: true, at: :finish, ps: "scheduler.10", upid: 125)
    DSP.log(scheduler: true, task: true, exec: true, at: :start, id: 16, command: "rake send_emails")
    DSP.log(scheduler: true, task: true, exec: true, at: :error)
  end
end