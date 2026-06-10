defmodule EventDefinition.Events.AuditLog do
  use Ash.Resource,
    domain: EventDefinition.Domain,
    data_layer: AshPostgres.DataLayer

  postgres do
    repo(EventDefinition.Repo)
    table("audit_logs")
  end

  attributes do
    uuid_primary_key(:id)
    attribute(:organization_id, :uuid, allow_nil?: false, public?: true)
    attribute(:event_id, :uuid, public?: true)
    attribute(:action, :string, allow_nil?: false, public?: true)
    attribute(:details, :map, public?: true, default: %{})
    attribute(:user, :string, public?: true)
    attribute(:timestamp, :utc_datetime_usec, allow_nil?: false, public?: true)
    timestamps()
  end

  actions do
    defaults([:read])

    create :create do
      accept([:organization_id, :event_id, :action, :details, :user, :timestamp])
    end
  end
end
