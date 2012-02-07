module DSP
  extend self

  def log(*datas)
    data = datas.inject(:merge)
    data[:__time] ||= Time.now.to_f

    # filter (copy or sample) logs into buffers
    filters.each do |id, opts|
      buff    = buffer(id)
      period  = opts[:period]
      pattern = opts[:pattern]
      blk     = opts[:blk]

      last  = buff.last
      bin   = (data[:__time] / period.to_f).floor rescue 0

      # match data to pattern or proc
      if blk
        if last && last[:__bin] == bin
          last.merge! blk.call(last, data)                    # accumulate in current bin
        else
          buff << blk.call({ id => true, __bin: bin }, data)  # append new bin
        end

        buff.last[:__time] = data[:__time]
        next
      end

      next if data.select { |k,v| pattern.keys.include? k } != pattern

      if period == nil  # copy
        buff << data
      else              # sample
        l = buff.last
        bin = (data[:__time] / period.to_f).floor
        if l && l[:__bin] == bin
          l[:num] += 1
        else
          data = { id => true, num: 1, __time: data[:__time], __bin: bin }
          buff << data
        end
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

  # String Formatting
  def unparse(data)
    data.map do |(k, v)|
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

  # Internal Storage / Processing
  def buffer(id=:all)
    buffers[id] ||= []
  end

  def callback(id, cond=nil, &blk)
    cond ||= lambda { true }
    callbacks[id] = { :cond => cond, :blk => blk }
  end

  def filter(id, period, pattern)
    filters[id] = { :period => period, :pattern => pattern }
  end

  def filter2(id, period, &blk)
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

    filter(:all, nil, {}) # every log goes to :all buffer
  end

  def close
    ios.each { |id, dev| dev.close unless dev == STDOUT }
  end
end

class Hash
  def match(h)
    return true
  end

  def reverse_merge!(h)
    replace(h.merge(self))
  end
end