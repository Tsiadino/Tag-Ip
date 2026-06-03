defmodule EventDefinitionWeb.OrgEventStandaloneNewLiveTest do
  use EventDefinitionWeb.ConnCase

  import Phoenix.LiveViewTest
  import Ecto.Query, only: [from: 2]

  alias EventDefinition.Repo
  alias EventDefinition.Accounts.Auth

  setup do
    now = NaiveDateTime.utc_now() |> NaiveDateTime.truncate(:second)

    Repo.insert_all("organizations", [
      [name: "Test Corp", slug: "test_corp", inserted_at: now, updated_at: now]
    ])

    org =
      from(o in "organizations", where: o.slug == "test_corp", select: %{id: o.id})
      |> Repo.one()

    {:ok, user} =
      Auth.register_user(%{
        email: "test@example.com",
        password: "password123",
        password_confirmation: "password123"
      })

    conn =
      build_conn()
      |> Plug.Test.init_test_session(%{})
      |> Plug.Conn.put_session(:user_id, user.id)

    %{org_id: org.id, conn: conn}
  end

  test "renders form for valid org", %{conn: conn, org_id: org_id} do
    {:ok, view, _html} = live(conn, ~p"/org-events/#{org_id}/new-standalone")

    assert has_element?(view, "#standalone-event-form")
    assert render(view) =~ "Nouvel événement personnalisé"
    assert render(view) =~ "Test Corp"
  end

  test "breadcrumb links to org-events", %{conn: conn, org_id: org_id} do
    {:ok, view, _html} = live(conn, ~p"/org-events/#{org_id}/new-standalone")

    html = render(view)
    assert html =~ "/org-events"
    assert html =~ "Config. organisations"
  end
end
