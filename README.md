pg_tools
========

A gem that facilitates working with Postgresql schemas for multi-tenant applications. It provides rake tasks and hooks on create for your User model. The advantage of using this gem over others is that it keeps your private schema migrations separate from the public ones (in db/migrate/private_schemas) and also keeps different schema.rb files in db/schema.rb (public) and db/private/schema.rb (private) respectively.