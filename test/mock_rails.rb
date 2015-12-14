
module Rails

  class << self

    def logger
      Logger.new(STDOUT)
    end


  end

end