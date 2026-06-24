defmodule EventDefinition.Events.EventDefinition do
  use Ash.Resource,
    domain: EventDefinition.Domain,
    extensions: [AshAdmin.Resource, AshPhoenix.Resource],
    data_layer: AshPostgres.DataLayer

  postgres do
    repo(EventDefinition.Repo)
    table("event_definitions")
  end

  attributes do
    uuid_primary_key(:id)
    attribute(:code, :string, allow_nil?: false)
    attribute(:name, :string, allow_nil?: false)
    attribute(:definition, :string)

    attribute :category, EventDefinition.Events.Category do
      allow_nil?(false)
    end

    attribute :class, EventDefinition.Events.Class do
      allow_nil?(false)
      default(:unknown)
    end

    attribute(:level, :integer, allow_nil?: false, constraints: [min: 1])
    attribute(:level_group, :string)
    attribute(:monitor_type, :string, allow_nil?: false)
    attribute(:active, :boolean, default: true)
    timestamps()
  end

  identities do
    identity(:unique_code, [:code], eager_check?: true)
  end

  relationships do
    has_many :organization_event_definitions, EventDefinition.Events.OrganizationEventDefinition,
      destination_attribute: :event_definition_id
  end

  actions do
    defaults([:read, :destroy])

    create :create do
      primary?(true)

      accept([
        :code,
        :name,
        :definition,
        :category,
        :class,
        :level,
        :level_group,
        :monitor_type,
        :active
      ])
    end

    update :update do
      primary?(true)

      accept([
        :name,
        :definition,
        :category,
        :class,
        :level,
        :level_group,
        :monitor_type,
        :active
      ])
    end
  end
end
