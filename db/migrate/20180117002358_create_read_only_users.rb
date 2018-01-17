class CreateReadOnlyUsers < ActiveRecord::Migration
  def change
    create_table :read_only_users do |t|
      t.string :username
      t.string :grantee

      t.timestamps null: false
    end

    add_index :read_only_users, :username
    add_index :read_only_users, :grantee
  end
end
