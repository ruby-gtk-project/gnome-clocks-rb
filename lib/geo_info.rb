# frozen_string_literal: true

require 'gio2'
require 'libgweather'
require 'geocode-glib'

# GeoInfo finds the person's current city, the way Clocks.Geo.Info does in
# src/geocoding.vala: a GeoClue2 location fix, reverse-geocoded to a country
# code, then matched against the GWeather location tree.
#
# GeoClue2 is a D-Bus service, not a GObject-Introspection library — no Ruby
# gem binds it, and adding one is outside this port's declared gems — so the
# fix itself is fetched with a plain Gio::DBusConnection call, the same way
# upstream's GClue.Simple talks to the org.freedesktop.GeoClue2 service
# under the hood. What upstream does with the fix once it has one — turn
# coordinates into a country code — is the genuine, gemspec-declared
# `geocode-glib`: GeocodeGlib::Location wraps the fix and
# GeocodeGlib::Reverse#resolve is the real call upstream's
# `Geocode.Reverse.for_location(...).resolve_async` makes, here synchronous
# since there is no run loop to yield into outside of GTK's own.
#
# Every failure here — no GeoClue2 service, no network for the reverse-geocode
# lookup, no fix within GeoClue2's own timeout — is exactly what upstream's
# own try/catch around GClue.Simple and Geocode.Reverse treats as "no
# automatic location today": #seek returns nil rather than raising.
class GeoInfo
  BUS_NAME = 'org.freedesktop.GeoClue2'
  MANAGER_PATH = '/org/freedesktop/GeoClue2/Manager'
  MANAGER_IFACE = 'org.freedesktop.GeoClue2.Manager'
  CLIENT_IFACE = 'org.freedesktop.GeoClue2.Client'
  LOCATION_IFACE = 'org.freedesktop.GeoClue2.Location'
  PROPERTIES_IFACE = 'org.freedesktop.DBus.Properties'

  def initialize(app_id: 'org.gnome.clocks')
    @app_id = app_id
  end

  # The nearest GWeather::Location to the current fix, or nil when no
  # location could be determined.
  def seek
    fix.then { |latitude, longitude| latitude && nearest_city(latitude, longitude) }
  rescue StandardError => e
    warn "GeoInfo#seek: location lookup failed: #{e.message}"
    nil
  end

  private

  def connection = @connection ||= Gio.bus_get_sync(:session, nil)

  def call(bus_name, path, iface, method, params = nil)
    connection.call_sync(bus_name, path, iface, method, params, nil, :none, -1, nil)
  end

  def get_property(path, iface, property)
    call(BUS_NAME, path, PROPERTIES_IFACE, 'Get', GLib::Variant.parse("('#{iface}', '#{property}')")).first.first
  end

  def fix
    client_path = call(BUS_NAME, MANAGER_PATH, MANAGER_IFACE, 'GetClient').first

    call(
      BUS_NAME, client_path, PROPERTIES_IFACE, 'Set',
      GLib::Variant.parse("('#{CLIENT_IFACE}', 'DesktopId', <'#{@app_id}'>)"),
    )
    call(BUS_NAME, client_path, CLIENT_IFACE, 'Start')

    location_path = get_property(client_path, CLIENT_IFACE, 'Location')
    return [nil, nil] if location_path.nil? || location_path == '/'

    [
      get_property(location_path, LOCATION_IFACE, 'Latitude'),
      get_property(location_path, LOCATION_IFACE, 'Longitude'),
    ]
  end

  def nearest_city(latitude, longitude)
    country_code = reverse_geocode_country(latitude, longitude)
    GWeather::Location.world.find_nearest_city(latitude, longitude).then do |candidate|
      candidate && (country_code.nil? || candidate.country == country_code) ? candidate : nil
    end
  end

  # The genuine geocode-glib call: upstream's Geocode.Reverse resolving a
  # GeoClue2 fix to the country code it compares locations by.
  def reverse_geocode_country(latitude, longitude)
    GeocodeGlib::Reverse.new(GeocodeGlib::Location.new(latitude, longitude, 0)).resolve.country_code
  rescue StandardError => e
    warn "GeoInfo#reverse_geocode_country: reverse geocoding failed: #{e.message}"
    nil
  end
end
