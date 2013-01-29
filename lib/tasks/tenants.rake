namespace :tenants do
  namespace :db do
    
    desc "runs db:migrate on each user's private schema"
    task :migrate => :environment do
      return unless ENV['RAILS_ENV'] != 'test'
      verbose = ENV["VERBOSE"] ? ENV["VERBOSE"] == "true" : true
      ActiveRecord::Migration.verbose = verbose

      dumped_schema = false
      User.all.each do |user|
        puts "migrating user #{user.id}"
        versions_in_private_schemas = []
        PgTools.in_search_path(user.id) {
          version = ENV["VERSION"] ? ENV["VERSION"].to_i : nil
          ActiveRecord::Migrator.migrate("db/migrate/private_schemas", version) 
          versions_in_private_schemas = ActiveRecord::Migrator.get_all_versions
          ENV["search_path"] = user.id.to_s
          Rake::Task['tenants:schema:dump'].invoke unless dumped_schema 
          dumped_schema = true 
        }
        #need to insert everything into default path's schema_migrations as well, otherwise things like rspec will complain there are unrun migrations
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

    desc "runs db:migrate on each a specific user's private schema"
    task :migrate_tenant => :environment do
      return unless ENV['RAILS_ENV'] != 'test'
      verbose = ENV["VERBOSE"] ? ENV["VERBOSE"] == "true" : true
      ActiveRecord::Migration.verbose = verbose

      user = User.find(ENV["USER_ID"])
      puts "migrating user #{user.id}"
      PgTools.in_search_path(user.id) {
        version = ENV["VERSION"] ? ENV["VERSION"].to_i : nil
        ActiveRecord::Migrator.migrate("db/migrate/private_schemas", version) 
        ENV["search_path"] = user.id.to_s
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
      User.all.each {|u|
        PgTools.set_search_path ENV["search_path"], false
        load "#{Rails.root}/db/private/schema.rb"
      }
    end
  end

end
