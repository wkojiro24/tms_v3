class AddEventFieldsToAnnouncements < ActiveRecord::Migration[7.2]
  def change
    add_column :announcements, :event_date, :date
    add_column :announcements, :event_end_date, :date
    add_column :announcements, :event_location, :string
    add_column :announcements, :all_day, :boolean
  end
end
