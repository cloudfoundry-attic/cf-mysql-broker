# encoding: UTF-8
# This file is auto-generated from the current state of the database. Instead
# of editing this file, please use the migrations feature of Active Record to
# incrementally modify your database, and then regenerate this schema definition.
#
# Note that this schema.rb definition is the authoritative source for your
# database schema. If you need to create the application database on another
# system, you should be using db:schema:load, not running all the migrations
# from scratch. The latter is a flawed and unsustainable approach (the more migrations
# you'll amass, the slower it'll run and the greater likelihood for issues).
#
# It's strongly recommended that you check this file into your version control system.

ActiveRecord::Schema.define(version: 20180117002358) do

  create_table "read_only_users", force: :cascade do |t|
    t.string   "username",   limit: 255
    t.string   "grantee",    limit: 255
    t.datetime "created_at",             null: false
    t.datetime "updated_at",             null: false
  end

  add_index "read_only_users", ["grantee"], name: "index_read_only_users_on_grantee", using: :btree
  add_index "read_only_users", ["username"], name: "index_read_only_users_on_username", using: :btree

  create_table "service_instances", force: :cascade do |t|
    t.string  "guid",           limit: 255
    t.string  "plan_guid",      limit: 255
    t.integer "max_storage_mb", limit: 4,   default: 0, null: false
    t.string  "db_name",        limit: 255
  end

  add_index "service_instances", ["db_name"], name: "index_service_instances_on_db_name", using: :btree
  add_index "service_instances", ["guid"], name: "index_service_instances_on_guid", using: :btree
  add_index "service_instances", ["plan_guid"], name: "index_service_instances_on_plan_guid", using: :btree

end
