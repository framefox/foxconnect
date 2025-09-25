module ReactHelper
  def react_component(name, props = {}, html_options = {})
    content_tag :div, "", {
      data: {
        react_component: name,
        react_props: props.to_json
      }
    }.merge(html_options)
  end
end
