defmodule EventDefinition.Events.OrganizationEventDefinition do
  use Ash.Resource,
    domain: EventDefinition.Domain,
    extensions: [AshAdmin.Resource, AshPhoenix.Resource],
    data_layer: AshPostgres.DataLayer

  postgres do
    repo(EventDefinition.Repo)
    table("organization_event_definitions")
  end

  attributes do
    uuid_primary_key(:id)
    attribute(:organization_id, :uuid, allow_nil?: false, public?: true)
    attribute(:event_definition_id, :uuid, public?: true)
    attribute(:code, :string, allow_nil?: false, public?: true)
    attribute(:name, :string, public?: true)
    attribute(:definition, :string, public?: true)
    attribute(:category, :atom, public?: true, constraints: [unsafe_to_atom?: true])
    attribute(:class, :atom, public?: true, constraints: [unsafe_to_atom?: true])
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
  end

  actions do
    defaults([:read, :destroy])

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
    end

    update :update do
      primary?(true)

      accept([
        :code,
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

      require_atomic?(false)
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

      change(fn changeset, _ctx ->
        rule = Ash.Changeset.get_attribute(changeset, :occurrence_rule)

        if is_nil(rule) or rule == %{} do
          Ash.Changeset.add_error(
            changeset,
            Ash.Error.Changes.InvalidAttribute.exception(
              field: :occurrence_rule,
              message: "is required for standalone events"
            )
          )
        else
          changeset
        end
      end)

      change(fn changeset, _ctx ->
        name = Ash.Changeset.get_attribute(changeset, :name)

        if is_nil(name) or name == "" do
          Ash.Changeset.add_error(
            changeset,
            Ash.Error.Changes.InvalidAttribute.exception(
              field: :name,
              message: "is required for standalone events"
            )
          )
        else
          changeset
        end
      end)

      change(fn changeset, _ctx ->
        category = Ash.Changeset.get_attribute(changeset, :category)

        if is_nil(category) do
          Ash.Changeset.add_error(
            changeset,
            Ash.Error.Changes.InvalidAttribute.exception(
              field: :category,
              message: "is required for standalone events"
            )
          )
        else
          changeset
        end
      end)

      change(fn changeset, _ctx ->
        class = Ash.Changeset.get_attribute(changeset, :class)

        if is_nil(class) do
          Ash.Changeset.add_error(
            changeset,
            Ash.Error.Changes.InvalidAttribute.exception(
              field: :class,
              message: "is required for standalone events"
            )
          )
        else
          changeset
        end
      end)

      change(fn changeset, _ctx ->
        level = Ash.Changeset.get_attribute(changeset, :level)

        if is_nil(level) do
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
      end)
    end
  end
end
