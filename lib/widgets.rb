# frozen_string_literal: true

require 'adwaita'
require_relative 'utils'

# ContentStore holds the items of one panel — the world clocks, the alarms,
# the timers — in the order they were added, tells its listeners when that
# order changes, and serialises itself to and from the `aa{sv}` GSettings keys
# upstream stores them in.
#
# Ported from Clocks.ContentStore in src/widgets.vala.
#
# Upstream's ContentStore implements GListModel over a GLib.ListStore so the
# panels can bind a Gtk.ListBox straight to it. This port keeps the items in a
# plain Ruby array and the panels build their rows themselves, for the reason
# the pilot port's ContactStore documents: removing an item from a GTK model
# drops the reference keeping it alive, and a Ruby object handed back out of a
# model afterwards can point at freed memory. The items here are plain Ruby
# objects, never GObjects, so they never go into a GTK model at all; what the
# panels get instead is the items_changed notification they were binding for.
#
class ContentStore
  include Enumerable

  def initialize
    @items = []
    @listeners = []
  end

  # Upstream's GListModel implementation.
  def n_items = @items.length
  def get_item(position) = @items[position]
  def each(&) = @items.each(&)

  def add(item)
    @items << item
    items_changed(@items.length - 1, 0, 1)
    item
  end

  # Upstream inserts the newest stopwatch lap at the front, so a position is
  # part of the store's interface rather than only the end.
  def insert(position, item)
    @items.insert(position, item)
    items_changed(position, 0, 1)
    item
  end

  def remove(item)
    @items.index(item).then do |position|
      if position
        @items.delete_at(position)
        items_changed(position, 1, 0)
      end
    end
    item
  end

  def remove_all
    @items.length.then do |removed|
      @items = []
      items_changed(0, removed, 0) if removed.positive?
    end
    self
  end

  def contains?(item) = @items.include?(item)

  # Upstream's ContentStore.find takes a predicate and hands back the first
  # item it matches; Enumerable#find already is that, so this only keeps the
  # name the panels call it by.
  def find_item(&) = @items.find(&)

  # Reorders the store in place. Upstream's timer panel gets this from a
  # Gtk.SortListModel wrapped around the store; a custom GTK sorter over Ruby
  # objects is not safe in these bindings, so the store sorts itself and the
  # panels hear about it through items_changed.
  def sort_items!(&block)
    @items.sort(&block).then do |sorted|
      unless sorted == @items
        @items = sorted
        items_changed(0, @items.length, @items.length)
      end
    end
    self
  end

  def on_items_changed(&block)
    @listeners << block
    self
  end

  # Upstream's serialize: every item writes one `a{sv}` dictionary into the
  # builder, and the key holds the array of them.
  def serialize = @items.map(&:serialize)

  # Upstream's deserialize: each dictionary goes through the item class's own
  # deserializer, and anything it rejects is dropped.
  def deserialize(variant, &block)
    Array(variant).each { |value| block.call(value).then { |item| add(item) if item } }
    self
  end

  private

    def items_changed(position, removed, added)
      @listeners.each { |listener| listener.call(position, removed, added) }
    end
end

# AmPmToggleButton flips between the locale's AM and PM labels.
#
# Ported from Clocks.AmPmToggleButton in src/widgets.vala: a button whose
# child is a stack of the two labels, which it swaps on every click. The
# labels come out of the first day of year 1 at midnight and at noon, so they
# are the locale's own, and the .clocks-ampm-toggle-button class in
# data/css/gnome-clocks.css sizes them.
#
class AmPmToggleButton < Gtk::Button
  AM = :am
  PM = :pm

  def initialize(choice: AM)
    super()
    add_css_class('clocks-ampm-toggle-button')
    @choice = choice
  end

  attr_reader :choice

  def build
    tap do |button|
      button.child = stack

      stack.tap do |st|
        st.add_child(am_label)
        st.add_child(pm_label)
      end

      button.signal_connect('clicked') { self.choice = choice == AM ? PM : AM }

      update
    end
  end

  def choice=(value)
    unless value == @choice
      @choice = value
      update
      @on_changed&.call(value)
    end
  end

  # Upstream's alarm setup dialog watches the `choice` property to keep the
  # hour spin button in 12-hour mode; this is the same notification.
  def on_changed(&block)
    @on_changed = block
    self
  end

  def update
    stack.visible_child = @choice == AM ? am_label : pm_label
    self
  end

  # Memoized widget methods

  def stack = @stack ||= Gtk::Stack.new
  def am_label = @am_label ||= Gtk::Label.new(AmPmToggleButton.period_label(0))
  def pm_label = @pm_label ||= Gtk::Label.new(AmPmToggleButton.period_label(12))

  def self.period_label(hour)
    GLib::DateTime.new(year: 1, month: 1, day: 1, hour: hour, minute: 0, second: 0).format('%p')
  end
end
