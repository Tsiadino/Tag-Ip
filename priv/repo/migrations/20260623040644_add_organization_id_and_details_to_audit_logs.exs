defmodule EventDefinition.Repo.Migrations.AddOrganizationIdAndDetailsToAuditLogs do
  use Ecto.Migration

  def change do
    alter table(:audit_logs) do
      add :organization_id, references(:organizations, type: :uuid, on_delete: :nothing)
      add :details, :map
    end
  end
end
