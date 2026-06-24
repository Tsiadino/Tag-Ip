defmodule EventDefinition.Repo.Migrations.AddColumnsToAlertLogs do
  use Ecto.Migration

  def change do
    alter table(:alert_logs, primary_key: false) do
      add :event_code, :string, null: false, default: "unknown"
      add :alert_type, :string, default: "info"
      add :severity, :string, default: "info"
      add :message, :text
      add :vehicle_id, :string
      add :gps_latitude, :float
      add :gps_longitude, :float
      add :metadata, :map, default: "{}"
    end
  end
end
