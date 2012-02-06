require "minitest/autorun"
require "./lib/dsp"

class TestDSP < MiniTest::Unit::TestCase
  def test_sanity
    assert true
  end

  def test_log_hash
    DSP.log()
  end
end
