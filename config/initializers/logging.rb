module FilterLongVectorFromSqlLogs
  def debug(msg=nil, &block)
    if msg
      # number in a vector might look like:
      # 0.1293487
      # -21.983739734
      # -0.24878434e-05
      #
      # Optionally with whitespace surrounding
      number_re = '\s*\-?\d+\.\d+(e-\d+)?\s*'

      # at least 50 dimensions, get it outta there!
      msg.gsub!(/\[(#{number_re},){49,}(#{number_re})\]/, '[FILTERED VECTOR]')
    end

    super(msg, &block)
  end
end

ActiveRecord::LogSubscriber.prepend(FilterLongVectorFromSqlLogs)