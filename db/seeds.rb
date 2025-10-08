# This file should ensure the existence of records required to run the application in every environment (production,
# development, test). The code here should be idempotent so that it can be executed at any point in every environment.
# The data can then be loaded with the bin/rails db:seed command (or created alongside the database with db:setup).
#
# Example:
#
#   ["Action", "Comedy", "Drama", "Horror"].each do |genre_name|
#     MovieGenre.find_or_create_by!(name: genre_name)
#   end

## seed Assemblee Nationale body types
body_type_list = YAML.load_file(Rails.root.join("db", "seeds", "an_body_types.yml"))

An::BodyType.upsert_all(body_type_list, unique_by: :code)
