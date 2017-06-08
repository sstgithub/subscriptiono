class CreateFolders < ActiveRecord::Migration[5.1]
  def change
    create_table :folders do |t|
      t.belongs_to :user
      t.string :name
      t.string :uid_validity_number, unique: true
      t.bigint :last_highest_uid_number, default: 0

      t.timestamps
    end
  end
end
