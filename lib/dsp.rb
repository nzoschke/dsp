module DSP
  def [](id)
    @@refs ||= { }
    @@refs[id]
  end

  def []=(id, ref)
    @@refs ||= { }
    @@refs[id] = ref
  end

  extend self

  def log(*datas)
    @@mtx ||= Mutex.new
    @@mtx.synchronize do
      data = datas.inject(:merge)
      data[:__time] ||= Time.now.to_f

      # filter (copy or modify and accumulate) data into buffers
      filters.each do |id, opts|
        buff    = DSP[id]
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

        # call callback
        next unless c = callbacks[id]
        cond = c[:cond]
        blk  = c[:blk]
        args = [[], [buff.last], [buff.last, buff]]
        blk.call(*args[blk.arity]) if cond.call(*args[cond.arity])
      end
    end
  end

  # Internal Storage / Processing
  def add_buffer(id)
    buffers[id] ||= []
    DSP[id] = buffers[id]
  end

  def add_callback(id, cond=nil, &blk)
    cond ||= lambda { true }
    callbacks[id] = { :cond => cond, :blk => blk }
  end

  def add_filter(id, period=nil, &blk)
    add_buffer(id)
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
    ios[id].sync = true
    DSP[id] = ios[id]
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

    add_filter(:all) # every log goes to :all buffer
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