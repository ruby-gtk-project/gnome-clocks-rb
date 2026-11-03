# frozen_string_literal: true

require 'adwaita'
require_relative 'utils'
require_relative 'stopwatch_lap'

# StopwatchLapsRow is one row of the stopwatch's lap list: the lap's duration,
# how it compares with the lap before it, and its number.
#
# Ported from Clocks.Stopwatch.LapsRow in src/stopwatch-laps-row.vala and
# data/ui/stopwatch-laps-row.ui, including the module-level render_duration
# the row formats both of its times with.
#
class StopwatchLapsRow < Gtk::ListBoxRow
  # Upstream's render_duration: hundredths, with the LTR mark and the RATIO
  # character so the fields never reorder in a right-to-left locale.
  def self.render_duration(duration)
    Utils.time_to_hms((duration * 100).floor / 100.0).then do |hours, minutes, seconds, remainder|
      format(
        "%<hours>02i#{Utils::LTR_MARK} #{Utils::RATIO} %<minutes>02i#{Utils::LTR_MARK} " \
        "#{Utils::RATIO} %<seconds>02i. %<centiseconds>i",
        hours: hours.abs,
        minutes: minutes.abs,
        seconds: seconds.abs,
        centiseconds: (remainder * 10).to_i.abs,
      )
    end
  end

  def initialize(current, before)
    super()
    @current = current
    @before = before
    self.activatable = false
    add_css_class('lap-row')
  end

  attr_reader :current, :before

  def build
    tap do |row|
      row.child = box

      box.tap do |container|
        container.append(duration_label)
        container.append(difference_label)
        container.append(index_label)
      end

      label_difference
    end
  end

  # Upstream only fills the difference label when there is a lap to compare
  # with, and colours it red when this lap was slower, blue when faster.
  def label_difference
    @before.then do |previous|
      if previous
        difference_label.label = delta_label
        delta_duration.then do |difference|
          difference_label.add_css_class('error') if difference.positive?
          difference_label.add_css_class('accent') if difference.negative?
        end
      end
    end
  end

  def duration_text = StopwatchLapsRow.render_duration(@current.duration)

  def delta_duration = @before ? @current.duration - @before.duration : 0

  def delta_label
    delta_duration.then do |difference|
      "#{difference.negative? ? '-' : '+'} #{StopwatchLapsRow.render_duration(difference)}"
    end
  end

  # Memoized widget methods

  def box
    @box ||= Gtk::Box.new(:horizontal, 18).tap do |box|
      box.margin_top = 18
      box.margin_bottom = 18
      box.margin_start = 18
      box.margin_end = 18
    end
  end

  def duration_label
    @duration_label ||= Gtk::Label.new(duration_text).tap do |label|
      label.tooltip_text = 'Time'
      label.halign = :start
      label.valign = :center
      label.add_css_class('lap-time')
      label.add_css_class('numeric')
    end
  end

  def difference_label
    @difference_label ||= Gtk::Label.new.tap do |label|
      label.tooltip_text = 'Difference'
      label.halign = :start
      label.hexpand = true
      label.valign = :center
      label.add_css_class('numeric')
    end
  end

  def index_label
    @index_label ||= Gtk::Label.new(format('Lap %<index>i', index: @current.index)).tap do |label|
      label.halign = :end
      label.valign = :center
      label.width_chars = 3
      label.add_css_class('dimmed')
    end
  end
end
