class CreateMessages < ActiveRecord::Migration[5.1]
  def change
    create_table :messages do |t|
      t.bigint :uid_number
      t.string :category
      t.datetime :received_at
      t.text :body
      t.string :subject
      t.datetime :extracted_datetime
      t.string :sender_email

      t.timestamps
    end
  end
end
