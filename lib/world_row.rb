# frozen_string_literal: true

require 'adwaita'
require_relative 'utils'
require_relative 'world_item'

# WorldRow is one row of the World panel's list: the city's name and day
# offset as the row's title and subtitle, the current time as a coloured
# pill, and the delete button every row but the automatic one has.
#
# Ported from Clocks.World.Row in src/world-row.vala and data/ui/world-row.ui.
# Upstream binds every field to the item's GObject properties with a
# Gtk.BindingGroup; this port's item reports changes through #on_tick
# instead, so the row's own #sync replaces every one of those bindings.
#
class WorldRow < Adwaita::ActionRow
  def initialize(item)
    super()
    @item = item
    self.activatable = true
  end

  attr_reader :item

  def build
    tap do |row|
      row.add_css_class('clock')
      row.add_suffix(time_label)
      row.add_suffix(delete_button)

      delete_button.signal_connect('clicked') { @on_remove&.call }

      @item.on_tick { sync }
      sync
    end
  end

  def on_remove(&block)
    @on_remove = block
    self
  end

  def sync
    self.title = @item.city_name
    self.subtitle = subtitle_text
    time_label.label = @item.time_label
    delete_button.sensitive = !@item.automatic
    delete_button.visible = !@item.automatic
    sync_sun_state
    self
  end

  # Memoized widget methods

  def time_label
    @time_label ||= Gtk::Label.new.tap do |label|
      label.valign = :center
      label.margin_top = 12
      label.margin_bottom = 12
      label.add_css_class('clock-time')
      label.add_css_class('numeric')
    end
  end

  def delete_button
    @delete_button ||= Gtk::Button.new.tap do |button|
      button.valign = :center
      button.tooltip_text = 'Delete'
      button.icon_name = 'edit-delete-symbolic'
      button.add_css_class('circular')
      button.add_css_class('flat')
    end
  end

  private

    def subtitle_text
      message = Utils.time_difference_message(@item.local_offset)
      day_label = @item.day_label
      if day_label && !day_label.empty?
        "#{day_label} • #{message}"
      elsif @item.automatic
        'Current location'
      else
        message
      end
    end

    def sync_sun_state
      WorldItem::STATE_CLASSES.each { |state| remove_css_class(state.to_s) }
      add_css_class(@item.sun_state.to_s)
      self
    end
end
