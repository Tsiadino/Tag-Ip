defmodule EventDefinition.Events.OrganizationEventDefinitionTest do
  use EventDefinition.DataCase, async: true

  alias EventDefinition.Events.OrganizationEventDefinition

  describe "create_standalone action" do
    test "requires occurrence_rule" do
      result =
        OrganizationEventDefinition
        |> Ash.Changeset.for_create(:create_standalone, %{
          organization_id: Ecto.UUID.generate(),
          code: "TEST_STANDALONE",
          name: "Test Standalone",
          category: "physical",
          class: "movement",
          level: 2,
          author_id: Ecto.UUID.generate()
        })
        |> Ash.create()

      assert {:error, %{errors: errors}} = result
      assert Enum.any?(errors, &match?(%{field: :occurrence_rule}, &1))
    end

    test "requires name" do
      result =
        OrganizationEventDefinition
        |> Ash.Changeset.for_create(:create_standalone, %{
          organization_id: Ecto.UUID.generate(),
          code: "NO_NAME",
          category: "system",
          class: "alarm",
          level: 2,
          occurrence_rule: %{"trigger" => "speed_exceeds", "threshold_kmh" => 80},
          author_id: Ecto.UUID.generate()
        })
        |> Ash.create()

      assert {:error, %{errors: errors}} = result
      assert Enum.any?(errors, &match?(%{field: :name}, &1))
    end

    test "requires category" do
      result =
        OrganizationEventDefinition
        |> Ash.Changeset.for_create(:create_standalone, %{
          organization_id: Ecto.UUID.generate(),
          code: "NO_CAT",
          name: "No Category",
          class: "fuel",
          level: 2,
          occurrence_rule: %{"trigger" => "fuel_drop", "drop_percent" => 20},
          author_id: Ecto.UUID.generate()
        })
        |> Ash.create()

      assert {:error, %{errors: errors}} = result
      assert Enum.any?(errors, &match?(%{field: :category}, &1))
    end

    test "requires class" do
      result =
        OrganizationEventDefinition
        |> Ash.Changeset.for_create(:create_standalone, %{
          organization_id: Ecto.UUID.generate(),
          code: "NO_CLASS",
          name: "No Class",
          category: "physical",
          level: 2,
          occurrence_rule: %{"trigger" => "no_movement", "duration_minutes" => 30},
          author_id: Ecto.UUID.generate()
        })
        |> Ash.create()

      assert {:error, %{errors: errors}} = result
      assert Enum.any?(errors, &match?(%{field: :class}, &1))
    end

    test "requires level" do
      result =
        OrganizationEventDefinition
        |> Ash.Changeset.for_create(:create_standalone, %{
          organization_id: Ecto.UUID.generate(),
          code: "NO_LVL",
          name: "No Level",
          category: "derived",
          class: "geofence",
          occurrence_rule: %{"trigger" => "geofence_enter"},
          author_id: Ecto.UUID.generate()
        })
        |> Ash.create()

      assert {:error, %{errors: errors}} = result
      assert Enum.any?(errors, &match?(%{field: :level}, &1))
    end
  end

  describe "fields constraints" do
    test "sets event_definition_id to nil and persists standalone event" do
      {:ok, result} =
        OrganizationEventDefinition
        |> Ash.Changeset.for_create(:create_standalone, %{
          organization_id: Ecto.UUID.generate(),
          code: "STANDALONE_OK",
          name: "Valid Standalone",
          category: "physical",
          class: "alarm",
          level: 2,
          occurrence_rule: %{"trigger" => "speed_exceeds", "threshold_kmh" => 100},
          alert_mode: :none,
          enabled: true,
          author_id: Ecto.UUID.generate()
        })
        |> Ash.create()

      assert result.event_definition_id == nil
      assert result.code == "STANDALONE_OK"
      assert result.name == "Valid Standalone"
      assert result.enabled == true
    end
  end
end
