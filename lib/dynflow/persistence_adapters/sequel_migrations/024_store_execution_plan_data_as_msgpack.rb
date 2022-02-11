# frozen_string_literal: true

require 'json'
require 'msgpack'

def table_pkeys(table)
  case table
  when :dynflow_execution_plans
    [:uuid]
  when :dynflow_actions, :dynflow_steps
    [:execution_plan_uuid, :id]
  else
    raise "Unknown table '#{table}'"
  end
end

def conditions_for_row(table, row)
  row.slice(*table_pkeys(table))
end

def migrate_table(table, from_names, to_names, new_type)
  alter_table(table) do
    to_names.each do |new|
      add_column new, new_type
    end
  end

  relevant_columns = table_pkeys(table) | from_names

  from(table).select(*relevant_columns).each do |row|
    update = from_names.zip(to_names).reduce({}) do |acc, (from, to)|
      row[from].nil? ? acc : acc.merge(to => yield(row[from]))
    end
    next if update.empty?
    from(table).where(conditions_for_row(table, row)).update(update)
  end

  from_names.zip(to_names).each do |old, new|
    alter_table(table) do
      drop_column old
    end

    if database_type == :mysql
      type = new_type == File ? 'blob' : 'mediumtext'
      run "ALTER TABLE #{table} CHANGE COLUMN `#{new}` `#{old}` #{type};"
    else
      rename_column table, new, old
    end
  end
end

Sequel.migration do

  TABLES = {
    :dynflow_execution_plans => [:data],
    :dynflow_steps => [:data]
  }

  up do
    TABLES.each do |table, columns|
      new_columns = columns.map { |c| "#{c}_blob" }

      migrate_table table, columns, new_columns, File do |data|
        ::Sequel.blob(MessagePack.pack(JSON.parse(data))) if data
      end
    end
  end

  down do
    TABLES.each do |table, columns|
      new_columns = columns.map { |c| c + '_text' }
      migrate_table table, columns, new_columns, String do |data|
        JSON.dump(MessagePack.unpack(data)) if data
      end
    end
  end
end
