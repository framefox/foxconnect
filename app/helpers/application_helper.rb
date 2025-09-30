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
end
