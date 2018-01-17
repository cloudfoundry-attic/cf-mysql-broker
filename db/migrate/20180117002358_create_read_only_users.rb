class CreateReadOnlyUsers < ActiveRecord::Migration
  def change
    create_table :read_only_users do |t|
      t.string :username
      t.string :grantee

      t.timestamps null: false
    end
  end
end
