defmodule EventDefinition.Events.AlertLog do
  use Ash.Resource,
    domain: EventDefinition.Domain,
    data_layer: AshPostgres.DataLayer

  postgres do
    table("alert_logs")
    repo(EventDefinition.Repo)
  end

  attributes do
    uuid_primary_key(:id)
    attribute(:organization_id, :uuid, allow_nil?: false, public?: true)
    attribute(:event_code, :string, allow_nil?: false, public?: true)
    attribute(:alert_type, :string, public?: true)
    attribute(:severity, :string, public?: true)
    attribute(:message, :string, public?: true)
    attribute(:vehicle_id, :string, public?: true)
    attribute(:gps_latitude, :float, public?: true)
    attribute(:gps_longitude, :float, public?: true)
    attribute(:metadata, :map, public?: true, default: %{})
    attribute(:timestamp, :utc_datetime_usec, allow_nil?: false, public?: true)
  end

  relationships do
    belongs_to :organization, EventDefinition.Accounts.Organization do
      source_attribute(:organization_id)
    end
  end

  actions do
    defaults([:read, :destroy])

    create :create do
      accept([
        :organization_id,
        :event_code,
        :alert_type,
        :severity,
        :message,
        :vehicle_id,
        :gps_latitude,
        :gps_longitude,
        :metadata,
        :timestamp
      ])
    end
  end
end
