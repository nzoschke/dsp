module DSP
  extend self

  def log(*datas)
    data = datas.inject(:merge)
    buffer << data

    samples.each do |id, period, pattern|
      next if data.select { |k,v| pattern.keys.include? k } != pattern

      buffers[id] ||= [{ id => true, :num => 0 }]
      buffers[id].last[:num] += 1
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