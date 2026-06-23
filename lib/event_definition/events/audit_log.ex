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
    attribute(:user, :string, allow_nil?: false, public?: true)
    attribute(:action, :string, allow_nil?: false, public?: true)

    # Mappage vers la colonne réelle 'event' en base
    attribute(:event_id, :string, source: :event, public?: true)

    # Mappage vers 'inserted_at'
    attribute(:timestamp, :utc_datetime, source: :inserted_at, public?: true)

    # NOTE: Ces deux colonnes n'existent pas en base, 
    # tu devras ajouter une migration pour les créer si tu en as besoin.
    # attribute(:organization_id, :uuid, public?: true)
    # attribute(:details, :map, public?: true)
    attribute(:organization_id, :uuid, public?: true)
    attribute(:details, :map, public?: true)
  end

  actions do
    defaults([:read])

    create :create do
      # Maintenant que les colonnes existent, on peut les accepter
      accept([:organization_id, :event_id, :action, :details, :user, :timestamp])
    end
  end
end
