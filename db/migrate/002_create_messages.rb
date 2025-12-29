class CreateMessages < ActiveRecord::Migration[7.2]
  def change
    create_table :messages do |t|
      t.references :thread, foreign_key: true
      t.string :role
      t.text :content
      t.string :channel
      t.timestamps
    end
  end
end
