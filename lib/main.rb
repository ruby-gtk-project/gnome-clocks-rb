# frozen_string_literal: true

require 'adwaita'
require_relative 'clock'
require_relative 'settings'
require_relative 'utils'
require_relative 'widgets'
require_relative 'shortcuts_dialog'
require_relative 'header_bar'
require_relative 'stopwatch_lap'
require_relative 'stopwatch_laps_row'
require_relative 'stopwatch_face'
require_relative 'timer_item'
require_relative 'timer_row'
require_relative 'timer_setup'
require_relative 'timer_setup_dialog'
require_relative 'timer_face'
require_relative 'window'
require_relative 'gnome/clocks/rb/version'

# App is the application object: the actions and accelerators, the
# notifications it keeps track of so it can withdraw them again, and the one
# window it shows.
#
# Ported from upstream's src/main.vala and src/application.vala.
#
# Three things upstream's Application does are not here:
#
#   * Adw.Application is broken in the Ruby bindings, so the application
#     object is a Gtk::Application; every Adwaita widget still works inside
#     its window;
#   * dbus_register exports a search provider and the Shell's world clocks on
#     the session bus, which arrive with the World panel they serve;
#   * add-location deserializes a GWeather.Location out of a variant, which
#     also belongs to the World panel, as do its stop-alarm and snooze-alarm
#     actions, which exist for the buttons on an alarm's notification.
#
class App
  APP_ID = 'org.rubygtkproject.GnomeClocks'
  VERSION = Gnome::Clocks::Rb::VERSION

  # Upstream's ACTION_ENTRIES, with the accelerators its startup handler sets
  # for them.
  APP_ACTIONS = {
    'quit'      => ['<Control>q'],
    'shortcuts' => ['<Control>question'],
  }.freeze

  # Upstream sets this one on the window's own close action.
  WINDOW_CLOSE_ACCELS = ['<Control>w'].freeze

  def initialize(app_id: APP_ID, flags: :default_flags, settings: nil, present: true)
    @app_id = app_id
    @flags = flags
    @settings = settings || Settings.new
    @present = present
    @system_notifications = []
  end

  attr_reader :settings

  def build
    app.tap do |application|
      application.signal_connect('startup') do
        Utils.load_css
        install_actions
        install_accels
      end

      application.signal_connect('activate') do
        window.build
        # Upstream emits the wall clock's first tick by hand at startup, so an
        # alarm that should already be ringing is noticed immediately.
        Utils::WallClock.default.tick
        if @present
          window.present
        end
      end

      application.signal_connect('shutdown') { withdraw_notifications }
    end
  end

  def run(argv = ARGV)
    handle_local_options(argv).then do |handled|
      if handled
        0
      else
        app.run([])
      end
    end
  end

  # Upstream's send_notification override: every notification it sends is
  # remembered so the window can withdraw them when it comes back to focus.
  def send_notification(notification_id, notification)
    app.send_notification(notification_id, notification)
    unless @system_notifications.include?(notification_id)
      @system_notifications << notification_id
    end
    self
  end

  def withdraw_notifications
    @system_notifications.each { |notification_id| app.withdraw_notification(notification_id) }
    @system_notifications = []
    self
  end

  # Memoized widget methods

  # Adwaita::Application is broken in the Ruby bindings; the application
  # object comes from Gtk and only the window is Adwaita.
  def app = @app ||= Gtk::Application.new(@app_id, @flags)

  def window = @window ||= Window.new(app, settings: @settings, version: VERSION)

  private

    # Upstream's OPTION_ENTRIES has one entry, -v/--version, and its
    # handle_local_options prints the version and exits before the
    # application ever starts up.
    def handle_local_options(argv)
      Array(argv).then { |args| args.include?('--version') || args.include?('-v') }.then do |asked|
        if asked
          puts "Clocks #{VERSION}"
          true
        else
          false
        end
      end
    end

    def install_actions
      APP_ACTIONS.each_key { |name| app.add_action(simple_action(name)) }
      self
    end

    def simple_action(name)
      Gio::SimpleAction.new(name).tap do |action|
        action.signal_connect('activate') { activate_app_action(name) }
      end
    end

    def activate_app_action(name)
      case name
      when 'quit' then on_quit_activate
      when 'shortcuts' then window.shortcuts_dialog.present(window)
      end
    end

    def install_accels
      APP_ACTIONS.each { |name, accels| app.set_accels_for_action("app.#{name}", accels) }
      Window::ACTIONS.each { |name, accels| app.set_accels_for_action("win.#{name}", accels) }
      app.set_accels_for_action('window.close', WINDOW_CLOSE_ACCELS)
      self
    end

    # Upstream's on_quit_activate closes the window before quitting, so the
    # window gets to save its geometry.
    def on_quit_activate
      @window&.close
      app.quit
    end
end
