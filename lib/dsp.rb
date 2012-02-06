module DSP
  extend self

  def log(*datas)
    data = datas.inject(:merge)
    data[:__time] ||= Time.now.to_f

    # filter (copy or sample) logs into buffers
    filters.each do |id, opts|
      period  = opts[:period]
      pattern = opts[:pattern]

      next if data.select { |k,v| pattern.keys.include? k } != pattern

      buff = buffer(id)
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

  def callback(id, cond, &blk)
    callbacks[id] = { :cond => cond, :blk => blk }
  end

  def filter(id, period, pattern)
    filters[id] = { :period => period, :pattern => pattern }
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

  def reset
    @@buffers   = nil
    @@filters   = nil
    @@callbacks = nil

    filter(:all, nil, {}) # every log goes to :all buffer
  end
end