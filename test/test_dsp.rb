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

  def test_counter
    DSP.filter(:exec_per_min, 60) do |acc, data|
      next unless data.match(exec: true, at: :start)
      acc[:num] ||= 0
      acc[:num]  += 1
      acc
    end

    DSP.log(exec: true, at: :start,   __time: 0)
    DSP.log(exec: true, at: :finish,  __time: 1)
    DSP.log(tick: true,               __time: 1)
    DSP.log(exec: true, at: :start,   __time: 2)
    DSP.log(exec: true, at: :error,   __time: 3)
    DSP.log(exec: true, at: :start,   __time: 60)
    DSP.log(exec: true, at: :finish,  __time: 61)

    assert_equal [
      { exec_per_min: true, num: 2, __time: 2,  __bin: 0 },
      { exec_per_min: true, num: 1, __time: 60, __bin: 1 }
    ], DSP.buffer(:exec_per_min)
  end

  def test_averager
    DSP.filter(:exec_time, 60) do |acc, data|
      next unless data.match(exec: true, at: /finish|error/, elapsed: /./)

      acc[:num]     ||= 0 # defaults
      acc[:elapsed] ||= 0

      acc[:num]     += 1
      acc[:elapsed] += data[:elapsed]
      acc[:avg]     =  acc[:elapsed] / acc[:num].to_f
      acc
    end

    DSP.log(exec: true, at: :finish, elapsed: 1.2, __time: 1)
    DSP.log(exec: true, at: :error,  elapsed: 5.3, __time: 3)
    DSP.log(exec: true, at: :finish, elapsed: 1.1, __time: 61)

    assert_equal [
      { exec_time: true, num: 2, elapsed: 6.5, avg: 3.25, __time: 3,  __bin: 0 },
      { exec_time: true, num: 1, elapsed: 1.1, avg: 1.10, __time: 61, __bin: 1 }
    ], DSP.buffer(:exec_time)
  end

  def test_chain_sampler
  end

  def test_priority_sampler
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
    DSP.add_patch(:all => :messages) { |b| b.last.unparse }

    DSP.log(__time: 0)
    assert_equal "__time=0\n", File.read(path)
  end
end

class TestStats < MiniTest::Unit::TestCase
  def test_stats
    vals = [1, 2, 2.2, 2.3, 4, 5]
    assert_in_delta 16.5, vals.sum,                 0.01
    assert_in_delta 2.75, vals.mean,                0.01
    assert_in_delta 2.15, vals.sample_variance,     0.01
    assert_in_delta 1.47, vals.standard_deviation,  0.01
  end

  def test_gaussian
    srand 42
    rg = RandomGaussian.new(2.75, 1.47)
    vals = (1..100).map { rg.rand }
    assert_in_delta 2.75, vals.mean,                0.26
    assert_in_delta 2.15, vals.sample_variance,     0.03
    assert_in_delta 1.47, vals.standard_deviation,  0.02
  end
end