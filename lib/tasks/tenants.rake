namespace :tenants do
  namespace :db do

    desc "initialize the private tenant schema.rb (run after your first private migration has been created)"
    task :init => :environment do
      return unless ENV['RAILS_ENV'] != 'test'
      verbose = ENV["VERBOSE"] ? ENV["VERBOSE"] == "true" : true
      ActiveRecord::Migration.verbose = verbose

      temp_schema = 'temporary_schema'
      PgTools.create_schema temp_schema
      PgTools.in_search_path(temp_schema) {
        version = ENV["VERSION"] ? ENV["VERSION"].to_i : nil
        ActiveRecord::Migrator.migrate("db/migrate/private_schemas", version)
        ENV["search_path"] = temp_schema
        Rake::Task['tenants:schema:dump'].invoke
      }
      PgTools.drop_schema temp_schema
    end

    desc "runs db:migrate on each user's private schema"
    task :migrate => :environment do
      return unless ENV['RAILS_ENV'] != 'test'
      verbose = ENV["VERBOSE"] ? ENV["VERBOSE"] == "true" : true
      ActiveRecord::Migration.verbose = verbose

      dumped_schema = false
      tenantModelName = ENV["TENANT_MODEL"] || 'User'
      tenantModel = tenantModelName.constantize
      tenantModel.all.each do |tenant|
        puts "migrating tenant #{tenant.tenant_schema_name}"
        versions_in_private_schemas = []
        PgTools.in_search_path(tenant.tenant_schema_name) {
          version = ENV["VERSION"] ? ENV["VERSION"].to_i : nil
          ActiveRecord::Migrator.migrate("db/migrate/private_schemas", version)
          versions_in_private_schemas = ActiveRecord::Migrator.get_all_versions
          ENV["search_path"] = tenant.tenant_schema_name
          Rake::Task['tenants:schema:dump'].invoke unless dumped_schema
          dumped_schema = true
        }

        #update "default" path's schema_migrations as well
        PgTools.in_search_path("public") {
          versions_in_public_schema = ActiveRecord::Migrator.get_all_versions

          (versions_in_private_schemas - versions_in_public_schema).each do |version|
            table = Arel::Table.new(ActiveRecord::Migrator.schema_migrations_table_name)
            stmt = table.compile_insert table["version"] => version.to_s
            ActiveRecord::Base.connection.insert stmt
          end
        }
      end
    end

    desc "runs db:migrate on each user's private schema"
    task :rollback => :environment do
      return unless ENV['RAILS_ENV'] != 'test'
      verbose = ENV["VERBOSE"] ? ENV["VERBOSE"] == "true" : true
      ActiveRecord::Migration.verbose = verbose

      dumped_schema = false
      tenantModelName = ENV["TENANT_MODEL"] || 'User'
      tenantModel = tenantModelName.constantize
      tenantModel.all.each do |tenant|
        versions_in_private_schemas = []
        puts "rollback tenant #{tenant.tenant_schema_name}"
        PgTools.in_search_path(tenant.tenant_schema_name) {
          step = ENV['STEP'] ? ENV['STEP'].to_i : 1
          ActiveRecord::Migrator.rollback("db/migrate/private_schemas", step)
          versions_in_private_schemas = ActiveRecord::Migrator.get_all_versions
          ENV["search_path"] = tenant.tenant_schema_name
          Rake::Task['tenants:schema:dump'].invoke unless dumped_schema
          dumped_schema = true
        }

        PgTools.in_search_path("public") {
          versions_in_public_schema = ActiveRecord::Migrator.get_all_versions

          (versions_in_private_schemas - versions_in_public_schema).each do |version|
            table = Arel::Table.new(ActiveRecord::Migrator.schema_migrations_table_name)
            stmt = table.compile_insert table["version"] => version.to_s
            ActiveRecord::Base.connection.insert stmt
          end
        }
      end
    end

    desc "runs db:migrate on a specific user's private schema"
    task :migrate_tenant => :environment do
      return unless ENV['RAILS_ENV'] != 'test'
      verbose = ENV["VERBOSE"] ? ENV["VERBOSE"] == "true" : true
      ActiveRecord::Migration.verbose = verbose
      tenantModelName = ENV["TENANT_MODEL"] || 'User'
      tenantModel = tenantModelName.constantize
      tenant = tenantModel.find(ENV["TENANT_ID"])
      puts "migrating #{tenantModelName} #{tenant.id}"
      PgTools.in_search_path(tenant.tenant_schema_name) {
        version = ENV["VERSION"] ? ENV["VERSION"].to_i : nil
        ActiveRecord::Migrator.migrate("db/migrate/private_schemas", version)
        ENV["search_path"] = tenant.tenant_schema_name
        Rake::Task['tenants:schema:dump'].invoke
      }
    end

  end

  namespace :schema do
    desc 'Create a db/private/schema.rb file that can be portably used against any DB supported by AR'
    task :dump => :environment do
      require 'active_record/schema_dumper'
      filename = "#{Rails.root}/db/private/schema.rb"
      File.open(filename, "w:utf-8") do |file|
        ActiveRecord::Base.establish_connection(Rails.env)
        PgTools.in_search_path(ENV["search_path"]) {
          ActiveRecord::SchemaDumper.dump(ActiveRecord::Base.connection, file)
        }
      end
    end

    task :load => :environment do
      tenantModelName = ENV["TENANT_MODEL"] || 'User'
      tenantModel = tenantModelName.constantize
      tenantModel.all.each { |t|
        PgTools.set_search_path ENV["search_path"], false
        load "#{Rails.root}/db/private/schema.rb"
      }
    end
  end

end
