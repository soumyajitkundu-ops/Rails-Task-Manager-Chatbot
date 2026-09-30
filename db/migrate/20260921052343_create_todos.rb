class CreateTodos < ActiveRecord::Migration[8.1]
  def change
    create_table :todos do |t|
      t.references :user, null: false, foreign_key: true
      t.string :task
      t.text :description
      t.integer :priority

      t.timestamps
    end
  end
end
