module DSP
  extend self

  def log(*datas)
    data = datas.inject(:merge)
    data[:__time] ||= Time.now.to_f
    buffer << data

    samples.each do |id, period, pattern|
      next if data.select { |k,v| pattern.keys.include? k } != pattern

      b = buffer(id)
      bin = (data[:__time] / period.to_f).floor
      if b.last && b.last[:__bin] == bin
        b.last[:num] += 1
      else
        b << { id => true, :num => 1, :__time => data[:__time], :__bin => bin }
      end
    end
  end

  # Internal Storage
  def buffer(id=:all)
    buffers[id] ||= []
  end

  def sample(id, period, pattern)
    samples << [id, period, pattern]
  end

  def buffers
    @@buffers ||= {}
  end

  def samples
    @@samples ||= []
  end

  def reset
    @@buffers = nil
    @@samples = nil
  end
end