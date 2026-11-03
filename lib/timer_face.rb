# frozen_string_literal: true

require 'adwaita'
require_relative 'clock'
require_relative 'settings'
require_relative 'utils'
require_relative 'widgets'
require_relative 'timer_item'
require_relative 'timer_row'
require_relative 'timer_setup'
require_relative 'timer_setup_dialog'

# TimerFace is the Timer panel: the setup pane while there are no timers, the
# list of timers once there are, and the bell and notification when one of
# them reaches zero.
#
# Ported from Clocks.Timer.Face in src/timer-face.vala and
# data/ui/timer-face.ui.
#
# Upstream keeps its timers in a Gtk.SortListModel wrapped around the store so
# a Gtk.ListBox can bind to it; this port sorts the store itself with the same
# Item.compare and rebuilds the rows, for the reason ContentStore documents.
#
class TimerFace < Adwaita::Bin
  include Clock

  SOUND = 'complete.oga'

  def initialize(settings: nil)
    super()
    @settings = settings || Settings.new
    @timers = ContentStore.new
    @is_running = false
    @running_listeners = []
  end

  attr_reader :timers, :is_running

  def panel_id = PanelId::TIMER

  # Translators: Tooltip for the + button
  def new_label = 'New Timer'

  def build
    tap do |face|
      face.child = stack

      stack.tap do |view_stack|
        view_stack.add_named(empty_page, 'empty')
        view_stack.add_named(timers_page, 'timers')

        empty_page.child = empty_box

        empty_box.tap do |box|
          box.append(timer_bin)
          box.append(start_button)

          timer_bin.child = timer_setup.build

          start_button.signal_connect('clicked') { start_new_timer }
        end

        timers_page.child = timers_clamp
        timers_clamp.child = timers_list
      end

      timer_setup.tap do |setup|
        setup.on_duration_changed { |duration| start_button.sensitive = !duration.zero? }
        setup.on_start_timer { start_new_timer }
      end

      start_button.sensitive = false

      # Upstream's items_changed handler: the panel swaps between its two
      # pages, offers the + button only when there is a list to add to, and
      # saves on every change.
      timers.on_items_changed do
        stack.visible_child_name = timers.n_items.positive? ? 'timers' : 'empty'
        self.button_mode = timers.n_items.positive? ? ButtonMode::NEW : ButtonMode::NONE
        refresh_rows
        save
        self.is_running = !active_timers.zero?
      end

      stack.visible_child_name = 'empty'

      load
    end
  end

  # Upstream's window watches the panel's `is-running` property to put the
  # needs-attention dot on the timer page.
  def on_is_running_changed(&block)
    @running_listeners << block
    self
  end

  # Upstream's activate_new: win.new opens the New Timer dialog, and the timer
  # it describes starts as soon as the dialog is done.
  def activate_new
    TimerSetupDialog.new.tap do |dialog|
      dialog.build
      dialog.on_done do |finished|
        add_timer(finished.timer_setup.timer)
        finished.close
      end
      dialog.present(self)
    end
  end

  # Upstream's escape_pressed: Escape pauses every running timer, and is only
  # consumed when there was one to pause.
  def escape_pressed
    timers.select { |timer| timer.state == TimerItem::RUNNING }
          .each { |timer| timer.state = TimerItem::PAUSED }
          .then { |paused| !paused.empty? }
  end

  # Upstream's grab_focus override: with no timers, the focus goes to the
  # start button under the setup pane.
  def grab_focus_start = timers.n_items.zero? && start_button.grab_focus

  # Upstream's `ring` signal handler: a notification unless the window has the
  # focus, and the bell either way.
  def ring
    window.then do |win|
      application.then do |app|
        app.send_notification('timer-is-up', notification) if app && !win&.active?
      end
    end
    bell.ring_once
    self
  end

  def add_timer(item)
    timers.add(item)
    connect_item(item)
    item.state = TimerItem::RUNNING
    item
  end

  def remove_timer(item)
    item.stop_countdown
    timers.remove(item)
  end

  # Memoized widget methods

  def stack
    @stack ||= Adwaita::ViewStack.new.tap { |view_stack| view_stack.add_css_class('timer-panel') }
  end

  def empty_page
    @empty_page ||= Gtk::ScrolledWindow.new.tap { |sw| sw.hscrollbar_policy = :never }
  end

  def empty_box
    @empty_box ||= Gtk::Box.new(:vertical, 26).tap do |box|
      box.halign = :center
      box.valign = :center
    end
  end

  def timer_bin = @timer_bin ||= Adwaita::Bin.new
  def timer_setup = @timer_setup ||= TimerSetup.new

  def start_button
    @start_button ||= Gtk::Button.new(label: 'St_art').tap do |button|
      button.halign = :center
      button.valign = :center
      button.use_underline = true
      button.add_css_class('pill')
      button.add_css_class('suggested-action')
    end
  end

  def timers_page = @timers_page ||= Gtk::ScrolledWindow.new
  def timers_clamp = @timers_clamp ||= Adwaita::Clamp.new

  def timers_list
    @timers_list ||= Gtk::ListBox.new.tap do |list|
      list.valign = :start
      list.selection_mode = :none
      list.activate_on_single_click = false
      list.margin_top = 18
      list.margin_bottom = 18
      list.margin_start = 12
      list.margin_end = 12
      list.add_css_class('boxed-list')
    end
  end

  # Upstream rings resource:///org/gnome/clocks/sounds/complete.oga; the same
  # file travels in this port's data/sounds directory.
  def bell = @bell ||= Utils::Bell.new(TimerFace.sound_path)

  def self.sound_path
    File.expand_path(File.join(__dir__, '..', 'data', 'sounds', SOUND))
  end

  def notification
    @notification ||= Gio::Notification.new('Time is up!').tap do |message|
      message.body = 'Timer countdown finished'
      message.priority = :high
    end
  end

  private

    def is_running=(value) # rubocop:disable Naming/PredicateName
      unless value == @is_running
        @is_running = value
        @running_listeners.each { |listener| listener.call(value) }
      end
    end

    def active_timers = timers.count { |timer| timer.state == TimerItem::RUNNING }

    def start_new_timer = add_timer(timer_setup.timer)

    # Upstream connects every timer, restored or new, to the same handlers:
    # its name is saved, its ring is the panel's ring, and a change to its
    # state or duration reorders the list.
    def connect_item(item)
      item.on_name_changed { save }
      item.on_ring { ring }
      item.on_state_changed do
        self.is_running = !active_timers.zero?
        resort
      end
      item
    end

    def resort = timers.sort_items! { |first, second| TimerItem.compare(first, second) }

    def load
      timers.deserialize(@settings.timers) { |values| TimerItem.deserialize(values) }
      timers.each { |item| connect_item(item) }
      resort
    end

    def save = @settings.timers = timers.serialize

    def refresh_rows
      timers_list.remove_all
      timers.each do |item|
        timers_list.append(
          TimerRow.new(item).tap do |row|
            row.build
            row.on_deleted { remove_timer(item) }
          end,
        )
      end
      self
    end

    def window = root

    def application = Gio::Application.default
end
