require 'pg_tools/acts_as_tenant_aware'
require 'pg_tools/railtie'

module PgTools
  extend self

  def default_search_path
    @default_search_path ||= %{"$user", public}
  end

  def set_search_path(name, include_public = true)
    path_parts = [name.to_s, ("public" if include_public)].compact
    ActiveRecord::Base.connection.schema_search_path = path_parts.join(",")
  end

  def search_path
    ActiveRecord::Base.connection.schema_search_path
  end

  def restore_default_search_path
    ActiveRecord::Base.connection.schema_search_path = default_search_path
  end

  def create_schema(name)
    sql = %{CREATE SCHEMA "#{name}"}
    ActiveRecord::Base.connection.execute sql
  end

  def drop_schema(name)
    sql = %{DROP SCHEMA "#{name}" CASCADE}
    ActiveRecord::Base.connection.execute sql
  end

  def schemas
    sql = "SELECT nspname FROM pg_namespace WHERE nspname != 'information_schema' and nspname !~ '^pg_.*'"
    ActiveRecord::Base.connection.query(sql).flatten
  end

  def in_search_path(i, &block)
    prev_search_path = search_path
    set_search_path(i, false)
    block_return = yield
    set_search_path(prev_search_path)
    block_return
  end

  #can be added at top of migrations on private schemas; thus, the migration will be skipped if they are attempted on any other schema
  def private_search_path?
    ActiveRecord::Base.connection.schema_search_path != '"$user",public'
  end

end
