defmodule EventDefinition.Repo.Migrations.CleanupEventDefinitionCategories do
  use Ecto.Migration

  def change do
    execute("UPDATE event_definitions SET category = 'physical' WHERE category = ''")
    execute("UPDATE event_definitions SET class = 'unknown' WHERE class = ''")
    execute("UPDATE organization_event_definitions SET category = NULL WHERE category = ''")
    execute("UPDATE organization_event_definitions SET class = NULL WHERE class = ''")
  end
end
