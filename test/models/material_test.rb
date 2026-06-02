require "test_helper"

class MaterialTest < ActiveSupport::TestCase
  setup do
    @user = User.create!(email_address: "mat@example.com", password: "password123", name: "Mat")
  end

  def attach_png(material)
    material.file.attach(io: StringIO.new("x"), filename: "a.png", content_type: "image/png")
    material
  end

  test "file-type material is valid" do
    m = attach_png(Material.new(user: @user, title: "図"))
    assert m.valid?, m.errors.full_messages.join(", ")
  end

  test "belongs to a page optionally" do
    page = Page.create!(title: "P", created_by: @user)
    m = attach_png(Material.new(user: @user, page: page))
    assert m.save
    assert_equal page, m.reload.page
  end
end
