class CreateTasks < ActiveRecord::Migration[7.2]
  def change
    create_table :tasks do |t|
      t.references :thread, foreign_key: true, null: true
      t.datetime :run_at
      t.text :prompt
      t.string :notify, default: 'slack'
      t.string :status, default: 'pending'
      t.text :result
      t.timestamps
    end

    add_index :tasks, [:status, :run_at]
  end
end
