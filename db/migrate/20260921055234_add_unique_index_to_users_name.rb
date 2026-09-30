class AddUniqueIndexToUsersName < ActiveRecord::Migration[8.1]
  def change
    add_index :users, :name, unique: true
  end
end
