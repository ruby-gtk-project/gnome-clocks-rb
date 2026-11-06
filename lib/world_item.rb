# frozen_string_literal: true

require 'adwaita'
require 'libgweather'
require 'date'
require_relative 'utils'
require_relative 'twilight'

# WorldItem is one world clock: a GWeather location, the current time there,
# and the twilight band its pill is coloured from.
#
# Ported from Clocks.World.Item in src/world-item.vala. Upstream recomputes
# everything on the shared wall clock's `tick` signal and notifies a handful
# of GObject properties afterwards; this port's listeners play the same role
# as the property-change notifications, since these items are not GObjects.
#
# Three deviations the Ruby bindings force:
#
#   * upstream converts GLib.DateTime between time zones with `to_timezone`,
#     which this binding does not expose. `GLib::DateTime.now(time_zone)`
#     reads the same instant directly in the target zone, which is all the
#     conversion here ever needed;
#   * the binding has no accessor for a DateTime's UTC offset or day-of-year,
#     so both come from `%z` and `%j` of `#format`, parsed by hand, the way
#     `format_time` already rewrites strftime output elsewhere in this port;
#   * `GWeather::Location#serialize`/`.deserialize` round-trip through a
#     GVariant this binding cannot hand back in, so a world clock survives a
#     restart as its coordinates, the way the pilot port's gnome-weather-rb
#     fork persists a `Location` — resolved back to a real `GWeather::Location`
#     with `find_nearest_city`, the same approximation upstream's own
#     `gweather_location_deserialize` falls back to for a station the
#     database has moved since it was saved.
#
class WorldItem
  NONE = :none
  NIGHT = :night
  ASTRO = :astro
  NAUT = :naut
  CIVIL = :civil
  DAY = :day

  STATE_CLASSES = [NONE, NIGHT, ASTRO, NAUT, CIVIL, DAY].freeze

  def self.deserialize(dictionary)
    dictionary['latitude'].then do |lat|
      lon = dictionary['longitude']
      next nil unless lat && lon

      GWeather::Location.world.find_nearest_city(lat.to_f, lon.to_f).then do |location|
        location && location.timezone ? new(location) : nil
      end
    end
  end

  def initialize(location)
    @location = location
    @automatic = false
    @time_zone = location.timezone
    @last_calc_day = nil
    @listeners = []
    tick
  end

  attr_reader :location
  attr_accessor :automatic
  attr_reader :date_time, :local_offset, :sun_state

  # Upstream's name/city_name/state_name/country_name: built from the
  # location and its parent administrative division every time, rather than
  # cached, since the location itself never changes underneath an item.
  def city_name = @location.city_name.to_s.empty? ? @location.name.to_s : @location.city_name.to_s

  def state_name
    parent = @location.parent
    parent && parent.level == GWeather::LocationLevel::ADM1 ? parent.name.to_s : nil
  end

  def country_name = @location.country_name

  def name
    if country_name
      state_name ? "#{city_name}, #{state_name}, #{country_name}" : "#{city_name}, #{country_name}"
    else
      city_name
    end
  end

  def sunrise_label = format_sun_label(@sun_rise)
  def sunset_label = format_sun_label(@sun_set)

  def time_label = Utils::WallClock.default.format_time(@date_time, false)
  def time_label_seconds = Utils::WallClock.default.format_time(@date_time, true)

  # Upstream's day_label: whether the location's calendar day is a day ahead
  # or behind the local one, ported with the same Jan-1/Dec-31 special case.
  def day_label
    d = @date_time.format('%j').to_i
    t = Utils::WallClock.default.date_time.format('%j').to_i

    if d < t
      d == 1 && t != 2 ? 'Tomorrow' : 'Yesterday'
    elsif d > t
      t == 1 && d != 2 ? 'Yesterday' : 'Tomorrow'
    end
  end

  def on_tick(&block)
    @listeners << block
    self
  end

  # Upstream's tick: rereads the wall clock, recomputes today's twilight
  # bands if the UTC day rolled over, and notifies.
  def tick
    local_time = Utils::WallClock.default.date_time
    @date_time = @time_zone ? GLib::DateTime.now(@time_zone) : local_time
    @local_offset = utc_offset_seconds(local_time) - utc_offset_seconds(@date_time)
    calculate_riseset
    @sun_state = compute_sun_state
    @listeners.each(&:call)
    self
  end

  # Upstream's serialize: an automatic (geolocated) item is never written,
  # since it is rediscovered on the next startup instead.
  def serialize
    @automatic ? {} : { 'latitude' => @location.coords.first, 'longitude' => @location.coords.last }
  end

  private

    def format_sun_label(date_time)
      date_time ? Utils::WallClock.default.format_time(date_time, false) : '-'
    end

    def utc_offset_seconds(date_time)
      date_time.format('%z').then do |offset|
        sign = offset.start_with?('-') ? -1 : 1
        sign * ((offset[1, 2].to_i * 3600) + (offset[3, 2].to_i * 60))
      end
    end

    def calculate_riseset
      day_of_year = @date_time.format('%j').to_i
      return if day_of_year == @last_calc_day
      return unless @location.has_coords?

      latitude, longitude = @location.coords
      return unless latitude.finite? && longitude.finite?

      utc_date = Date.new(@date_time.format('%Y').to_i, @date_time.format('%m').to_i, @date_time.format('%d').to_i)

      @sun_rise, @sun_set = riseset_at(latitude, longitude, utc_date, Utils::RISESET_CORRECTION_NONE)
      @civil_rise, @civil_set = riseset_at(latitude, longitude, utc_date, Utils::RISESET_CORRECTION_CIVIL)
      @naut_rise, @naut_set = riseset_at(latitude, longitude, utc_date, Utils::RISESET_CORRECTION_NAUTICAL)
      @astro_rise, @astro_set = riseset_at(latitude, longitude, utc_date, Utils::RISESET_CORRECTION_ASTRONOMICAL)

      @last_calc_day = day_of_year
    end

    def riseset_at(latitude, longitude, utc_date, correction)
      result = Twilight.calculate_sunrise_sunset(
        latitude, longitude, utc_date.year, utc_date.month, utc_date.day, correction,
      )
      return [nil, nil] unless result.calculable

      sunrise = utc_datetime(utc_date, result.rise_hour, result.rise_min)
      sunset = utc_datetime(utc_date, result.set_hour, result.set_min)
      sunset = utc_datetime(utc_date + 1, result.set_hour, result.set_min) if unix_seconds(sunset) < unix_seconds(sunrise)
      [sunrise, sunset]
    end

    def utc_datetime(date, hour, minute)
      GLib::DateTime.new(
        timezone: GLib::TimeZone.new('UTC'),
        year: date.year, month: date.month, day: date.day,
        hour: hour, minute: minute, second: 0,
      )
    end

    # Upstream's sun_state: the CSS class for the band `date_time` falls in,
    # from the widest correction (astronomical twilight) down to none, with
    # full daylight checked first.
    def compute_sun_state
      if @sun_rise.nil? || @sun_set.nil?
        NONE
      elsif current?(@sun_rise, @sun_set) then DAY
      elsif current?(@civil_rise, @civil_set) then CIVIL
      elsif current?(@naut_rise, @naut_set) then NAUT
      elsif current?(@astro_rise, @astro_set) then ASTRO
      else NIGHT
      end
    end

    def current?(rise, set)
      rise && set && unix_seconds(@date_time) > unix_seconds(rise) && unix_seconds(@date_time) < unix_seconds(set)
    end

    # The Ruby bindings give GLib::DateTime no comparison operator of its own
    # (`<=>` falls through to Kernel's identity-only default), so every
    # instant comparison in this class goes through Unix seconds instead.
    def unix_seconds(date_time) = date_time.format('%s').to_i
end
