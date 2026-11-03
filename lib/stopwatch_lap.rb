# frozen_string_literal: true

# StopwatchLap is one lap of the stopwatch: its number, counting from one, and
# how long it lasted in seconds.
#
# Ported from Clocks.Stopwatch.Lap in src/stopwatch-lap.vala.
#
class StopwatchLap
  def initialize(index, duration)
    @index = index
    @duration = duration
  end

  attr_accessor :index, :duration
end
