defmodule EventDefinition.Repo.Migrations.DropOldAlertLogsColumns do
  use Ecto.Migration

  def change do
    alter table(:alert_logs, primary_key: false) do
      remove :event
      remove :status
    end
  end
end
