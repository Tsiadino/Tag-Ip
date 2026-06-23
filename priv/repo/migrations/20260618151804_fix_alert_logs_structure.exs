defmodule EventDefinition.Repo.Migrations.FixAuditLogTimestamp do
  use Ecto.Migration

  alter table(:audit_logs) do
    add :organization_id, :uuid
    add :details, :map
  end
end
