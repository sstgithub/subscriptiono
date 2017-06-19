class AddFolderRefToMessages < ActiveRecord::Migration[5.1]
  def change
    add_reference :messages, :folder, foreign_key: true
  end
end
