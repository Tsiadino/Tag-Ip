defmodule EventDefinition.Events.OrganizationEventDefinition do
  use Ash.Resource,
    domain: EventDefinition.Domain,
    extensions: [AshAdmin.Resource, AshPhoenix.Resource],
    data_layer: AshPostgres.DataLayer

  postgres do
    repo(EventDefinition.Repo)
    table("organization_event_definitions")

    identity_index_names(
      org_event_definition_shadow: "org_event_definitions_org_event_definition_index",
      org_event_definition_code: "org_event_definitions_org_code_index"
    )
  end

  identities do
    identity(:org_event_definition_shadow, [:organization_id, :event_definition_id],
      eager_check?: true
    )

    identity(:org_event_definition_code, [:organization_id, :code], eager_check?: true)
  end

  attributes do
    uuid_primary_key(:id)
    attribute(:organization_id, :uuid, allow_nil?: false, public?: true)
    attribute(:event_definition_id, :uuid, public?: true)
    attribute(:code, :string, allow_nil?: false, public?: true)
    attribute(:name, :string, public?: true)
    attribute(:definition, :string, public?: true)

    attribute(:category, EventDefinition.Events.Category, public?: true)
    attribute(:class, EventDefinition.Events.Class, public?: true)

    attribute(:level, :integer, constraints: [min: 1], public?: true)
    attribute(:level_group, :string, public?: true)
    attribute(:occurrence_rule, :map, public?: true)

    attribute(:alert_mode, :atom,
      default: :none,
      constraints: [one_of: [:none, :alert, :report, :both]],
      public?: true
    )

    attribute(:enabled, :boolean, default: true, public?: true)
    attribute(:author_id, :uuid, allow_nil?: false, public?: true)
    timestamps()
  end

  relationships do
    belongs_to :organization, EventDefinition.Accounts.Organization,
      source_attribute: :organization_id,
      destination_attribute: :id

    belongs_to :event_definition, EventDefinition.Events.EventDefinition,
      source_attribute: :event_definition_id

    belongs_to :author, EventDefinition.Accounts.User, source_attribute: :author_id
  end

  calculations do
    calculate(:resolved_name, :string, expr(coalesce(name, event_definition.name)))

    calculate(
      :resolved_definition,
      :string,
      expr(coalesce(definition, event_definition.definition))
    )

    calculate(
      :resolved_category,
      EventDefinition.Events.Category,
      expr(coalesce(category, event_definition.category))
    )

    calculate(
      :resolved_class,
      EventDefinition.Events.Class,
      expr(coalesce(class, event_definition.class))
    )

    calculate(:resolved_level, :integer, expr(coalesce(level, event_definition.level)))

    calculate(
      :resolved_level_group,
      :string,
      expr(coalesce(level_group, event_definition.level_group))
    )

    calculate(:monitor_type, :string, expr(event_definition.monitor_type))
  end

  actions do
    defaults([:read, :destroy])

    read :resolved do
      argument(:organization_id, :uuid, allow_nil?: false)

      prepare(build(load: [:event_definition]))

      filter(expr(organization_id == ^arg(:organization_id)))
    end

    create :create do
      primary?(true)

      accept([
        :organization_id,
        :event_definition_id,
        :code,
        :name,
        :definition,
        :category,
        :class,
        :level,
        :level_group,
        :occurrence_rule,
        :alert_mode,
        :enabled,
        :author_id
      ])

      change(&strip_blank_category/2)
    end

    create :enable do
      description("Upsert a shadow org event definition, setting enabled = true")
      accept([:organization_id, :event_definition_id, :author_id])

      change(set_attribute(:enabled, true))

      change(fn changeset, _ctx ->
        ed_id = Ash.Changeset.get_attribute(changeset, :event_definition_id)

        if ed_id do
          ed = Ash.get!(EventDefinition.Events.EventDefinition, ed_id)

          changeset
          |> Ash.Changeset.change_attribute(:code, ed.code)
          |> Ash.Changeset.change_attribute(:name, ed.name)
        else
          changeset
        end
      end)

      upsert?(true)
      upsert_identity(:org_event_definition_shadow)
      upsert_fields([:enabled])
    end

    create :create_standalone do
      description("Create an org-specific event with no global counterpart")

      accept([
        :organization_id,
        :code,
        :name,
        :definition,
        :category,
        :class,
        :level,
        :level_group,
        :occurrence_rule,
        :alert_mode,
        :enabled,
        :author_id
      ])

      change(set_attribute(:event_definition_id, nil))

      change(&require_standalone_field_rule/2)
      change(&require_standalone_field_name/2)
      change(&require_standalone_field_category/2)
      change(&require_standalone_field_class/2)
      change(&require_standalone_field_level/2)
    end

    update :update do
      primary?(true)
      require_atomic?(false)

      accept([
        :name,
        :definition,
        :category,
        :class,
        :level,
        :level_group,
        :occurrence_rule,
        :alert_mode,
        :enabled
      ])

      change(&strip_blank_category/2)
    end
  end

  defp require_standalone_field_rule(changeset, _ctx) do
    rule = Ash.Changeset.get_attribute(changeset, :occurrence_rule)

    cond do
      is_nil(rule) or rule == %{} ->
        Ash.Changeset.add_error(
          changeset,
          Ash.Error.Changes.InvalidAttribute.exception(
            field: :occurrence_rule,
            message: "is required for standalone events"
          )
        )

      not Map.has_key?(rule, "trigger") ->
        Ash.Changeset.add_error(
          changeset,
          Ash.Error.Changes.InvalidAttribute.exception(
            field: :occurrence_rule,
            message: "must have a \"trigger\" key"
          )
        )

      not valid_trigger?(Map.get(rule, "trigger")) ->
        trigger = Map.get(rule, "trigger")

        known =
          ~w(speed_exceeds no_movement geofence_enter geofence_exit geofence_inside poi_near poi_approaching poi_leaving fuel_drop min_distance)

        Ash.Changeset.add_error(
          changeset,
          Ash.Error.Changes.InvalidAttribute.exception(
            field: :occurrence_rule,
            message: "unknown trigger \"#{trigger}\". Known triggers: #{Enum.join(known, ", ")}"
          )
        )

      true ->
        changeset
    end
  end

  defp valid_trigger?(trigger) when is_binary(trigger) do
    trigger in ~w(
      speed_exceeds no_movement geofence_enter geofence_exit geofence_inside
      poi_near poi_approaching poi_leaving fuel_drop min_distance
    )
  end

  defp valid_trigger?(_), do: false

  defp require_standalone_field_name(changeset, _ctx) do
    check_blank(changeset, :name, "is required for standalone events")
  end

  defp require_standalone_field_category(changeset, _ctx) do
    check_blank(changeset, :category, "is required for standalone events")
  end

  defp require_standalone_field_class(changeset, _ctx) do
    check_blank(changeset, :class, "is required for standalone events")
  end

  defp require_standalone_field_level(changeset, _ctx) do
    value = Ash.Changeset.get_attribute(changeset, :level)

    if is_nil(value) do
      Ash.Changeset.add_error(
        changeset,
        Ash.Error.Changes.InvalidAttribute.exception(
          field: :level,
          message: "is required for standalone events"
        )
      )
    else
      changeset
    end
  end

  defp strip_blank_category(changeset, _ctx) do
    case Ash.Changeset.get_attribute(changeset, :category) do
      "" -> Ash.Changeset.change_attribute(changeset, :category, nil)
      _ -> changeset
    end
  end

  defp check_blank(changeset, field, message) do
    value = Ash.Changeset.get_attribute(changeset, field)

    if is_nil(value) or value == "" do
      Ash.Changeset.add_error(
        changeset,
        Ash.Error.Changes.InvalidAttribute.exception(
          field: field,
          message: message
        )
      )
    else
      changeset
    end
  end
end
