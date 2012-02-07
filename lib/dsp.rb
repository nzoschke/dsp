module DSP
  extend self

  def log(*datas)
    data = datas.inject(:merge)
    data[:__time] ||= Time.now.to_f

    # filter (copy or modify and accumulate) data into buffers
    filters.each do |id, opts|
      buff    = buffer(id)
      period  = opts[:period]
      blk     = opts[:blk]

      last  = buff.last
      bin   = (data[:__time] / period.to_f).floor rescue 0
      
      if !blk
        buff << data
      else
        if last && last[:__bin] == bin
          acc = blk.call(last, data)
          last.merge! acc if acc                # accumulate in current bin
        else
          acc = blk.call({ id => true }, data)
          buff << acc if acc                    # append new bin
        end

        buff.last.merge!(__time: data[:__time], __bin: bin) if acc
      end
    end

    # call any callbacks (write, flush, rotate, store)
    callbacks.each do |id, c|
      buff = buffer(id)
      cond = c[:cond]
      blk  = c[:blk]
      args = cond.arity == 1 ? [buff] : []
      if cond.call(*args)
        blk.call(buff)
      end
    end
  end

  def write(data)
    @@mtx ||= Mutex.new
    @@mtx.synchronize do
      STDOUT.puts unparse(data)
      STDOUT.flush
    end
  end

  # Internal Storage / Processing
  def buffer(id=:all)
    buffers[id] ||= []
  end

  def callback(id, cond=nil, &blk)
    cond ||= lambda { true }
    callbacks[id] = { :cond => cond, :blk => blk }
  end

  def filter(id, period=nil, &blk)
    filters[id] = { :period => period, :blk => blk }
  end

  def add_io(id, dev, opts={})
    if dev.is_a? IO
      ios[id] = dev
    elsif dev.is_a? Array
      ios[id] = IO.popen(dev, mode=opts[:mode] || "w")
    elsif dev.is_a? String
      ios[id] = File.open(dev, mode=opts[:mode] || "a")
    end
  end

  def add_patch(h, &blk)
    h.each do |k,v|
      DSP.callback(k) { |b| io = DSP.ios[v]; io.puts(blk.call(b)); io.flush }
    end
  end

  def buffers
    @@buffers ||= {}
  end

  def callbacks
    @@callbacks ||= {}
  end

  def filters
    @@filters ||= {}
  end

  def ios
    @@ios ||= {}
  end

  def reset
    @@buffers   = nil
    @@callbacks = nil
    @@filters   = nil
    @@ios       = nil

    filter(:all) # every log goes to :all buffer
  end

  def close
    ios.each { |id, dev| dev.close unless dev == STDOUT }
  end
end

class Hash
  def unparse
    self.map do |(k, v)|
      if (v == true)
        k.to_s
      elsif (v == false)
        "#{k}=false"
      elsif (v.is_a?(String) && v.include?("\""))
        "#{k}='#{v}'"
      elsif (v.is_a?(String) && (v !~ /^[a-zA-Z0-9\:\.\-\_]+$/))
        "#{k}=\"#{v}\""
      elsif (v.is_a?(String) || v.is_a?(Symbol))
        "#{k}=#{v}"
      elsif v.is_a?(Float)
        "#{k}=#{format("%.3f", v)}"
      elsif v.is_a?(Numeric) || v.is_a?(Class) || v.is_a?(Module)
        "#{k}=#{v}"
      end
    end.compact.join(" ")
  end

  def match(h)
    return false if keys & h.keys != h.keys

    h.each do |k, v|
      if v.is_a? Regexp
        return false if !v.match(self[k].to_s)
      else
        return false if self[k] != v
      end
    end

    return true
  end

  def reverse_merge!(h)
    replace(h.merge(self))
  end
end

module Enumerable
  def sum
    return self.inject(0){|accum, i| accum + i }
  end

  def mean
    return self.sum / self.length.to_f
  end

  def sample_variance
    m = self.mean
    sum = self.inject(0){|accum, i| accum + (i - m) ** 2 }
    return sum / (self.length - 1).to_f
  end

  def standard_deviation
    return Math.sqrt(self.sample_variance)
  end
end

class RandomGaussian
  def initialize(mean, stddev, rand_helper = lambda { Kernel.rand })
    @rand_helper = rand_helper
    @mean = mean
    @stddev = stddev
    @valid = false
    @next = 0
  end

  def rand
    if @valid then
      @valid = false
      return @next
    else
      @valid = true
      x, y = self.class.gaussian(@mean, @stddev, @rand_helper)
      @next = y
      return x
    end
  end

  private
  def self.gaussian(mean, stddev, rand)
    theta = 2 * Math::PI * rand.call
    rho = Math.sqrt(-2 * Math.log(1 - rand.call))
    scale = stddev * rho
    x = mean + scale * Math.cos(theta)
    y = mean + scale * Math.sin(theta)
    return x, y
  end
end