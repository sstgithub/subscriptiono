class AddTokensToUser < ActiveRecord::Migration[5.1]
  def change
    add_column :users, :token, :string
    add_column :users, :refresh_token, :string
  end
end
