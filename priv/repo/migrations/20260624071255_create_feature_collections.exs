defmodule EventDefinition.Repo.Migrations.CreateFeatureCollections do
  use Ecto.Migration

  def change do
    create table(:feature_collections, primary_key: false) do
      add :id, :uuid, null: false, default: fragment("gen_random_uuid()"), primary_key: true
      add :organization_id, :uuid, null: false
      add :name, :string, null: false
      add :description, :string
      add :geometry_type, :string, null: false, default: "polygon"
      add :geojson, :map
      timestamps(type: :utc_datetime_usec)
    end

    create index(:feature_collections, [:organization_id])
  end
end
