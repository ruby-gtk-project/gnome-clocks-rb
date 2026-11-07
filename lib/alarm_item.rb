# frozen_string_literal: true

require 'securerandom'
require 'time'
require_relative 'utils'
require_relative 'alarm_sound_model'

# AlarmItem is one alarm: the time it fires at, the days it repeats on, how
# long it snoozes and keeps ringing, and the bell it rings with.
#
# Ported from Clocks.Alarm.Item in src/alarm-item.vala. GObject properties
# and notifications become plain Ruby accessors and listener blocks, the way
# TimerItem already does; the destructor that drops the bell's source has no
# equivalent here because the bell itself owns no outstanding source once
# stopped.
#
# One deviation from upstream: GLib.DateTime's arithmetic and comparison
# methods (add_days, add_minutes, compare, get_day_of_week, from_iso8601)
# are not exposed by this binding — only the plain field readers and
# `format`/`format_iso8601` are. Ring-time bookkeeping is done with Ruby's
# own Time instead, and a GLib::DateTime is built only at the boundary where
# Utils::WallClock#format_time needs one.
class AlarmItem
  READY = :ready
  RINGING = :ringing
  SNOOZING = :snoozing
  MISSED = :missed

  def self.generate_id = SecureRandom.uuid

  # Upstream's Item.compare: ordered by time of day.
  def self.compare(first, second)
    (first.hour * 60 + first.minute) <=> (second.hour * 60 + second.minute)
  end

  def self.deserialize(dictionary)
    dictionary.fetch('hour', -1).then do |hour|
      dictionary.fetch('minute', -1).then do |minute|
        if hour >= 0 && minute >= 0
          build_from_dictionary(dictionary, hour, minute)
        else
          warn "Invalid alarm #{dictionary['name'] || '[unnamed]'}"
          nil
        end
      end
    end
  end

  def self.build_from_dictionary(dictionary, hour, minute)
    new(dictionary['id']).tap do |alarm|
      alarm.name = dictionary['name']
      alarm.hour = hour
      alarm.minute = minute
      alarm.days = dictionary['days'] ? Utils::Weekdays.deserialize(dictionary['days']) : nil
      alarm.ring_minutes = dictionary.fetch('ring_minutes', 5)
      alarm.snooze_minutes = dictionary.fetch('snooze_minutes', 10)
      alarm.sound_file = dictionary['sound_uri'] ? Gio::File.new_for_uri(dictionary['sound_uri']) : AlarmSoundModel.build_fallback_file
      # Keep compatibility with older versions, which stored only `active`.
      if dictionary['active'] && !dictionary['ring_time']
        alarm.active = true
      else
        alarm.load_ring_time(dictionary['ring_time'] ? Time.parse(dictionary['ring_time']) : nil)
      end
    end
  end

  def initialize(id = nil)
    @id = id || self.class.generate_id
    @hour = 0
    @minute = 0
    @snooze_minutes = 10
    @ring_minutes = 5
    @sound_file = AlarmSoundModel.build_default_file
    @days = nil
    @ring_time = nil
    @state = READY
    @listeners = { active: [], state: [], name: [], ring: [] }
  end

  attr_reader :id, :hour, :minute, :days, :ring_time, :state, :sound_file, :name
  attr_accessor :snooze_minutes, :ring_minutes
  attr_writer :name, :hour, :minute, :days

  def sound_file=(value)
    @sound_file = value
    setup_bell
  end

  # Loads a deserialized ring time directly, bypassing the active= listener
  # notification a freshly-built alarm would fire.
  def load_ring_time(time)
    @ring_time = time
    self
  end

  def time_label
    Utils::WallClock.default.then { |wallclock| wallclock.format_time(time_of_day_datetime(wallclock), false) }
  end

  def ring_time_label
    Utils::WallClock.default.then { |wallclock| wallclock.format_time(ruby_time_to_glib(ring_time, wallclock), false) }
  end

  def days_label = days ? days.label : nil

  def active? = !ring_time.nil?

  def active=(value)
    unless value == active?
      self.ring_time = (value ? next_ring_time : nil)
    end
    self.state = READY
  end

  def reset
    self.ring_time = next_ring_time
    self.state = READY
  end

  def snooze
    self.ring_time = ring_time + (snooze_minutes * 60)
    self.state = SNOOZING
  end

  def stop(missed: false)
    self.ring_time = (days.nil? || days.empty? ? nil : next_ring_time)
    self.state = missed ? MISSED : READY
  end

  # Upstream's tick: ring or stop depending on the current time. Returns
  # true when the state changed.
  def tick
    active? && state.then do |last_state|
      now = Time.now
      ring_end_time = ring_time + (ring_minutes * 60)

      if now > ring_end_time
        stop(missed: true)
      elsif state != RINGING && now > ring_time
        self.state = RINGING
      end

      state != last_state
    end
  end

  def duplicate_of?(other)
    hour == other.hour && minute == other.minute && active? && other.active?
  end

  def check_duplicate_alarm(alarms)
    alarms.any? { |item| duplicate_of?(item) }
  end

  def serialize
    {
      'name' => name,
      'id' => id,
      'hour' => hour,
      'minute' => minute,
      'ring_time' => ring_time&.iso8601,
      'days' => days ? days.serialize : Utils::Weekdays.new.serialize,
      'snooze_minutes' => snooze_minutes,
      'ring_minutes' => ring_minutes,
      'sound_uri' => sound_file.uri,
    }.compact
  end

  def on_active_changed(&block)
    @listeners[:active] << block
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

  # Upstream's `ring` signal, which the panel connects to so it can send the
  # system notification with the Stop/Snooze buttons; this item only rings
  # its own bell.
  def on_ring(&block)
    @listeners[:ring] << block
    self
  end

  private

    def ring_time=(value)
      unless value == @ring_time
        prev_active = active?
        @ring_time = value
        @listeners[:active].each { |listener| listener.call(active?) } unless prev_active == active?
      end
    end

    def state=(value)
      unless value == @state
        bell.stop if @state == RINGING
        @state = value
        ring if @state == RINGING
        @listeners[:state].each { |listener| listener.call(value) }
      end
    end

    def setup_bell
      @bell = Utils::Bell.new(sound_file&.path)
    end

    def bell = @bell ||= Utils::Bell.new(sound_file&.path)

    # Today's date with this alarm's hour and minute, as the wall clock's
    # own timezone sees it — for display only.
    def time_of_day_datetime(wallclock)
      now = wallclock.date_time
      GLib::DateTime.new(year: now.year, month: now.month, day: now.day_of_month, hour: hour, minute: minute, second: 0, timezone: wallclock.timezone)
    end

    def ruby_time_to_glib(time, wallclock)
      GLib::DateTime.new(year: time.year, month: time.month, day: time.day, hour: time.hour, minute: time.min, second: time.sec, timezone: wallclock.timezone)
    end

    # Monday-first weekday number (0 = Monday) for a Ruby Time, matching
    # Utils::Weekdays' indexing; Ruby's own Time#wday is Sunday-first.
    def weekday_index(time) = (time.wday + 6) % 7

    def next_ring_time
      now = Time.now
      candidate = Time.local(now.year, now.month, now.day, hour, minute, 0)

      if days.nil? || days.empty?
        candidate += 86_400 if candidate <= now
      else
        candidate += 86_400 while candidate <= now || !days[weekday_index(candidate)]
      end

      candidate
    end

    def ring
      bell.ring
      @listeners[:ring].each(&:call)
    end
end
