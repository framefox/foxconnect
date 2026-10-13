require "test_helper"

class CustomPrintSizeTest < ActiveSupport::TestCase
  test "new sizes require an explicit paper or canvas material" do
    size = build_size
    assert size.valid?
    size.material_type = "canvas"
    assert size.valid?
    [nil, "", "cotton"].each do |material|
      size.material_type = material
      assert_not size.valid?
      assert size.errors[:material_type].any?
    end
  end

  test "description distinguishes identical dimensions by material" do
    size = build_size
    assert_equal "Paper · 40×40cm (Priced as 40×40cm)", size.full_description
    size.material_type = "canvas"
    size.frame_sku_size_description = "420×420mm"
    assert_equal "Canvas · 40×40cm (Priced as 420×420mm)", size.full_description
  end

  test "legacy sizes remain readable without assuming their material" do
    size = build_size
    size.save!
    size.update_column(:material_type, nil)
    assert_nil size.reload.material_type
    assert_includes size.full_description, "Confirm material"
    assert size.valid?
  end

  private

  def build_size
    users(:one).custom_print_sizes.build(long: 40, short: 40, unit: "cm",
      material_type: "paper", frame_sku_size_id: 1, frame_sku_size_description: "40×40cm")
  end
end
