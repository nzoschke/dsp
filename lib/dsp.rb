module DSP
  extend self

  def log(*datas)
    buffer << datas.inject(:merge)
  end

  def reset
    @@buffer = []
  end

  def buffer
    @@buffer ||= []
  end
end