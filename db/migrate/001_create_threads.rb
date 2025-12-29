class CreateThreads < ActiveRecord::Migration[7.2]
  def change
    create_table :threads do |t|
      t.string :name
      t.string :session_id
      t.timestamps
    end
  end
end
