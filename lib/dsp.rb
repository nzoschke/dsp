module DSP
  extend self

  def log(*datas)
    data = datas.inject(:merge)
    buffer << data

    samples.each do |id, period, pattern|
      next if data.select { |k,v| pattern.keys.include? k } != pattern

      buffer(id) << { id => true, :num => 1, :__time => data[:__time] }
    end
  end

  # Map / Reduce
  def reduce(sample_id)
    reduced = {}
    buffer(:execs_per_min).each do |r|
      t = (r[:__time] / 60.0).floor
      if !reduced[t]
        reduced[t] = r
      else
        reduced[t][:num] += r[:num]
      end
    end
    reduced.values
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