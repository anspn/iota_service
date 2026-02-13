defmodule IotaService.Web.Frontend.Templates do
  @moduledoc """
  Compiled EEx templates for the server-side rendered frontend.

  Templates are compiled at build time from the `templates/` directory
  alongside this module.
  """

  require EEx

  @template_dir Path.expand("templates", __DIR__)

  # Compile each template into a render function
  EEx.function_from_file(:defp, :layout_html, Path.join(@template_dir, "layout.html.eex"), [
    :assigns
  ])

  EEx.function_from_file(:defp, :home_html, Path.join(@template_dir, "home.html.eex"), [
    :assigns
  ])

  EEx.function_from_file(:defp, :identity_html, Path.join(@template_dir, "identity.html.eex"), [
    :assigns
  ])

  EEx.function_from_file(:defp, :login_html, Path.join(@template_dir, "login.html.eex"), [
    :assigns
  ])

  @doc "Render a named template wrapped in the layout."
  @spec render(atom(), map()) :: String.t()
  def render(template, assigns \\ %{}) do
    inner = render_inner(template, assigns)

    layout_html(%{
      title: page_title(template),
      active: template,
      inner_content: inner
    })
  end

  defp render_inner(:home, assigns), do: home_html(assigns)
  defp render_inner(:identity, assigns), do: identity_html(assigns)
  defp render_inner(:login, assigns), do: login_html(assigns)

  defp page_title(:home), do: "Dashboard — IOTA Service"
  defp page_title(:identity), do: "Identity — IOTA Service"
  defp page_title(:login), do: "Login — IOTA Service"
  defp page_title(_), do: "IOTA Service"
end
