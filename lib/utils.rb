# frozen_string_literal: true

require 'adwaita'

# Utils holds the pieces the panels share: the wall clock every face ticks
# from, the time and duration formatters, the weekday set alarms repeat on,
# the bell the timer rings, and the stylesheet.
#
# Ported from upstream's src/utils.vala together with the two helpers it
# declares `extern` and implements in src/cutils.c — `format_time_span` and
# `get_week_start` — plus data/css/gnome-clocks.css, which upstream ships in
# its GResource and loads from the application's startup handler.
#
# Three deliberate deviations from upstream:
#
#   * upstream's WallClock wraps Gnome.WallClock from libgnome-desktop, which
#     has no Ruby binding; this one drives itself off a GLib timeout realigned
#     to the next minute (or second) boundary after every tick, which is what
#     libgnome-desktop does internally;
#   * upstream reads the system clock format from the org.freedesktop.portal
#     Settings interface and only falls back to GSettings; there is no portal
#     binding in ruby-gnome, so this port reads org.gnome.desktop.interface
#     directly — the fallback path upstream keeps for the same purpose;
#   * `format_time_span` is built on ICU's number formatter in cutils.c. ICU
#     has no Ruby binding either, so the unit names and the "and" join are
#     spelled out here; the output is the same shape ("1 hour and 5 minutes",
#     abbreviated "1 h 5 min").
#
module Utils
  # The solar depression angles upstream passes to calculate_sunrise_sunset to
  # get the four twilight bands the world clock pills are coloured from.
  RISESET_CORRECTION_NONE = 0.0
  RISESET_CORRECTION_CIVIL = 6.0
  RISESET_CORRECTION_NAUTICAL = 12.0
  RISESET_CORRECTION_ASTRONOMICAL = 18.0

  CLOCK_FORMAT_SCHEMA = 'org.gnome.desktop.interface'
  CLOCK_FORMAT_PROPERTY_NAME = 'clock-format'

  # GLib.TimeSpan is microseconds, and so are the spans in this port.
  MICROSECOND = 1
  MILLISECOND = 1000
  SECOND = 1_000_000
  MINUTE = 60 * SECOND
  HOUR = 60 * MINUTE
  DAY = 24 * HOUR

  # Replacements upstream applies to every formatted time: the colon becomes a
  # RATIO preceded by a LEFT-TO-RIGHT MARK so the digits never reorder, and in
  # 12-hour locales the space before AM/PM becomes a THIN SPACE.
  LTR_MARK = "‎"
  RATIO = "∶"
  THIN_SPACE = " "

  # A direct port of data/css/gnome-clocks.css.
  STYLESHEET = <<~CSS
    /* Shared */

    .large-button {
      padding: 6px;
    }

    /* alarms */

    .alarm-time {
      font-size: 2.5em;
      font-weight: 300;
    }

    .clocks-ampm-toggle-button,
    .clocks-secondary-standalone-label {
      font-size: 18pt;
    }

    .clocks-standalone-label,
    .clocks-ringing-label {
      font-size: 6em;
      font-weight: 300;
    }

    .clocks-standalone-label-small {
      font-size: 4.0em;
      font-weight: 300;
    }

    .clocks-ringing-title {
      font-size: 1.5em;
      font-weight: bold;
    }

    .clocks-alarm-setup-time {
      font-size: 32pt;
    }

    /* Timer Panel */

    .clocks-timer-label {
      font-size: 48pt;
    }

    .clocks-spinbutton {
      font-size: 42pt;
    }

    .clocks-spinbutton > text {
      padding: 0px 7px;
    }

    .timer-countdown {
      font-size: 40pt;
      font-weight: 300;
    }

    /* Stopwatch Panel */

    .lap-time {
      font-weight: bold;
    }

    .stopped-stopwatch label,
    .running-stopwatch label,
    .paused-stopwatch label {
      font-size: 70px;
      font-weight: lighter;
    }

    .stopped-stopwatch .seconds-label,
    .running-stopwatch .seconds-label,
    .paused-stopwatch .seconds-label {
      font-weight: 300;
    }

    .running-stopwatch .seconds-label,
    .running-stopwatch .milliseconds-label {
      color: var(--accent-color);
    }

    .stopped-stopwatch .milliseconds-label,
    .running-stopwatch .milliseconds-label,
    .paused-stopwatch .milliseconds-label {
      font-size: 50px;
    }

    /* World */

    .clock-location {
      font-weight: bolder;
    }

    .hidden {
      opacity: 0;
    }

    .clock-time {
      font-size: 2em;
      padding: 0.2em 0.5em;
      border-radius: 1em;
      color: oklab(from var(--pill-color) var(--standalone-color-oklab));
      background-color: color-mix(in srgb, var(--pill-color) 25%, transparent);
    }

    @media (prefers-contrast: more) {
      .clock-time {
        font-weight: bold;
      }
    }

    .none {
      --pill-color: var(--card-fg-color);
    }

    .night {
      --pill-color: var(--blue-3);
    }

    .naut, .astro {
      --pill-color: var(--orange-3);
    }

    .civil, .day {
      --pill-color: var(--yellow-5);
    }
  CSS

  # Splits a number of seconds into hours, minutes, whole seconds and the
  # sub-second remainder, the way upstream's time_to_hms hands four out
  # parameters back to its callers.
  def self.time_to_hms(seconds)
    [(seconds / 3600).to_i, ((seconds % 3600) / 60).to_i, (seconds % 60).to_i,
     (seconds % 60) - (seconds % 60).to_i,]
  end

  # Rounds a span away from zero to the next whole unit: a 61-second span
  # ceiled to minutes is two minutes, which is what the alarm list means by
  # "rings in 2 minutes".
  def self.ceil_time_span(time_span, unit)
    time_span.abs.then do |span|
      unit.abs.then do |step|
        (span % step).then { |remainder| span - remainder + (remainder.positive? ? step : 0) }
      end
    end
  end

  UNITS = [
    [DAY, Float::INFINITY, 'day', 'd'],
    [HOUR, 24, 'hour', 'h'],
    [MINUTE, 60, 'minute', 'min'],
    [SECOND, 60, 'second', 's'],
    [MILLISECOND, 1000, 'millisecond', 'ms'],
    [MICROSECOND, 1000, 'microsecond', 'µs'],
  ].freeze

  # Upstream's clocks_cutils_format_time_span: the span is named by its
  # largest non-zero unit and every smaller non-zero unit after it, with the
  # count of the largest unit rounded to an integer.
  def self.format_time_span(time_span, abbreviated)
    time_span.abs.then do |span|
      UNITS.select { |unit, limit, _, _| (span / unit) % (limit.infinite? ? span + 1 : limit) >= 1 }
           .then { |units| units.empty? ? [UNITS.last] : units }
           .then { |units| format_span_segments(span, units, abbreviated) }
    end
  end

  # The segments of a formatted span: the first unit carries the rounded
  # count, every following unit carries its own remainder count.
  def self.format_span_segments(span, units, abbreviated)
    units.each_with_index.map do |(unit, limit, name, symbol), index|
      (index.zero? ? (span.to_f / unit).round : (span / unit) % limit).then do |count|
        abbreviated ? "#{count}#{THIN_SPACE}#{symbol}" : "#{count} #{count == 1 ? name : "#{name}s"}"
      end
    end.then { |segments| abbreviated ? segments.join(' ') : segments.join(' and ') }
  end

  # Upstream's get_time_difference_message: how far a world clock's timezone
  # is from the local one, in whole, half or quarter hours.
  def self.time_difference_message(offset)
    (offset.to_f / HOUR).then do |diff|
      format_hour_difference(diff).then do |diff_string|
        if diff.positive?
          diff.abs.to_i == 1 ? "#{diff_string} hour behind" : "#{diff_string} hours behind"
        elsif diff.negative?
          diff.abs.to_i == 1 ? "#{diff_string} hour ahead" : "#{diff_string} hours ahead"
        else
          'Current timezone'
        end
      end
    end
  end

  # Whole hours get no decimals, half hours get one, anything else two.
  def self.format_hour_difference(diff)
    if diff == diff.round
      format('%.0f', diff.abs)
    elsif diff * 2 == (diff * 2).round
      format('%.1f', diff.abs)
    else
      format('%.2f', diff.abs)
    end
  end

  # Upstream's list_model_contains, which it needs because GListModel has no
  # "contains" of its own.
  def self.list_model_contains?(model, object)
    model.n_items.times.any? { |index| model.get_item(index).equal?(object) }
  end

  # Upstream loads its stylesheet from the GResource bundle at startup; here
  # the rules travel in STYLESHEET and are added to the default display once.
  def self.load_css
    @css_provider ||= Gtk::CssProvider.new.tap do |provider|
      provider.load_from_string(STYLESHEET)
      Gtk::StyleContext.add_provider_for_display(
        Gdk::Display.default,
        provider,
        Gtk::StyleProvider::PRIORITY_APPLICATION,
      )
    end
  end

  # WallClock is the single clock every face and item reads the time from, so
  # a minute boundary moves the whole app at once.
  #
  # Ported from Utils.WallClock in src/utils.vala.
  class WallClock
    TWELVE = :twelve
    TWENTYFOUR = :twentyfour

    def self.default = @default ||= new

    attr_reader :date_time, :timezone, :format

    def initialize
      @timezone = GLib::TimeZone.new(nil)
      @format = read_format
      @seconds_precision = false
      @listeners = []
      watch_format
      update
      schedule
    end

    # Upstream mirrors this straight onto Gnome.WallClock's force_seconds; the
    # world standalone page turns it on so its clock counts seconds.
    attr_reader :seconds_precision

    def seconds_precision=(value)
      unless value == @seconds_precision
        @seconds_precision = value
        reschedule
      end
    end

    # Upstream's `tick` signal. Items connect to it in their constructors and
    # never disconnect, so plain blocks are enough.
    def on_tick(&block)
      @listeners << block
      self
    end

    # Upstream emits tick by hand once at startup so an alarm that should
    # already be ringing is noticed before the first timeout fires.
    def tick
      update
      @listeners.each(&:call)
      self
    end

    # Upstream's format_time: the system clock format decides whether the hour
    # is 12- or 24-hour, and the separators are rewritten afterwards because
    # strftime may fail on the replacement characters in some locales.
    def format_time(date_time, seconds)
      date_time.format(time_format(seconds))
               .gsub(':', "#{LTR_MARK}#{RATIO}")
               .then { |time| @format == TWELVE ? time.tr(' ', THIN_SPACE) : time }
    end

    private

      def time_format(seconds)
        if seconds
          @format == TWELVE ? '%I:%M:%S %p' : '%H:%M:%S'
        else
          @format == TWELVE ? '%I:%M %p' : '%H:%M'
        end
      end

      def update
        @timezone = GLib::TimeZone.new(nil)
        @date_time = GLib::DateTime.now(@timezone)
      end

      def settings = @settings ||= Gio::Settings.new(CLOCK_FORMAT_SCHEMA)

      def read_format
        settings.get_string(CLOCK_FORMAT_PROPERTY_NAME) == '12h' ? TWELVE : TWENTYFOUR
      end

      def watch_format
        settings.signal_connect("changed::#{CLOCK_FORMAT_PROPERTY_NAME}") do
          @format = read_format
          tick
        end
      end

      # The next boundary rather than a fixed interval, so the displayed
      # minute changes when the minute does.
      def schedule
        @timeout_id = GLib::Timeout.add(milliseconds_to_boundary) do
          @timeout_id = nil
          tick
          schedule
          GLib::Source::REMOVE
        end
      end

      def reschedule
        GLib::Source.remove(@timeout_id) if @timeout_id
        @timeout_id = nil
        schedule
      end

      def milliseconds_to_boundary
        (@seconds_precision ? 1 : 60).then do |step|
          Time.now.then { |now| ((step - (now.to_f % step)) * 1000).ceil }
        end
      end
  end

  # Weekdays is the set of days an alarm repeats on, Monday first.
  #
  # Ported from Utils.Weekdays in src/utils.vala, including its ISO 8601
  # serialisation: a GSettings `ai` of day numbers where Monday is 1 and
  # Sunday is 7.
  class Weekdays
    MON = 0
    TUE = 1
    WED = 2
    THU = 3
    FRI = 4
    SAT = 5
    SUN = 6

    DAYS = [MON, TUE, WED, THU, FRI, SAT, SUN].freeze

    WEEKDAYS = [true, true, true, true, true, false, false].freeze
    WEEKENDS = [false, false, false, false, false, true, true].freeze
    NONE = [false, false, false, false, false, false, false].freeze
    ALL = [true, true, true, true, true, true, true].freeze

    # Upstream's Day.symbol: the single letter the alarm repeat toggles carry,
    # each with its own translation context so locales can disambiguate the
    # two Tuesdays-and-Thursdays style collisions.
    SYMBOLS = %w[M T W T F S S].freeze

    # Upstream's Day.plural, the label a once-a-week alarm shows.
    PLURALS = %w[Mondays Tuesdays Wednesdays Thursdays Fridays Saturdays Sundays].freeze

    # Upstream formats the abbreviation and the full name out of the first
    # seven days of year 1, which happen to run Monday to Sunday.
    def self.day_time(day) = GLib::DateTime.new(year: 1, month: 1, day: day + 1, hour: 0, minute: 0, second: 0)
    def self.abbreviation(day) = day_time(day).format('%a')
    def self.name(day) = day_time(day).format('%A')
    def self.symbol(day) = SYMBOLS[day]
    def self.plural(day) = PLURALS[day]

    # Upstream's Day.get_first_weekday, which asks cutils for the locale's
    # week start (0 is Sunday there) and rotates it into Monday-first space.
    def self.first_weekday = (week_start + 6) % 7

    # cutils reads this out of the locale with nl_langinfo(_NL_TIME_FIRST_WEEKDAY);
    # Ruby reaches the same libc call through Fiddle. A locale that does not
    # answer leaves the week starting on Sunday, as it does upstream.
    def self.week_start
      @week_start ||= read_week_start
    end

    def self.read_week_start
      require 'fiddle'
      Fiddle::Function.new(
        Fiddle::Handle::DEFAULT['nl_langinfo'],
        [Fiddle::TYPE_INT],
        Fiddle::TYPE_VOIDP,
      ).then do |nl_langinfo|
        # _NL_TIME_FIRST_WEEKDAY is 1 for Sunday, and _NL_TIME_WEEK_1STDAY
        # names the day that count starts from.
        nl_langinfo.call(0x2_0000).to_str(1).unpack1('C').then do |first_weekday|
          nl_langinfo.call(0x2_0001).to_i.then do |week_origin|
            ((week_origin == 19_971_201 ? 1 : 0) + first_weekday - 1) % 7
          end
        end
      end
    rescue StandardError, LoadError => e
      warn "Could not read the locale's first weekday: #{e.message}"
      0
    end

    def self.deserialize(days_variant)
      new.tap do |weekdays|
        Array(days_variant).each do |day|
          if day.is_a?(Integer) && day.positive? && day <= 7
            weekdays[day - 1] = true
          else
            warn "Invalid days #{day}"
          end
        end
      end
    end

    def initialize = @days = NONE.dup

    def [](day) = @days[day]
    def []=(day, on)
      @days[day] = on
    end

    def empty? = @days == NONE
    def weekdays? = @days == WEEKDAYS
    def weekends? = @days == WEEKENDS
    def all? = @days == ALL

    # Upstream's get_label: a single day is named in the plural, the two
    # canonical sets have names of their own, and anything else is a list of
    # abbreviations starting at the locale's first weekday.
    def label
      DAYS.count { |day| self[day] }.then do |selected|
        if selected.zero? then ''
        elsif selected == 1 then Weekdays.plural(DAYS.find { |day| self[day] })
        elsif selected == 7 then 'Every Day'
        elsif weekdays? then 'Weekdays'
        elsif weekends? then 'Weekends'
        else abbreviation_list
        end
      end
    end

    # Serialised the way upstream does, as ISO 8601 day numbers.
    def serialize = DAYS.select { |day| self[day] }.map { |day| day + 1 }

    private

      def abbreviation_list
        DAYS.map { |offset| (Weekdays.first_weekday + offset) % 7 }
            .select { |day| self[day] }
            .map { |day| Weekdays.abbreviation(day) }
            .join(', ')
      end
  end

  # Bell plays one sound file, once or on a loop, and stops it again.
  #
  # Ported from Utils.Bell in src/utils.vala. The Ruby bindings expose no
  # Gtk.MediaFile.for_file constructor, so the file is assigned to a plain
  # Gtk::MediaFile instead — the same object upstream ends up with.
  class Bell
    def initialize(path)
      @path = path
      warn 'Sound is missing' unless path && File.exist?(path)
    end

    attr_reader :path

    def ring_once = ring_real(false)
    def ring = ring_real(true)

    def stop
      @media_file&.tap do |media_file|
        media_file.playing = false
        media_file.clear
      end
      @media_file = nil
    end

    private

      def ring_real(repeat)
        (@path && File.exist?(@path)).then do |playable|
          if playable
            @media_file = Gtk::MediaFile.new.tap do |media_file|
              media_file.filename = @path
              media_file.loop = repeat
              media_file.signal_connect('notify::prepared') do
                warn 'Invalid sound' unless media_file.has_audio?
              end
              media_file.play
            end
          end
        end
      end
  end
end
