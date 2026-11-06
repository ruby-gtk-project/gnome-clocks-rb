# frozen_string_literal: true

# Twilight calculates sunrise and sunset for a place and date, adjusted for
# one of four twilight corrections, so the World panel can colour a clock's
# pill by whether it is day, night or in one of the twilight bands there.
#
# Ported from calculate_sunrise_sunset in src/twilight.c, itself based on
# https://en.wikipedia.org/wiki/Sunrise_equation and the equations from
# "Practical Astronomy with your Calculator or Spreadsheet", 4th edition, by
# Peter Duffett-Smith and Jonathan Zwart. Arguments and results are all UTC,
# exactly as upstream documents.
#
module Twilight
  JULIAN_YEAR_2000 = 2_451_545

  Result = Struct.new(:rise_hour, :rise_min, :set_hour, :set_min, :calculable)

  def self.radians(degrees) = degrees * Math::PI / 180.0
  def self.degrees(radians) = radians * 180.0 / Math::PI

  # Upstream uses meteorological seasons, which need no solstice, to decide
  # whether the polar-circle short-circuit below applies. Ported verbatim,
  # including the C source's own asymmetry between the two checks: the
  # "winter" condition can never be true for a 1-indexed month, so in
  # practice only the summer branch of the short-circuit ever fires.
  def self.north_summer?(month) = 6 >= month && month <= 8
  def self.north_winter?(month) = (1 >= month + 1) && (month + 1 <= 3)

  # Upstream's calculate_sunrise_sunset: true and the four out-parameters when
  # the sun actually rises and sets that day at that latitude, false (with the
  # full-day placeholder upstream also returns) when the pole is in
  # permanent day or night.
  def self.calculate_sunrise_sunset(lat, lon, year, month, day, correction)
    julian_day_number = ((1461 * (year + 4800 + ((month - 14) / 12))) / 4) +
                         ((367 * (month - 2 - (12 * ((month - 14) / 12)))) / 12) -
                         ((3 * ((year + 4900 + ((month - 14) / 12)) / 100)) / 4) +
                         day - 32_075

    n = julian_day_number - JULIAN_YEAR_2000 + 0.0008
    j = n - (lon / 360)
    m = (357.5291 + (0.98560028 * j)) % 360.0
    c = (1.9148 * Math.sin(radians(m))) +
        (0.0200 * Math.sin(radians(2 * m))) +
        (0.0003 * Math.sin(radians(3 * m)))
    l = (m + c + 180 + 102.9372) % 360.0
    j_transit = j + JULIAN_YEAR_2000 + (0.0053 * Math.sin(radians(m))) - (0.0069 * Math.sin(radians(2 * l)))
    d = degrees(Math.asin(Math.sin(radians(l)) * Math.sin(radians(23.55))))

    if polar_short_circuit?(lat, d, correction, month)
      Result.new(0, 0, 23, 59, false)
    else
      rise_set_from_transit(lat, d, correction, j_transit)
    end
  end

  def self.polar_short_circuit?(lat, d, correction, month)
    ((north_summer?(month) && (lat <= d + 0.83 + correction - 90)) || (lat >= 90 - d - 0.83 - correction)) ||
      ((north_winter?(month) && (lat <= -90 - d - 0.83 - correction)) || (lat >= 90 + d + 0.83 + correction))
  end
  private_class_method :polar_short_circuit?

  def self.rise_set_from_transit(lat, d, correction, j_transit)
    w = degrees(Math.acos(
      ((Math.sin(radians(-correction)) + Math.sin(radians(-0.83))) -
        (Math.sin(radians(lat)) * Math.sin(radians(d)))) /
        (Math.cos(radians(lat)) * Math.cos(radians(d))),
    ))

    j_sunrise = j_transit - (w / 360) - 0.5
    j_sunset = j_transit + (w / 360) - 0.5

    Result.new(*hour_and_minute(j_sunrise), *hour_and_minute(j_sunset), true)
  end
  private_class_method :rise_set_from_transit

  # Upstream's modf-based decomposition of a Julian date into the hour and
  # minute of its time-of-day component, truncated rather than rounded, the
  # same way the C `modf` calls upstream uses are.
  def self.hour_and_minute(julian_date)
    days_fraction = julian_date - julian_date.floor
    hours = days_fraction * 24
    hour = hours.floor
    minute = ((hours - hour) * 60).floor
    [hour, minute]
  end
  private_class_method :hour_and_minute
end
