module ApplicationHelper
  # Include Pagy Frontend for pagination helpers
  include Pagy::Frontend

  # Toast notification helpers
  def toast_success(message)
    flash[:notice] = message
  end

  def toast_error(message)
    flash[:alert] = message
  end

  def toast_warning(message)
    flash[:warning] = message
  end

  def toast_info(message)
    flash[:info] = message
  end

  def order_state_badge(order)
    case order.aasm_state
    when "draft"
      content_tag :span, class: "inline-flex items-center rounded-full bg-slate-100 px-2.5 py-0.5 text-xs font-medium text-slate-800" do
        concat tag.i(class: "fa-solid fa-file-lines w-3 h-3 mr-1")
        concat "Draft"
      end
    when "awaiting_production"
      content_tag :span, class: "inline-flex items-center rounded-full bg-yellow-100 px-2.5 py-0.5 text-xs font-medium text-yellow-800" do
        concat tag.i(class: "fa-solid fa-clock w-3 h-3 mr-1")
        concat "Awaiting Production"
      end
    when "in_production"
      content_tag :span, class: "inline-flex items-center rounded-full bg-blue-100 px-2.5 py-0.5 text-xs font-medium text-blue-800" do
        concat tag.i(class: "fa-solid fa-gear w-3 h-3 mr-1")
        concat "In Production"
      end
    when "cancelled"
      content_tag :span, class: "inline-flex items-center rounded-full bg-red-100 px-2.5 py-0.5 text-xs font-medium text-red-800" do
        concat tag.i(class: "fa-solid fa-times-circle w-3 h-3 mr-1")
        concat "Cancelled"
      end
    else
      content_tag :span, class: "inline-flex items-center rounded-full bg-gray-100 px-2.5 py-0.5 text-xs font-medium text-gray-800" do
        order.aasm_state.humanize
      end
    end
  end

  def render_icon(icon_name)
    icon_classes = "w-5 h-5"

    case icon_name
    when "dashboard"
      content_tag(:svg, class: icon_classes, fill: "none", stroke: "currentColor", viewBox: "0 0 24 24") do
        content_tag(:path, nil,
          "stroke-linecap": "round",
          "stroke-linejoin": "round",
          "stroke-width": "2",
          d: "M9 19v-6a2 2 0 00-2-2H5a2 2 0 00-2 2v6a2 2 0 002 2h2a2 2 0 002-2zm0 0V9a2 2 0 012-2h2a2 2 0 012 2v10m-6 0a2 2 0 002 2h2a2 2 0 002-2m0 0V5a2 2 0 012-2h2a2 2 0 012 2v14a2 2 0 01-2 2h-2a2 2 0 01-2-2z"
        )
      end
    when "stores"
      content_tag(:svg, class: icon_classes, fill: "none", stroke: "currentColor", viewBox: "0 0 24 24") do
        content_tag(:path, nil,
          "stroke-linecap": "round",
          "stroke-linejoin": "round",
          "stroke-width": "2",
          d: "M19 21V5a2 2 0 00-2-2H7a2 2 0 00-2 2v16m14 0h2m-2 0h-5m-9 0H3m2 0h5M9 7h1m-1 4h1m4-4h1m-1 4h1m-5 10v-5a1 1 0 011-1h1a1 1 0 011 1v5m-4 0h4"
        )
      end
    when "orders"
      content_tag(:svg, class: icon_classes, fill: "none", stroke: "currentColor", viewBox: "0 0 24 24") do
        content_tag(:path, nil,
          "stroke-linecap": "round",
          "stroke-linejoin": "round",
          "stroke-width": "2",
          d: "M9 12h6m-6 4h6m2 5H7a2 2 0 01-2-2V5a2 2 0 012-2h5.586a1 1 0 01.707.293l5.414 5.414a1 1 0 01.293.707V19a2 2 0 01-2 2z"
        )
      end
    when "admin"
      content_tag(:svg, class: icon_classes, fill: "none", stroke: "currentColor", viewBox: "0 0 24 24") do
        concat content_tag(:path, nil,
          "stroke-linecap": "round",
          "stroke-linejoin": "round",
          "stroke-width": "2",
          d: "M10.325 4.317c.426-1.756 2.924-1.756 3.35 0a1.724 1.724 0 002.573 1.066c1.543-.94 3.31.826 2.37 2.37a1.724 1.724 0 001.065 2.572c1.756.426 1.756 2.924 0 3.35a1.724 1.724 0 00-1.066 2.573c.94 1.543-.826 3.31-2.37 2.37a1.724 1.724 0 00-2.572 1.065c-.426 1.756-2.924 1.756-3.35 0a1.724 1.724 0 00-2.573-1.066c-1.543.94-3.31-.826-2.37-2.37a1.724 1.724 0 00-1.065-2.572c-1.756-.426-1.756-2.924 0-3.35a1.724 1.724 0 001.066-2.573c-.94-1.543.826-3.31 2.37-2.37.996.608 2.296.07 2.572-1.065z"
        )
        concat content_tag(:path, nil,
          "stroke-linecap": "round",
          "stroke-linejoin": "round",
          "stroke-width": "2",
          d: "M15 12a3 3 0 11-6 0 3 3 0 016 0z"
        )
      end
    when "settings"
      content_tag(:svg, class: icon_classes, fill: "none", stroke: "currentColor", viewBox: "0 0 24 24") do
        concat content_tag(:path, nil,
          "stroke-linecap": "round",
          "stroke-linejoin": "round",
          "stroke-width": "2",
          d: "M10.325 4.317c.426-1.756 2.924-1.756 3.35 0a1.724 1.724 0 002.573 1.066c1.543-.94 3.31.826 2.37 2.37a1.724 1.724 0 001.065 2.572c1.756.426 1.756 2.924 0 3.35a1.724 1.724 0 00-1.066 2.573c.94 1.543-.826 3.31-2.37 2.37a1.724 1.724 0 00-2.572 1.065c-.426 1.756-2.924 1.756-3.35 0a1.724 1.724 0 00-2.573-1.066c-1.543.94-3.31-.826-2.37-2.37a1.724 1.724 0 00-1.065-2.572c-1.756-.426-1.756-2.924 0-3.35a1.724 1.724 0 001.066-2.573c-.94-1.543.826-3.31 2.37-2.37.996.608 2.296.07 2.572-1.065z"
        )
        concat content_tag(:path, nil,
          "stroke-linecap": "round",
          "stroke-linejoin": "round",
          "stroke-width": "2",
          d: "M15 12a3 3 0 11-6 0 3 3 0 016 0z"
        )
      end
    when "billing"
      content_tag(:svg, class: icon_classes, fill: "none", stroke: "currentColor", viewBox: "0 0 24 24") do
        content_tag(:path, nil,
          "stroke-linecap": "round",
          "stroke-linejoin": "round",
          "stroke-width": "2",
          d: "M3 10h18M7 15h1m4 0h1m-7 4h12a3 3 0 003-3V8a3 3 0 00-3-3H6a3 3 0 00-3 3v8a3 3 0 003 3z"
        )
      end
    when "api"
      content_tag(:svg, class: icon_classes, fill: "none", stroke: "currentColor", viewBox: "0 0 24 24") do
        content_tag(:path, nil,
          "stroke-linecap": "round",
          "stroke-linejoin": "round",
          "stroke-width": "2",
          d: "M15 7a2 2 0 012 2m4 0a6 6 0 01-7.743 5.743L11 17H9v2H7v2H4a1 1 0 01-1-1v-2.586a1 1 0 01.293-.707l5.964-5.964A6 6 0 1721 9z"
        )
      end
    else
      content_tag(:svg, class: icon_classes, fill: "none", stroke: "currentColor", viewBox: "0 0 24 24") do
        content_tag(:path, nil,
          "stroke-linecap": "round",
          "stroke-linejoin": "round",
          "stroke-width": "2",
          d: "M12 6V4m0 2a2 2 0 100 4m0-4a2 2 0 110 4m-6 8a2 2 0 100-4m0 4a2 2 0 100 4m0-4v2m0-6V4m6 6v10m6-2a2 2 0 100-4m0 4a2 2 0 100 4m0-4v2m0-6V4"
        )
      end
    end
  end
end
