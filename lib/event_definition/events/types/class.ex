defmodule EventDefinition.Events.Class do
  use Ash.Type.Enum,
    values: [
      :movement,
      :power,
      :fuel,
      :geofence,
      :driver,
      :alarm,
      :connectivity,
      :speed,
      :driving,
      :accelerometer,
      :unknown
    ]
end
