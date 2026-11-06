# frozen_string_literal: true

require 'adwaita'
require_relative 'utils'

# WorldLocationDialogRow is one search result in the Add World Clock dialog:
# the city and country, the time zone's offset from local time, and the
# checkmark that shows once it is the selected result.
#
# Ported from Clocks.World.LocationDialogRow in src/world-location-dialog-row.vala
# and data/ui/world-location-dialog-row.ui.
#
class WorldLocationDialogRow < Gtk::ListBoxRow
  def initialize(location, selected: false)
    super()
    @location = location
    @selected = selected
    self.selectable = false
    self.sensitive = !selected
  end

  attr_reader :location
  attr_reader :selected

  def selected=(value)
    @selected = value
    self.sensitive = !value
    icon.visible = value
    self
  end

  def build
    tap do |row|
      row.child = box

      box.tap do |container|
        container.append(text_box)
        container.append(icon)

        text_box.tap do |column|
          column.append(heading_box)
          column.append(description_label)

          heading_box.tap do |line|
            line.append(name_label)
            line.append(location_label)
          end
        end
      end

      icon.visible = @selected
    end
  end

  # Memoized widget methods

  def box
    @box ||= Gtk::Box.new(:horizontal, 0).tap do |b|
      b.margin_top = 12
      b.margin_bottom = 12
      b.margin_start = 12
      b.margin_end = 12
    end
  end

  def text_box
    @text_box ||= Gtk::Box.new(:vertical, 6).tap do |b|
      b.hexpand = true
    end
  end

  def heading_box = @heading_box ||= Gtk::Box.new(:horizontal, 10)

  def name_label
    @name_label ||= Gtk::Label.new(@location.name.to_s).tap do |label|
      label.ellipsize = :end
      label.xalign = 0
      label.yalign = 1
      label.add_css_class('title')
    end
  end

  def location_label
    @location_label ||= Gtk::Label.new(@location.country_name.to_s).tap do |label|
      label.xalign = 0
      label.yalign = 1
      label.add_css_class('heading')
    end
  end

  def description_label
    @description_label ||= Gtk::Label.new(description).tap do |label|
      label.hexpand = true
      label.ellipsize = :end
      label.xalign = 0
      label.yalign = 0
      label.add_css_class('dimmed')
      label.add_css_class('caption')
    end
  end

  def icon
    @icon ||= Gtk::Image.new.tap do |image|
      image.accessible_role = :presentation
      image.icon_name = 'object-select-symbolic'
    end
  end

  private

    # Upstream's clock_description: the time zone's own name, dash-joined
    # with how far it sits from local time, or just the offset for a
    # timezone-less named zone.
    def description
      time_zone = @location.timezone
      return nil unless time_zone

      local_time = Utils::WallClock.default.date_time
      remote_time = GLib::DateTime.now(time_zone)
      diff = utc_offset_seconds(local_time) - utc_offset_seconds(remote_time)
      message = Utils.time_difference_message(diff)
      zone_name = time_zone.identifier.to_s.tr('_', ' ')
      zone_name.empty? ? message : "#{zone_name} • #{message}"
    end

    def utc_offset_seconds(date_time)
      date_time.format('%z').then do |offset|
        sign = offset.start_with?('-') ? -1 : 1
        sign * ((offset[1, 2].to_i * 3600) + (offset[3, 2].to_i * 60))
      end
    end
end
