module ReactHelper
  # Helper method to render React components in Rails views
  #
  # Usage:
  #   <%= react_component("HelloReact", { name: "John", message: "Welcome!" }) %>
  #   <%= react_component("HelloReact") %>
  #
  def react_component(component_name, props = {})
    content_tag :div,
                "",
                data: {
                  react_component: component_name,
                  react_props: props.to_json
                }
  end
end
