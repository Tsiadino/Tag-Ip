defmodule EventDefinitionWeb.OrgEventStandaloneNewLive do
  use EventDefinitionWeb, :live_view

  alias EventDefinition.Repo
  import Ecto.Query, only: [from: 2]

  @spec_classes ~w(movement power fuel geofence driver alarm connectivity)
  @spec_level_groups ~w(movement power fuel geofence driver alarm connectivity speed geofence poi)
  @spec_triggers ~w(speed_exceeds no_movement geofence_enter geofence_exit geofence_inside poi_near poi_approaching poi_leaving fuel_drop min_distance)

  @trigger_params %{
    "speed_exceeds" => ~w(threshold_kmh min_duration_seconds),
    "no_movement" => ~w(duration_minutes),
    "geofence_enter" => ~w(feature_collection_id),
    "geofence_exit" => ~w(feature_collection_id),
    "geofence_inside" => ~w(feature_collection_id report_interval_minutes),
    "poi_near" => ~w(feature_collection_id),
    "poi_approaching" => ~w(feature_collection_id),
    "poi_leaving" => ~w(feature_collection_id),
    "fuel_drop" => ~w(drop_percent window_minutes),
    "min_distance" => ~w(min_distance_meters)
  }

  @trigger_label %{
    "speed_exceeds" => "Excès de vitesse",
    "no_movement" => "Absence de mouvement",
    "geofence_enter" => "Entrée dans zone",
    "geofence_exit" => "Sortie de zone",
    "geofence_inside" => "Présence dans zone",
    "poi_near" => "Proximité POI",
    "poi_approaching" => "Approche POI",
    "poi_leaving" => "Départ POI",
    "fuel_drop" => "Baisse carburant",
    "min_distance" => "Distance minimum"
  }

  @impl true
  def mount(%{"org_id" => org_id}, session, socket) do
    org = load_org(org_id)
    current_user_id = session["user_id"]

    if org do
      form =
        to_form(
          %{
            "code" => "",
            "name" => "",
            "definition" => "",
            "category" => "",
            "class" => "",
            "level" => "2",
            "level_group" => "",
            "alert_mode" => "none",
            "enabled" => "true"
          },
          as: :standalone_event
        )

      {:ok,
       socket
       |> assign(:form, form)
       |> assign(:org, org)
       |> assign(:org_id, org_id)
       |> assign(:current_user_id, current_user_id)
       |> assign(:trigger, "")
       |> assign(:current_params, %{})
       |> assign(:classes, @spec_classes)
       |> assign(:level_groups, @spec_level_groups)
       |> assign(:triggers, @spec_triggers)
       |> assign(:trigger_label, @trigger_label)
       |> assign(:trigger_param_map, @trigger_params)
       |> assign(:codes, distinct_values(:code))
       |> assign(:names, distinct_values(:name))
       |> assign(:definitions, distinct_values(:definition))
       |> assign(:feature_collections, load_feature_collections())}
    else
      {:ok,
       socket
       |> put_flash(:error, "Organisation introuvable")
       |> push_navigate(to: ~p"/org-events")}
    end
  end

  @impl true
  def handle_event("validate", %{"standalone_event" => params}, socket) do
    trigger = params["trigger"] || ""
    form = to_form(params, as: :standalone_event)

    {:noreply,
     socket
     |> assign(:form, form)
     |> assign(:trigger, trigger)
     |> assign(:current_params, params)}
  end

  @impl true
  def handle_event("save", %{"standalone_event" => params}, socket) do
    org_id = socket.assigns.org_id
    org_id_bin = uuid_bin!(org_id)
    trigger = params["trigger"] || ""
    rule = build_rule(trigger, params)

    author_id_bin =
      if uid = socket.assigns.current_user_id, do: uuid_bin!(uid), else: org_id_bin

    case validate_occurrence_rule(rule) do
      :ok ->
        db_params = %{
          id: uuid_bin!(Ecto.UUID.generate()),
          organization_id: org_id_bin,
          event_definition_id: nil,
          code: params["code"],
          name: params["name"],
          definition: empty_to_nil(params["definition"]),
          category: params["category"],
          class: params["class"],
          level: String.to_integer(params["level"] || "2"),
          level_group: empty_to_nil(params["level_group"]),
          occurrence_rule: rule,
          alert_mode: params["alert_mode"] || "none",
          enabled: params["enabled"] == "true",
          author_id: author_id_bin,
          inserted_at: NaiveDateTime.utc_now() |> NaiveDateTime.truncate(:second),
          updated_at: NaiveDateTime.utc_now() |> NaiveDateTime.truncate(:second)
        }

        case insert_standalone(db_params) do
          {:ok, _} ->
            Phoenix.PubSub.broadcast(
              EventDefinition.PubSub,
              "global_events",
              {:org_created, org_id}
            )

            {:noreply,
             socket
             |> put_flash(:info, "Événement personnalisé cré avec succès")
             |> push_navigate(to: ~p"/org-events")}

          {:error, error} ->
            form = to_form(params, as: :standalone_event)

            {:noreply,
             socket
             |> assign(:form, form)
             |> put_flash(:error, "Erreur : #{error}")}
        end

      {:error, msg} ->
        form = to_form(params, as: :standalone_event)

        {:noreply,
         socket
         |> assign(:form, form)
         |> assign(:trigger, trigger)
         |> put_flash(:error, msg)}
    end
  end

  @impl true
  def handle_event("preview", %{"standalone_event" => params}, socket) do
    {:noreply, assign(socket, :current_params, params)}
  end

  def build_rule(trigger, _params) when trigger in ["", nil], do: %{}

  def build_rule(trigger, params) do
    param_keys = @trigger_params[trigger] || []

    rule_params =
      Enum.reduce(param_keys, %{}, fn key, acc ->
        value = params["param_#{key}"] || ""
        trimmed = String.trim(value)

        case infer_type(trimmed) do
          {:int, v} -> Map.put(acc, key, v)
          {:float, v} -> Map.put(acc, key, v)
          :skip -> acc
          {:string, v} -> Map.put(acc, key, v)
        end
      end)

    Map.put(rule_params, "trigger", trigger)
  end

  defp infer_type(""), do: :skip

  defp infer_type(str) do
    case Integer.parse(str) do
      {int, ""} ->
        {:int, int}

      _ ->
        case Float.parse(str) do
          {float, ""} -> {:float, float}
          _ -> {:string, str}
        end
    end
  end

  def param_info(param) do
    case param do
      "threshold_kmh" ->
        %{
          label: "Seuil (km/h)",
          type: "number",
          placeholder: "80",
          hint: "Vitesse déclenchant l'événement"
        }

      "min_duration_seconds" ->
        %{
          label: "Durée minimum (s)",
          type: "number",
          placeholder: "5",
          hint: "Temps minimum de dépassement"
        }

      "duration_minutes" ->
        %{
          label: "Durée (min)",
          type: "number",
          placeholder: "30",
          hint: "Durée d'inactivité avant alerte"
        }

      "feature_collection_id" ->
        %{
          label: "ID de la collection géo",
          type: "text",
          placeholder: "UUID de la zone/POI",
          hint: "Référence vers une zone ou un point d'intérêt"
        }

      "report_interval_minutes" ->
        %{
          label: "Intervalle de rapport (min)",
          type: "number",
          placeholder: "15",
          hint: "Fréquence de génération des rapports"
        }

      "drop_percent" ->
        %{
          label: "Seuil de baisse (%)",
          type: "number",
          placeholder: "20",
          hint: "Pourcentage de chute de carburant"
        }

      "window_minutes" ->
        %{
          label: "Fenêtre de détection (min)",
          type: "number",
          placeholder: "5",
          hint: "Période d'observation de la baisse"
        }

      "min_distance_meters" ->
        %{
          label: "Distance minimum (m)",
          type: "number",
          placeholder: "500",
          hint: "Distance parcourue minimum pour le déclenchement"
        }

      _ ->
        %{label: "Valeur", type: "text", placeholder: "", hint: ""}
    end
  end

  defp load_feature_collections do
    Repo.query!(
      "SELECT DISTINCT occurrence_rule->>'feature_collection_id' FROM organization_event_definitions WHERE occurrence_rule ? 'feature_collection_id' ORDER BY 1",
      []
    ).rows
    |> List.flatten()
    |> Enum.reject(&is_nil/1)
  rescue
    _ -> []
  end

  defp load_org(id) do
    binary_id = Ecto.UUID.cast!(id)

    from(o in "organizations",
      where: o.id == type(^binary_id, Ecto.UUID),
      select: %{id: o.id, name: o.name, slug: o.slug}
    )
    |> Repo.one()
    |> case do
      nil -> nil
      org -> %{org | id: normalize_uuid(org.id)}
    end
  end

  defp insert_standalone(params) do
    Repo.insert_all("organization_event_definitions", [params])
    {:ok, params}
  rescue
    e ->
      message = Exception.message(e)
      require Logger
      Logger.error("Insert standalone failed: #{message}")
      {:error, message}
  end

  defp validate_occurrence_rule(rule) do
    cond do
      rule == %{} ->
        {:error, "La règle d'occurrence ne peut pas être vide pour un événement autonome"}

      not Map.has_key?(rule, "trigger") ->
        {:error, "La règle doit contenir un déclencheur valide"}

      Map.get(rule, "trigger") in [nil, ""] ->
        {:error, "Veuillez sélectionner un déclencheur"}

      true ->
        :ok
    end
  end

  defp empty_to_nil(""), do: nil
  defp empty_to_nil(v), do: v

  defp distinct_values(field) do
    from(e in "event_definitions",
      select: field(e, ^field),
      distinct: true,
      order_by: field(e, ^field)
    )
    |> Repo.all()
    |> Enum.reject(fn v -> is_nil(v) or v == "" end)
  end

  defp uuid_bin!(str) do
    {:ok, bin} = Ecto.UUID.dump(str)
    bin
  end

  defp normalize_uuid(id) when is_binary(id) do
    case Ecto.UUID.load(id) do
      {:ok, uuid} -> uuid
      :error -> id
    end
  end

  defp normalize_uuid(id), do: to_string(id)
end
