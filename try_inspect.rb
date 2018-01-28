# frozen_string_literal: true
require "bundler/setup"
require "active_record"
require_relative './inject_query_inspector.rb'

logger = Logger.new(STDOUT)
logger.formatter = proc do |severity, datetime, progname, msg|
   "#{severity}: #{msg}\n"
end
QueryInspector.logger = logger

ActiveRecord::Base.establish_connection(adapter: "sqlite3", database: ":memory:")
ActiveRecord::Schema.define do
  create_table "products" do |t|
    t.string "title"
    t.integer "author_id"
    t.boolean "active"
    t.timestamps
  end
end

class Product < ActiveRecord::Base
end

# Writing tests is too hard.

Product.where(active: true).where("author_id IS NOT NULL").where(created_at: 2.days.ago..1.day.ago).to_a
Product.where("active = ?", 1).where("author_id IS NULL").to_a
Product.where.not(active: true).to_a
Product.where("`title` LIKE ?", "locales/%").to_a
Product.where("`title` IS NOT NULL").to_a
Product.where(
  Product.arel_table[:created_at].gteq(Date.new(2015, 8, 11))
).to_a
Product.where(
  Product.arel_table[:created_at].lteq(Date.new(2015, 8, 11))
).to_a
Product.where(
  Product.arel_table[:created_at].lt(Date.new(2015, 8, 11))
).to_a
Product.where(
  Product.arel_table[:created_at].gt(Date.new(2015, 8, 11))
).to_a
Product.where("1=0").to_a
Product.where(active: true).or(Product.where(active: false)).to_a
Product.where.not(active: [true, false]).to_a
