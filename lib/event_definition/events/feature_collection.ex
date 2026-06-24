defmodule EventDefinition.Events.FeatureCollection do
  use Ash.Resource,
    domain: EventDefinition.Domain,
    data_layer: AshPostgres.DataLayer

  postgres do
    repo(EventDefinition.Repo)
    table("feature_collections")
  end

  attributes do
    uuid_primary_key(:id)
    attribute(:organization_id, :uuid, allow_nil?: false, public?: true)
    attribute(:name, :string, allow_nil?: false, public?: true)
    attribute(:description, :string, public?: true)

    attribute(:geometry_type, :atom,
      allow_nil?: false,
      constraints: [one_of: [:polygon, :point, :linestring]],
      default: :polygon,
      public?: true
    )

    attribute(:geojson, :map, public?: true)
    timestamps()
  end

  relationships do
    belongs_to :organization, EventDefinition.Accounts.Organization,
      source_attribute: :organization_id,
      destination_attribute: :id
  end

  actions do
    defaults([:read, :destroy])

    create :create do
      primary?(true)

      accept([
        :organization_id,
        :name,
        :description,
        :geometry_type,
        :geojson
      ])
    end

    update :update do
      primary?(true)
      require_atomic?(false)

      accept([
        :name,
        :description,
        :geometry_type,
        :geojson
      ])
    end
  end
end
