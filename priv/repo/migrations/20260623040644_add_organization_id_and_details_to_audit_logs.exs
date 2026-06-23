defmodule EventDefinition.Repo.Migrations.AddOrganizationIdAndDetailsToAuditLogs do
  use Ecto.Migration

  def change do
    execute """
              ALTER TABLE audit_logs
              ADD COLUMN IF NOT EXISTS organization_id UUID REFERENCES organizations(id) ON DELETE NO ACTION,
              ADD COLUMN IF NOT EXISTS details JSONB
            """,
            """
              ALTER TABLE audit_logs
              DROP COLUMN IF EXISTS organization_id,
              DROP COLUMN IF EXISTS details
            """
  end
end
