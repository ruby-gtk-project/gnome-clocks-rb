# frozen_string_literal: true

require 'adwaita'
require_relative 'utils'

# TimerItem is one timer: a duration, an optional title, and the countdown
# that runs it down to zero and rings.
#
# Ported from Clocks.Timer.Item in src/timer-item.vala. Upstream's `state`
# property, its `ring` and `countdown_updated` signals and its destructor's
# source cleanup are all here; GObject signals are plain blocks instead,
# because this port's items are not GObjects.
#
class TimerItem
  STOPPED = :stopped
  RUNNING = :running
  PAUSED = :paused

  # Upstream's Item.deserialize: a timer with no duration is not a timer, and
  # is dropped rather than restored.
  def self.deserialize(dictionary)
    dictionary.then do |values|
      values['duration'].to_i.then do |duration|
        duration.zero? ? nil : from_seconds(duration, values['name'])
      end
    end
  end

  def self.from_seconds(seconds, name)
    new(seconds / 3600, (seconds / 60) % 60, seconds % 60, name)
  end

  # Upstream's Item.compare: running and paused timers come before stopped
  # ones, the running ones ordered by how much of their span is left and the
  # stopped ones by how long they were set for.
  def self.compare(first, second)
    if first.state == STOPPED && second.state != STOPPED then 1
    elsif first.state != STOPPED && second.state == STOPPED then -1
    elsif first.state != STOPPED then first.span <=> second.span
    else first.total_seconds <=> second.total_seconds
    end
  end

  def initialize(hours, minutes, seconds, name = nil)
    @hours = hours
    @minutes = minutes
    @seconds = seconds
    @name = name
    @state = STOPPED
    @timer = GLib::Timer.new
    @timeout_id = nil
    @listeners = { countdown: [], ring: [], state: [], name: [] }
    update_state
  end

  attr_reader :hours, :minutes, :seconds, :name, :state, :span
  attr_reader :stored_hour, :stored_minute, :stored_second

  def total_seconds = (@hours * 3600) + (@minutes * 60) + @seconds

  def name=(value)
    unless value == @name
      @name = value
      @listeners[:name].each { |listener| listener.call(value) }
    end
  end

  def state=(value)
    unless value == @state
      @state = value
      update_state
      @listeners[:state].each { |listener| listener.call(value) }
    end
  end

  def on_countdown_updated(&block)
    @listeners[:countdown] << block
    self
  end

  def on_ring(&block)
    @listeners[:ring] << block
    self
  end

  def on_state_changed(&block)
    @listeners[:state] << block
    self
  end

  def on_name_changed(&block)
    @listeners[:name] << block
    self
  end

  # Upstream's serialize: the duration in seconds, and the title when it has
  # one.
  def serialize
    { 'duration' => total_seconds }.tap do |values|
      values['name'] = @name if @name
    end
  end

  # Upstream's destructor drops the timeout with the item; nothing collects a
  # Ruby object deterministically, so the panel calls this when it removes a
  # timer from its store.
  def stop_countdown
    @timeout_id.then do |id|
      if id
        GLib::Source.remove(id)
        @timeout_id = nil
      end
    end
    self
  end

  private

    # Upstream's update_state: stopping rewinds the countdown to the full
    # duration, pausing banks what is left of the span, and starting puts the
    # 100ms tick back on.
    def update_state
      stop_countdown

      case @state
      when STOPPED
        @stored_hour = @hours
        @stored_minute = @minutes
        @stored_second = @seconds
        @span = total_seconds
        @timer.reset
        countdown_updated
      when PAUSED
        @span -= elapsed
        @timer.stop
      when RUNNING
        @timeout_id = GLib::Timeout.add(100) { tick }
        @timer.start
        countdown_updated
      end
    end

    # The Ruby binding hands GLib::Timer#elapsed back as [seconds, microseconds].
    def elapsed = Array(@timer.elapsed).first

    def countdown_updated
      @listeners[:countdown].each { |listener| listener.call(@stored_hour, @stored_minute, @stored_second) }
    end

    # Upstream's tick_cb: the countdown is reported only when one of the three
    # fields actually moved, and reaching the span stops the timer and rings.
    def tick
      if @state != RUNNING
        @timeout_id = nil
        GLib::Source::REMOVE
      elsif elapsed >= @span
        @timeout_id = nil
        self.state = STOPPED
        @listeners[:ring].each(&:call)
        GLib::Source::REMOVE
      else
        report_countdown((@span - elapsed).ceil)
        GLib::Source::CONTINUE
      end
    end

    def report_countdown(remaining)
      Utils.time_to_hms(remaining).then do |hours, minutes, seconds, _remainder|
        unless [@stored_hour, @stored_minute, @stored_second] == [hours, minutes, seconds]
          @stored_hour = hours
          @stored_minute = minutes
          @stored_second = seconds
          countdown_updated
        end
      end
    end
end
