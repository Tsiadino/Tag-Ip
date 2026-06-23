defmodule EventDefinitionWeb.OrgEventsLive do
  use EventDefinitionWeb, :live_view

  alias EventDefinition.Repo
  import Ecto.Query, only: [from: 2]

  @alert_modes ~w(none alert report both)
  @categories ~w(physical derived system alarm geofence fuel)
  @classes ~w(movement power connectivity speed alarm geofence fuel driving accelerometer unknown)
  @standalone_categories ~w(alarm physical derived geofence fuel)
  @spec_level_groups ~w(movement power fuel geofence driver alarm connectivity speed geofence poi)

  @global_presets %{
    "DEP" => %{
      name: "Départ",
      monitor_type: "MovementMonitor",
      level: 1,
      definition: "Détecte le début d'un mouvement",
      category: "physical",
      class: "movement",
      level_group: "movement",
      alert_mode: "none"
    },
    "MOV" => %{
      name: "Déplacement",
      monitor_type: "MovementMonitor",
      level: 1,
      definition: "État de déplacement continu",
      category: "derived",
      class: "movement",
      level_group: "movement",
      alert_mode: "none"
    },
    "PRK_MOV" => %{
      name: "Déplacement parking",
      monitor_type: "MovementMonitor",
      level: 1,
      definition: "Mouvement spécifique au parking",
      category: "derived",
      class: "movement",
      level_group: "movement",
      alert_mode: "none"
    },
    "ARR" => %{
      name: "Arrivée",
      monitor_type: "MovementMonitor",
      level: 1,
      definition: "Détecte la fin d'un mouvement",
      category: "physical",
      class: "movement",
      level_group: "movement",
      alert_mode: "none"
    },
    "PRK" => %{
      name: "Arrêt",
      monitor_type: "MovementMonitor",
      level: 1,
      definition: "Détecte l'arrêt/stationnement",
      category: "physical",
      class: "movement",
      level_group: "movement",
      alert_mode: "none"
    },
    "LOW_BATTERY" => %{
      name: "Batterie faible",
      monitor_type: "PowerMonitor",
      level: 1,
      definition: "Détecte un niveau de batterie bas",
      category: "system",
      class: "power",
      level_group: "power",
      alert_mode: "report"
    },
    "GPS_LOST" => %{
      name: "Perte signal GPS",
      monitor_type: "ConnectivityMonitor",
      level: 1,
      definition: "Perte de signal GPS",
      category: "system",
      class: "connectivity",
      level_group: "connectivity",
      alert_mode: "report"
    },
    "GPS_RESTORED" => %{
      name: "Signal GPS retrouvé",
      monitor_type: "ConnectivityMonitor",
      level: 1,
      definition: "Rétablissement du signal GPS",
      category: "system",
      class: "connectivity",
      level_group: "connectivity",
      alert_mode: "report"
    },
    "CONN_LOST" => %{
      name: "Connexion perdue",
      monitor_type: "ConnectivityMonitor",
      level: 1,
      definition: "Perte de connexion réseau",
      category: "system",
      class: "connectivity",
      level_group: "connectivity",
      alert_mode: "report"
    },
    "OVERSPEED" => %{
      name: "Excès de vitesse",
      monitor_type: "SpeedMonitor",
      level: 2,
      definition: "speed_exceeds",
      category: "alarm",
      class: "speed",
      level_group: "speed",
      alert_mode: "alert"
    },
    "IDLE" => %{
      name: "Inactivité prolongée",
      monitor_type: "IdleMonitor",
      level: 2,
      definition: "no_movement",
      category: "alarm",
      class: "alarm",
      level_group: "alarm",
      alert_mode: "alert"
    },
    "GEO_ENTER" => %{
      name: "Entrée de zone",
      monitor_type: "GeofenceMonitor",
      level: 2,
      definition: "geofence_enter",
      category: "physical",
      class: "geofence",
      level_group: "geofence",
      alert_mode: "alert"
    },
    "GEO_EXIT" => %{
      name: "Sortie de zone",
      monitor_type: "GeofenceMonitor",
      level: 2,
      definition: "geofence_exit",
      category: "physical",
      class: "geofence",
      level_group: "geofence",
      alert_mode: "alert"
    },
    "GEO_INSIDE" => %{
      name: "Dans la zone",
      monitor_type: "GeofenceMonitor",
      level: 2,
      definition: "geofence_inside",
      category: "derived",
      class: "geofence",
      level_group: "geofence",
      alert_mode: "report"
    },
    "POI_NEAR" => %{
      name: "Proximité POI",
      monitor_type: "PoiMonitor",
      level: 2,
      definition: "poi_near",
      category: "geofence",
      class: "geofence",
      level_group: "poi",
      alert_mode: "alert"
    },
    "POI_APPROACHING" => %{
      name: "Approche POI",
      monitor_type: "PoiMonitor",
      level: 2,
      definition: "poi_approaching",
      category: "geofence",
      class: "geofence",
      level_group: "poi",
      alert_mode: "alert"
    },
    "POI_LEAVING" => %{
      name: "Départ POI",
      monitor_type: "PoiMonitor",
      level: 2,
      definition: "poi_leaving",
      category: "geofence",
      class: "geofence",
      level_group: "poi",
      alert_mode: "alert"
    },
    "FUEL_DROP" => %{
      name: "Chute de carburant",
      monitor_type: "FuelMonitor",
      level: 2,
      definition: "fuel_drop",
      category: "fuel",
      class: "fuel",
      level_group: "fuel",
      alert_mode: "alert"
    },
    "HARSH_BRAKE" => %{
      name: "Freinage brusque",
      monitor_type: "DrivingMonitor",
      level: 2,
      definition: "deceleration_exceeds",
      category: "alarm",
      class: "driving",
      level_group: "driving",
      alert_mode: "alert"
    },
    "IMPACT" => %{
      name: "Impact/choc",
      monitor_type: "AccelerometerMonitor",
      level: 2,
      definition: "acceleration_shock",
      category: "alarm",
      class: "accelerometer",
      level_group: "driving",
      alert_mode: "alert"
    }
  }

  @standalone_presets %{
    "OVERSPEED" => %{
      name: "Excès de vitesse",
      category: "alarm",
      rule: ~s({"trigger":"speed_exceeds","threshold_kmh":80,"min_duration_seconds":5})
    },
    "IDLE" => %{
      name: "Inactivité prolongée",
      category: "alarm",
      rule: ~s({"trigger":"no_movement","duration_minutes":15})
    },
    "FUEL_DROP" => %{
      name: "Chute de carburant",
      category: "fuel",
      rule: ~s({"trigger":"fuel_drop","drop_percent":20,"window_minutes":5})
    },
    "GEO_ENTER_CUSTOM" => %{
      name: "Entrée zone personnalisée",
      category: "geofence",
      rule: ~s({"trigger":"geofence_enter","feature_collection_id":"<uuid>"})
    },
    "GEO_EXIT_CUSTOM" => %{
      name: "Sortie zone personnalisée",
      category: "geofence",
      rule: ~s({"trigger":"geofence_exit","feature_collection_id":"<uuid>"})
    },
    "GEO_INSIDE_CUSTOM" => %{
      name: "Présence zone",
      category: "geofence",
      rule:
        ~s({"trigger":"geofence_inside","feature_collection_id":"<uuid>","report_interval_minutes":10})
    },
    "POI_NEAR_CUSTOM" => %{
      name: "Proximité POI",
      category: "geofence",
      rule: ~s({"trigger":"poi_near","feature_collection_id":"<uuid>"})
    },
    "POI_APPROACHING_CUSTOM" => %{
      name: "Approche POI",
      category: "geofence",
      rule: ~s({"trigger":"poi_approaching","feature_collection_id":"<uuid>"})
    },
    "POI_LEAVING_CUSTOM" => %{
      name: "Départ POI",
      category: "geofence",
      rule: ~s({"trigger":"poi_leaving","feature_collection_id":"<uuid>"})
    },
    "SPEED_EXCEEDS" => %{
      name: "Excès vitesse",
      category: "alarm",
      rule: ~s({"trigger":"speed_exceeds","threshold_kmh":80,"min_duration_seconds":5})
    },
    "NO_MOVEMENT" => %{
      name: "Absence mouvement",
      category: "alarm",
      rule: ~s({"trigger":"no_movement","duration_minutes":15})
    },
    "GEOFENCE_ENTER" => %{
      name: "Entrée zone géo",
      category: "physical",
      rule: ~s({"trigger":"geofence_enter","feature_collection_id":"<uuid>"})
    },
    "GEOFENCE_EXIT" => %{
      name: "Sortie zone géo",
      category: "physical",
      rule: ~s({"trigger":"geofence_exit","feature_collection_id":"<uuid>"})
    },
    "GEOFENCE_INSIDE" => %{
      name: "Présence zone",
      category: "derived",
      rule:
        ~s({"trigger":"geofence_inside","feature_collection_id":"<uuid>","report_interval_minutes":10})
    }
  }

  @impl true
  def mount(params, _session, socket) do
    if connected?(socket), do: Phoenix.PubSub.subscribe(EventDefinition.PubSub, "global_events")

    orgs = load_orgs()
    selected_org_id = selected_org_id(params, orgs)
    org_map = Map.new(orgs, fn o -> {o.id, o.name} end)
    org_options = Enum.map(orgs, fn o -> {o.name <> " (" <> o.slug <> ")", o.id} end)

    {:ok,
     socket
     |> assign_static_options()
     |> assign(
       organizations: orgs,
       org_options: org_options,
       org_map: org_map,
       selected_org_id: selected_org_id,
       selected_org: selected_org_id,
       selected_org_label: org_label(orgs, selected_org_id),
       active_tab: "global",
       modal: nil,
       form: to_form(%{}),
       editing_record: nil,
       json_error: nil
     )
     |> refresh_all()}
  end

  @impl true
  def handle_event("switch-tab", %{"tab" => tab}, socket)
      when tab in ~w(global organization custom) do
    {:noreply, assign(socket, active_tab: tab, modal: nil, form: to_form(%{}), json_error: nil)}
  end

  @impl true
  def handle_event("select-org", %{"org_id" => org_id}, socket) do
    org_id = if org_id == "", do: nil, else: normalize_uuid(org_id)
    org_map = Map.new(socket.assigns.organizations, fn o -> {o.id, o.name} end)

    {:noreply,
     socket
     |> assign(
       org_map: org_map,
       selected_org_id: org_id,
       selected_org: org_id,
       selected_org_label: org_label(socket.assigns.organizations, org_id)
     )
     |> refresh_org_data()}
  end

  @impl true
  def handle_event("validate", params, socket) do
    current = socket.assigns.form
    merged = merge_form_params(current, params)
    code = merged["code"]
    name = merged["name"]

    auto_filled =
      cond do
        Map.has_key?(params, "code") && code != "" && code != current["code"] ->
          auto_fill_from_preset(code, merged)

        Map.has_key?(params, "name") && name != "" && name != current["name"] ->
          case find_code_by_name(name) do
            nil -> merged |> Map.put("name", name)
            found_code -> auto_fill_from_preset(found_code, merged |> Map.put("code", found_code))
          end

        true ->
          merged
      end

    socket =
      if Map.has_key?(params, "organization_id") do
        org_id = params["organization_id"]
        org_map = Map.new(socket.assigns.organizations, fn o -> {o.id, o.name} end)

        socket
        |> assign(
          selected_org_id: org_id,
          selected_org: org_id,
          selected_org_label: org_label(socket.assigns.organizations, org_id),
          org_map: org_map
        )
        |> refresh_org_data()
      else
        socket
      end

    {:noreply,
     assign(socket,
       form: to_form(auto_filled),
       json_error: validate_json_syntax(auto_filled["occurrence_rule"])
     )}
  end

  @impl true
  def handle_event("open-global-new-modal", _, socket) do
    {:noreply,
     assign(socket,
       modal: :global_new,
       form: empty_global_form(),
       editing_record: nil,
       json_error: nil
     )}
  end

  @impl true
  def handle_event("open-global-edit-modal", %{"id" => id}, socket) do
    event = Enum.find(socket.assigns.global_events, &(to_string(&1.id) == id))

    if event do
      {:noreply,
       assign(socket,
         modal: :global_edit,
         editing_record: event,
         json_error: nil,
         form: %{
           "id" => id,
           "code" => event.code,
           "name" => event.name,
           "monitor_type" => event.monitor_type,
           "level" => to_string(event.level),
           "definition" => event.definition || "",
           "category" => event.category || "",
           "class" => event.class || "",
           "level_group" => event.level_group || ""
         }
       )}
    else
      {:noreply, put_flash(socket, :error, "Événement global introuvable.")}
    end
  end

  @impl true
  def handle_event("open-org-activate-modal", _, socket) do
    {:noreply,
     socket
     |> assign(
       modal: :org_activate,
       form: empty_org_form(),
       activation_form: to_form(empty_org_form()),
       available_events: socket.assigns.active_global_events,
       editing_record: nil,
       json_error: nil
     )}
  end

  @impl true
  def handle_event("on_select_global_event", %{"code" => code}, socket) do
    event = Enum.find(socket.assigns.available_events, &(&1.code == code))
    form = (event && org_activation_form_from_event(event)) || empty_org_form()

    {:noreply, assign(socket, activation_form: to_form(form), json_error: nil)}
  end

  @impl true
  def handle_event("create_org_event", params, socket) do
    code = params["code"]
    event = Enum.find(socket.assigns.available_events, &(&1.code == code))

    if event do
      org_id = socket.assigns.selected_org_id

      now =
        DateTime.utc_now()
        |> DateTime.truncate(:second)

      Repo.insert_all("organization_event_definitions", [
        %{
          id: Ecto.UUID.dump!(Ecto.UUID.generate()),
          organization_id: Ecto.UUID.dump!(org_id),
          event_definition_id: Ecto.UUID.dump!(event.id),
          code: event.code,
          name: blank_to_nil(params["custom_name"]),
          alert_mode: params["alert_mode"] || "none",
          occurrence_rule: decode_occurrence_rule(params["occurrence_rule"]),
          enabled: true,
          inserted_at: now,
          updated_at: now
        }
      ])

      Phoenix.PubSub.broadcast(EventDefinition.PubSub, "global_events", {:org_created, org_id})

      {:noreply,
       socket
       |> close_and_refresh_org()
       |> put_flash(
         :info,
         "Événement « #{event.name} » activé pour #{socket.assigns.selected_org_label}."
       )}
    else
      {:noreply, put_flash(socket, :error, "Événement introuvable.")}
    end
  end

  @impl true
  def handle_event("open-org-edit-modal", %{"id" => id}, socket) do
    event = Enum.find(socket.assigns.org_event_defs, &(to_string(&1.id) == id))

    if event do
      {:noreply,
       assign(socket,
         modal: :org_edit,
         editing_record: event,
         json_error: nil,
         form: %{
           "id" => id,
           "code" => event.code,
           "name" => event.resolved_name || event.name || "",
           "custom_name" => event.name || "",
           "monitor_type" => event.monitor_type || "",
           "definition" => event.resolved_definition || "",
           "alert_mode" => event.alert_mode || "none",
           "occurrence_rule" => encode_rule(event.occurrence_rule)
         }
       )}
    else
      {:noreply, put_flash(socket, :error, "Configuration introuvable.")}
    end
  end

  @impl true
  def handle_event("open-custom-new-modal", _, socket) do
    {:noreply,
     assign(socket,
       modal: :custom_new,
       form: to_form(empty_custom_form()),
       editing_record: nil,
       json_error: nil
     )}
  end

  @impl true
  def handle_event("open-custom-edit-modal", %{"id" => id}, socket) do
    event = Enum.find(socket.assigns.standalone_event_defs, &(to_string(&1.id) == id))

    if event do
      {:noreply,
       assign(socket,
         modal: :custom_edit,
         editing_record: event,
         json_error: nil,
         form:
           to_form(%{
             "id" => id,
             "code" => event.code,
             "name" => event.name || "",
             "category" => event.category || "",
             "level" => to_string(event.level || 2),
             "occurrence_rule" => encode_rule(event.occurrence_rule)
           })
       )}
    else
      {:noreply, put_flash(socket, :error, "Événement personnalisé introuvable.")}
    end
  end

  @impl true
  def handle_event("close-modal", _, socket) do
    {:noreply,
     assign(socket, modal: nil, form: to_form(%{}), editing_record: nil, json_error: nil)}
  end

  @impl true
  def handle_event("update-global-form", %{"code" => code} = params, socket) do
    form =
      if socket.assigns.modal == :global_new and params["_target"] == ["code"] do
        global_form_from_code(code)
      else
        Map.merge(socket.assigns.form, params)
      end

    {:noreply, assign(socket, form: form)}
  end

  @impl true
  def handle_event("update-global-form", params, socket) do
    {:noreply, assign(socket, form: Map.merge(socket.assigns.form, params))}
  end

  @impl true
  def handle_event("update-org-form", %{"event_definition_id" => id} = params, socket) do
    form =
      if socket.assigns.modal == :org_activate and params["_target"] == ["event_definition_id"] do
        org_form_from_event_id(id, socket.assigns.active_global_events)
      else
        Map.merge(socket.assigns.form, params)
      end

    {:noreply,
     assign(socket, form: form, json_error: validate_json_syntax(form["occurrence_rule"]))}
  end

  @impl true
  def handle_event("update-org-form", params, socket) do
    form = Map.merge(socket.assigns.form, params)

    {:noreply,
     assign(socket, form: form, json_error: validate_json_syntax(form["occurrence_rule"]))}
  end

  @impl true
  def handle_event("update-custom-form", %{"preset_code" => code} = params, socket) do
    form =
      if socket.assigns.modal == :custom_new and params["_target"] == ["preset_code"] do
        custom_form_from_code(code)
      else
        Map.merge(socket.assigns.form, Map.drop(params, ["_target"]))
      end

    {:noreply,
     assign(socket,
       form: to_form(form),
       json_error: validate_json_syntax(form["occurrence_rule"])
     )}
  end

  @impl true
  def handle_event("update-custom-form", params, socket) do
    form = Map.merge(socket.assigns.form, Map.drop(params, ["_target"]))

    {:noreply,
     assign(socket,
       form: to_form(form),
       json_error: validate_json_syntax(form["occurrence_rule"])
     )}
  end

  @impl true
  def handle_event("save-global-new", _, socket) do
    form = socket.assigns.form

    with :ok <- require_field(form["code"], "Veuillez sélectionner un code événement."),
         :ok <- require_field(form["name"], "Le nom est obligatoire."),
         {:ok, level} <- parse_level(form["level"]) do
      now = NaiveDateTime.utc_now() |> NaiveDateTime.truncate(:second)
      existing = get_global_by_code(form["code"])

      attrs = [
        code: form["code"],
        name: form["name"],
        definition: form["definition"],
        category: form["category"] || "physical",
        class: form["class"] || "unknown",
        level: level,
        level_group: blank_to_nil(form["level_group"]),
        monitor_type: form["monitor_type"] || "MovementMonitor",
        active: true,
        updated_at: now
      ]

      if existing do
        existing.id
        |> cast_uuid!()
        |> update_global(attrs)

        {:noreply,
         socket
         |> close_and_refresh()
         |> put_flash(:info, "Événement global « #{form["code"]} » réactivé.")}
      else
        Repo.insert_all("event_definitions", [
          [id: Ecto.UUID.dump!(Ecto.UUID.generate()), inserted_at: now] ++ attrs
        ])

        Phoenix.PubSub.broadcast(
          EventDefinition.PubSub,
          "global_events",
          {:event_created, form["code"]}
        )

        {:noreply,
         socket
         |> close_and_refresh()
         |> put_flash(:info, "Événement global « #{form["code"]} » créé.")}
      end
    else
      {:error, reason} -> {:noreply, put_flash(socket, :error, reason)}
    end
  end

  @impl true
  def handle_event("save-global-edit", _, socket) do
    form = socket.assigns.form

    with event when not is_nil(event) <- socket.assigns.editing_record,
         :ok <- require_field(form["name"], "Le nom est obligatoire.") do
      event.id
      |> cast_uuid!()
      |> update_global(
        name: form["name"],
        definition: form["definition"],
        category: form["category"],
        class: form["class"],
        level_group: blank_to_nil(form["level_group"])
      )

      Phoenix.PubSub.broadcast(
        EventDefinition.PubSub,
        "global_events",
        {:event_updated, event.id}
      )

      {:noreply,
       socket
       |> close_and_refresh()
       |> put_flash(:info, "Événement global « #{event.code} » modifié.")}
    else
      nil -> {:noreply, put_flash(socket, :error, "Événement global introuvable.")}
      {:error, reason} -> {:noreply, put_flash(socket, :error, reason)}
    end
  end

  @impl true
  def handle_event("delete-global", %{"id" => id}, socket) do
    event = Enum.find(socket.assigns.global_events, &(to_string(&1.id) == id))

    if event do
      id
      |> cast_uuid!()
      |> update_global(active: false)

      Phoenix.PubSub.broadcast(EventDefinition.PubSub, "global_events", {:event_deleted, id})

      {:noreply,
       socket
       |> refresh_all()
       |> put_flash(:info, "Événement global « #{event.code} » désactivé.")}
    else
      {:noreply, put_flash(socket, :error, "Événement global introuvable.")}
    end
  end

  @impl true
  def handle_event("save", params, socket) do
    org_id = params["organization_id"]
    code = params["code"] |> to_string() |> String.trim()

    with :ok <- require_field(org_id, "Sélectionnez une organisation."),
         :ok <- require_field(code, "Le code événement est obligatoire."),
         {:ok, rule} <- decode_json_rule(params["occurrence_rule"]) do
      org_bin = cast_uuid!(org_id)

      existing =
        from(oed in "organization_event_definitions",
          where: oed.organization_id == type(^org_bin, Ecto.UUID) and oed.code == ^code,
          select: %{id: oed.id, name: oed.name, alert_mode: oed.alert_mode}
        )
        |> Repo.one()

      now = NaiveDateTime.utc_now() |> NaiveDateTime.truncate(:second)

      if existing do
        update_org_event(
          cast_uuid!(existing.id),
          name: params["name"] || code,
          definition: params["definition"],
          category: params["category"],
          class: params["class"],
          level: String.to_integer(params["level"] || "1"),
          level_group: params["level_group"],
          alert_mode: params["alert_mode"] || "none",
          occurrence_rule: rule,
          enabled: params["enabled"] == "true"
        )
      else
        Repo.insert_all("organization_event_definitions", [
          %{
            id: Ecto.UUID.dump!(Ecto.UUID.generate()),
            organization_id: Ecto.UUID.dump!(org_id),
            event_definition_id: nil,
            code: code,
            name: params["name"] || code,
            definition: params["definition"],
            category: params["category"],
            class: params["class"],
            level: String.to_integer(params["level"] || "1"),
            level_group: params["level_group"],
            occurrence_rule: rule,
            alert_mode: params["alert_mode"] || "none",
            enabled: params["enabled"] == "true",
            author_id: Ecto.UUID.dump!(org_id),
            inserted_at: now,
            updated_at: now
          }
        ])
      end

      Phoenix.PubSub.broadcast(EventDefinition.PubSub, "global_events", {:org_created, org_id})

      msg =
        if(existing,
          do: "Configuration « #{code} » mise à jour",
          else: "Configuration « #{code} » créée"
        )

      {:noreply,
       socket
       |> assign(form: to_form(%{}))
       |> refresh_org_data()
       |> put_flash(:info, msg)}
    else
      {:error, reason} ->
        {:noreply, assign(socket, json_error: reason) |> put_flash(:error, reason)}
    end
  end

  @impl true
  def handle_event("delete", _, socket) do
    editing = socket.assigns.editing_record

    if editing do
      binary_id = cast_uuid!(editing.id)

      from(oed in "organization_event_definitions", where: oed.id == type(^binary_id, Ecto.UUID))
      |> Repo.delete_all()

      Phoenix.PubSub.broadcast(
        EventDefinition.PubSub,
        "global_events",
        {:org_created, socket.assigns.selected_org_id}
      )

      msg = "Configuration « #{editing.code} » supprimée."

      {:noreply,
       socket
       |> assign(form: to_form(%{}), editing_record: nil)
       |> refresh_org_data()
       |> put_flash(:info, msg)}
    else
      {:noreply,
       socket
       |> assign(editing_record: nil, form: to_form(%{}))
       |> refresh_org_data()
       |> put_flash(:info, "Aucune configuration à supprimer.")}
    end
  end

  @impl true
  def handle_event("save-org-activate", _, socket) do
    org_id = socket.assigns.selected_org_id
    form = socket.assigns.form

    with :ok <- require_field(org_id, "Sélectionnez une organisation."),
         :ok <-
           require_field(form["event_definition_id"], "Sélectionnez un événement du catalogue."),
         global when not is_nil(global) <-
           find_global(socket.assigns.active_global_events, form["event_definition_id"]),
         {:ok, rule} <- decode_json_rule(form["occurrence_rule"]) do
      org_bin = cast_uuid!(org_id)
      event_bin = cast_uuid!(global.id)

      existing =
        from(oed in "organization_event_definitions",
          where:
            oed.organization_id == type(^org_bin, Ecto.UUID) and
              (oed.event_definition_id == type(^event_bin, Ecto.UUID) or oed.code == ^global.code),
          select: count(oed.id)
        )
        |> Repo.one()

      if existing > 0 do
        {:noreply,
         put_flash(socket, :error, "Cet événement est déjà configuré pour l'organisation active.")}
      else
        now = NaiveDateTime.utc_now() |> NaiveDateTime.truncate(:second)

        Repo.insert_all("organization_event_definitions", [
          [
            id: Ecto.UUID.dump!(Ecto.UUID.generate()),
            organization_id: org_bin,
            event_definition_id: event_bin,
            code: global.code,
            name: blank_to_nil(form["custom_name"]),
            definition: nil,
            category: nil,
            class: nil,
            level: nil,
            level_group: nil,
            occurrence_rule: rule,
            alert_mode: form["alert_mode"] || "none",
            enabled: true,
            author_id: org_bin,
            inserted_at: now,
            updated_at: now
          ]
        ])

        {:noreply,
         socket
         |> close_and_refresh_org()
         |> put_flash(
           :info,
           "Événement « #{global.code} » activé pour #{socket.assigns.selected_org_label}."
         )}
      end
    else
      nil -> {:noreply, put_flash(socket, :error, "Événement global introuvable.")}
      {:error, reason} -> {:noreply, assign(socket, json_error: reason)}
    end
  end

  @impl true
  def handle_event("save-org-edit", _, socket) do
    form = socket.assigns.form

    with event when not is_nil(event) <- socket.assigns.editing_record,
         {:ok, rule} <- decode_json_rule(form["occurrence_rule"]) do
      event.id
      |> cast_uuid!()
      |> update_org_event(
        name: blank_to_nil(form["custom_name"]),
        occurrence_rule: rule,
        alert_mode: form["alert_mode"] || "none"
      )

      {:noreply,
       socket
       |> close_and_refresh_org()
       |> put_flash(:info, "Configuration « #{event.code} » modifiée.")}
    else
      nil -> {:noreply, put_flash(socket, :error, "Configuration introuvable.")}
      {:error, reason} -> {:noreply, assign(socket, json_error: reason)}
    end
  end

  @impl true
  def handle_event("toggle-org-enabled", %{"id" => id}, socket) do
    toggle_org_record(id, socket.assigns.org_event_defs, socket)
  end

  @impl true
  def handle_event("delete-org-config", %{"id" => id}, socket) do
    delete_org_record(id, socket.assigns.org_event_defs, socket, "Configuration supprimée.")
  end

  @impl true
  def handle_event("save-custom-new", params, socket) do
    org_id = params["organization_id"] || socket.assigns.selected_org_id
    code = params["code"] |> to_string() |> String.trim()

    with :ok <- require_field(org_id, "Sélectionnez une organisation."),
         :ok <- validate_custom_code(code),
         :ok <- require_field(params["name"], "Le nom est obligatoire."),
         {:ok, rule} <- decode_json_rule(params["occurrence_rule"]) do
      existing =
        from(oed in "organization_event_definitions",
          where:
            oed.organization_id == type(^cast_uuid!(org_id), Ecto.UUID) and oed.code == ^code,
          select: count(oed.id)
        )
        |> Repo.one()

      if existing > 0 do
        {:noreply,
         put_flash(socket, :error, "Le code « #{code} » existe déjà pour cette organisation.")}
      else
        now = NaiveDateTime.utc_now() |> NaiveDateTime.truncate(:second)

        Repo.insert_all("organization_event_definitions", [
          %{
            id: Ecto.UUID.dump!(Ecto.UUID.generate()),
            organization_id: Ecto.UUID.dump!(org_id),
            event_definition_id: nil,
            code: code,
            name: params["name"],
            definition: nil,
            category: params["category"] || "alarm",
            class: nil,
            level: 2,
            level_group: nil,
            occurrence_rule: rule,
            alert_mode: "none",
            enabled: true,
            author_id: Ecto.UUID.dump!(org_id),
            inserted_at: now,
            updated_at: now
          }
        ])

        Phoenix.PubSub.broadcast(EventDefinition.PubSub, "global_events", {:org_created, org_id})

        {:noreply,
         socket
         |> close_and_refresh_org()
         |> put_flash(:info, "Événement personnalisé « #{code} » créé.")}
      end
    else
      {:error, reason} ->
        {:noreply, assign(socket, json_error: reason) |> put_flash(:error, reason)}
    end
  end

  @impl true
  def handle_event("save-custom-edit", params, socket) do
    with event when not is_nil(event) <- socket.assigns.editing_record,
         :ok <- require_field(params["name"], "Le nom est obligatoire."),
         {:ok, rule} <- decode_json_rule(params["occurrence_rule"]) do
      event.id
      |> cast_uuid!()
      |> update_org_event(name: params["name"], occurrence_rule: rule)

      Phoenix.PubSub.broadcast(
        EventDefinition.PubSub,
        "global_events",
        {:org_created, socket.assigns.selected_org_id}
      )

      {:noreply,
       socket
       |> close_and_refresh_org()
       |> put_flash(:info, "Événement personnalisé « #{event.code} » modifié.")}
    else
      nil ->
        {:noreply, put_flash(socket, :error, "Événement personnalisé introuvable.")}

      {:error, reason} ->
        {:noreply, assign(socket, json_error: reason) |> put_flash(:error, reason)}
    end
  end

  @impl true
  def handle_event("toggle-custom-enabled", %{"id" => id}, socket) do
    toggle_org_record(id, socket.assigns.standalone_event_defs, socket)
  end

  @impl true
  def handle_event("delete-custom", %{"id" => id}, socket) do
    delete_org_record(
      id,
      socket.assigns.standalone_event_defs,
      socket,
      "Événement personnalisé supprimé."
    )
  end

  @impl true
  def handle_info({:org_created, _name}, socket) do
    orgs = load_orgs()

    {:noreply,
     socket
     |> assign(
       organizations: orgs,
       selected_org_label: org_label(orgs, socket.assigns.selected_org_id)
     )
     |> refresh_all()}
  end

  @impl true
  def handle_info(_msg, socket), do: {:noreply, refresh_all(socket)}

  defp assign_static_options(socket) do
    assign(socket,
      alert_modes: @alert_modes,
      categories: @categories,
      classes: @classes,
      standalone_categories: @standalone_categories,
      global_preset_codes: Map.keys(@global_presets) |> Enum.sort(),
      standalone_presets: @standalone_presets,
      standalone_preset_codes: Map.keys(@standalone_presets) |> Enum.sort(),
      standalone_code_options: build_standalone_code_options(),
      codes: distinct_values(:code),
      names: distinct_values(:name),
      level_groups: Enum.uniq(distinct_values(:level_group) ++ @spec_level_groups),
      definitions: distinct_values(:definition),
      code_options: build_code_options(),
      name_options: build_name_options()
    )
  end

  defp build_code_options do
    @global_presets
    |> Enum.sort_by(fn {code, _} -> code end)
    |> Enum.map(fn {code, preset} -> {preset.name <> " (" <> code <> ")", code} end)
  end

  defp build_name_options do
    @global_presets
    |> Enum.sort_by(fn {_, preset} -> preset.name end)
    |> Enum.map(fn {_code, preset} -> {preset.name, preset.name} end)
  end

  defp build_standalone_code_options do
    @standalone_presets
    |> Enum.sort_by(fn {code, _} -> code end)
    |> Enum.map(fn {code, preset} -> {preset.name <> " (" <> code <> ")", code} end)
  end

  defp refresh_all(socket) do
    socket
    |> assign(
      global_events: load_global_events(),
      active_global_events: load_active_global_events()
    )
    |> refresh_org_data()
  end

  defp refresh_org_data(socket) do
    org_id = socket.assigns.selected_org_id

    assign(socket,
      org_event_defs: load_org_event_defs(org_id),
      standalone_event_defs: load_standalone_event_defs(org_id)
    )
  end

  defp close_and_refresh(socket) do
    socket
    |> assign(modal: nil, form: to_form(%{}), editing_record: nil, json_error: nil)
    |> refresh_all()
  end

  defp close_and_refresh_org(socket) do
    socket
    |> assign(modal: nil, form: to_form(%{}), editing_record: nil, json_error: nil)
    |> refresh_org_data()
  end

  defp default_org_id(orgs) do
    cond do
      org = Enum.find(orgs, &(&1.name == "Demo Corp")) -> org.id
      org = Enum.find(orgs, &(&1.name == "Organisation 1")) -> org.id
      orgs != [] -> List.first(orgs).id
      true -> nil
    end
  end

  defp selected_org_id(%{"org_id" => org_id}, orgs) do
    org_id = normalize_uuid(org_id)

    if Enum.any?(orgs, &(&1.id == org_id)) do
      org_id
    else
      default_org_id(orgs)
    end
  end

  defp selected_org_id(_params, orgs), do: default_org_id(orgs)

  defp org_label(orgs, org_id) do
    if org = Enum.find(orgs, &(&1.id == org_id)), do: org.name, else: ""
  end

  defp empty_global_form do
    %{
      "code" => "",
      "name" => "",
      "monitor_type" => "",
      "level" => "",
      "definition" => "",
      "category" => "",
      "class" => "",
      "level_group" => ""
    }
  end

  defp empty_org_form do
    %{
      "event_definition_id" => "",
      "code" => "",
      "name" => "",
      "custom_name" => "",
      "monitor_type" => "",
      "definition" => "",
      "alert_mode" => "none",
      "occurrence_rule" => ""
    }
  end

  defp org_activation_form_from_event(event) do
    %{
      "event_definition_id" => to_string(event.id),
      "code" => event.code,
      "name" => event.name,
      "custom_name" => "",
      "monitor_type" => event.monitor_type,
      "definition" => event.definition || "",
      "alert_mode" => "none",
      "occurrence_rule" => occurrence_rule_template(event)
    }
  end

  defp empty_custom_form do
    %{
      "preset_code" => "",
      "code" => "",
      "name" => "",
      "category" => "alarm",
      "level" => "2",
      "occurrence_rule" => ""
    }
  end

  defp global_form_from_code(""), do: empty_global_form()

  defp global_form_from_code(code) do
    case Map.get(@global_presets, code) do
      nil ->
        empty_global_form() |> Map.put("code", code)

      preset ->
        %{
          "code" => code,
          "name" => preset.name,
          "monitor_type" => preset.monitor_type,
          "level" => to_string(preset.level),
          "definition" => preset.definition,
          "category" => preset.category,
          "class" => preset.class,
          "level_group" => preset.level_group
        }
    end
  end

  defp org_form_from_event_id("", _events), do: empty_org_form()

  defp org_form_from_event_id(id, events) do
    case find_global(events, id) do
      nil ->
        empty_org_form()

      event ->
        %{
          "event_definition_id" => to_string(event.id),
          "code" => event.code,
          "name" => event.name,
          "custom_name" => "",
          "monitor_type" => event.monitor_type,
          "definition" => event.definition || "",
          "alert_mode" => "none",
          "occurrence_rule" => occurrence_rule_template(event)
        }
    end
  end

  defp custom_form_from_code(""), do: empty_custom_form()

  defp custom_form_from_code(code) do
    case Map.get(@standalone_presets, code) do
      nil ->
        empty_custom_form() |> Map.put("preset_code", code) |> Map.put("code", code)

      preset ->
        %{
          "preset_code" => code,
          "code" => code,
          "name" => preset.name,
          "category" => preset.category,
          "level" => "2",
          "occurrence_rule" => preset.rule
        }
    end
  end

  defp occurrence_rule_template(%{code: "LOW_BATTERY"}),
    do: ~s({"trigger":"battery_voltage_below","threshold_volts":11.8,"min_duration_seconds":10})

  defp occurrence_rule_template(%{code: "GPS_LOST"}),
    do: ~s({"trigger":"heartbeat_missed","timeout_minutes":10})

  defp occurrence_rule_template(%{code: "GPS_RESTORED"}),
    do: ~s({"trigger":"heartbeat_restored","timeout_minutes":10})

  defp occurrence_rule_template(%{code: "CONN_LOST"}),
    do: ~s({"trigger":"heartbeat_missed","timeout_minutes":10})

  defp occurrence_rule_template(%{level: 1}) do
    ~s({"trigger":"min_distance","min_distance_meters":100})
  end

  defp occurrence_rule_template(%{code: "OVERSPEED"}),
    do: ~s({"trigger":"speed_exceeds","threshold_kmh":80,"min_duration_seconds":5})

  defp occurrence_rule_template(%{code: "IDLE"}),
    do: ~s({"trigger":"no_movement","duration_minutes":15})

  defp occurrence_rule_template(%{code: "GEO_ENTER"}),
    do: ~s({"trigger":"geofence_enter","feature_collection_id":"<uuid>"})

  defp occurrence_rule_template(%{code: "GEO_EXIT"}),
    do: ~s({"trigger":"geofence_exit","feature_collection_id":"<uuid>"})

  defp occurrence_rule_template(%{code: "GEO_INSIDE"}),
    do:
      ~s({"trigger":"geofence_inside","feature_collection_id":"<uuid>","report_interval_minutes":10})

  defp occurrence_rule_template(%{code: "POI_NEAR"}),
    do: ~s({"trigger":"poi_near","feature_collection_id":"<uuid>"})

  defp occurrence_rule_template(%{code: "POI_APPROACHING"}),
    do: ~s({"trigger":"poi_approaching","feature_collection_id":"<uuid>"})

  defp occurrence_rule_template(%{code: "POI_LEAVING"}),
    do: ~s({"trigger":"poi_leaving","feature_collection_id":"<uuid>"})

  defp occurrence_rule_template(%{code: "FUEL_DROP"}),
    do: ~s({"trigger":"fuel_drop","drop_percent":20,"window_minutes":5})

  defp occurrence_rule_template(%{code: "HARSH_BRAKE"}),
    do: ~s({"trigger":"deceleration_exceeds","threshold_g":0.35})

  defp occurrence_rule_template(%{code: "IMPACT"}),
    do: ~s({"trigger":"acceleration_shock","threshold_g":2.5})

  defp occurrence_rule_template(%{definition: trigger})
       when is_binary(trigger) and trigger != "" do
    ~s({"trigger":"#{trigger}"})
  end

  defp occurrence_rule_template(_), do: "{}"

  defp load_orgs do
    from(o in "organizations",
      select: %{id: o.id, name: o.name, slug: o.slug},
      order_by: [asc: o.name]
    )
    |> Repo.all()
    |> Enum.map(fn org -> %{org | id: normalize_uuid(org.id)} end)
  end

  defp load_global_events do
    from(e in "event_definitions",
      select: %{
        id: e.id,
        code: e.code,
        name: e.name,
        definition: e.definition,
        category: e.category,
        class: e.class,
        level: e.level,
        level_group: e.level_group,
        monitor_type: e.monitor_type,
        active: e.active
      },
      order_by: [asc: e.level, asc: e.code]
    )
    |> Repo.all()
    |> Enum.map(fn event -> %{event | id: normalize_uuid(event.id)} end)
  end

  defp load_active_global_events do
    from(e in "event_definitions",
      where: e.active == true,
      select: %{
        id: e.id,
        code: e.code,
        name: e.name,
        definition: e.definition,
        category: e.category,
        class: e.class,
        level: e.level,
        level_group: e.level_group,
        monitor_type: e.monitor_type,
        active: e.active
      },
      order_by: [asc: e.level, asc: e.code]
    )
    |> Repo.all()
    |> Enum.map(fn event -> %{event | id: normalize_uuid(event.id)} end)
  end

  defp load_org_event_defs(nil), do: []

  defp load_org_event_defs(org_id) do
    binary_org_id = cast_uuid!(org_id)

    from(oed in "organization_event_definitions",
      left_join: e in "event_definitions",
      on: oed.event_definition_id == e.id,
      where:
        oed.organization_id == type(^binary_org_id, Ecto.UUID) and
          not is_nil(oed.event_definition_id),
      select: %{
        id: oed.id,
        event_definition_id: oed.event_definition_id,
        code: oed.code,
        name: oed.name,
        resolved_name: fragment("COALESCE(?, ?)", oed.name, e.name),
        resolved_definition: fragment("COALESCE(?, ?)", oed.definition, e.definition),
        resolved_category: fragment("COALESCE(?, ?)", oed.category, e.category),
        resolved_class: fragment("COALESCE(?, ?)", oed.class, e.class),
        resolved_level: fragment("COALESCE(?, ?)", oed.level, e.level),
        resolved_level_group: fragment("COALESCE(?, ?)", oed.level_group, e.level_group),
        monitor_type: e.monitor_type,
        occurrence_rule: oed.occurrence_rule,
        alert_mode: oed.alert_mode,
        enabled: oed.enabled
      },
      order_by: [asc: oed.code]
    )
    |> Repo.all()
    |> Enum.map(fn event ->
      %{
        event
        | id: normalize_uuid(event.id),
          event_definition_id: normalize_uuid(event.event_definition_id)
      }
    end)
  end

  defp load_standalone_event_defs(nil), do: []

  defp load_standalone_event_defs(org_id) do
    binary_org_id = cast_uuid!(org_id)

    from(oed in "organization_event_definitions",
      where:
        oed.organization_id == type(^binary_org_id, Ecto.UUID) and
          is_nil(oed.event_definition_id),
      select: %{
        id: oed.id,
        code: oed.code,
        name: oed.name,
        category: oed.category,
        level: oed.level,
        occurrence_rule: oed.occurrence_rule,
        enabled: oed.enabled
      },
      order_by: [asc: oed.code]
    )
    |> Repo.all()
    |> Enum.map(fn event -> %{event | id: normalize_uuid(event.id)} end)
  end

  defp get_global_by_code(code) do
    from(e in "event_definitions",
      where: e.code == ^code,
      select: %{id: e.id, code: e.code}
    )
    |> Repo.one()
    |> case do
      nil -> nil
      event -> %{event | id: normalize_uuid(event.id)}
    end
  end

  defp find_global(events, id), do: Enum.find(events, &(to_string(&1.id) == to_string(id)))

  defp update_global(id, attrs) do
    from(e in "event_definitions", where: e.id == type(^id, Ecto.UUID))
    |> Repo.update_all(
      set:
        Keyword.put_new(
          attrs,
          :updated_at,
          NaiveDateTime.utc_now() |> NaiveDateTime.truncate(:second)
        )
    )
  end

  defp update_org_event(id, attrs) do
    from(oed in "organization_event_definitions", where: oed.id == type(^id, Ecto.UUID))
    |> Repo.update_all(
      set:
        Keyword.put_new(
          attrs,
          :updated_at,
          NaiveDateTime.utc_now() |> NaiveDateTime.truncate(:second)
        )
    )
  end

  defp toggle_org_record(id, records, socket) do
    record = Enum.find(records, &(to_string(&1.id) == id))

    if record do
      update_org_event(cast_uuid!(id), enabled: !record.enabled)

      Phoenix.PubSub.broadcast(
        EventDefinition.PubSub,
        "global_events",
        {:org_created, socket.assigns.selected_org_id}
      )

      {:noreply,
       socket
       |> refresh_org_data()
       |> put_flash(:info, "Statut de « #{record.code} » mis à jour.")}
    else
      {:noreply, put_flash(socket, :error, "Événement introuvable.")}
    end
  end

  defp delete_org_record(id, records, socket, message) do
    record = Enum.find(records, &(to_string(&1.id) == id))

    if record do
      binary_id = cast_uuid!(id)

      from(oed in "organization_event_definitions", where: oed.id == type(^binary_id, Ecto.UUID))
      |> Repo.delete_all()

      Phoenix.PubSub.broadcast(
        EventDefinition.PubSub,
        "global_events",
        {:org_created, socket.assigns.selected_org_id}
      )

      {:noreply,
       socket
       |> refresh_org_data()
       |> put_flash(:info, message)}
    else
      {:noreply, put_flash(socket, :error, "Événement introuvable.")}
    end
  end

  defp require_field(nil, message), do: {:error, message}
  defp require_field("", message), do: {:error, message}

  defp require_field(value, _message) when is_binary(value),
    do: if(String.trim(value) == "", do: {:error, "Champ obligatoire."}, else: :ok)

  defp require_field(_value, _message), do: :ok

  defp parse_level(value) do
    case Integer.parse(to_string(value || "")) do
      {level, ""} when level in [1, 2] -> {:ok, level}
      _ -> {:error, "Le niveau doit être 1 ou 2."}
    end
  end

  defp validate_custom_code(code) do
    cond do
      code == "" ->
        {:error, "Le code est obligatoire."}

      String.length(code) > 20 ->
        {:error, "Le code doit contenir 20 caractères maximum."}

      code != String.upcase(code) ->
        {:error, "Le code doit être en majuscules."}

      not Regex.match?(~r/^[A-Z0-9_]+$/, code) ->
        {:error, "Le code accepte uniquement A-Z, 0-9 et underscore."}

      true ->
        :ok
    end
  end

  defp decode_json_rule(nil), do: {:error, "La règle JSON est obligatoire."}
  defp decode_json_rule(""), do: {:error, "La règle JSON est obligatoire."}

  defp decode_json_rule(value) when is_binary(value) do
    case Jason.decode(value) do
      {:ok, rule} when is_map(rule) -> {:ok, rule}
      {:ok, _} -> {:error, "La règle JSON doit être un objet."}
      {:error, _} -> {:error, "Syntaxe JSON invalide. Vérifiez les guillemets et virgules."}
    end
  end

  defp validate_json_syntax(nil), do: nil
  defp validate_json_syntax(""), do: nil

  defp validate_json_syntax(value) when is_binary(value) do
    case Jason.decode(value) do
      {:ok, map} when is_map(map) -> nil
      {:ok, _} -> "La règle JSON doit être un objet."
      {:error, _} -> "Format JSON invalide."
    end
  end

  defp encode_rule(nil), do: "{}"
  defp encode_rule(rule), do: Jason.encode!(rule)

  defp decode_occurrence_rule(nil), do: nil
  defp decode_occurrence_rule(""), do: nil
  defp decode_occurrence_rule("{}"), do: nil

  defp decode_occurrence_rule(value) when is_binary(value) do
    case Jason.decode(value) do
      {:ok, map} when is_map(map) -> map
      _ -> nil
    end
  end

  defp distinct_values(field) do
    from(e in "event_definitions",
      select: field(e, ^field),
      distinct: true,
      order_by: field(e, ^field)
    )
    |> Repo.all()
    |> Enum.reject(fn v -> is_nil(v) or v == "" end)
  end

  defp blank_to_nil(nil), do: nil

  defp blank_to_nil(value) when is_binary(value),
    do: if(String.trim(value) == "", do: nil, else: value)

  defp blank_to_nil(value), do: value

  defp cast_uuid!(id), do: Ecto.UUID.cast!(id)

  defp normalize_uuid(nil), do: nil

  defp normalize_uuid(id) when is_binary(id) do
    case Ecto.UUID.load(id) do
      {:ok, uuid} -> uuid
      :error -> id
    end
  end

  defp normalize_uuid(id), do: to_string(id)

  defp merge_form_params(form, params) do
    current =
      case form do
        %Phoenix.HTML.Form{} -> form.params
        map when is_map(map) -> map
      end

    enabled =
      cond do
        Map.has_key?(params, "enabled") -> params["enabled"]
        Map.has_key?(params, "_unused_enabled") -> "false"
        true -> current["enabled"]
      end

    current
    |> Map.merge(
      Map.drop(params, [
        "_target" | Enum.filter(Map.keys(params), &String.starts_with?(&1, "_unused_"))
      ])
    )
    |> Map.put("enabled", enabled)
  end

  defp auto_fill_from_preset(code, form) do
    case Map.get(@global_presets, code) do
      nil ->
        form

      preset ->
        form
        |> Map.put("name", to_string(preset.name))
        |> Map.put("monitor_type", to_string(preset.monitor_type))
        |> Map.put("level", to_string(preset.level))
        |> Map.put("definition", to_string(preset.definition))
        |> Map.put("category", to_string(preset.category))
        |> Map.put("class", to_string(preset.class))
        |> Map.put("level_group", to_string(preset.level_group))
        |> Map.put("alert_mode", to_string(preset.alert_mode))
        |> Map.put("occurrence_rule", occurrence_rule_for_code(code))
    end
  end

  defp find_code_by_name(name) do
    @global_presets
    |> Enum.find_value(fn {code, preset} -> if preset.name == name, do: code end)
  end

  defp occurrence_rule_for_code(code) do
    template = occurrence_rule_template(%{code: code})

    case template do
      "{}" ->
        case Map.get(@standalone_presets, code) do
          nil -> "{}"
          preset -> preset.rule
        end

      _ ->
        template
    end
  end
end
