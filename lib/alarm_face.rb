# frozen_string_literal: true

require 'adwaita'
require_relative 'clock'
require_relative 'settings'
require_relative 'utils'
require_relative 'widgets'
require_relative 'alarm_item'
require_relative 'alarm_row'
require_relative 'alarm_setup_dialog'

# AlarmFace is the Alarm panel: the empty state while there are no alarms,
# the list of alarms once there are, the toast telling the user how long
# until the alarm they just set or edited next rings, and the ticking that
# notices when one of them starts ringing.
#
# Ported from Clocks.Alarm.Face in src/alarm-face.vala and
# data/ui/alarm-face.ui.
#
# Upstream keeps its alarms in a Gtk.SortListModel wrapped around the store
# so a Gtk.ListBox can bind to it; this port sorts the store itself with the
# same Item.compare and rebuilds the rows, for the reason ContentStore
# documents.
#
# Upstream's `app.stop-alarm`/`app.snooze-alarm` actions, fired by the
# notification's own buttons, are installed here rather than on the
# application object, since they have nothing to do until this panel's
# ContentStore exists for them to look an alarm id up in.
class AlarmFace < Adwaita::Bin
  include Clock

  def initialize(settings: nil)
    super()
    @settings = settings || Settings.new
    @alarms = ContentStore.new
    @ring_time_toast = nil
    @ring_time_toast_alarm = nil
  end

  attr_reader :alarms

  def panel_id = PanelId::ALARM

  # Translators: Tooltip for the + button
  def new_label = 'New Alarm'

  def build
    tap do |face|
      face.child = stack

      stack.tap do |view_stack|
        view_stack.add_named(empty_view, 'empty')
        view_stack.add_named(list_view, 'list')
      end

      empty_view.child = empty_add_button

      list_view.child = list_clamp
      list_clamp.child = listbox

      install_alarm_actions

      alarms.on_items_changed do
        refresh_rows
        save
        reset_view
      end

      listbox.signal_connect('row-activated') { |_box, row| edit(row.alarm) }

      load

      reset_view

      Utils::WallClock.default.on_tick { tick }
    end
  end

  def activate_new
    dialog = AlarmSetupDialog.new(nil, alarms.to_a).tap(&:build)
    dialog.on_response do |response|
      if response == :add
        alarm = AlarmItem.new
        dialog.apply_to_alarm(alarm)
        alarms.add(alarm)
        connect_item(alarm)
        show_ring_time_toast(alarm)
        save
      end
      dialog.close
    end
    dialog.present(self)
    self
  end

  # Upstream's grab_focus override: with no alarms, the focus goes to the
  # empty state's own add button; the pilot port's panels name this
  # grab_focus_start, which the window calls on every panel switch.
  def grab_focus_start = alarms.n_items.zero? && empty_add_button.grab_focus

  # Memoized widget methods

  def stack
    @stack ||= Gtk::Stack.new.tap do |view_stack|
      view_stack.hhomogeneous = false
      view_stack.vhomogeneous = false
    end
  end

  def empty_view
    @empty_view ||= Adwaita::StatusPage.new.tap { |page| page.icon_name = 'alarm-centered-symbolic' }
  end

  def empty_add_button
    @empty_add_button ||= Gtk::Button.new(label: 'Add A_larm…').tap do |button|
      button.action_name = 'win.new'
      button.use_underline = true
      button.can_shrink = true
      button.halign = :center
      button.add_css_class('suggested-action')
      button.add_css_class('pill')
    end
  end

  def list_view = @list_view ||= Gtk::ScrolledWindow.new
  def list_clamp = @list_clamp ||= Adwaita::Clamp.new

  def listbox
    @listbox ||= Gtk::ListBox.new.tap do |list|
      list.valign = :start
      list.selection_mode = :none
      list.activate_on_single_click = true
      list.margin_top = 18
      list.margin_bottom = 18
      list.margin_start = 12
      list.margin_end = 12
      list.add_css_class('boxed-list')
    end
  end

  private

    def edit(alarm)
      dialog = AlarmSetupDialog.new(alarm, alarms.to_a).tap(&:build)
      dialog.on_response do |response|
        if response == :add
          dialog.apply_to_alarm(alarm)
          alarm.active = true
          save
        end
        dialog.close
      end
      dialog.on_delete do
        alarms.remove(alarm)
        save
        dialog.close
      end
      dialog.present(self)
      self
    end

    def reset_view
      stack.visible_child_name = alarms.n_items.zero? ? 'empty' : 'list'
      self.button_mode = ButtonMode::NEW
      self
    end

    def connect_item(alarm)
      alarm.on_active_changed do
        show_ring_time_toast(alarm)
        save
      end
      alarm
    end

    def load
      alarms.deserialize(@settings.alarms) { |values| AlarmItem.deserialize(values) }
      alarms.each { |alarm| connect_item(alarm) }
      self
    end

    def save = @settings.alarms = alarms.serialize

    def refresh_rows
      listbox.remove_all
      alarms.sort_items! { |first, second| AlarmItem.compare(first, second) }.each do |alarm|
        listbox.append(
          AlarmRow.new(alarm).tap do |row|
            row.build
            row.on_deleted { remove_alarm(alarm) }
          end,
        )
      end
      self
    end

    # Removing fires the store's items_changed listener installed in #build,
    # which saves and resets the view; only the pending toast needs handling
    # here.
    def remove_alarm(alarm)
      alarms.remove(alarm)
      if @ring_time_toast_alarm == alarm
        @ring_time_toast_alarm = nil
        @ring_time_toast&.dismiss
      end
      self
    end

    # Upstream's show_ring_time_toast: how long until the alarm next rings,
    # rounded up to the next whole minute.
    def show_ring_time_toast(alarm)
      alarm.ring_time && window.then do |win|
        if win
          seconds_left = [alarm.ring_time - Time.now, 0].max
          minutes_left = Utils.ceil_time_span((seconds_left * Utils::SECOND).to_i, Utils::MINUTE) / Utils::MINUTE
          time_left_string = minutes_left == 1 ? '1 minute' : "#{minutes_left} minutes"

          @ring_time_toast&.dismiss
          @ring_time_toast = Adwaita::Toast.new("Alarm set for #{time_left_string} from now")
          @ring_time_toast_alarm = alarm
          win.add_toast(@ring_time_toast)
        end
      end
      self
    end

    def window = root

    def install_alarm_actions
      application.then do |app|
        if app
          install_alarm_action(app, 'stop-alarm') { |alarm| alarm.stop }
          install_alarm_action(app, 'snooze-alarm') { |alarm| alarm.snooze }
        end
      end
      self
    end

    def install_alarm_action(app, name, &block)
      action = Gio::SimpleAction.new(name, GLib::VariantType.new('s'))
      action.signal_connect('activate') do |_action, parameter|
        alarms.find_item { |alarm| alarm.id == parameter.to_s }.then { |alarm| block.call(alarm) if alarm }
      end
      app.add_action(action)
      self
    end

    def application = Gio::Application.default

    # Upstream's tick handler: every alarm advances its own state, and a
    # newly-ringing one gets a system notification alongside its bell.
    def tick
      alarms.each do |alarm|
        ring(alarm) if alarm.tick && alarm.state == AlarmItem::RINGING
      end
      self
    end

    def ring(alarm)
      application.then { |app| app.send_notification("alarm-#{alarm.id}", notification_for(alarm)) if app }
      self
    end

    def notification_for(alarm)
      Gio::Notification.new(alarm.name.to_s.empty? ? 'Alarm' : alarm.name).tap do |message|
        message.body = alarm.time_label
        message.priority = :urgent
        message.add_button_with_target('Stop', 'app.stop-alarm', alarm.id)
        message.add_button_with_target('Snooze', 'app.snooze-alarm', alarm.id)
      end
    end
end
