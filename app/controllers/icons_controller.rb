# frozen_string_literal: true

# Controller to serve SVG icons for React components
class IconsController < ApplicationController
  skip_before_action :verify_authenticity_token, only: [ :show ]

  def show
    icon_name = params[:name]
    file_path = Rails.root.join("app", "assets", "images", "icons", "#{icon_name}.svg")

    if File.exist?(file_path)
      svg_content = File.read(file_path)
      render plain: svg_content, content_type: "image/svg+xml"
    else
      head :not_found
    end
  end
end
