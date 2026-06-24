defmodule EventDefinition.Events.Category do
  use Ash.Type.Enum,
    values: [:physical, :system, :derived, :alarm, :fuel, :geofence, :information, :infraction]
end
