defmodule EventDefinitionWeb.MonitoringLive do
  use EventDefinitionWeb, :live_view

  @impl true
  def mount(_params, _session, socket) do
    if connected?(socket),
      do: Phoenix.PubSub.subscribe(EventDefinition.PubSub, "monitoring_alerts")

    organizations = EventDefinition.Accounts.Organization |> Ash.read!()

    event_types =
      EventDefinition.Events.EventDefinition
      |> Ash.read!()
      |> Enum.map(& &1.name)
      |> Enum.uniq()
      |> Enum.sort()

    alert_logs =
      EventDefinition.Events.AlertLog
      |> Ash.Query.sort(timestamp: :desc)
      |> Ash.Query.limit(10)
      |> Ash.Query.load([:organization])
      |> Ash.read!()

    audit_logs =
      EventDefinition.Events.AuditLog
      |> Ash.Query.sort(timestamp: :desc)
      |> Ash.Query.limit(10)
      |> Ash.read!()

    monitoring_config = %{
      polling_interval: 30,
      webhook_url: "https://webhook.site/7e5a7841-0982-411c-83bd-7a7ce6bd7483",
      email_alert: "fannie@event-definition.com",
      logs_enabled: true
    }

    {:ok,
     assign(socket,
       organizations: organizations,
       event_types: event_types,
       selected_org_id: (List.first(organizations) || %{id: nil}).id,
       selected_event: List.first(event_types) || "Aucun événement disponible",
       alert_logs: alert_logs,
       audit_logs: audit_logs,
       monitoring_config: monitoring_config
     )}
  end

  @impl true
  def handle_info({:new_alert, alert}, socket) do
    alert_loaded = Ash.load!(alert, [:organization])
    # Conserver uniquement les 10 dernières alertes à l'écran pour la performance
    updated_alerts = [alert_loaded | socket.assigns.alert_logs] |> Enum.take(10)

    {:noreply,
     socket
     |> assign(alert_logs: updated_alerts)
     |> put_flash(:info, "🔔 Nouvelle alerte reçue : #{alert_loaded.event_code}")}
  end

  @impl true
  def handle_event("validate_config", %{"config" => params}, socket) do
    {:noreply,
     assign(socket,
       selected_org_id: params["organization_id"],
       selected_event: params["event_name"]
     )}
  end

  @impl true
  def handle_event("update_config", %{"config" => params}, socket) do
    new_config = %{
      polling_interval: String.to_integer(params["polling_interval"]),
      webhook_url: params["webhook_url"],
      email_alert: params["email_alert"],
      logs_enabled: params["logs_enabled"] == "true"
    }

    org_id = params["organization_id"]
    event_name = params["event_name"]

    if org_id do
      org =
        EventDefinition.Accounts.Organization
        |> Ash.get!(org_id)

      merged_config = Map.merge(org.config || %{}, new_config)

      org
      |> Ash.Changeset.for_update(:update, %{config: merged_config})
      |> Ash.update!()
    end

    now = DateTime.utc_now() |> DateTime.truncate(:second)

    audit_params = %{
      organization_id: org_id,
      event_id: "config_update",
      action: "Modification Config",
      details: %{polling_interval: params["polling_interval"], webhook_url: params["webhook_url"]},
      user: "Fannie",
      timestamp: now
    }

    EventDefinition.Events.AuditLog
    |> Ash.Changeset.for_create(:create, audit_params)
    |> Ash.create!()

    updated_audit_logs =
      EventDefinition.Events.AuditLog
      |> Ash.Query.sort(timestamp: :desc)
      |> Ash.Query.limit(10)
      |> Ash.read!()

    {:noreply,
     socket
     |> assign(monitoring_config: new_config, audit_logs: updated_audit_logs)
     |> assign(selected_org_id: org_id)
     |> assign(selected_event: event_name)
     |> push_event("show_toast", %{
       type: "success",
       message: "Configuration sauvegardée avec succès"
     })
     |> put_flash(:info, "Configuration mise à jour et audité avec succès")}
  end

  @impl true
  def handle_event("test_webhook", _params, socket) do
    webhook_url = socket.assigns.monitoring_config.webhook_url

    alert_params = %{
      event_code: socket.assigns.selected_event,
      organization_id: socket.assigns.selected_org_id,
      alert_type: "webhook_test",
      severity: "info",
      message: "Test webhook pour #{socket.assigns.selected_event}",
      timestamp: DateTime.utc_now() |> DateTime.truncate(:second)
    }

    case EventDefinition.Events.AlertLog
         |> Ash.Changeset.for_create(:create, alert_params)
         |> Ash.create() do
      {:ok, new_alert} ->
        Phoenix.PubSub.broadcast(
          EventDefinition.PubSub,
          "monitoring_alerts",
          {:new_alert, new_alert}
        )

        webhook_result =
          case Req.post(webhook_url, json: alert_params, receive_timeout: 5000) do
            {:ok, %{status: status}} when status in 200..299 ->
              {:ok, status}

            {:ok, %{status: status}} ->
              {:error, "HTTP #{status}"}

            {:error, reason} ->
              {:error, inspect(reason)}
          end

        now = DateTime.utc_now() |> DateTime.truncate(:second)

        {webhook_status, webhook_response} =
          case webhook_result do
            {:ok, status} -> {"success", "HTTP #{status}"}
            {:error, reason} -> {"error", reason}
          end

        audit_params = %{
          organization_id: socket.assigns.selected_org_id,
          event_id: "webhook_test",
          action: "Test Webhook",
          details: %{
            event_code: alert_params.event_code,
            message: alert_params.message,
            webhook_status: webhook_status,
            webhook_response: webhook_response
          },
          user: "Fannie",
          timestamp: now
        }

        EventDefinition.Events.AuditLog
        |> Ash.Changeset.for_create(:create, audit_params)
        |> Ash.create()

        updated_audit_logs =
          EventDefinition.Events.AuditLog
          |> Ash.Query.sort(timestamp: :desc)
          |> Ash.Query.limit(10)
          |> Ash.read!()

        {toast_type, toast_msg} =
          case webhook_result do
            {:ok, _} ->
              {"success", "Webhook vérifié avec succès pour #{alert_params.event_code}"}

            {:error, reason} ->
              {"warning", "Webhook : #{reason} pour #{alert_params.event_code}"}
          end

        {:noreply,
         socket
         |> assign(audit_logs: updated_audit_logs)
         |> push_event("show_toast", %{
           type: toast_type,
           message: toast_msg
         })
         |> put_flash(:info, toast_msg)}

      {:error, _} ->
        {:noreply, put_flash(socket, :error, "Erreur d'enregistrement PostgreSQL")}
    end
  end
end
