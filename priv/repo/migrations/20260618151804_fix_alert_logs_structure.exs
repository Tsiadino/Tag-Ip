defmodule EventDefinition.Repo.Migrations.FixAlertLogsStructure do
  use Ecto.Migration

  def change do
    # This migration is superseded by 20260623040644_add_organization_id_and_details_to_audit_logs
    # Keep as no-op to avoid conflicts
  end
end
