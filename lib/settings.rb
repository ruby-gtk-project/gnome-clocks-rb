# frozen_string_literal: true

require 'json'
require 'fileutils'

# Settings holds the same keys, defaults and semantics as upstream's three
# GSettings schemas in data/org.gnome.clocks.gschema.xml.in:
#
#   org.gnome.clocks               world-clocks, alarms, timers, geolocation
#   org.gnome.clocks.state.window  maximized, size, panel-id
#
# Upstream reaches them through GSettings, which needs a compiled schema
# installed into a glib-2.0/schemas directory before the app will even start —
# a GSettings miss is fatal, not an error a port can handle. Requiring an
# install step to run the app from a checkout is worse than the alternative, so
# the keys are backed by a JSON file under XDG_CONFIG_HOME instead, exactly as
# the pilot port does.
#
# The window state keys keep upstream's delayed-write behaviour: upstream calls
# GSettings.delay() in the window's constructor and apply() when it saves its
# geometry, so a resize in progress does not write once per frame. Here #remember
# is the apply.
#
class Settings
  DEFAULTS = {
    'world-clocks' => [],
    'alarms'       => [],
    'timers'       => [],
    'geolocation'  => true,
    'maximized'    => false,
    'width'        => 870,
    'height'       => 690,
    'panel-id'     => 'world',
  }.freeze

  def initialize(path: nil)
    @path = path || default_path
    @values = DEFAULTS.merge(read)
  end

  def location = @path

  def [](key) = @values.fetch(key.to_s, DEFAULTS[key.to_s])

  def []=(key, value)
    @values[key.to_s] = value
    write
    value
  end

  # Named accessors for every key, so callers do not repeat the strings.
  DEFAULTS.each_key do |key|
    method_name = key.tr('-', '_')
    define_method(method_name) { self[key] }
    define_method(:"#{method_name}=") { |value| self[key] = value }
  end

  def geolocation? = self['geolocation'] == true
  def maximized? = self['maximized'] == true

  # Upstream's Window.load_window_state: a maximized window is restored
  # maximized and its stored size is left alone.
  def apply_to(window)
    if maximized?
      window.maximize
    else
      window.set_default_size(self['width'], self['height'])
    end
    self
  end

  # Upstream's Window.save_window_state, including the debug line it logs.
  def remember(window)
    window.default_size.then do |width, height|
      @values['width'] = width
      @values['height'] = height
    end
    @values['maximized'] = window.maximized?
    write
    self
  end

  private

    def default_path
      File.join(
        ENV.fetch('XDG_CONFIG_HOME', File.expand_path('~/.config')),
        'ruby-clocks',
        'settings.json',
      )
    end

    def read
      File.exist?(@path) ? JSON.parse(File.read(@path)) : {}
    rescue JSON::ParserError => e
      warn "Error parsing #{@path}: #{e.message}"
      {}
    end

    def write
      FileUtils.mkdir_p(File.dirname(@path))
      File.write(@path, JSON.pretty_generate(@values))
    end
end
